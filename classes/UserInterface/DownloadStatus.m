//
//  DownloadStatus.m
//  TrailTracker
//
//  Created by Anna Johnson on 6/6/13.
//
//

#import "DownloadStatus.h"

@implementation DownloadStatus


- (id) initWithName:(NSString*) aName object:(NSObject*) aObject {
  self = [super init];
  self.name = aName;
  self.object = aObject;
  self.downloading = NO;
  self.progress = 0;
  self.totalDownloadSize = 0;
  self.sizeReceived = 0;
  self.currentBandwidth = 0;
  lastProgressNotified = -1;
  self.type = @"";
  self.slug = @"";
  return self;
}


- (void) postDownloadUpdateNotification {
    dispatch_async(dispatch_get_main_queue(), ^{
      
      [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadStatusChangedNotification"
                                                          object:self
                                                        userInfo:nil];
    });
}


- (void)setProgress:(float)newProgress {
  _progress = newProgress;
 
  if (ABS(_progress - lastProgressNotified) > .001) {    
    [self postDownloadUpdateNotification];
    lastProgressNotified = _progress;    
  }
}


- (void) setSizeReceived:(float)sizeReceived {
  _sizeReceived = sizeReceived;
  if (self.sizeReceived > 0 && self.totalDownloadSize > 0) {
    self.progress = sizeReceived / self.totalDownloadSize;
  }
}


- (void) finishedWithHttpCode:(int) code {
  self.downloading = NO;
  
  if (code == 200) {
    self.msg = @"Success";
    
  } else if (code == 304) {
    self.msg = @"Not modified";
    self.progress = 1;
    
  } else {
    self.msg = @"Failed";
  }
  [self postDownloadUpdateNotification];

  
}


- (void) setDownloading:(BOOL)downloading {
  _downloading = downloading;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate downloadingStatusChanged:self];
  });
  [self postDownloadUpdateNotification];
}


- (NSString*) slug {

  if ([self.object isKindOfClass:NSClassFromString(@"MarineChartController")]) {
    return @"The catalog data about the charts.";
  }
  if ([self.object isKindOfClass:NSClassFromString(@"MarineChart")]) {
    return @"A chart from NOAA.";
  }
  return @"A set of POI data.";
}


- (NSString*) type {

  if ([self.object isKindOfClass:NSClassFromString(@"MarineChartController")]) {
    return @"Chart Catalog";
  }
  if ([self.object isKindOfClass:NSClassFromString(@"MarineChart")]) {
    return @"Chart";
  }
  return @"Data";
}


- (UIImage*) icon {

  if ([self.object isKindOfClass:NSClassFromString(@"MarineChartController")]) {
    return [UIImage imageNamed:@"399-list1.png"];
  }
  if ([self.object isKindOfClass:NSClassFromString(@"MarineChart")]) {
    return [UIImage imageNamed:@"map-icon-white.png"];
  }
  return [UIImage imageNamed:@"flag-icon.png"];
}


- (NSString*) description {
  NSString *desc = [NSString stringWithFormat:
                    @"\n\n~~~~~~~~~~~~~~~~~~~~\n" \
                    "name: %@\n" \
                    "msg: %@\n" \
                    "slug: %@\n" \
                    "type: %@\n" \
                    "progress: %f\n" \
                    "downloading: %d\n" \
                    "curr_bandwidth: %f\n" \
                    "totalDownloadSize: %f\n" \
                    "sizeReceived: %f\n" \
                    "~~~~~~~~~~~~~~~~~~~~\n\n",
                    self.name,
                    self.msg,
                    self.slug,
                    self.type,
                    self.progress,
                    self.downloading,
                    self.currentBandwidth,
                    self.totalDownloadSize,
                    self.sizeReceived];
  return desc;
}

- (BOOL) isDownloadForObject:(NSObject*) obj {
  return [obj isEqual:self.object];
}

@end
