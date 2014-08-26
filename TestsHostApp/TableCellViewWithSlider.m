//
//  TableCellViewWithSlider.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/22/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "TableCellViewWithSlider.h"
#import "AppModel.h"

@interface TableCellViewWithSlider()
@property (strong, readwrite) AppModel *model;
@end

@implementation TableCellViewWithSlider

- (void)configureWithModel: (AppModel *)newModel
{
    if (newModel) {
        self.model = newModel;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.textField.stringValue = self.model.title;
            self.volumeSlider.doubleValue = self.model.volumeLevel;
        });
    }
}

@end
