//
//  MapDownloader.m
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MapDownloader.h"
#import "RMTile.h"
#import "BurnTileSource.h"
#import "ASIHTTPRequest.h"
#import "ASINetworkQueue.h"
#import "util.h"
#import "iBurnAppDelegate.h"
#import "JSONKit.h"

@implementation MapDownloader
@synthesize networkQueue, lastProgress, tileSource, refreshTiles;


- (void) createDirectoryIfNeeded:(NSString*) filePath {
  NSString* dir = [filePath stringByDeletingLastPathComponent];
  if(![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:nil]) {
    if(![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil])
      NSLog(@"Error: Create folder failed");
  }   
}

- (id)initWithTileSource:(BurnTileSource*)_tileSource progressView:(UIProgressView*) progressView {
  self = [super init];
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
  [self.networkQueue setMaxConcurrentOperationCount:10];
  [self.networkQueue setShouldCancelAllRequestsOnFailure:NO];
  lastProgress = .01;
  
  refreshTiles = NO;
  pgView = progressView;
  [pgView setProgress:lastProgress];
  [pgView setNeedsDisplay];
  return self;
}


- (void) downloadTile:(RMTile)tile fromURL:(NSString*)url toPath:(NSString*)path {
  ASIHTTPRequest *request = [[[ASIHTTPRequest alloc]initWithURL:[NSURL URLWithString:url]] autorelease];
  [request setNumberOfTimesToRetryOnTimeout:3];
  [request setQueue:self.networkQueue];
  [request setUserInfo:[[[NSDictionary alloc] initWithObjectsAndKeys:path, @"path",
                         url, @"url", nil]autorelease]];
  //NSLog(@"url %@ path %@", url, path);
  [self createDirectoryIfNeeded:path];
  [request setDownloadDestinationPath:path];
  [[self networkQueue] addOperation:request];
}


- (void) waitForQueueToFinish {
  
  NSLog(@"entering into batch %d", [self.networkQueue requestsCount]);
  if ([self.networkQueue isSuspended]) {
    [self.networkQueue go];
  }
  downloadSectionComplete = NO;
  int requestCount = 1000;
  while (!downloadSectionComplete) {
    
    [NSThread sleepForTimeInterval:3];
    //[self performSelectorOnMainThread:@selector(updateDelegate) withObject:nil waitUntilDone:NO];
    
    if ([self.networkQueue isSuspended]) {
      [self.networkQueue go];
    }
    NSLog(@"in request queue %d %lu bandwidth", [self.networkQueue requestsCount], [ASIHTTPRequest averageBandwidthUsedPerSecond]);
    
    if (requestCount < 5 && requestCount == [self.networkQueue requestsCount]) {
      [self.networkQueue cancelAllOperations];
      return;
    }
    requestCount = [self.networkQueue requestsCount];
  }
}


-(void) startMapDownload {
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

  NSString * path = [[NSBundle mainBundle] pathForResource:@"tiles-2012" ofType:@"json"];
  NSString* responseTxt = [[[NSString alloc] initWithContentsOfFile:path
                                                           encoding:NSUTF8StringEncoding 
                                                              error:nil] autorelease];
  NSDictionary * dict = [responseTxt objectFromJSONString];
  int batchCount = 0;
  totalRequests = [dict count];
  downloadSectionComplete = NO;
  NSAutoreleasePool* pool2 = [[NSAutoreleasePool alloc] init];

  for (NSDictionary* zDict in dict) {
    uint64_t key = [[zDict objectForKey:@"k"] longLongValue];
    RMTile t = RMTileFromKey(key);
    
    //if (t.zoom < self.tileSource.sourceMinZoom)
    //  continue;
    
    if (self.tileSource.reverseY) {
      int maxY = 1 << t.zoom;
      t.y = maxY - t.y - 1;
    }
    
    NSString * filePath = [self.tileSource tileFile:t];
    //NSLog(@"downloading tile from url %@", filePath);

    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
      [self downloadTile:t fromURL:[self.tileSource tileURL:t] toPath:filePath];
    } else {
      totalRequests--;
    }
  
    if ((batchCount++ > 500 || completedRequests == totalRequests) && [self.networkQueue requestsCount] > 0) {
      [self waitForQueueToFinish];
      downloadSectionComplete = NO;
      batchCount = 0;
      [pool2 release];
      pool2 = [[NSAutoreleasePool alloc] init];
    }
    
  }
  [self waitForQueueToFinish];
  
  downloading = YES;

  
  [pool2 release];
    
  iBurnAppDelegate *d = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [d performSelectorOnMainThread:@selector(dismissProgessIndicator) withObject:nil waitUntilDone:NO];  
  [pool release];
}
  




- (void) userDownloadComplete:(ASINetworkQueue *)theNetworkQueue {	
  downloadSectionComplete = YES;
}



- (void)tileRequestDone:(ASIHTTPRequest *)request {
  completedRequests++;
  float newProgress = completedRequests++ / (float) totalRequests;
  if (newProgress - lastProgress > .01) {
    [pgView setProgress:newProgress];
    lastProgress = newProgress;
  }
  
}


- (void)tileRequestFailed:(ASIHTTPRequest *)request {
  //[request release];
  //[self.networkQueue incrementDownloadSizeBy:1];
  //NSError *error = [request error];	
  NSLog(@"tile failed error %@", [request error]);
}



-(void)dealloc {
 
  [networkQueue release];
  [mapDirectory release];
  [tileDirectory release];
  self.tileSource = nil;
  [super dealloc];
}

@end
