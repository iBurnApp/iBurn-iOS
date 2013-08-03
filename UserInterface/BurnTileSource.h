//
//  BurnTileSource.h
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface BurnTileSource : NSObject <NSObject> {
  NSString* uniqueTilecacheKey;
  NSString* shortName;
  NSString* longDescription;
  NSString* attribution;
  float sourceMinZoom;
  NSString* tileURL;
  RMSphericalTrapezium bounds;
  CLLocationCoordinate2D demoCoord;
  NSString* tileDirectory;
  
  BOOL reverseY;
}

@property (nonatomic, strong) NSString *uniqueTilecacheKey;
@property (nonatomic, strong) NSString *shortName;
@property (nonatomic, strong) NSString *longDescription;
@property (nonatomic, strong) NSString *attribution;
@property (nonatomic, strong) NSString *tileURL, *tileDirectory;

@property (nonatomic, assign) CLLocationCoordinate2D demoCoord;
@property (nonatomic, assign) RMSphericalTrapezium bounds;
@property (nonatomic, assign) float sourceMinZoom;
@property (nonatomic, assign) BOOL reverseY;


- (NSString*)getTileURLForX:(int)x forY:(int)y forZ:(int)z;
- (RMSphericalTrapezium) latitudeLongitudeBoundingBox;

@end
