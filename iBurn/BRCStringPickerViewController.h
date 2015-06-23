//
//  BRCStringPickerView.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/6/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCStringPickerViewController;
typedef void(^BRCStringPickerDoneBlock)(BRCStringPickerViewController *picker, NSUInteger selectedIndex, NSString *selectedValue);

@interface BRCStringPickerViewController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, readwrite) NSUInteger selectedIndex;
@property (nonatomic, strong, readonly) UIPickerView *pickerView;
@property (nonatomic, strong, readonly) NSArray *pickerStrings;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, copy) BRCStringPickerDoneBlock doneBlock;

- (instancetype)initWithPickerStrings:(NSArray *)pickerStrings initialSelection:(NSUInteger)initialSelection doneBlock:(BRCStringPickerDoneBlock)doneBlock;

@end
