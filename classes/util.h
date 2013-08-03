//
//  util.h
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMTile.h"

#define N(N$)  [NSNumber numberWithInt: (N$)]
#define F(N$)  [NSNumber numberWithFloat: (N$)]
#define metersToFeet(meters) meters > 0?  meters * 3.2808399: 0.0f

RMTile RMTileFromKey(uint64_t tilekey);
NSString* privateDocumentsDirectory();

@interface util : NSObject {

}

+ (NSString*) distanceString:(float)distance 
                  convertMax:(int)convertMax 
                 includeUnit:(BOOL)includeUnit 
               decimalPlaces:(int)decimalPlaces;

+ (NSDictionary*) dayDict;
+ (NSArray*) dayArray;
+ (NSArray*) creditsArray;
+ (void) checkDirectory:(NSString*) filePath;


@end
