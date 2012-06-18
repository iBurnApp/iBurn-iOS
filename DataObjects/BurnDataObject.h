//
//  BurnDataObject.h
//  iBurn
//
//  Created by Chris Ballinger on 6/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BurnDataObject <NSObject>
@required
- (NSNumber*) bm_id;
- (NSString*) desc;
- (NSString*) name;
@end
