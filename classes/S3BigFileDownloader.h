//
//  S3BigFileDownloader.h
//  iBurn
//
//  Created by Andrew Johnson on 8/3/13.
//
//

#import <AmazonS3Client.h>
#import <Foundation/Foundation.h>

@interface S3BigFileDownloader : NSObject <AmazonServiceRequestDelegate>

- (void) loadMBTilesFile;
- (NSString*) mbTilesPath;
- (void) copyMBTileFileFromBundle;


@end
