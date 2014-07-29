//
//  BRCDataImporter.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataImporter.h"
#import "BRCDatabaseManager.h"
#import "MTLJSONAdapter.h"

@implementation BRCDataImporter

- (void) loadDataFromURL:(NSURL*)dataURL dataClass:(Class)dataClass completionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *jsonData = [NSData dataWithContentsOfURL:dataURL];
        NSError *error = nil;
        NSArray *jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        NSArray *objects = [MTLJSONAdapter modelsOfClass:dataClass fromJSONArray:jsonObjects error:&error];
        NSLog(@"objects count: %d", (int)objects.count);
    });
    
    //[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection
}

@end
