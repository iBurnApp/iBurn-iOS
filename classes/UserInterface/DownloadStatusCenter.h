//
//  DownloadStatusCenter.h
//  TrailTracker
//
//  Created by Anna Johnson on 6/6/13.
//
//

#import <Foundation/Foundation.h>
#import "DownloadStatus.h"



@interface DownloadStatusCenter : NSObject<DownloadStatusDelegate>

@property (nonatomic, retain) NSMutableArray * downloads;
@property (nonatomic, assign) BOOL downloading;
@property (nonatomic, assign) BOOL allDownloadsComplete;

+ (DownloadStatusCenter*)sharedInstance;

- (void) addDownload:(DownloadStatus*) download;
- (void) removeDownload:(DownloadStatus*) download;
- (DownloadStatus*) downloadStatusForObject:(NSObject*) obj;

@end
