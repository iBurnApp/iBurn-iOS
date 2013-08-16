//
//  S3BigFileDownloader.m
//  iBurn
//
//  Created by Andrew Johnson on 8/3/13.
//
//

#import <AWSiOSSDK/S3/AmazonS3Client.h>
#import "DownloadStatus.h"
#import "DownloadStatusCenter.h"
#import "NSDate-Utilities.h"
#import "S3BigFileDownloader.h"
#import "util.h"

@class AmazonS3Client;

@interface S3BigFileDownloader() {
  AmazonS3Client *s3Client;
  DownloadStatus *downloadStatus;
  int sizeTransfered, totalFileSize, downloadRetyCount, downloadAttempts;
  NSDate *lastTransferUpdate;
  NSOutputStream *downloadOutputStream;
  NSString *temporaryDestinationPath;
  S3GetObjectRequest *getObjectRequest;
}
@end


@implementation S3BigFileDownloader

- (NSDate*) lastSavedDate {
  NSString *filePath = [self cacheInfoFilePath];
  if (![[NSFileManager defaultManager]fileExistsAtPath:filePath]) {
    return nil;
  }
  NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:filePath];
  return [info objectForKey:@"mbtiles_modified_date"];
}


- (void) saveCacheDate {
  NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:[NSDate date] forKey:@"mbtiles_modified_date"];
  [info writeToFile:[self cacheInfoFilePath] atomically:YES];
}


- (NSURL*) mbTilesURL {
  NSString *urlString = [NSString stringWithFormat:@"http://%@.s3-website-us-east-1.amazonaws.com/%@", [self s3BucketName],
                                [self mbTilesBucketKey]];
  return [NSURL URLWithString:urlString];
}


- (NSString*) mbTilesPath {
  return [privateDocumentsDirectory() stringByAppendingPathComponent:[self mbTilesBucketKey]];;
}


- (NSString*) cacheInfoFilePath {
  return [privateDocumentsDirectory() stringByAppendingPathComponent:@"cache_info.json"];;
}


- (NSString*) s3DownloadKey {
  return @"AKIAI4TNGRCEZMOBLMDQ";
}


- (NSString*) s3DownloadSecret {
  return @"OQ7CVvR3q60e6iUqj64sricggjOVwSdqLD1kmsMW";
}


- (NSString*) mbTilesBucketKey {
  return @"iburn.mbtiles";
}


- (NSString*) s3BucketName {
  return @"com.gaiagps.iburn";
}


- (void) initS3Client {
  if(!s3Client) {
    s3Client = [[AmazonS3Client alloc] initWithAccessKey:[self s3DownloadKey]
                                           withSecretKey:[self s3DownloadSecret]];
    s3Client.timeout = 1200;
    s3Client.connectionTimeout = 60;
  }
  [AmazonErrorHandler shouldNotThrowExceptions];
  [AmazonLogger verboseLogging];

  S3ListObjectsRequest *req = [[S3ListObjectsRequest alloc] initWithName:[self s3BucketName]];
  
  S3ListObjectsResponse *listObjectResponse = [s3Client listObjects:req];
  
  S3ListObjectsResult *listObjectsResults = listObjectResponse.listObjectsResult;
  
  for (S3ObjectSummary *objectSummary in listObjectsResults.objectSummaries) {
    NSLog(@"Bucket Contents %@ " ,[objectSummary key]);
  }
  [AmazonLogger turnLoggingOff];
}


- (int) fileSizeForPath:(NSString*)path {
  NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
  return [fileAttribs fileSize];
}


- (void) cacheMBTiles {
  [self initS3Client];
  
  S3GetObjectMetadataRequest *metadataRequest = [[S3GetObjectMetadataRequest alloc] initWithKey:[self mbTilesBucketKey]
                                                                                     withBucket:[self s3BucketName]];
  S3GetObjectMetadataResponse *metadataResponse = [s3Client getObjectMetadata:metadataRequest];
  
  totalFileSize = metadataResponse.contentLength;
  
  NSDate * lastUpdateDate;
  if([[NSFileManager defaultManager] fileExistsAtPath:[self mbTilesPath]]) {
    NSDate *lastUpdateDate = [self lastSavedDate];
    if ([[metadataResponse lastModified] isLaterThanDate:lastUpdateDate]) {
      return;
    }
  }
  
  
  BOOL append = NO;
  temporaryDestinationPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[self mbTilesBucketKey]];;
  if ([[NSFileManager defaultManager] fileExistsAtPath:temporaryDestinationPath]) {
    sizeTransfered = [self fileSizeForPath:temporaryDestinationPath];
    if (sizeTransfered < totalFileSize -1) {
      append = YES;
    }
  }
  
  downloadOutputStream = [[NSOutputStream alloc] initToFileAtPath:temporaryDestinationPath append:append];
  [downloadOutputStream open];
  getObjectRequest = [[S3GetObjectRequest alloc] initWithKey:[self mbTilesBucketKey]
                                                  withBucket:[self s3BucketName]];
  
  if (append) {
    [getObjectRequest setRangeStart:sizeTransfered
                           rangeEnd:totalFileSize-1];
  }
  
  getObjectRequest.outputStream = downloadOutputStream;
  getObjectRequest.ifModifiedSince = lastUpdateDate;
  getObjectRequest.delegate = self;
  [s3Client getObject:getObjectRequest]; 
}


