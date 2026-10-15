#import <UIKit/UIKit.h>
#import "HBStore.h"
#import "ORJSON.h"

static NSArray *gPalette = nil; static NSArray *gHabits = nil; static NSDictionary *gLog = nil;   // in-memory copies; disk is only read once per launch

@implementation HBStore
+ (NSString *)docs { return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]; }
+ (id)readJSON:(NSString *)name { NSString *t = [NSString stringWithContentsOfFile:[[self docs] stringByAppendingPathComponent:name] encoding:NSUTF8StringEncoding error:nil]; return t ? [ORJSON parse:t] : nil; }
+ (void)writeJSON:(id)obj name:(NSString *)name { [[ORJSON stringify:obj] writeToFile:[[self docs] stringByAppendingPathComponent:name] atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
+ (NSArray *)habits { if (!gHabits) { id a = [self readJSON:@"habits.json"]; gHabits = [([a isKindOfClass:[NSArray class]] ? a : [NSArray array]) retain]; } return gHabits; }
+ (void)saveHabits:(NSArray *)h { [gHabits release]; gHabits = [[NSArray alloc] initWithArray:h]; [self writeJSON:gHabits name:@"habits.json"]; [self scheduleReminders]; }
+ (NSDictionary *)habit:(NSString *)hid { for (NSDictionary *h in [self habits]) if ([[h objectForKey:@"id"] isEqualToString:hid]) return h; return nil; }
+ (void)upsertHabit:(NSDictionary *)h {
    NSMutableArray *all = [NSMutableArray arrayWithArray:[self habits]]; BOOL found = NO;
    for (NSUInteger i = 0; i < [all count]; i++) if ([[[all objectAtIndex:i] objectForKey:@"id"] isEqualToString:[h objectForKey:@"id"]]) { [all replaceObjectAtIndex:i withObject:h]; found = YES; }
    if (!found) [all addObject:h];
    [self saveHabits:all];
}
+ (void)deleteHabit:(NSString *)hid {
    NSMutableArray *all = [NSMutableArray array]; for (NSDictionary *h in [self habits]) if (![[h objectForKey:@"id"] isEqualToString:hid]) [all addObject:h];
    [self saveHabits:all];
    NSMutableDictionary *l = [NSMutableDictionary dictionaryWithDictionary:[self log]]; [l removeObjectForKey:hid]; [self saveLog:l];
}
+ (NSDictionary *)log { if (!gLog) { id a = [self readJSON:@"log.json"]; gLog = [([a isKindOfClass:[NSDictionary class]] ? a : [NSDictionary dictionary]) retain]; } return gLog; }
+ (void)saveLog:(NSDictionary *)l { [gLog release]; gLog = [[NSDictionary alloc] initWithDictionary:l]; [self writeJSON:gLog name:@"log.json"]; }
+ (NSNumber *)value:(NSDictionary *)h day:(NSString *)key { id v = [[[self log] objectForKey:[h objectForKey:@"id"]] objectForKey:key]; return [v isKindOfClass:[NSNumber class]] ? v : nil; }
+ (void)setValue:(NSNumber *)v habit:(NSDictionary *)h day:(NSString *)key {
    NSMutableDictionary *l = [NSMutableDictionary dictionaryWithDictionary:[self log]];
    NSMutableDictionary *per = [NSMutableDictionary dictionaryWithDictionary:[l objectForKey:[h objectForKey:@"id"]] ?: [NSDictionary dictionary]];
    if (v) [per setObject:v forKey:key]; else [per removeObjectForKey:key];
    [l setObject:per forKey:[h objectForKey:@"id"]]; [self saveLog:l];
}
#pragma mark dates
+ (NSDateFormatter *)keyFmt { static NSDateFormatter *f = nil; if (!f) { f = [[NSDateFormatter alloc] init]; [f setDateFormat:@"yyyy-MM-dd"]; } return f; }
+ (NSString *)dayKey:(NSDate *)d { return [[self keyFmt] stringFromDate:d]; }
+ (NSDate *)dateFromKey:(NSString *)k { return [[self keyFmt] dateFromString:k]; }
+ (NSString *)today { return [self dayKey:[NSDate date]]; }
+ (int)weekdayIndex:(NSDate *)d { NSInteger wd = [[[NSCalendar currentCalendar] components:NSWeekdayCalendarUnit fromDate:d] weekday]; return (int)((wd + 5) % 7); }
+ (NSDate *)addDays:(int)n to:(NSDate *)d { NSDateComponents *c = [[[NSDateComponents alloc] init] autorelease]; [c setDay:n]; return [[NSCalendar currentCalendar] dateByAddingComponents:c toDate:d options:0]; }
+ (BOOL)isDue:(NSDictionary *)h on:(NSDate *)d { NSArray *days = [h objectForKey:@"days"]; int i = [self weekdayIndex:d]; return [days count] == 7 ? [[days objectAtIndex:i] boolValue] : YES; }
+ (double)target:(NSDictionary *)h { double t = [[h objectForKey:@"target"] doubleValue]; return t > 0 ? t : 1; }
+ (BOOL)isDone:(NSDictionary *)h day:(NSString *)key { NSNumber *v = [self value:h day:key]; if (!v || [v doubleValue] < 0) return NO; return [v doubleValue] >= [self target:h]; }
+ (int)state:(NSDictionary *)h on:(NSDate *)d {
    NSString *key = [self dayKey:d];
    if ([key compare:[h objectForKey:@"created"] ?: @""] == NSOrderedAscending) return HBBeforeStart;
    if ([key compare:[self today]] == NSOrderedDescending) return HBNotDue;   // the future is not a miss
    NSNumber *v = [self value:h day:key];
    if (v && [v doubleValue] < 0) return HBSkipped;
    if (![self isDue:h on:d]) return [self isDone:h day:key] ? HBDone : HBNotDue;
    if ([self isDone:h day:key]) return HBDone;
    return [key isEqualToString:[self today]] ? HBPending : HBMissed;
}
+ (NSDate *)createdDate:(NSDictionary *)h { NSDate *d = [self dateFromKey:[h objectForKey:@"created"] ?: @""]; return d ?: [NSDate date]; }
+ (double)strength:(NSDictionary *)h {
    int dueDays = 0; for (NSNumber *x in [h objectForKey:@"days"]) if ([x boolValue]) dueDays++;
    double freq = dueDays ? dueDays / 7.0 : 1.0, m = pow(0.5, sqrt(freq) / 13.0), score = 0;
    NSDate *d = [self createdDate:h], *now = [NSDate date];
    while ([[self dayKey:d] compare:[self dayKey:now]] != NSOrderedDescending) {
        int s = [self state:h on:d];
        if (s == HBDone) score = score * m + (1 - m); else if (s == HBMissed) score = score * m;
        d = [self addDays:1 to:d];
    }
    return score;
}
+ (int)streak:(NSDictionary *)h {
    int n = 0; NSDate *d = [NSDate date];
    int s0 = [self state:h on:d]; if (s0 == HBPending || s0 == HBNotDue || s0 == HBSkipped) d = [self addDays:-1 to:d];   // today still open
    for (int i = 0; i < 3660; i++) {
        int s = [self state:h on:d];
        if (s == HBDone) n++; else if (s == HBMissed || s == HBBeforeStart) break;
        d = [self addDays:-1 to:d];
    }
    return n;
}
+ (int)bestStreak:(NSDictionary *)h {
    int best = 0, n = 0; NSDate *d = [self createdDate:h], *now = [NSDate date];
    while ([[self dayKey:d] compare:[self dayKey:now]] != NSOrderedDescending) {
        int s = [self state:h on:d];
        if (s == HBDone) { n++; if (n > best) best = n; } else if (s == HBMissed) n = 0;
        d = [self addDays:1 to:d];
    }
    int cur = [self streak:h]; return best > cur ? best : cur;   // the running streak is a streak too
}
+ (void)completion:(NSDictionary *)h days:(int)cnt done:(int *)done due:(int *)due {
    int dn = 0, du = 0; NSDate *d = [NSDate date];
    for (int i = 0; i < cnt; i++) { int s = [self state:h on:d]; if (s == HBDone) { dn++; du++; } else if (s == HBMissed) du++; d = [self addDays:-1 to:d]; }
    if (done) *done = dn; if (due) *due = du;
}
+ (NSArray *)dayStates:(NSDictionary *)h from:(NSDate *)start to:(NSDate *)end {
    NSMutableArray *a = [NSMutableArray array]; NSDate *d = start;
    while ([[self dayKey:d] compare:[self dayKey:end]] != NSOrderedDescending) { [a addObject:[NSNumber numberWithInt:[self state:h on:d]]]; d = [self addDays:1 to:d]; }
    return a;
}
+ (NSArray *)weeklyCompletion:(int)weeks {
    NSArray *hs = [self habits]; NSMutableArray *out = [NSMutableArray array];
    NSDate *monday = [self addDays:-[self weekdayIndex:[NSDate date]] to:[NSDate date]];
    monday = [self addDays:-7 * (weeks - 1) to:monday];
    for (int w = 0; w < weeks; w++) {
        int done = 0, due = 0, open = 0;
        for (int i = 0; i < 7; i++) { NSDate *d = [self addDays:w * 7 + i to:monday]; for (NSDictionary *h in hs) { int s = [self state:h on:d]; if (s == HBDone) { done++; due++; } else if (s == HBMissed) due++; else if (s == HBPending) open++; } }
        [out addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:[[self addDays:w * 7 to:monday] timeIntervalSince1970]], @"t", [NSNumber numberWithDouble:due ? 100.0 * done / due : 0], @"pct", [NSNumber numberWithInt:done], @"done", [NSNumber numberWithInt:due], @"due", [NSNumber numberWithInt:due + open], @"dueSoFar", nil]];
    }
    return out;
}
+ (NSString *)newId { CFUUIDRef u = CFUUIDCreate(NULL); NSString *s = [(NSString *)CFUUIDCreateString(NULL, u) autorelease]; CFRelease(u); return s; }
+ (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }
+ (NSString *)apiKey { return [[self d] stringForKey:@"hb_api_key"] ?: @""; }
+ (void)setApiKey:(NSString *)k { [[self d] setObject:k forKey:@"hb_api_key"]; [[self d] synchronize]; }
+ (NSString *)weekKey { NSDate *m = [self addDays:-[self weekdayIndex:[NSDate date]] to:[NSDate date]]; return [@"hb_note_" stringByAppendingString:[self dayKey:m]]; }
+ (NSString *)note { return [[self d] stringForKey:[self weekKey]]; }
+ (void)setNote:(NSString *)n { if (n) [[self d] setObject:n forKey:[self weekKey]]; else [[self d] removeObjectForKey:[self weekKey]]; [[self d] synchronize]; }
#pragma mark reminders
+ (void)scheduleReminders {
    UIApplication *app = [UIApplication sharedApplication];
    for (UILocalNotification *n in [app scheduledLocalNotifications]) if (![[n.userInfo objectForKey:@"kind"] isEqualToString:@"pomo"]) [app cancelLocalNotification:n];
    NSArray *hs = [self habits]; int slots = 0;
    for (NSDictionary *h in hs) { if ([[h objectForKey:@"reminder"] integerValue] < 0) continue; for (NSNumber *x in [h objectForKey:@"days"]) if ([x boolValue]) slots++; }
    BOOL perWeekday = slots <= 60;   // iOS keeps the 64 soonest notifications; fall back to one daily alarm per habit
    NSCalendar *cal = [NSCalendar currentCalendar];
    for (NSDictionary *h in hs) {
        NSInteger mins = [[h objectForKey:@"reminder"] integerValue]; if (mins < 0) continue;
        NSArray *days = [h objectForKey:@"days"];
        for (int wd = 0; wd < 7; wd++) {
            if (perWeekday && ![[days objectAtIndex:wd] boolValue]) continue;
            if (!perWeekday && wd > 0) break;
            NSDate *d = [NSDate date];
            for (int i = 0; i < 8; i++) {
                NSDateComponents *c = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:d];
                [c setHour:mins / 60]; [c setMinute:mins % 60]; [c setSecond:0];
                NSDate *fire = [cal dateFromComponents:c];
                if ([fire timeIntervalSinceNow] > 0 && (!perWeekday || [self weekdayIndex:fire] == wd)) {
                    UILocalNotification *n = [[[UILocalNotification alloc] init] autorelease];
                    n.fireDate = fire; n.timeZone = [NSTimeZone defaultTimeZone]; n.repeatInterval = perWeekday ? NSWeekCalendarUnit : NSDayCalendarUnit;
                    n.alertBody = [h objectForKey:@"name"]; n.alertAction = @"Check off"; n.soundName = UILocalNotificationDefaultSoundName;
                    n.userInfo = [NSDictionary dictionaryWithObject:[h objectForKey:@"id"] forKey:@"habit"];
                    [app scheduleLocalNotification:n];
                    break;
                }
                d = [self addDays:1 to:d];
            }
        }
    }
}
+ (NSDictionary *)pomo { id a = [self readJSON:@"pomodoros.json"]; return [a isKindOfClass:[NSDictionary class]] ? a : [NSDictionary dictionary]; }
+ (NSInteger)pomodorosToday { return [[[self pomo] objectForKey:[self today]] integerValue]; }
+ (void)addPomodoro { NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:[self pomo]]; [p setObject:[NSNumber numberWithInteger:[[p objectForKey:[self today]] integerValue] + 1] forKey:[self today]]; [self writeJSON:p name:@"pomodoros.json"]; }
+ (NSInteger)pomodorosInLastDays:(int)n { NSInteger t = 0; NSDate *d = [NSDate date]; for (int i = 0; i < n; i++) { t += [[[self pomo] objectForKey:[self dayKey:d]] integerValue]; d = [self addDays:-1 to:d]; } return t; }
+ (NSArray *)pomodorosByDay:(int)n {
    NSMutableArray *out = [NSMutableArray array]; NSDictionary *p = [self pomo];
    for (int i = n - 1; i >= 0; i--) { NSDate *d = [self addDays:-i to:[NSDate date]]; [out addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:[d timeIntervalSince1970]], @"t", [NSNumber numberWithInteger:[[p objectForKey:[self dayKey:d]] integerValue]], @"count", nil]]; }
    return out;
}
+ (NSString *)describeSchedule:(NSDictionary *)h {
    NSArray *days = [h objectForKey:@"days"]; if ([days count] != 7) return @"Every day";
    int n = 0; for (NSNumber *x in days) if ([x boolValue]) n++;
    if (n == 7) return @"Every day"; if (n == 0) return @"Never";
    BOOL weekdays = YES; for (int i = 0; i < 7; i++) if ([[days objectAtIndex:i] boolValue] != (i < 5)) weekdays = NO;
    if (weekdays) return @"Weekdays";
    BOOL weekend = YES; for (int i = 0; i < 7; i++) if ([[days objectAtIndex:i] boolValue] != (i >= 5)) weekend = NO;
    if (weekend) return @"Weekends";
    NSArray *names = [NSArray arrayWithObjects:@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun", nil]; NSMutableArray *on = [NSMutableArray array];
    for (int i = 0; i < 7; i++) if ([[days objectAtIndex:i] boolValue]) [on addObject:[names objectAtIndex:i]];
    return [on componentsJoinedByString:@", "];
}
+ (NSString *)describeTime:(NSInteger)m { if (m < 0) return @"None"; NSInteger h = m / 60; return [NSString stringWithFormat:@"%ld:%02ld %@", (long)(h % 12 == 0 ? 12 : h % 12), (long)(m % 60), h < 12 ? @"AM" : @"PM"]; }
+ (NSArray *)palette {
    if (!gPalette) gPalette = [[NSArray arrayWithObjects:
        [UIColor colorWithRed:0.42 green:0.70 blue:0.16 alpha:1], [UIColor colorWithRed:0.20 green:0.52 blue:0.90 alpha:1], [UIColor colorWithRed:0.93 green:0.47 blue:0.14 alpha:1],
        [UIColor colorWithRed:0.86 green:0.24 blue:0.32 alpha:1], [UIColor colorWithRed:0.55 green:0.35 blue:0.80 alpha:1], [UIColor colorWithRed:0.10 green:0.65 blue:0.65 alpha:1], nil] retain];
    return gPalette;
}
+ (UIColor *)color:(NSDictionary *)h { NSInteger i = [[h objectForKey:@"color"] integerValue]; NSArray *p = [self palette]; return [p objectAtIndex:(i % [p count] + [p count]) % [p count]]; }
@end
