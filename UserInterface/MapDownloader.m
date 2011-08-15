//
//  MapDownloader.m
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MapDownloader.h"
#import "RMTile.h"
#import "RMTileSource.h"
#import "ASIHTTPRequest.h"
#import "ASINetworkQueue.h"
#import "util.h"
#import "iBurnAppDelegate.h"

@implementation MapDownloader
@synthesize networkQueue, lastProgress, tileSource, refreshTiles;

- (id)initWithTileSource:(RMTileSource*)_tileSource progressView:(UIProgressView*) progressView {
  self = [super init];
  finishedRequests = [[NSMutableArray alloc] init];
  downloadSectionComplete = NO;
  downloading = NO;
  stopDownload = NO;
  mapType = [_tileSource uniqueTilecacheKey];
  NSLog(@"%@", mapType);
  completedRequests = 0;
  self.tileSource = _tileSource;
  NSFileManager *NSFm= [NSFileManager defaultManager]; 
  BOOL isDir=YES;
  tileDirectory = [self.tileSource tileDirectory];
  if(![NSFm fileExistsAtPath:tileDirectory isDirectory:&isDir]) {
    if(![NSFm createDirectoryAtPath:tileDirectory withIntermediateDirectories:YES attributes:nil error:nil]) {
      NSLog(@"Error: Create folder failed");
    }
  }

  if(!self.networkQueue) networkQueue = [[ASINetworkQueue alloc] init];

  [self.networkQueue setRequestDidFinishSelector:@selector (tileRequestDone:)];
  [self.networkQueue setRequestDidFailSelector:@selector(tileRequestFailed:)];
  [self.networkQueue setDelegate:self];
  [self.networkQueue setQueueDidFinishSelector:@selector(userDownloadComplete:)];
  [self.networkQueue setMaxConcurrentOperationCount:3];
  [self.networkQueue setShouldCancelAllRequestsOnFailure:NO];
  lastProgress = .01;
  
  refreshTiles = NO;
  pgView = progressView;
  [pgView setProgress:lastProgress];
  [pgView setNeedsDisplay];
  return self;
}


+(CLLocationCoordinate2D) normalizePixelCoords:(CLLocationCoordinate2D) point {
  
	if (point.longitude > 180) {
		point.longitude -= 360;
	}
	point.longitude /= 360.0;
	point.longitude += 0.5;
	point.latitude = 0.5 - ((log(tan((M_PI_4) + ((0.5 * M_PI *point.latitude) / 180.0))) / M_PI) / 2.0);
	
	return point;		
}

+(RMTile)tileWithCoordinate:(CLLocationCoordinate2D)point andZoom:(int)zoom {
	int scale = (1<<zoom);
	CLLocationCoordinate2D normalizedPoint = [self normalizePixelCoords:point];
	RMTile returnTile;
	returnTile.x = (int)(normalizedPoint.longitude * scale);
	returnTile.y = (int)(normalizedPoint.latitude * scale);
	returnTile.zoom = zoom;
	return returnTile;
}

+(NSArray *)getTileArrayWithUpperLeft:(CLLocationCoordinate2D)upperLeft andLowerRight:(CLLocationCoordinate2D)lowerRight fromZoom:(int)bottomZoom toZoom:(int)topZoom {
	NSMutableArray *tileArray = [[[NSMutableArray alloc] init] autorelease];
	for(int zoom = bottomZoom; zoom <= topZoom; zoom++) {
		RMTile upperLeftTile = [self tileWithCoordinate:upperLeft andZoom:zoom];
		RMTile lowerRightTile = [self tileWithCoordinate:lowerRight andZoom:zoom];
		for (int y = upperLeftTile.y; y <= lowerRightTile.y; y++ ) {
			for(int x = upperLeftTile.x; x<= lowerRightTile.x; x++) {
				RMTile newTile;
				newTile.x = x;
				newTile.y = y;
				newTile.zoom = zoom;
				
				[tileArray addObject:[NSNumber numberWithUnsignedLongLong:RMTileKey(newTile)]];
			}
		}
	}
	return tileArray;
}

-(void) startMapDownload {
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

  RMSphericalTrapezium bounds = [tileSource latitudeLongitudeBoundingBox];
  CLLocationCoordinate2D tl = {bounds.northeast.latitude, bounds.southwest.longitude};
  CLLocationCoordinate2D br = {bounds.southwest.latitude, bounds.northeast.longitude};
  
  tileKeys = [MapDownloader getTileArrayWithUpperLeft:tl andLowerRight:br fromZoom:[tileSource minZoom] toZoom:[tileSource maxZoom]];
  [tileKeys retain];
  downloading = YES;

  NSString *mapTilePath = [tileDirectory stringByAppendingString: @"/maptiles.txt"];
  [tileKeys writeToFile:mapTilePath atomically:NO];
  
  if ([tileKeys count] > 1) {
    [self.networkQueue request:nil incrementDownloadSizeBy:([tileKeys count] - 1)];
  }
  
  totalRequests = [tileKeys count];
  NSLog(@"number of tiles %d", totalRequests);
  [self handleDownloadLoop];
  [pool release];
}


