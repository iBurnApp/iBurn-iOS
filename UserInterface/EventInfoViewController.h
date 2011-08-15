//
//  EventInfoViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-08-22.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "InfoViewController.h"

@class Event;

@interface EventInfoViewController : InfoViewController  {
    Event *event;
}

@property (nonatomic, retain) Event *event;

@end


