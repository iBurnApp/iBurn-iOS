//
//  util.m
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "util.h"


@implementation util

RMTile RMTileFromKey(uint64_t tilekey)
{
	RMTile t;
	t.zoom = tilekey >> 56;
	t.x = tilekey >> 28 & 0xFFFFFFFLL;
	t.y = tilekey & 0xFFFFFFFLL;
	return t;
}

@end
