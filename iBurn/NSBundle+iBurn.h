//
//  NSBundle+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/9/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSBundle (iBurn)

/** Return iBurn-Data bundle */
@property (class, nonnull, nonatomic, readonly) NSBundle* brc_dataBundle;
@property (class, nonnull, nonatomic, readonly) NSBundle* brc_tilesCache;

@end
