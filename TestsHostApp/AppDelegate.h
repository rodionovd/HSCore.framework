//
//  AppDelegate.h
//  TestsHostApp
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

@import Cocoa;

@interface AppDelegate : NSObject
<NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *tableView;

- (IBAction)addApplication: (id)sender;
- (IBAction)removeSelectedApplication: (id)sender;
@end

