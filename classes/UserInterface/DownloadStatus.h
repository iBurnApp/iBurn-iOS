//
//  DownloadStatus.h
//  TrailTracker
//
//  Created by Anna Johnson on 6/6/13.
//
//

#import <ASIProgressDelegate.h>

@class DownloadStatus;

@protocol DownloadStatusDelegate <NSObject>

- (void) downloadingStatusChanged:(DownloadStatus *) ds;

@end

@interface DownloadStatus : NSObject<ASIProgressDelegate> {
  float lastProgressNotified;
}

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * slug;
@property (nonatomic, retain) NSString * msg;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) BOOL downloading;
@property (nonatomic, retain) NSObject * object;
@property (nonatomic, assign) float currentBandwidth;

// These will not be set if progress is being maintained with only the progress delegate
@property (nonatomic, assign) float totalDownloadSize;
@property (nonatomic, assign) float sizeReceived;
@property (nonatomic, assign) id<DownloadStatusDelegate> delegate;
@property (nonatomic, retain) NSString *type;
@property (nonatomic, retain) UIImage *icon;

- (id) initWithName:(NSString*) aName object:(NSObject*) aObject;

- (void) finishedWithHttpCode:(int) code;
- (BOOL) isDownloadForObject:(NSObject*) obj;

- (void) postDownloadUpdateNotification;



@end
