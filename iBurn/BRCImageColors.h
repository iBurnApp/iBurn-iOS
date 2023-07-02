//
//  BRCImageColors.h
//  iBurn
//
//  Created by Chris Ballinger on 8/8/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

@import Mantle;

NS_ASSUME_NONNULL_BEGIN
@interface BRCImageColors : MTLModel
@property (nonatomic, strong, readonly) UIColor *backgroundColor;
@property (nonatomic, strong, readonly) UIColor *primaryColor;
@property (nonatomic, strong, readonly) UIColor *secondaryColor;
@property (nonatomic, strong, readonly) UIColor *detailColor;

- (instancetype) initWithBackgroundColor:(UIColor*)backgroundColor
                            primaryColor:(UIColor*)primaryColor
                          secondaryColor:(UIColor*)secondaryColor
                             detailColor:(UIColor*)detailColor;

@end
NS_ASSUME_NONNULL_END
