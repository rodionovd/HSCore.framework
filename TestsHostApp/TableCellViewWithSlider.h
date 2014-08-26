//
//  TableCellViewWithSlider.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/22/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

@import Cocoa;

@class AppModel;

@interface TableCellViewWithSlider : NSTableCellView
@property (strong, readonly) AppModel *model;
@property (weak) IBOutlet NSSlider *volumeSlider;

- (void)configureWithModel: (AppModel *)newModel;
@end
