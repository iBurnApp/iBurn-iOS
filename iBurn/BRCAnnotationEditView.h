//
//  BRCAnnotationEditView.h
//  iBurn
//
//  Created by David Chiles on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BButton.h"
#import "BRCUserMapPoint.h"

@class BRCAnnotationEditView;

NS_ASSUME_NONNULL_BEGIN
@protocol BRCAnnotationEditViewDelegate <NSObject>
@required
- (void)editViewDidSelectDelete:(BRCAnnotationEditView *)editView mapPointToDelete:(BRCUserMapPoint *)mapPointToDelete;
- (void)editViewDidSelectSave:(BRCAnnotationEditView *)editView editedMapPoint:(BRCUserMapPoint *)editedMapPoint;
@end

@interface BRCAnnotationEditView : UIView

- (instancetype)initWithDelegate:(id <BRCAnnotationEditViewDelegate>)delegate;

/** set the mapPoint to change textField title */
@property (nonatomic, copy, nullable) BRCUserMapPoint *mapPoint;

@property (nonatomic, weak, readonly) id<BRCAnnotationEditViewDelegate> delegate;
@property (nonatomic, strong, readonly) UITextField* textField;
@property (nonatomic, strong, readonly) BButton *saveButton;
@property (nonatomic, strong, readonly) BButton *deleteButton;

/** for different BRCUserMapPoint types */
@property (nonatomic, strong, readonly) NSArray<UIButton*> *typeButtons;

@end
NS_ASSUME_NONNULL_END
