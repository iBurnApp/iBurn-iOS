/*
 * Copyright (c) 2008, Keith Lazuka, dba The Polypeptides
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *	- Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *	- Neither the name of the The Polypeptides nor the
 *	  names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY Keith Lazuka ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Keith Lazuka BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//
//	  NOTES
//
//		(1) KLDate was created because I didn't want to mess around with time,
//			just dates. Also, some of the CFCalendar* functions are quite
//			slow on the iPhone (or at least they were in iPhone OS 2.0
//			when I created this class).
//
//		(2)	Special effort was made such that changing the iPhone's
//			regional format and timezone would not change the logical date.
//			This was needed in my application, Goalkeep, because the purpose
//			of the app was to chain together several days in a row. If you 
//			changed the timezone or the regional format, I didn't want the 
//			chain to break just because of international time issues.
//			
//		(3) Considering the above notes, it may be prudent 
//			to replace KLDate with NSDate.
//

#import <UIKit/UIKit.h>

@interface KLDate : NSObject <NSCopying, NSCoding> {
    NSInteger _year, _month, _day;
}

+ (id)today;

// Designated initializer
- (id)initWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day;

- (NSComparisonResult)compare:(KLDate *)otherDate;
- (NSInteger)yearOfCommonEra;
- (NSInteger)monthOfYear;
- (NSInteger)dayOfMonth;

- (BOOL)isEarlierThan:(KLDate *)aDate;
- (BOOL)isLaterThan:(KLDate *)aDate;
- (BOOL)isToday;
- (BOOL)isTheDayBefore:(KLDate *)anotherDate;

// NSCopying
- (id)copyWithZone:(NSZone *)zone;

// NSCoding
- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

@end








