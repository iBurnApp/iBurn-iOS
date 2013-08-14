//
//  DownloadStatusCenter.m
//  TrailTracker
//
//  Created by Anna Johnson on 6/6/13.
//
//

#import "DownloadStatusCenter.h"

@implementation DownloadStatusCenter




- (id) init {
  self = [super init];
  self.downloads = [NSMutableArray array];
  return self;
}

+ (DownloadStatusCenter*)sharedInstance {
  static DownloadStatusCenter *sharedInstance = nil;
  @synchronized(self) {
    if (sharedInstance == nil) {
			@autoreleasepool {
        sharedInstance = [[DownloadStatusCenter alloc] init];
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
			}
    }
  }
  return sharedInstance;
}

- (void) addDownload:(DownloadStatus*) download {
  [self.downloads addObject:download];
  download.delegate = self;
  [[NSNotificationCenter defaultCenter] postNotificationName:@"NewDownloadAdded"
                                                      object:self
                                                    userInfo:nil];
}

- (void) removeDownload:(DownloadStatus*) download {
  [self.downloads removeObject:download];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"NewDownloadAdded"
                                                      object:self
                                                    userInfo:nil];
}



- (void) downloadingStatusChanged:(DownloadStatus*) ds {
  self.allDownloadsComplete = YES;
  for (DownloadStatus * status in self.downloads) {
    if (status.progress < 0.99) {
      self.allDownloadsComplete = NO;
      break;
    }
  }
  
  if (ds.downloading && !self.downloading) {
    self.downloading = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GlobalDownloadingStateChanged" object:self];
    
  }
  
  
  
  if (self.downloading) {
    for (DownloadStatus * status in self.downloads) {
      if (status.downloading) {
        return;
      }
    }
    
    self.downloading = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GlobalDownloadingStateChanged" object:self];

  }
}

- (DownloadStatus*) downloadStatusForObject:(NSObject*) obj {
  for (DownloadStatus * status in self.downloads) {
    if ([status isDownloadForObject:obj]) {
      return status;
    }
  }
  return nil;
}



@end
