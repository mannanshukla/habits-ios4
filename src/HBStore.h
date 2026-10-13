#import <UIKit/UIKit.h>
// Habits + log live in Documents as JSON. Habit: {id, name, type: check|count|measure, target, unit, days:[7 ints Mon..Sun], reminder (minutes from midnight or -1), color (0-5), created (dayKey), why}
// Log: {habitId: {dayKey: value}}  value -1 means skipped.
enum { HBNotDue = 0, HBDone = 1, HBMissed = 2, HBSkipped = 3, HBPending = 4, HBBeforeStart = 5 };
@interface HBStore : NSObject
+ (NSArray *)habits; + (void)saveHabits:(NSArray *)h;
+ (NSDictionary *)habit:(NSString *)hid;
+ (void)upsertHabit:(NSDictionary *)h; + (void)deleteHabit:(NSString *)hid;
+ (NSDictionary *)log; + (void)saveLog:(NSDictionary *)l;
+ (NSNumber *)value:(NSDictionary *)h day:(NSString *)key;           // nil if nothing logged
+ (void)setValue:(NSNumber *)v habit:(NSDictionary *)h day:(NSString *)key;   // nil clears
+ (NSString *)dayKey:(NSDate *)d; + (NSDate *)dateFromKey:(NSString *)k; + (NSString *)today;
+ (int)weekdayIndex:(NSDate *)d;                                     // 0 = Monday .. 6 = Sunday
+ (NSDate *)addDays:(int)n to:(NSDate *)d;
+ (BOOL)isDue:(NSDictionary *)h on:(NSDate *)d;
+ (BOOL)isDone:(NSDictionary *)h day:(NSString *)key;
+ (int)state:(NSDictionary *)h on:(NSDate *)d;                        // HB* enum
+ (double)strength:(NSDictionary *)h;                                 // 0..1, Loop-style moving average
+ (int)streak:(NSDictionary *)h; + (int)bestStreak:(NSDictionary *)h;
+ (void)completion:(NSDictionary *)h days:(int)n done:(int *)done due:(int *)due;
+ (NSArray *)dayStates:(NSDictionary *)h from:(NSDate *)start to:(NSDate *)end;   // NSNumbers of HB*, oldest first
+ (NSArray *)weeklyCompletion:(int)weeks;                             // oldest first: {t, pct, done, due}
+ (NSString *)newId;
+ (NSString *)apiKey; + (void)setApiKey:(NSString *)k;
+ (NSString *)note; + (void)setNote:(NSString *)n;                     // cached weekly note (keyed by week in prefs)
+ (void)scheduleReminders;
+ (NSInteger)pomodorosToday; + (void)addPomodoro; + (NSInteger)pomodorosInLastDays:(int)n;
+ (NSArray *)pomodorosByDay:(int)n;   // oldest first: {t, count}   // pomodoros.json {dayKey: count}
+ (NSString *)describeSchedule:(NSDictionary *)h;                     // "Every day", "Weekdays", "Mon, Wed, Fri"
+ (NSString *)describeTime:(NSInteger)minutes;                        // "7:30 AM"
+ (UIColor *)color:(NSDictionary *)h;
+ (NSArray *)palette;
@end
