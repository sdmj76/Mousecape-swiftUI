//
//  MCAppDelegate.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCAppDelegate.h"
#import <Security/Security.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "MCCursorLibrary.h"
#import "create.h"
#import "MASPreferencesWindowController.h"
#import "MCGeneralPreferencesController.h"

static NSString * const kHelperBundleIdentifier = @"com.alexzielenski.mousecloakhelper";

@interface MCAppDelegate () {
    MASPreferencesWindowController *_preferencesWindowController;
}
@property (readonly) MASPreferencesWindowController *preferencesWindowController;
- (void)configureHelperToolMenuItem;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message button:(NSString *)button;
@end

@implementation MCAppDelegate
@dynamic preferencesWindowController;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    self.libraryWindowController = [[MCLibraryWindowController alloc] initWithWindowNibName:@"Library"];
    [self.libraryWindowController loadWindow];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self configureHelperToolMenuItem];
    [self.libraryWindowController showWindow:self];

    // Re-apply currently applied cape
    if (self.libraryWindowController.libraryViewController.libraryController.appliedCape != NULL) {
        [self.libraryWindowController.libraryViewController.libraryController applyCape:self.libraryWindowController.libraryViewController.libraryController.appliedCape];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    BOOL open = [filename.pathExtension.lowercaseString isEqualToString:@"cape"];
    NSURL *url = [NSURL fileURLWithPath:filename];
    if (open) {
        [self.libraryWindowController.libraryViewController.libraryController importCapeAtURL:url];
    }
    return open;
}

#pragma mark - Helper Tool Management

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message button:(NSString *)button {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    [alert addButtonWithTitle:button];
    [alert runModal];
}

- (BOOL)isHelperToolInstalled {
    SMAppService *service = [SMAppService loginItemServiceWithIdentifier:kHelperBundleIdentifier];
    return (service.status == SMAppServiceStatusEnabled);
}

- (void)configureHelperToolMenuItem {
    BOOL installed = [self isHelperToolInstalled];

    [self.toggleHelperItem setTag: installed ? 1 : 0];
    [self.toggleHelperItem setTitle:installed ?
                    NSLocalizedString(@"Uninstall Helper Tool", "Uninstall Helper Tool Menu Item") :
                    NSLocalizedString(@"Install Helper Tool", "Install Helper Tool Menu Item")];
}

- (IBAction)toggleInstall:(NSMenuItem *)sender {
    BOOL success = NO;
    NSError *error = nil;
    BOOL shouldInstall = (self.toggleHelperItem.tag == 0);

    SMAppService *service = [SMAppService loginItemServiceWithIdentifier:kHelperBundleIdentifier];
    if (shouldInstall) {
        success = [service registerAndReturnError:&error];
    } else {
        success = [service unregisterAndReturnError:&error];
    }

    if (success && shouldInstall) {
        // Successfully Installed
        [self.toggleHelperItem setTag: 1];
        [self.toggleHelperItem setTitle:NSLocalizedString(@"Uninstall Helper Tool", "Uninstall Helper Tool Menu Item")];

        [self showAlertWithTitle:NSLocalizedString(@"Success", "Helper Tool Install Result Title Success")
                         message:NSLocalizedString(@"The Mousecape helper was successfully installed", "Helper Tool Install Success Result useless description")
                          button:NSLocalizedString(@"OK", "Helper Tool Install Result OK")];
    } else if (success) {
        // Successfully Uninstalled
        [self.toggleHelperItem setTag: 0];
        [self.toggleHelperItem setTitle:NSLocalizedString(@"Install Helper Tool", "Install Helper Tool Menu Item")];

        [self showAlertWithTitle:NSLocalizedString(@"Success", "Helper Tool Uninstall Result Title Success")
                         message:NSLocalizedString(@"The Mousecape helper was successfully uninstalled", "Helper Tool Uninstall Success Result useless description")
                          button:NSLocalizedString(@"OK", "Helper Tool Uninstall Result OK")];
    } else {
        NSString *errorMessage = error ? error.localizedDescription : NSLocalizedString(@"The action did not complete successfully", "Helper Tool Result Useless Failure Description");
        [self showAlertWithTitle:NSLocalizedString(@"Failure", "Helper Tool Result Title Failure")
                         message:errorMessage
                          button:NSLocalizedString(@"OK", "Helper Tool Result Failure OK")];
    }
}

- (MASPreferencesWindowController *)preferencesWindowController {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSViewController *general = [[MCGeneralPreferencesController alloc] init];
        _preferencesWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:@[ general ] title:NSLocalizedString(@"Preferences", "Preferences Window Title")];
    });
    
    return _preferencesWindowController;
}

#pragma mark - Interface Actions

- (IBAction)restoreCape:(id)sender {
    [self.libraryWindowController.libraryViewController.libraryController restoreCape];
}

- (IBAction)convertCape:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    UTType *mightyMouseType = [UTType typeWithFilenameExtension:@"MightyMouse"];
    panel.allowedContentTypes = mightyMouseType ? @[mightyMouseType] : @[];
    panel.title             = NSLocalizedString(@"Import", "MightyMouse Import Panel Title");
    panel.message           = NSLocalizedString(@"Choose a MightyMouse file to import", "MightyMouse Import Panel useless description");
    panel.prompt            = NSLocalizedString(@"Import", "MightyMouse Import Panel Prompt");
    if ([panel runModal] == NSModalResponseOK) {
        NSString *name = panel.URL.lastPathComponent.stringByDeletingPathExtension;
        NSDictionary *metadata = @{
                                   @"name": name,
                                   @"version": @1.0,
                                   @"author": NSLocalizedString(@"Unknown", "MightyMouse Import Default Author"),
                                   @"identifier": [NSString stringWithFormat:@"local.import.%@.%f", name, [NSDate timeIntervalSinceReferenceDate]]
                                   };
        
        NSDictionary *cape = createCapeFromMightyMouse([NSDictionary dictionaryWithContentsOfURL:panel.URL], metadata);
        MCCursorLibrary *library = [MCCursorLibrary cursorLibraryWithDictionary:cape];
        [self.libraryWindowController.libraryViewController.libraryController importCape:library];
    }
}

- (IBAction)newDocument:(id)sender {
    [self.libraryWindowController.libraryViewController.libraryController importCape:[[MCCursorLibrary alloc] init]];
}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    UTType *capeType = [UTType typeWithFilenameExtension:@"cape"];
    panel.allowedContentTypes = capeType ? @[capeType] : @[];
    panel.title             = NSLocalizedString(@"Import", "Mousecape Import Title");
    panel.message           = NSLocalizedString(@"Choose a Mousecape to import", "Mousecape Import useless description");
    panel.prompt            = NSLocalizedString(@"Import", "Mousecape Import Prompt");
    if ([panel runModal] == NSModalResponseOK) {
        [self.libraryWindowController.libraryViewController.libraryController importCapeAtURL:panel.URL];
    }
}

- (IBAction)showPreferences:(id)sender {
    [self.preferencesWindowController showWindow:sender];
}

@end
