#import "BIFFAppDelegate.h"

@implementation BIFFAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    maildir = [inboxPath stringByExpandingTildeInPath];
    [self updateStatusText];
    fseventStream = [self startObserving:maildir latency:1 block:^{
        [self updateStatusText];
    }];
}

- (FSEventStreamRef)startObserving:(NSString *)path
                           latency:(CFTimeInterval)latency
                             block:(void(^)())block {
    void *blockptr = (void *)CFBridgingRetain(block);
    FSEventStreamContext context = { 0, blockptr, NULL, fseventCallbackRelease, NULL };
    FSEventStreamRef stream = FSEventStreamCreate(NULL, fseventCallback, &context, (__bridge CFArrayRef)@[path], kFSEventStreamEventIdSinceNow, latency, 0);
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
    return stream;
}

- (void)stopObserving:(FSEventStreamRef)stream {
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
    FSEventStreamRelease(stream);
}

- (void)awakeFromNib {
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
}

- (void) updateStatusText {
    int unreadCount = [self countUnreadEmails];
    NSString *text;
    if (unreadCount == 0) {
        text = @"📭";
    } else {
        text = [NSString stringWithFormat:@"📬 %d", unreadCount, nil];
    }
    [statusItem setTitle:text];
}

static NSString *unreadFilePattern = @":[^S]+$";

- (int)countUnreadEmails {
    int count = 0;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSDirectoryEnumerator *iter = [fm enumeratorAtPath:maildir];

    NSRegularExpression *unreadRegexp =
        [NSRegularExpression regularExpressionWithPattern:unreadFilePattern
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];

    for (NSString* file in iter) {
        NSDictionary *attr = [iter fileAttributes];
        bool isDir = [[attr fileType] isEqualToString:NSFileTypeDirectory];

        if ([iter level] == 1) {
            // filter everything except {cur,new}/*
            if (isDir) {
                if (([file caseInsensitiveCompare:@"cur"] != NSOrderedSame)
                    && ([file caseInsensitiveCompare:@"new"] != NSOrderedSame)) {
                    [iter skipDescendants];
                }
            }
            continue;
        } else if ([iter level] == 2 && isDir) {
            // ignore subdirectories
            [iter skipDescendants];
            continue;
        }

        NSRange r = NSMakeRange(0, [file length]);
        if ([unreadRegexp numberOfMatchesInString:file options:0 range:r] > 0) {
            count++;
        }
    }

    NSLog(@"unread count in %@ is %d", maildir, count);
    return count;
}

@end

static void fseventCallback(ConstFSEventStreamRef streamRef,
                            void *clientCallBackInfo,
                            size_t numEvents,
                            void *eventPaths,
                            const FSEventStreamEventFlags eventFlags[],
                            const FSEventStreamEventId eventIds[]) {
    void (^block)() = (__bridge void (^)())(clientCallBackInfo);
    block();
}

static void fseventCallbackRelease(const void *info) {
    CFBridgingRelease(info);
}
