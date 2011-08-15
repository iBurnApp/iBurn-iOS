//
//  EventNodeController.h
//  iBurn
//
//  Created by Andrew Johnson on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "NodeController.h"


@interface EventNodeController : NodeController {

  NSMutableDictionary *eventDateHash;
  
}

@property(nonatomic,retain) NSMutableDictionary *eventDateHash;


@end
