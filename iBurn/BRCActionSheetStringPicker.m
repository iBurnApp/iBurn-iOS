//
//  BRCActionSheetStringPicker.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCActionSheetStringPicker.h"

@interface ActionSheetStringPicker()
- (UIToolbar *)createPickerToolbarWithTitle:(NSString *)title;
@end

@implementation BRCActionSheetStringPicker

- (UIToolbar *)createPickerToolbarWithTitle:(NSString *)title {
    UIToolbar *toolbar = [super createPickerToolbarWithTitle:title];
    UIBarButtonItem *segmentedBarItem = [[UIBarButtonItem alloc] initWithCustomView:self.segmentedControl];
    NSMutableArray *toolbarItems = [toolbar.items mutableCopy];
    [toolbarItems insertObject:segmentedBarItem atIndex:2];
    [toolbarItems insertObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] atIndex:3];
    toolbar.items = toolbarItems;
    return toolbar;
}

@end
