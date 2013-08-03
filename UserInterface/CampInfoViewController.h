//
//  CampInfoViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-18.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "InfoViewController.h"
#import "ThemeCamp.h"

@interface CampInfoViewController : InfoViewController {
  ThemeCamp *camp;
}

@property(nonatomic,strong) ThemeCamp *camp;


- (id)initWithCamp:(ThemeCamp*)cmp;


@end


