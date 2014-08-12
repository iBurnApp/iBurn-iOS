//
//  BRCAnnotationEditView.h
//  iBurn
//
//  Created by David Chiles on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCAnnotationEditView;

@protocol BRCAnnotationEditViewDelegate <NSObject>

- (void)editViewDidSelectDelete:(BRCAnnotationEditView *)view;
- (void)editViewDidSelectDone:(BRCAnnotationEditView *)view text:(NSString *)text;

@end

@interface BRCAnnotationEditView : UIView

- (instancetype)initWithText:(NSString *)text delegate:(id <BRCAnnotationEditViewDelegate>)delegate;

@property (nonatomic, weak, readonly) id<BRCAnnotationEditViewDelegate> delegate;
@property (nonatomic, strong, readonly) UITextField* textField;
@property (nonatomic, strong, readonly) UIButton *doneButton;
@property (nonatomic, strong, readonly) UIButton *deleteButton;

@end
