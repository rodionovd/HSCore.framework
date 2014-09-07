//
//  AppDelegate.m
//  TestsHostApp
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//
#import <HSCore/HSCore.h>
#import "TableCellViewWithSlider.h"
#import "AppDelegate.h"
#import "AppModel.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (strong) NSMutableArray *applications;
@end

@implementation AppDelegate

- (instancetype)init
{
    if ((self = [super init])) {
        _applications = [NSMutableArray new];
    }

    return self;
}

- (void)awakeFromNib
{
    [self.tableView setDelegate: self];
    [self.tableView setDataSource: self];
}

- (void)dealloc
{
    [self.tableView setDelegate: nil];
    [self.tableView setDataSource: nil];
}


#pragma mark - Public

- (IBAction)addApplication: (id)sender
{
    // Open panel
    static BOOL openPanelIsShown = NO;
    if (openPanelIsShown) {
        return;
    }
    openPanelIsShown = YES;

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setTitle: NSLocalizedString(@"Choose one or more applications", @"Open panel > Title")];
    [panel setPrompt: NSLocalizedString(@"Add", "Open panel > OK button")];
    NSString *applicationsDirectory = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                                                          NSSystemDomainMask,
                                                                          YES)[0];
    [panel setDirectoryURL: [NSURL URLWithString: applicationsDirectory]];
    [panel setShowsHiddenFiles: NO];
    [panel setAllowsOtherFileTypes: NO];
    [panel setAllowedFileTypes: @[@"app"]];
    [panel setAllowsMultipleSelection: YES];
    [panel beginWithCompletionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self _addApplications: panel.URLs];
        }
        openPanelIsShown = NO;
    }];
}

- (IBAction)removeSelectedApplication: (id)sender
{
    NSUInteger idx = [self.tableView selectedRow];
    if (idx < self.applications.count) {
        AppModel *model = self.applications[idx];
        [[HSCVolumeMaster sharedMaster] revertVolumeChangesForBundle: model.bundleID];
        [self.applications removeObjectAtIndex: idx];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

- (void)sliderMove: (NSSlider *)sender
{
    TableCellViewWithSlider *superview = (TableCellViewWithSlider *)[sender superview];
    AppModel *model = [superview model];
    if (!model) return;

    CGFloat newVolumeLevel = sender.doubleValue;
    if (fabs(newVolumeLevel - model.volumeLevel) > 0.05) {
        model.volumeLevel = newVolumeLevel;
        [[HSCVolumeMaster sharedMaster] setVolumeLevel: newVolumeLevel
                                             forBundle: model.bundleID
                                            completion:
         ^(BOOL succeeded) {
             NSLog(@"%@: %d", model.bundleID, succeeded);
         }];
    }
}

#pragma mark - NSTableViewDataSource's

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.applications.count;
}

- (NSView *)tableView: (NSTableView *)tableView
   viewForTableColumn: (NSTableColumn *)tableColumn
                  row: (NSInteger)row
{
    TableCellViewWithSlider *view = [tableView makeViewWithIdentifier: [tableColumn identifier]
                                                                owner: self];
    AppModel *model = self.applications[(NSUInteger)row];
    [view configureWithModel: model];

    [view.volumeSlider setTarget: self];
    [view.volumeSlider setAction: @selector(sliderMove:)];

    return view;
}

#pragma mark - Private

- (void)_addApplications: (NSArray *)URLs
{
    [URLs enumerateObjectsUsingBlock: ^(NSURL *url, NSUInteger idx, BOOL *stop) {
        AppModel *model = [AppModel modelWithURL: url];

        NSUInteger index = [self.applications indexOfObjectPassingTest:
                            ^BOOL(AppModel *item, NSUInteger idx, BOOL *stop) {
                                return (item.bundleID == model.bundleID);
                            }];
        if (index != NSNotFound) {
            return;
        }

        if (model) {
            [self.applications addObject: model];
            [[HSCVolumeMaster sharedMaster] setVolumeLevel: 1.0
                                                 forBundle: model.bundleID
                                                completion:
             ^(BOOL succeeded) {
                 NSLog(@"%@: %d", model.bundleID, succeeded);
             }];
        }
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [[HSCVolumeMaster sharedMaster] revertAllVolumeChanges];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    [[HSCVolumeMaster sharedMaster] revertAllVolumeChanges];
}

@end
