//
//  backup.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "backup.h"
#import "apply.h"
#import "MCDefs.h"

NSString *backupStringForIdentifier(NSString *identifier) {
    return [NSString stringWithFormat:@"com.alexzielenski.mousecape.%@", identifier];
}

void backupCursorForIdentifier(NSString *ident) {
    MMLog("  Backing up: %s", ident.UTF8String);
    bool registered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)ident.UTF8String, &registered);

//     dont try to backup a nonexistant cursor
    if (!registered) {
        MMLog("    Skipped - cursor not registered");
        return;
    }

    NSString *backupIdent = backupStringForIdentifier(ident);
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupIdent.UTF8String, &registered);

//     don't re-back it up
    if (registered) {
        MMLog("    Skipped - backup already exists");
        return;
    }

    NSDictionary *cape = capeWithIdentifier(ident);
    BOOL success = applyCapeForIdentifier(cape, backupIdent, YES);
    MMLog("    Backup result: %s", success ? "SUCCESS" : "FAILED");
}

void backupAllCursors() {
    MMLog("=== backupAllCursors ===");
    bool arrowRegistered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupStringForIdentifier(@"com.apple.coregraphics.Arrow").UTF8String, &arrowRegistered);

    if (arrowRegistered) {
        MMLog("Skipping backup, backup already exists");
//         we are already backed up
        return;
    }
    // Backup main cursors first
    MMLog("--- Backing up default cursors ---");
    NSUInteger i = 0;
    NSString *key = nil;
    while ((key = defaultCursors[i]) != nil) {
        backupCursorForIdentifier(key);
        i++;
    }

    // Additionally, back up any Arrow synonyms the system may use (for macOS 26+ compatibility)
    MMLog("--- Backing up Arrow synonyms ---");
    NSArray<NSString *> *synonyms = MCArrowSynonyms();
    for (NSString *name in synonyms) {
        backupCursorForIdentifier(name);
    }

    // And also back up I-beam synonyms
    MMLog("--- Backing up IBeam synonyms ---");
    NSArray<NSString *> *ibeamSynonyms = MCIBeamSynonyms();
    for (NSString *name in ibeamSynonyms) {
        backupCursorForIdentifier(name);
    }
    // no need to backup core cursors
    MMLog("=== backupAllCursors complete ===");
}
