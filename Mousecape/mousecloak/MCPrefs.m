//
//  MCPrefs.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCPrefs.h"
#import "MCDefs.h"

NSString *MCPreferencesAppliedCursorKey          = @"MCAppliedCursor";
NSString *MCPreferencesAppliedClickActionKey     = @"MCLibraryClickAction";
NSString *MCPreferencesCursorScaleKey            = @"MCCursorScale";
NSString *MCPreferencesDoubleActionKey           = @"MCDoubleAction";
NSString *MCPreferencesHandednessKey             = @"MCHandedness";
NSString *MCSuppressDeleteLibraryConfirmationKey = @"MCSuppressDeleteLibraryConfirmationKey";
NSString *MCSuppressDeleteCursorConfirmationKey  = @"MCSuppressDeleteCursorConfirmationKey";

id MCDefaultFor(NSString *key, NSString *user, NSString *host) {
    NSString *value = (__bridge_transfer NSString *)CFPreferencesCopyValue((__bridge CFStringRef)key, (__bridge CFStringRef)kMCDomain, (__bridge CFStringRef)user, (__bridge CFStringRef)host);
#ifdef DEBUG
    MMLog("MCDefaultFor: key=%s, user=%s, value=%s",
          key.UTF8String,
          user.UTF8String,
          value ? [value description].UTF8String : "(null)");
#endif
    return value;
}

id MCDefault(NSString *key) {
    id value = (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kMCDomain);
#ifdef DEBUG
    MMLog("MCDefault: key=%s, value=%s",
          key.UTF8String,
          value ? [value description].UTF8String : "(null)");
#endif
    return value;
}

void MCSetDefaultFor(id value, NSString *key, NSString *user, NSString *host) {
#ifdef DEBUG
    MMLog("MCSetDefaultFor: key=%s, user=%s, value=%s",
          key.UTF8String,
          user.UTF8String,
          value ? [value description].UTF8String : "(null)");
#endif
    CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)kMCDomain, (__bridge CFStringRef)user, (__bridge CFStringRef)host);
    //    CFPreferencesSynchronize((CFStringRef)kMCDomain, (CFStringRef)user, (CFStringRef)host);
}

