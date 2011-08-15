//
//  ArtInfoViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-18.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "InfoViewController.h"
#import "ArtInstall.h"

@interface ArtInfoViewController : InfoViewController {
  ArtInstall *art;
}

- (id)initWithArt:(ArtInstall*)artInstall;


@end


