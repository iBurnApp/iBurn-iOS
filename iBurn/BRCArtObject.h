//
//  BRCArtObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"

@interface BRCArtObject : BRCDataObject

@property (nonatomic, strong, readonly) NSString *artistName;
@property (nonatomic, strong, readonly) NSString *artistLocation;
/** use thumbnail_url key in dict */
@property (nonatomic, strong, readonly) NSArray<NSDictionary*> *imageURLs;

/** Returns local URL if present, otherwise remote */
@property (nonatomic, strong, readonly) NSURL *audioURL;
/** Remote audio tour URL */
@property (nonatomic, strong, readonly) NSURL *remoteAudioURL;
/** If cached, returns local URL otherwise nil */
@property (nonatomic, strong, readonly) NSURL *localAudioURL;

@end
