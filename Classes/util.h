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
#define B(N$)  [NSNumber numberWithBool: (N$)]
RMTile RMTileFromKey(uint64_t tilekey);

@interface util : NSObject {

}

@end
