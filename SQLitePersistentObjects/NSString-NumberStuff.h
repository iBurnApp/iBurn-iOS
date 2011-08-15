//
//  NSString-NumberStuff.h
//  CashFlow
//
//  Created by Jeff LaMarche on 11/6/08.

#import <Foundation/Foundation.h>

@interface NSString(NumberStuff)
- (BOOL)holdsFloatingPointValue;
- (BOOL)holdsFloatingPointValueForLocale:(NSLocale *)locale;
- (BOOL)holdsIntegerValue;
+ (id)formattedCurrencyStringWithValue:(float)inValue;
@end
