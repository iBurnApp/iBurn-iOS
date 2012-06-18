//
//  NSObject-MissingKV.h
//  iContractor
//
//  Created by Jeff LaMarche on 2/18/09.
//  Copyright 2009 Jeff LaMarche Consulting. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef TARGET_OS_IPHONE
@interface NSObject(MissingKV) 
- (void)takeValuesFromDictionary:(NSDictionary *)properties;
- (void)takeValue:(id)value forKey:(NSString *)key;
@end
#endif;
