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

#import "KLCalendarModel.h"
#import "THCalendarInfo.h"
#import "KLDate.h"

@implementation KLCalendarModel

- (id)init
{
    if (![super init])
        return nil;
    
    _calendarInfo = [[THCalendarInfo alloc] init];
    [_calendarInfo setDate:[NSDate date]];
    
    _cal = CFCalendarCopyCurrent();
    
    _dayNames = [[NSArray alloc] initWithObjects:@"Sun", @"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", nil];
    return self;
}



#pragma mark Public methods

- (void)decrementMonth
{
    [_calendarInfo moveToPreviousMonth];
}

- (void)incrementMonth
{
    [_calendarInfo moveToNextMonth];
}

- (NSString *)selectedMonthName
{
    return [_calendarInfo monthName];
}

- (NSInteger)selectedYear
{
    return [_calendarInfo year];
}

- (NSInteger)selectedMonthNumberOfWeeks
{
    return (NSInteger)[_calendarInfo weeksInMonth];

}

// gives you "Mon" for input 1 if region is set to United States ("Mon" for Monday)
// if region uses a calendar that starts the week with monday, an input of 1 will give "Tue"
- (NSString *)dayNameAbbreviationForDayOfWeek:(NSUInteger)dayOfWeek
{
    if (CFCalendarGetFirstWeekday(_cal) == 2)          // Monday is first day of week
        return [_dayNames objectAtIndex:(dayOfWeek+1)%7];
    
    return [_dayNames objectAtIndex:dayOfWeek];        // Sunday is first day of week
}

- (NSArray *)daysInFinalWeekOfPreviousMonth
{
    NSDate *savedState = [_calendarInfo date];
    NSMutableArray *days = [NSMutableArray array];

    [_calendarInfo moveToFirstDayOfMonth];
    [_calendarInfo moveToPreviousDay];
    NSInteger year = [_calendarInfo year];
    NSInteger month = [_calendarInfo month];
    NSInteger lastDayOfPreviousMonth = [_calendarInfo dayOfMonth];
    NSInteger lastDayOfWeekInPreviousMonth = [_calendarInfo dayOfWeek];
    
    if (lastDayOfWeekInPreviousMonth != 7)
        for (NSInteger day = 1 + lastDayOfPreviousMonth - lastDayOfWeekInPreviousMonth; day <= lastDayOfPreviousMonth; day++) {
            KLDate *d = [[KLDate alloc] initWithYear:year month:month day:day];
            [days addObject:d];
            [d release];
        }

        
    [_calendarInfo setDate:savedState];
    return days;
}

- (NSArray *)daysInSelectedMonth
{
    NSDate *savedState = [_calendarInfo date];
    NSMutableArray *days = [NSMutableArray array];
    
    NSInteger year = [_calendarInfo year];
    NSInteger month = [_calendarInfo month];
    NSInteger lastDayOfMonth = [_calendarInfo daysInMonth];
    
    for (NSInteger day = 1; day <= lastDayOfMonth; day++) {
        KLDate *d = [[KLDate alloc] initWithYear:year month:month day:day];
        [days addObject:d];
        [d release];
    }
    
    [_calendarInfo setDate:savedState];
    
    return days;
}

- (NSArray *)daysInFirstWeekOfFollowingMonth
{
    NSDate *savedState = [_calendarInfo date];
    NSMutableArray *days = [NSMutableArray array];
    
    [_calendarInfo moveToNextMonth];
    [_calendarInfo moveToFirstDayOfMonth];
    NSInteger year = [_calendarInfo year];
    NSInteger month = [_calendarInfo month];
    NSInteger firstDayOfWeekInFollowingMonth = [_calendarInfo dayOfWeek];
    
    if (firstDayOfWeekInFollowingMonth != 1)
        for (NSInteger day = 1; day <= 8-firstDayOfWeekInFollowingMonth; day++) {
            KLDate *d = [[KLDate alloc] initWithYear:year month:month day:day];
            [days addObject:d];
            [d release];
        }
    
    [_calendarInfo setDate:savedState];
    return days;
}

- (void)dealloc
{
    CFRelease(_cal);
    [_calendarInfo release];
    [_dayNames release];
    [super dealloc];
}

@end





