//
//  MCLbraryWindowController.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/2/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCLibraryWindowController.h"

@interface MCLibraryWindowController () {
    BOOL _accessoryComposed;
}
- (void)composeAccessory;
- (void)configureWindowAppearance;
@end

@implementation MCLibraryWindowController

- (void)awakeFromNib {
    [self composeAccessory];
    [self configureWindowAppearance];
}

- (id)initWithWindow:(NSWindow *)window {
    if ((self = [super initWithWindow:window])) {

    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self composeAccessory];
    [self configureWindowAppearance];
}

#pragma mark - Window Appearance

- (void)configureWindowAppearance {
    // Enable full size content view for modern window appearance
    self.window.titlebarAppearsTransparent = NO;
    self.window.titleVisibility = NSWindowTitleVisible;

    // Add visual effect background for modern look
    NSVisualEffectView *visualEffectView = [[NSVisualEffectView alloc] initWithFrame:self.window.contentView.bounds];
    visualEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    visualEffectView.material = NSVisualEffectMaterialSidebar;
    visualEffectView.state = NSVisualEffectStateFollowsWindowActiveState;

    // Insert as background
    NSView *contentView = self.window.contentView;
    NSArray *subviews = [contentView.subviews copy];
    [visualEffectView setFrame:contentView.bounds];
    [contentView addSubview:visualEffectView positioned:NSWindowBelow relativeTo:subviews.firstObject];
}

- (void)composeAccessory {
    if (_accessoryComposed) return;

    NSView *accessory = self.appliedAccessory;
    if (!accessory) return;

    _accessoryComposed = YES;

    // Use NSTitlebarAccessoryViewController for proper titlebar integration on modern macOS
    NSTitlebarAccessoryViewController *accessoryVC = [[NSTitlebarAccessoryViewController alloc] init];
    accessoryVC.view = accessory;
    accessoryVC.layoutAttribute = NSLayoutAttributeRight;

    [self.window addTitlebarAccessoryViewController:accessoryVC];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return self.libraryViewController.libraryController.undoManager;
}

#pragma mark - Menu Actions

- (IBAction)applyCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.libraryViewController.clickedCape;
    else
        cape = self.libraryViewController.selectedCape;
    
    [self.libraryViewController.libraryController applyCape:cape];
}

- (IBAction)editCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.libraryViewController.clickedCape;
    else
        cape = self.libraryViewController.selectedCape;
    
    [self.libraryViewController editCape:cape];
}

- (IBAction)removeCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.libraryViewController.clickedCape;
    else
        cape = self.libraryViewController.selectedCape;
    
    if (cape != self.libraryViewController.editingCape) {
        [self.libraryViewController.libraryController removeCape:cape];
    } else {
        [[NSSound soundNamed:@"Funk"] play];
        [self.libraryViewController editCape:self.libraryViewController.editingCape];
    }
}

- (IBAction)duplicateCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.libraryViewController.clickedCape;
    else
        cape = self.libraryViewController.selectedCape;
    
    [self.libraryViewController.libraryController importCape:cape.copy];
}

- (IBAction)showCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.libraryViewController.clickedCape;
    else
        cape = self.libraryViewController.selectedCape;
    
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ cape.fileURL ]];
}

- (IBAction)dumpCapeAction:(NSMenuItem *)sender {
    [self.window beginSheet:self.progressBar.window completionHandler:nil];
    __weak MCLibraryWindowController *weakSelf = self;
    self.progressBar.doubleValue = 0.0;
    [self.progressBar setIndeterminate:NO];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [weakSelf.libraryViewController.libraryController dumpCursorsWithProgressBlock:^BOOL (NSUInteger current, NSUInteger total) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                weakSelf.progressField.stringValue = [NSString stringWithFormat:@"%lu %@ %lu", (unsigned long)current, NSLocalizedString(@"of", @"Dump cursor progress separator (eg: 5 of 129)"), (unsigned long)total];
                weakSelf.progressBar.minValue = 0;
                weakSelf.progressBar.maxValue = total;
                weakSelf.progressBar.doubleValue = current;
            });
            return YES;
        }];

        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf.window endSheet:self.progressBar.window];
            [[NSCursor arrowCursor] set];
        });
    });

}

@end

@implementation MCAppliedCapeValueTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

- (id)transformedValue:(id)value {
    return [
            NSLocalizedString(@"Applied Cape: ", @"Accessory label for applied cape")
            stringByAppendingString:value ? value : NSLocalizedString(@"None", @"Window Titlebar Accessory label for when no cape is applied")];
}

@end
