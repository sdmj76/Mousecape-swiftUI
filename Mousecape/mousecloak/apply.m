//
//  apply.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "create.h"
#import "backup.h"
#import "restore.h"
#import "MCPrefs.h"
#import "NSBitmapImageRep+ColorSpace.h"
#import "MCDefs.h"

static BOOL MCRegisterImagesForCursorName(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *name) {
    char *cursorName = (char *)name.UTF8String;
    int seed = 0;
    CGError err = CGSRegisterCursorWithImages(CGSMainConnectionID(),
                                              cursorName,
                                              true,
                                              true,
                                              size,
                                              hotSpot,
                                              frameCount,
                                              frameDuration,
                                              (__bridge CFArrayRef)images,
                                              &seed);
    return (err == kCGErrorSuccess);
}

BOOL applyCursorForIdentifier(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident, NSUInteger repeatCount) {
    if (frameCount > 24 || frameCount < 1) {
        MMLog(BOLD RED "Frame count of %s out of range [1...24]", ident.UTF8String);
        return NO;
    }

    // Special handling for Arrow on newer macOS where the underlying name may have changed.
    BOOL isArrow = ([ident isEqualToString:@"com.apple.coregraphics.Arrow"] || [ident isEqualToString:@"com.apple.coregraphics.ArrowCtx"]);
    if (isArrow) {
        BOOL anySuccess = NO;
        NSArray *synonyms = MCArrowSynonyms();

        // Register for all discovered Arrow-related names.
        for (NSString *name in synonyms) {
            if (name.length == 0) {
                continue;
            }
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, name)) {
                anySuccess = YES;
            }
        }
        // Also try the legacy identifier if it wasn't in the discovered set.
        if (![synonyms containsObject:ident]) {
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident)) {
                anySuccess = YES;
            }
        }

        // Reduce the chance of the Dock overriding the cursor immediately after registration.
        CGSSetDockCursorOverride(CGSMainConnectionID(), false);
        return anySuccess;
    }

    // Special handling for I-beam (text cursor) on newer macOS
    BOOL isIBeam = ([ident isEqualToString:@"com.apple.coregraphics.IBeam"] || [ident isEqualToString:@"com.apple.coregraphics.IBeamXOR"]);
    if (isIBeam) {
        BOOL anySuccess = NO;
        NSArray *synonyms = MCIBeamSynonyms();
        for (NSString *name in synonyms) {
            if (name.length == 0) {
                continue;
            }
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, name)) {
                anySuccess = YES;
            }
        }
        if (![synonyms containsObject:ident]) {
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident)) {
                anySuccess = YES;
            }
        }
        CGSSetDockCursorOverride(CGSMainConnectionID(), false);
        return anySuccess;
    }

    // Default behavior for all other cursors.
    return MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident);
}

