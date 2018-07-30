//
//  YapDatabaseViewConnection+iBurn.h
//  iBurn
//
//  Created by Chris Ballinger on 2/24/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

@import YapDatabase;
@class BRCSectionRowChanges;

NS_ASSUME_NONNULL_BEGIN
@interface YapDatabaseViewConnection (iBurn)

- (BRCSectionRowChanges*) brc_getSectionRowChangesForNotifications:(NSArray<NSNotification*> *)notifications
                                                      withMappings:(YapDatabaseViewMappings *)mappings;
@end
NS_ASSUME_NONNULL_END
