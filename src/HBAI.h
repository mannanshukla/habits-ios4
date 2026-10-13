#import <Foundation/Foundation.h>
// Non-streaming OpenRelay completions. Synchronous; call off the main thread.
@interface HBAI : NSObject
+ (NSString *)complete:(NSString *)system user:(NSString *)user error:(NSString **)err;
+ (NSArray *)habitsForGoal:(NSString *)goal count:(NSInteger)n error:(NSString **)err;   // validated habit dicts, not yet saved
+ (NSString *)weeklyNoteWithError:(NSString **)err;
@end
