//
//  NoSleep_ControlAppDelegate.m
//  NoSleep-Control
//
//  Created by Pavel Prokofiev on 4/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NoSleep_ControlAppDelegate.h"
#import <IOKit/IOMessage.h>
#import <NoSleep/GlobalConstants.h>
#import <NoSleep/Utilities.h>

#include <signal.h>

@implementation NoSleep_ControlAppDelegate

@synthesize window;
@synthesize statusItemMenu;

@synthesize updater;

static void handleSIGTERM(int signum) {
    if([[((NoSleep_ControlAppDelegate *)[NSApp delegate]) updater] updateInProgress]) {
        return;
    }
    
    signal(signum, SIG_DFL);
    raise(signum);
}

- (IBAction)openPreferences:(id)sender {
    BOOL ret = [[NSWorkspace sharedWorkspace] openFile:@NOSLEEP_PREFPANE_PATH];
    if(ret == NO) {
        [[NSWorkspace sharedWorkspace] openFile:
         [NSHomeDirectory() stringByAppendingPathComponent: @NOSLEEP_PREFPANE_PATH]];
    }
}

- (void)showUnloadedExtensionDialog {
    SHOW_UI_ALERT_KEXT_NOT_LOADED();
}

- (void)applicationShouldBeTerminated:(BOOL)showUI {
    if(showUI) {
        [self showUnloadedExtensionDialog];
    }

    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (void)activateStatusMenu {
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    
    inactiveImage = [NSImage imageNamed:@"ZzInactive.pdf"];
    [inactiveImage setTemplate:YES];
    activeImage = [NSImage imageNamed:@"ZzActive.pdf"];
    // allow red ACTIVE image in status bar
    //[activeImage setTemplate:YES];
    
    if ([statusItem respondsToSelector:@selector(button)]) {
        [[statusItem button] setImage:inactiveImage];
    } else {
        [statusItem setImage:inactiveImage];
        [statusItem setHighlightMode:YES];
    }

    [statusItem setMenu:statusItemMenu];
}

- (void)menuWillOpen:(NSMenu *)menu {
    const NSUInteger pressedButtonMask = [NSEvent pressedMouseButtons];
    //const BOOL leftMouseDown = (pressedButtonMask & (1 << 0)) != 0;
    const BOOL rightMouseDown = (pressedButtonMask & (1 << 1)) != 0;

    // NOTE: using !rightClick b/c first time menu is opened, both left and right click values are 0
    if (!rightMouseDown) {
        // toggle active state
        if([noSleep stateForMode:kNoSleepModeCurrent]) {
            [self setEnabled:NSOffState];
        } else {
            [self setEnabled:NSOnState];
        }
        // dismiss menu (prevents it from displaying at all)
        [menu cancelTracking];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    signal(SIGTERM, handleSIGTERM);
    //[updater setUpdateCheckInterval:60*60*24*7];
    
    noSleep = [[NoSleepInterfaceWrapper alloc] init];
    if(noSleep == nil) {
        //NSString *kextUrl = [[NSBundle mainBundle] pathForResource:@"NoSleep" ofType:@"kext"];
        noSleep = [[NoSleepInterfaceWrapper alloc] init];
        if(noSleep == nil) {
            [self applicationShouldBeTerminated:YES];
            return;
        }
    }
    [noSleep setNotificationDelegate:self];
    
    [self activateStatusMenu];

    [statusItemMenu setDelegate:self];

    //[self updateSettings];
    
    //NSString *observedObject = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
    //NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    //[center addObserver: self
    //           selector: @selector(callbackWithNotification:)
    //               name: @NOSLEEP_SETTINGS_UPDATE_EVENTNAME
    //             object: observedObject];
    
    [self updateState:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [noSleep release];
}

- (void)dealloc {
    [super dealloc];
}

- (IBAction)updateState:(id)sender {
    if([noSleep stateForMode:kNoSleepModeCurrent]) {
        [self setEnabled:NSOnState];
    } else {
        [self setEnabled:NSOffState];
    }
}

- (NSCellStateValue)enabled {
    if ([noSleep stateForMode:kNoSleepModeCurrent]) {
        return NSOnState;
    } else {
        return NSOffState;
    }
}

- (void)setEnabled:(NSCellStateValue)value {
    NSImage *image;
    NSString *tooltip;
    BOOL newState;
    
    if(value == NSOnState) {
        newState = YES;
        image = activeImage;
        tooltip = @"NoSleep ON";
    } else {
        newState = NO;
        image = inactiveImage;
        tooltip = @"NoSleep OFF";
    }
    
    if(value != [self enabled]) {
        [noSleep setState:newState forMode:kNoSleepModeAC];
        [noSleep setState:newState forMode:kNoSleepModeBattery];
    }
    
    if ([statusItem respondsToSelector:@selector(button)]) {
        [[statusItem button] setImage:image];
    } else {
        [statusItem setImage:image];
    }
    [statusItem setToolTip:tooltip];
}

- (void)notificationReceived:(uint32_t)messageType :(void *)messageArgument
{
    switch (messageType) {
        case kIOMessageServiceIsTerminated:
            [self applicationShouldBeTerminated:NO];
            break;
        case kNoSleepCommandDisabled:
        case kNoSleepCommandEnabled:
            [self updateState:nil];
            break;
        case kNoSleepCommandLockScreenRequest:
            [self willLockScreen];
            break;
        default:
            break;
    }
}

/*
- (void)updateSettings {
    CFBooleanRef isBWIconEnabled = (CFBooleanRef)[[NSUserDefaults standardUserDefaults] valueForKey:@NOSLEEP_SETTINGS_isBWIconEnabledID];
    if(isBWIconEnabled == nil) {
        isBWIconEnabled = kCFBooleanFalse;
    }
}
*/

//- (void)callbackWithNotification:(NSNotification *)myNotification {
//    //[self updateSettings];
//}

- (void)willLockScreen {
    if(GetLockScreen()) {
        [self lockScreen:nil];
    }
}

- (IBAction)lockScreen:(id)sender {
    CFMessagePortRef portRef = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.apple.loginwindow.notify"));
    if(portRef) {
        CFMessagePortSendRequest(portRef, 0x258, 0, 0, 0, 0, 0);
        CFRelease(portRef);
    }
}

@end
