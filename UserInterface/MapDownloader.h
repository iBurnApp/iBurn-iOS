//
//  MapDownloader.h
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ASINetworkQueue;
@class ASIHTTPRequest;
@class RMTileSource;
@interface MapDownloader : NSObject {
  ASINetworkQueue *networkQueue;
	NSMutableArray *finishedRequests;
	Boolean downloadSectionComplete;
	Boolean downloading;
	UIProgressView* pgView;
	int totalRequests;
	int completedRequests;
  Boolean stopDownload;
  float lastProgress;
  NSString * mapDirectory;
  NSString * tileDirectory;
  NSMutableArray* tileKeys;
  NSString* mapType;
  RMTileSource* tileSource;
  
  Boolean refreshTiles;
}  

@property (nonatomic, retain) ASINetworkQueue *networkQueue;
@property (nonatomic, assign) float lastProgress;
@property (nonatomic, retain) RMTileSource *tileSource;
@property (nonatomic, assign) Boolean refreshTiles;

- (id)initWithTileSource:(RMTileSource*)_tileSource progressView:(UIProgressView*) progressView;
- (void) startMapDownload;

@end
