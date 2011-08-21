// 
//  ThemeCamp.m
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ThemeCamp.h"

#import "Favorite.h"

@implementation ThemeCamp 

@dynamic zoom;
@dynamic longitude;
@dynamic url;
@dynamic latitude;
@dynamic desc;
@dynamic location;
@dynamic bm_id;
@dynamic year;
@dynamic name;
@dynamic contactEmail;
@dynamic Favorite;
@dynamic simpleName;



+ (NSCharacterSet*) getNonAlphaNumericCharacterSet {
  static NSCharacterSet* cs;
  if (!cs) {
    cs = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    cs = [cs retain];
  }
  return cs;
}


+ (NSString*) createSimpleName:(NSString*) name {
  NSString* simpleName = [[name componentsSeparatedByCharactersInSet:[ThemeCamp getNonAlphaNumericCharacterSet]] componentsJoinedByString:@""];
  
  return [simpleName lowercaseString];

}
@end
