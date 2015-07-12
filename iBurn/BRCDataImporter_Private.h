//
//  BRCDataImporter_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/11/15.
//  Copyright © 2015 Burning Man Earth. All rights reserved.
//

#import "BRCDataImporter.h"

@interface BRCDataImporter(Private)
/** Synchronously imports data. Do not call from main thread! */
- (BOOL) loadDataFromJSONData:(NSData*)jsonData
                    dataClass:(Class)dataClass
                        error:(NSError**)error;
@end

