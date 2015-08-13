//
//  PFAnalytics+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

@import Parse;
#import "BRCDataObject.h"

@interface PFAnalytics (iBurn)

+ (void) brc_trackEventInBackground:(NSString*)name object:(BRCDataObject*)object;

@end
