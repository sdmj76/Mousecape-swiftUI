//
//  restore.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "backup.h"
#import "apply.h"
#import "MCPrefs.h"
#import "MCDefs.h"

NSString *restoreStringForIdentifier(NSString *identifier) {
    NSString *prefix = @"com.alexzielenski.mousecape.";
    if ([identifier hasPrefix:prefix] && identifier.length > prefix.length) {
        return [identifier substringFromIndex:prefix.length];
    }
    return identifier;
}

void restoreCursorForIdentifier(NSString *ident) {
    MMLog("  Restoring: %s", ident.UTF8String);
    bool registered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)ident.UTF8String, &registered);

    NSString *restoreIdent = restoreStringForIdentifier(ident);
    NSDictionary *cape = capeWithIdentifier(ident);

    MMLog("    Restore target: %s, registered: %s, cape: %s",
          restoreIdent.UTF8String,
          registered ? "YES" : "NO",
          cape ? "YES" : "NO");

    if (cape && registered) {
        BOOL success = applyCapeForIdentifier(cape, restoreIdent, YES);
        MMLog("    Restore result: %s", success ? "SUCCESS" : "FAILED");
    } else {
        MMLog("    Skipped - no cape or not registered");
    }

    CGSRemoveRegisteredCursor(CGSMainConnectionID(), (char *)ident.UTF8String, false);
    MMLog("    Removed backup cursor");
}

void resetAllCursors() {
    MMLog("=== resetAllCursors ===");

    // Restore main cursors first
    MMLog("--- Restoring default cursors ---");
    NSUInteger i = 0;
    NSString *key = nil;
    while ((key = defaultCursors[i]) != nil) {
        restoreCursorForIdentifier(backupStringForIdentifier(key));
        i++;
    }

    // Also restore any Arrow synonyms that may have been backed up
    MMLog("--- Restoring Arrow synonyms ---");
    NSArray<NSString *> *synonyms = MCArrowSynonyms();
    for (NSString *name in synonyms) {
        restoreCursorForIdentifier(backupStringForIdentifier(name));
    }

    // And also restore I-beam synonyms
    MMLog("--- Restoring IBeam synonyms ---");
    NSArray<NSString *> *ibeamSynonyms = MCIBeamSynonyms();
    for (NSString *name in ibeamSynonyms) {
        restoreCursorForIdentifier(backupStringForIdentifier(name));
    }

    // Restore auxiliary/core cursors
    MMLog("--- Restoring core cursors ---");
    CGError err = CoreCursorUnregisterAll(CGSMainConnectionID());
    MMLog("CoreCursorUnregisterAll result: %d", err);

    if (err == 0) {
        MCSetDefault(NULL, MCPreferencesAppliedCursorKey);

        for (int x = 0; x < 45; x++) {
            CoreCursorSet(CGSMainConnectionID(), x);
        }

        MMLog(BOLD GREEN "Successfully restored all cursors." RESET);
    } else {
        MMLog(BOLD RED "Received an error while restoring core cursors." RESET);
    }
    MMLog("=== resetAllCursors complete ===");
}
