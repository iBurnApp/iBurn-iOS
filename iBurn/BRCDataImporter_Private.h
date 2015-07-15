//
//  BRCDataImporter_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/11/15.
//  Copyright © 2015 Burning Man Earth. All rights reserved.
//

#import "BRCDataImporter.h"
#import "BRCUpdateInfo.h"

@interface BRCDataImporter(Private)
/** Synchronously imports data. Do not call from outside of tests! */
- (BOOL) loadDataFromJSONData:(NSData*)jsonData
                    dataClass:(Class)dataClass
                   updateInfo:(BRCUpdateInfo*)updateInfo
                        error:(NSError**)error;
@end

