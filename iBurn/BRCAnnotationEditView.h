//
//  BRCAnnotationEditView.h
//  iBurn
//
//  Created by David Chiles on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BButton.h"
#import "BRCMapPoint.h"

@class BRCAnnotationEditView;

@protocol BRCAnnotationEditViewDelegate <NSObject>
@required
- (void)editViewDidSelectDelete:(BRCAnnotationEditView *)editView mapPointToDelete:(BRCMapPoint *)mapPointToDelete;
- (void)editViewDidSelectSave:(BRCAnnotationEditView *)editView editedMapPoint:(BRCMapPoint *)editedMapPoint;
@end

@interface BRCAnnotationEditView : UIView

- (instancetype)initWithDelegate:(id <BRCAnnotationEditViewDelegate>)delegate;

/** set the mapPoint to change textField title */
@property (nonatomic, copy) BRCMapPoint *mapPoint;

@property (nonatomic, weak, readonly) id<BRCAnnotationEditViewDelegate> delegate;
@property (nonatomic, strong, readonly) UITextField* textField;
@property (nonatomic, strong, readonly) BButton *saveButton;
@property (nonatomic, strong, readonly) BButton *deleteButton;

@end
