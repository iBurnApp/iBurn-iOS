//
//  NSString-NumberStuff.m
//  CashFlow
//
//  Created by Jeff LaMarche on 11/6/08.
//  Copyright 2008 Jeff LaMarche Consulting. All rights reserved.
//

#import "NSString-NumberStuff.h"


@implementation NSString(NumberStuff)
- (BOOL)holdsFloatingPointValue
{
	return [self holdsFloatingPointValueForLocale:[NSLocale currentLocale]];
}
- (BOOL)holdsFloatingPointValueForLocale:(NSLocale *)locale
{
	NSString *currencySymbol = [locale objectForKey:NSLocaleCurrencySymbol];
	NSString *decimalSeparator = [locale objectForKey:NSLocaleDecimalSeparator];
	NSString *groupingSeparator = [locale objectForKey:NSLocaleGroupingSeparator];
	
	
	// Must be at least one character
	if ([self length] == 0)
		return NO;
	NSString *compare = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	
	// Strip out grouping separators
	compare = [compare stringByReplacingOccurrencesOfString:groupingSeparator withString:@""];
	
	// We'll allow a single dollar sign in the mix
	if ([compare hasPrefix:currencySymbol])
	{	
		compare = [compare substringFromIndex:1];
		// could be spaces between dollar sign and first digit
		compare = [compare stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	}
	
	NSUInteger numberOfSeparators = 0;
	
	NSCharacterSet *validCharacters = [NSCharacterSet decimalDigitCharacterSet];
	for (NSUInteger i = 0; i < [compare length]; i++) 
	{
		unichar oneChar = [compare characterAtIndex:i];
		if (oneChar == [decimalSeparator characterAtIndex:0])
			numberOfSeparators++;
		else if (![validCharacters characterIsMember:oneChar])
			return NO;
	}
	return (numberOfSeparators == 1);
	
}
- (BOOL)holdsIntegerValue
{
	if ([self length] == 0)
		return NO;
	
	NSString *compare = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSCharacterSet *validCharacters = [NSCharacterSet decimalDigitCharacterSet];
	for (NSUInteger i = 0; i < [compare length]; i++) 
	{
		unichar oneChar = [compare characterAtIndex:i];
		if (![validCharacters characterIsMember:oneChar])
			return NO;
	}
	return YES;
}
+ (id)formattedCurrencyStringWithValue:(float)inValue
{

		NSNumberFormatter *numberFormatter;
		NSString *ret;
		numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
		[numberFormatter setCurrencyCode:[[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode]];
//		[numberFormatter setNegativePrefix:[[NSLocale currentLocale] negativePrefix]];
		
	
		ret = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:inValue]];
		[numberFormatter release];
		return ret;

}
@end