- (void) copyMBTileFileFromBundle {
  if (![[NSFileManager defaultManager]fileExistsAtPath:[self mbTilesPath]]) {
    [[NSFileManager defaultManager]copyItemAtPath:[[NSBundle mainBundle]pathForResource:@"iburn" ofType:@"mbtiles"]
                                           toPath:[self mbTilesPath] error:nil];
  }
}


- (void) loadMBTilesFile {
  [self cacheMBTiles];
}


- (void)request: (AmazonServiceRequest*)request didReceiveData:(NSData*)data {
  sizeTransfered += [data length];
  downloadStatus.sizeReceived = sizeTransfered;
  if(lastTransferUpdate) {
    NSTimeInterval interval = fabs([lastTransferUpdate timeIntervalSinceNow]);
    float intervalSpeed = ([data length]/128.0)/interval; // /128 to go from bytes to kBits
    float k = 0.8;
    downloadStatus.currentBandwidth = k * intervalSpeed + (1.0 - k) * downloadStatus.currentBandwidth;
  }
  lastTransferUpdate = [NSDate date];
}


- (void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)response {
  [downloadOutputStream close];
  downloadOutputStream = nil;
  getObjectRequest = nil;
  
  [downloadStatus finishedWithHttpCode:response.httpStatusCode];
  if (response.httpStatusCode == 304) {
    [[DownloadStatusCenter sharedInstance] removeDownload:downloadStatus];
  }
  
  if(response.httpStatusCode == 200 || response.httpStatusCode == 206) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if (response.httpStatusCode == 200) {
        [self databaseDownloadFinished];
      }
      temporaryDestinationPath = nil;
    });
  } else {
    [[NSFileManager defaultManager] removeItemAtPath:temporaryDestinationPath error:nil];
    temporaryDestinationPath = nil;
    
  }
  
  s3Client = nil;
  [self saveCacheDate];  
  lastTransferUpdate = nil;
  [self postDownloadStatusNotification];
}


- (void)postDownloadStatusNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GaiaDownloadingPOIDatabase"
                                                        object:self
                                                      userInfo:nil];
  });
}


- (void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error {
  if(downloadRetyCount < 3) {
    getObjectRequest = [[S3GetObjectRequest alloc] initWithKey:[self mbTilesBucketKey]
                                                    withBucket:[self s3BucketName]];
    
    // our start range will be the amount downloaded
    // and we want to download to the last byte
    [getObjectRequest setRangeStart:sizeTransfered
                           rangeEnd:totalFileSize-1];
    
    // reuse output stream and continue to use the same delegate
    getObjectRequest.outputStream = downloadOutputStream;
    getObjectRequest.delegate = self;
    
    // resume the download where we left off
    [s3Client getObject:getObjectRequest];
    downloadRetyCount++;
  } else {
    [downloadOutputStream close];
    downloadOutputStream = nil;
    [[NSFileManager defaultManager] removeItemAtPath:temporaryDestinationPath error:nil];
    temporaryDestinationPath = nil;
    getObjectRequest = nil;
  }
}


- (void)databaseDownloadFinished {
  [[NSFileManager defaultManager] removeItemAtPath:[self mbTilesPath] error:nil];
  [[NSFileManager defaultManager]copyItemAtPath:temporaryDestinationPath toPath:[self mbTilesPath] error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:temporaryDestinationPath error:nil];
  [[NSNotificationCenter defaultCenter]postNotificationName:@"BIG_FILE_DOWNLOAD_DONE" object:nil];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self saveCacheDate];
  });
}

@end