BOOL applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore) {
    if (!cursor || !identifier) {
        NSLog(@"bad seed");
        return NO;
    }

    BOOL lefty = MCFlag(MCPreferencesHandednessKey);
    BOOL pointer = MCCursorIsPointer(identifier);
    NSNumber *frameCount    = cursor[MCCursorDictionaryFrameCountKey];
    NSNumber *frameDuration = cursor[MCCursorDictionaryFrameDuratiomKey];
    //    NSNumber *repeatCount   = cursor[MCCursorDictionaryRepeatCountKey];
    
    CGPoint hotSpot         = CGPointMake([cursor[MCCursorDictionaryHotSpotXKey] doubleValue],
                                          [cursor[MCCursorDictionaryHotSpotYKey] doubleValue]);
    CGSize size             = CGSizeMake([cursor[MCCursorDictionaryPointsWideKey] doubleValue],
                                         [cursor[MCCursorDictionaryPointsHighKey] doubleValue]);
    NSArray *reps           = cursor[MCCursorDictionaryRepresentationsKey];
    NSMutableArray *images  = [NSMutableArray array];

    if (lefty && !restore && pointer) {
        MMLog("Lefty mode for %s", identifier.UTF8String);
        hotSpot.x = size.width - hotSpot.x - 1;
    }

    for (id object in reps) {
        CFTypeID type = CFGetTypeID((__bridge CFTypeRef)object);
        NSBitmapImageRep *rep;
        if (type == CGImageGetTypeID()) {
            rep = [[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object];
        } else {
            rep = [[NSBitmapImageRep alloc] initWithData:object];
        }
        rep = rep.retaggedSRGBSpace;

        if (!lefty || restore || !pointer) {
            // special case if array has a type of CGImage already there is no need to convert it
            if (type == CGImageGetTypeID()) {
                images[images.count] = object;
                continue;
            }

            images[images.count] = (__bridge id)[rep CGImage];

        } else {
            NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:rep.pixelsWide
                                                                               pixelsHigh:rep.pixelsHigh
                                                                            bitsPerSample:8
                                                                          samplesPerPixel:4
                                                                                 hasAlpha:YES
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedRGBColorSpace
                                                                              bytesPerRow:4 * rep.pixelsWide
                                                                             bitsPerPixel:32];
            NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:ctx];
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:rep.pixelsWide yBy:0];
            [transform scaleXBy:-1 yBy:1];
            [transform concat];

            [rep drawInRect:NSMakeRect(0, 0, rep.pixelsWide, rep.pixelsHigh)
                   fromRect:NSZeroRect
                  operation:NSCompositingOperationSourceOver
                   fraction:1.0
             respectFlipped:NO
                      hints:nil];
            [NSGraphicsContext restoreGraphicsState];
            images[images.count] = (__bridge id)[newRep CGImage];
        }
    }
    
    return applyCursorForIdentifier(frameCount.unsignedIntegerValue, frameDuration.doubleValue, hotSpot, size, images, identifier, 0);
}

BOOL applyCape(NSDictionary *dictionary) {
    @autoreleasepool {
        NSDictionary *cursors = dictionary[MCCursorDictionaryCursorsKey];
        NSString *name = dictionary[MCCursorDictionaryCapeNameKey];
        NSNumber *version = dictionary[MCCursorDictionaryCapeVersionKey];
        
        resetAllCursors();
        backupAllCursors();
        
        MMLog("Applying cape: %s %.02f", name.UTF8String, version.floatValue);
        
        for (NSString *key in cursors) {
            NSDictionary *cape = cursors[key];
            MMLog("Hooking for %s", key.UTF8String);
            
            BOOL success = applyCapeForIdentifier(cape, key, NO);
            if (!success) {
                MMLog(BOLD RED "Failed to hook identifier %s for some unknown reason. Bailing out..." RESET, key.UTF8String);
                return NO;
            }
        }
        
        MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], MCPreferencesAppliedCursorKey);
        
        MMLog(BOLD GREEN "Applied %s successfully!" RESET, name.UTF8String);
        
        return YES;
    }
}

BOOL applyCapeAtPath(NSString *path) {
    // Validate path
    if (!path || path.length == 0) {
        MMLog(BOLD RED "Invalid path" RESET);
        return NO;
    }

    // Resolve symlinks and check for path traversal
    NSString *realPath = [path stringByResolvingSymlinksInPath];
    NSString *standardPath = [realPath stringByStandardizingPath];

    // Validate file extension
    if (![[standardPath pathExtension] isEqualToString:@"cape"]) {
        MMLog(BOLD RED "Invalid file extension - must be .cape" RESET);
        return NO;
    }

    // Check file exists and is readable
    if (![[NSFileManager defaultManager] isReadableFileAtPath:standardPath]) {
        MMLog(BOLD RED "File not readable at path" RESET);
        return NO;
    }

    NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:standardPath];
    if (cape)
        return applyCape(cape);
    MMLog(BOLD RED "Could not parse valid cape file" RESET);
    return NO;
}
