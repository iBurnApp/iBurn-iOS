//
//  PeopleInfoViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-05-25.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "User.h"
#import "InfoViewController.h"

@interface PeopleInfoViewController : InfoViewController {
  User *user;
}

@property (nonatomic, retain) User *user;

@end