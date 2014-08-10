//
//  NSURL+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "NSURL+iBurn.h"

@implementation NSURL (iBurn)

+ (NSURL*) brc_githubURL {
    NSURL *githubURL = [NSURL URLWithString:@"https://github.com/Burning-Man-Earth/iBurn-iOS"];
    return githubURL;
}

+ (NSURL*) brc_facebookAppURL {
    NSURL *facebookURL = [NSURL URLWithString:@"fb://profile/322327871267883"];
    return facebookURL;
}

+ (NSURL*) brc_facebookWebURL {
    NSURL *facebookURL = [NSURL URLWithString:@"https://facebook.com/iBurnApp"];
    return facebookURL;
}

+ (NSURL*) brc_twitterAppURL {
    NSURL *twitterURL = [NSURL URLWithString:@"twitter://user?screen_name=iBurnApp"];
    return twitterURL;
}
+ (NSURL*) brc_twitterWebURL {
    NSURL *twitterURL = [NSURL URLWithString:@"https://twitter.com/iBurnApp"];
    return twitterURL;
}

@end
