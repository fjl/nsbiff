#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

@interface BIFFAppDelegate : NSObject <NSApplicationDelegate> {
    NSStatusItem *statusItem;
    IBOutlet NSMenu *statusMenu;

    FSEventStreamRef fseventStream;
    NSString *maildir;
}

- (IBAction) updateStatusText;

@end

static const NSString *inboxPath = @"~/Mail/INBOX";

static void fseventCallback(ConstFSEventStreamRef streamRef,
                            void *clientCallBackInfo,
                            size_t numEvents,
                            void *eventPaths,
                            const FSEventStreamEventFlags eventFlags[],
                            const FSEventStreamEventId eventIds[]);

static void fseventCallbackRelease(const void *info);
