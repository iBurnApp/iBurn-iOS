//
//  BRCGeocoder.h
//  iBurn
//
//  Created by David Chiles on 8/5/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (BRCGeocoder)
/** Add font-awesome crosshairs */
@property (nonatomic, readonly) NSAttributedString *brc_attributedLocationStringWithCrosshairs;
@end

NS_ASSUME_NONNULL_END
