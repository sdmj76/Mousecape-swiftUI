//
//  listen.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "listen.h"
#import "apply.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "MCPrefs.h"
#import "CGSCursor.h"
#import <Cocoa/Cocoa.h>
#import "scale.h"

NSString *appliedCapePathForUser(NSString *user) {
    // Validate user - must not be empty or contain path separators
    if (!user || user.length == 0 || [user containsString:@"/"] || [user containsString:@".."]) {
        MMLog(BOLD RED "Invalid username" RESET);
        return nil;
    }

    NSString *home = NSHomeDirectoryForUser(user);
    if (!home) {
        MMLog(BOLD RED "Could not get home directory for user" RESET);
        return nil;
    }

    NSString *ident = MCDefaultFor(@"MCAppliedCursor", user, (NSString *)kCFPreferencesCurrentHost);

    // Validate identifier - remove any path traversal attempts
    if (ident && ([ident containsString:@"/"] || [ident containsString:@".."])) {
        MMLog(BOLD RED "Invalid cape identifier" RESET);
        return nil;
    }

    if (!ident || ident.length == 0) {
        return nil;
    }

    NSString *appSupport = [home stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *capePath = [[[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByAppendingPathComponent:ident] stringByAppendingPathExtension:@"cape"];

    // Ensure the final path is within the expected directory
    NSString *standardPath = [capePath stringByStandardizingPath];
    NSString *expectedPrefix = [[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByStandardizingPath];
    if (![standardPath hasPrefix:expectedPrefix]) {
        MMLog(BOLD RED "Path traversal detected" RESET);
        return nil;
    }

    return capePath;
}

static void UserSpaceChanged(SCDynamicStoreRef	store, CFArrayRef changedKeys, void *info) {
    MMLog("========================================");
    MMLog("=== USER SPACE CHANGED EVENT ===");
    MMLog("========================================");

    CFStringRef currentConsoleUser = SCDynamicStoreCopyConsoleUser(store, NULL, NULL);

    MMLog("Console user: %s", currentConsoleUser ? [(__bridge NSString *)currentConsoleUser UTF8String] : "(null)");
    MMLog("Changed keys count: %ld", CFArrayGetCount(changedKeys));

    if (!currentConsoleUser || CFEqual(currentConsoleUser, CFSTR("loginwindow"))) {
        MMLog("Skipping - loginwindow or no user");
        if (currentConsoleUser) CFRelease(currentConsoleUser);
        return;
    }

    NSString *appliedPath = appliedCapePathForUser((__bridge NSString *)currentConsoleUser);
    MMLog(BOLD GREEN "User Space Changed to %s, applying cape..." RESET, [(__bridge NSString *)currentConsoleUser UTF8String]);
    MMLog("Cape path: %s", appliedPath ? appliedPath.UTF8String : "(none)");

    // Only attempt to apply if there's a valid cape path
    if (appliedPath) {
        BOOL success = applyCapeAtPath(appliedPath);
        MMLog("Apply result: %s", success ? "SUCCESS" : "FAILED");
        if (!success) {
            MMLog(BOLD RED "Application of cape failed" RESET);
        }
    } else {
        MMLog("No cape configured for user");
    }

    setCursorScale(defaultCursorScale());
    MMLog("Cursor scale applied");

    CFRelease(currentConsoleUser);
}

void reconfigurationCallback(CGDirectDisplayID display,
    	CGDisplayChangeSummaryFlags flags,
    	void *userInfo) {
    MMLog("========================================");
    MMLog("=== DISPLAY RECONFIGURATION EVENT ===");
    MMLog("========================================");
    MMLog("Display ID: %u", display);
    MMLog("Flags: 0x%x", flags);
    MMLog("  kCGDisplayBeginConfigurationFlag: %s", (flags & kCGDisplayBeginConfigurationFlag) ? "YES" : "NO");
    MMLog("  kCGDisplaySetMainFlag: %s", (flags & kCGDisplaySetMainFlag) ? "YES" : "NO");
    MMLog("  kCGDisplayAddFlag: %s", (flags & kCGDisplayAddFlag) ? "YES" : "NO");
    MMLog("  kCGDisplayRemoveFlag: %s", (flags & kCGDisplayRemoveFlag) ? "YES" : "NO");

    NSString *capePath = appliedCapePathForUser(NSUserName());
    MMLog("Cape path: %s", capePath ? capePath.UTF8String : "(none)");
    if (capePath) {
        BOOL success = applyCapeAtPath(capePath);
        MMLog("Apply result: %s", success ? "SUCCESS" : "FAILED");
    }
    float scale;
    CGSGetCursorScale(CGSMainConnectionID(), &scale);
    MMLog("Current cursor scale: %.2f", scale);
    CGSSetCursorScale(CGSMainConnectionID(), scale + .3);
    CGSSetCursorScale(CGSMainConnectionID(), scale);
    MMLog("Cursor scale refreshed");
}


void listener(void) {
#ifdef DEBUG
    MCLoggerInit();
#endif

    MMLog("========================================");
    MMLog("=== MOUSECAPE HELPER DAEMON STARTED ===");
    MMLog("========================================");

    NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
    MMLog("macOS version: %ld.%ld.%ld",
          (long)ver.majorVersion, (long)ver.minorVersion, (long)ver.patchVersion);
    MMLog("Process: %s (PID: %d)",
          [[[NSProcessInfo processInfo] processName] UTF8String],
          [[NSProcessInfo processInfo] processIdentifier]);
    MMLog("User: %s", NSUserName().UTF8String);
    MMLog("Home: %s", NSHomeDirectory().UTF8String);

    // Log environment variables
    MMLog("--- Environment Variables ---");
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    for (NSString *key in @[@"USER", @"HOME", @"DISPLAY", @"XPC_SERVICE_NAME"]) {
        MMLog("  %s = %s", key.UTF8String, [env[key] UTF8String] ?: "(null)");
    }

    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), UserSpaceChanged, NULL);
    assert(store != NULL);

    CFStringRef key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    assert(key != NULL);

    CFArrayRef keys = CFArrayCreate(NULL, (const void **)&key, 1, &kCFTypeArrayCallBacks);
    assert(keys != NULL);

    Boolean success = SCDynamicStoreSetNotificationKeys(store, keys, NULL);
    assert(success);

    NSApplicationLoad();
    CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, NULL);
    MMLog(BOLD CYAN "Listening for Display changes" RESET);

    CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    assert(rls != NULL);
    MMLog(BOLD CYAN "Listening for User changes" RESET);

    // Check CGS Connection
    MMLog("--- Checking CGS Connection ---");
    CGSConnectionID cid = CGSMainConnectionID();
    MMLog("CGSMainConnectionID: %d", cid);

    // Apply the cape for the user on load (if configured)
    MMLog("--- Initial Cape Check ---");
    NSString *initialCapePath = appliedCapePathForUser(NSUserName());
    MMLog("Cape path: %s", initialCapePath ? initialCapePath.UTF8String : "(none)");
    if (initialCapePath) {
        MMLog("--- Applying initial cape ---");
        BOOL applySuccess = applyCapeAtPath(initialCapePath);
        MMLog("Initial apply result: %s", applySuccess ? "SUCCESS" : "FAILED");
    } else {
        MMLog("No cape configured - running in standby mode");
    }
    setCursorScale(defaultCursorScale());
    MMLog("Initial cursor scale applied");

    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
    MMLog("Entering run loop...");
    CFRunLoopRun();

    // Cleanup
    MMLog("Exiting run loop, cleaning up...");
    CFRunLoopSourceInvalidate(rls);
    CFRelease(rls);
    CFRelease(keys);
    CFRelease(key);
    CFRelease(store);

#ifdef DEBUG
    MCLoggerClose();
#endif
}