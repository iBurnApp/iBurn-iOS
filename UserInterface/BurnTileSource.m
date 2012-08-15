//
//  BurnTileSource.m
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BurnTileSource.h"
#import "util.h"

@implementation BurnTileSource

@synthesize uniqueTilecacheKey, shortName, longDescription, attribution;
@synthesize sourceMinZoom, tileURL, tileDirectory;
@synthesize bounds, demoCoord, reverseY;

//{40.775, -119.220037}

-(id) init {
  if (self = [super init]) {
    bounds = ((RMSphericalTrapezium){.northeast = {.latitude = 40.802822, .longitude = -119.172673}, 
      .southwest = {.latitude = 40.759210, .longitude = -119.23454}});
    //bounds = ((RMSphericalTrapezium){.northeast = {.latitude = 46.816, .longitude = -92.0}, 
    //  .southwest = {.latitude = 35.700, .longitude = -125.156}});
     
    sourceMinZoom = 8;
    self.uniqueTilecacheKey = @"iBurn";
    self.shortName = @"iBurn";
    self.reverseY = YES;
    self.longDescription = @"Tiles description";
    self.minZoom = 5;
    self.maxZoom = 18;
    //self.tileURL = @"http://earthdev.burningman.com/osm_tiles_2010/ZPARAM/XPARAM/YPARAM.png";
    //self.tileURL = @"http://iburn.s3.amazonaws.com/ZPARAM/XPARAM/YPARAM.png";
    self.tileURL = @"http://iburn.s3.amazonaws.com/2012/ZPARAM/XPARAM/YPARAM.png";

    NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.tileDirectory = [NSString stringWithFormat:@"%@/%@/%@/",
                      documentsDirectory, @"tiles", uniqueTilecacheKey];
  }
  return self;
}

- (NSString*)getTileURLForX:(int)x forY:(int)y forZ:(int)z {
  //return [NSString 
  //        stringWithFormat:@"http://tile.openstreetmap.org/%d/%d/%d.png", z, x, y];
  
  NSString * result = [tileURL stringByReplacingOccurrencesOfString:@"XPARAM" 
                                                         withString:[N(x) stringValue]];
  result = [result stringByReplacingOccurrencesOfString:@"YPARAM" 
                                             withString:[N(y) stringValue]];
  result = [result stringByReplacingOccurrencesOfString:@"ZPARAM" 
                                             withString:[N(z) stringValue]];
  //NSLog(result);
  return result;
}



-(NSString*) tileURL:(RMTile)tile {
	int y = tile.y;
  int x = tile.x;
  
  int maxY = 1 << tile.zoom;
  y = maxY - y - 1;
  return [self getTileURLForX:x forY:y forZ:tile.zoom];
}

-(NSString *) tileFile: (RMTile) tile {
  NSString* path = [NSString stringWithFormat:@"%@/%d/%d/%d",
                    @"tiles", tile.zoom, tile.x, tile.y];

  NSString *bundlePath = [[[NSBundle mainBundle] resourcePath]
                                   stringByAppendingPathComponent:path];
  //NSLog(bundlePath);
  
  return bundlePath;
  
//  NSString* tilePath = [NSString stringWithFormat:@"%@%d/%d/%d",
//                        tileDirectory, tile.zoom, tile.x, tile.y];
}


-(NSString *)shortAttribution {
	return attribution;
}
-(NSString *)longAttribution {
	return attribution;
}

- (void) removeAllCachedImages {}
- (void) didReceiveMemoryWarning {}


- (RMSphericalTrapezium) latitudeLongitudeBoundingBox {
  return bounds;
  /*CLLocationCoordinate2D northeast = {19.9888, -71.7682};
   CLLocationCoordinate2D southwest = {18.0284, -74.4406};
   RMSphericalTrapezium boundingBox =  {northeast, southwest};
   return boundingBox;*/
  
}  



- (void) dealloc {
  [uniqueTilecacheKey release];
  [shortName release];
  [longDescription release];
  [attribution release];
  [tileURL release];
  [super dealloc];
}  

@end