-(void) handleDownloadLoop {
  while (downloading && !stopDownload) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    if ([[self.networkQueue operations] count] == 0 && [finishedRequests count] == 0) {
      //NSLog(@"starting tile request");
      [self startTileRequests];
    }
    [NSThread sleepForTimeInterval:1];
    NSLog(@"request count %d, total requests %d", [finishedRequests count], totalRequests);
    [self processRequests];
    [pool release];
  }
  if (stopDownload) {
    [self.networkQueue cancelAllOperations];
  }
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [t performSelectorOnMainThread:@selector(dismissProgessIndicator) withObject:nil waitUntilDone:NO];  

}


-(void) startTileRequests {
  
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  
  int tileCount = 0;
  for (int i = 0; i < [tileKeys count]; i++) {
    NSNumber* tileKey = [tileKeys objectAtIndex:i];
    RMTile rmTile = RMTileFromKey([tileKey longLongValue]);
    
    NSString* tilePath = [tileSource tileFile:rmTile];
    
    NSFileManager *NSFm= [NSFileManager defaultManager]; 
    
    if(!refreshTiles && [NSFm fileExistsAtPath:tilePath isDirectory:nil]) {
      [tileKeys removeObjectAtIndex:i];
      i--;
      totalRequests--;
      continue;
    }
    tileCount++;
    NSString *urlString = [tileSource tileURL:rmTile];
    
    ASIHTTPRequest *request = [[[ASIHTTPRequest alloc]initWithURL:[NSURL URLWithString:urlString]] autorelease];
    [request setQueue:self.networkQueue];
    [request setUserInfo:[[[NSDictionary alloc] initWithObjectsAndKeys:mapType, @"mapSource",
                           tileKey, @"tileKey", nil]autorelease]];
    
    [[self networkQueue] addOperation:request];
    
    if ([self.networkQueue isSuspended]) {
      [self.networkQueue go];
    } 
    if (tileCount > 100) {
      break;
    }
  }
  
  NSString *tilesToDownloadPath = [tileDirectory stringByAppendingString: @"/remainingtiles.txt"];
  
  if ([tileKeys count] == 0) {
    [[NSFileManager defaultManager] removeItemAtPath:tilesToDownloadPath error:nil];
  } else {
    [tileKeys writeToFile:tilesToDownloadPath atomically:NO];
  }
  
  if (![self.networkQueue isSuspended]) {
    [self.networkQueue go];
  } 
  
  if ([tileKeys count] == 0) {  
    [pgView setProgress:1.0];  
    downloading = NO;
  }
  
  [pool release];
}


- (void) userDownloadComplete:(ASINetworkQueue *)theNetworkQueue {	
  downloadSectionComplete = YES;
}

- (void) processRequests {
  //NSLog(@"Processing requests. queue count %d finish requests %d", 
  //      [[networkQueue operations] count], [finishedRequests count]);
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  while ([finishedRequests count] > 0) {
    RMTile tile;
    NSData* image;
    
    @synchronized (finishedRequests) {
      ASIHTTPRequest* request = [finishedRequests objectAtIndex:0];
      //mapType = [[request userInfo] objectForKey:@"mapSource"];
      tile =  RMTileFromKey([[[request userInfo] objectForKey:@"tileKey"] longLongValue]);
      image = [[request responseData] retain];
      [finishedRequests removeObjectAtIndex:0];
      //[request.userInfo release];
      //[request release];
    }
    
    
    NSString* tileDirectoryPath = [NSString stringWithFormat:@"%@/%d/%d/",
                                   tileDirectory, tile.zoom, tile.x];
    
    NSFileManager *NSFm= [NSFileManager defaultManager]; 
    BOOL isDir=YES;
    
    if(![NSFm fileExistsAtPath:tileDirectoryPath isDirectory:&isDir])
      if(![NSFm createDirectoryAtPath:tileDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil])
        NSLog(@"Error: Create folder failed");
    
    NSString* tilePath = [NSString stringWithFormat:@"%@/%d",
                          tileDirectoryPath, tile.y];
    [[NSFileManager defaultManager] createFileAtPath:tilePath contents:image attributes:nil];
    [tileKeys removeObject:[NSNumber numberWithUnsignedLongLong:RMTileKey(tile)]];
    [image release];
  }
  [pool release];
}

- (void)tileRequestDone:(ASIHTTPRequest *)request {
  NSLog(@"in tile request done. operations count %d %d", completedRequests, totalRequests);
  
  @synchronized (finishedRequests) {
    [finishedRequests addObject:request];
  }
  float newProgress = completedRequests++ / (float) totalRequests;
  if (newProgress - lastProgress > .01) {
    [pgView setProgress:lastProgress];
    lastProgress = newProgress;
  }
  
}


- (void)tileRequestFailed:(ASIHTTPRequest *)request {
  //[request release];
  //[self.networkQueue incrementDownloadSizeBy:1];
  //NSError *error = [request error];	
  NSLog(@"tile failed error %@", [request error]);
  if ([request responseStatusCode] == 404) {
    RMTile tile = RMTileFromKey([[[request userInfo] objectForKey:@"tileKey"] longLongValue]);
    [tileKeys removeObject:[NSNumber numberWithUnsignedLongLong:RMTileKey(tile)]];
    NSLog(@"removing 404 tile from download");
  }
}



-(void)dealloc {
 
  [networkQueue release];
  [finishedRequests release];
  [mapDirectory release];
  [mapType release];
  [tileDirectory release];
  [tileKeys release];
  self.tileSource = nil;
  [super dealloc];
}

@end
