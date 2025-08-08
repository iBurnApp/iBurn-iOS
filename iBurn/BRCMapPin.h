//
//  BRCMapPin.h
//  iBurn
//
//  Created by iBurn Development Team on 8/8/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

#import "BRCDataObject.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Custom map pin created by users for marking locations
 */
@interface BRCMapPin : BRCDataObject

/**
 * Pin color/category (e.g., "red", "blue", "green")
 */
@property (nonatomic, copy) NSString *color;

/**
 * Date when the pin was created
 */
@property (nonatomic, strong) NSDate *createdDate;

/**
 * Optional notes or additional description
 */
@property (nonatomic, copy, nullable) NSString *notes;

/**
 * Generate a shareable URL for this pin
 */
- (nullable NSURL *)generateShareURL;

@end

NS_ASSUME_NONNULL_END