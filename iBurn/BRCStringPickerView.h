//
//  BRCStringPickerView.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/6/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCStringPickerView;
typedef void(^BRCStringPickerDoneBlock)(BRCStringPickerView *picker, NSUInteger selectedIndex, NSString *selectedValue);
typedef void(^BRCStringPickerCancelBlock)(BRCStringPickerView *picker);

@interface BRCStringPickerView : UIView <UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, readwrite) NSUInteger selectedIndex;
@property (nonatomic, strong, readonly) UIPickerView *pickerView;
@property (nonatomic, strong, readonly) UIToolbar *toolbar;
@property (nonatomic, strong, readonly) NSArray *pickerStrings;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, weak, readonly) UIViewController *presentingViewController;
@property (nonatomic, readonly) BOOL isVisible;
@property (nonatomic, copy) BRCStringPickerDoneBlock doneBlock;
@property (nonatomic, copy) BRCStringPickerCancelBlock cancelBlock;

- (instancetype)initWithTitle:(NSString *)title pickerStrings:(NSArray *)pickerStrings initialSelection:(NSUInteger)initialSelection doneBlock:(BRCStringPickerDoneBlock)doneBlock cancelBlock:(BRCStringPickerCancelBlock)cancelBlock;

- (void) showFromViewController:(UIViewController*)viewController;

@end
