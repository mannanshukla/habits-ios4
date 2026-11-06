#import <Foundation/Foundation.h>
@interface HBAI : NSObject
+ (NSString *)habitSystem;
+ (NSString *)goalPrompt:(NSString *)goal count:(NSInteger)n constraints:(NSString *)constraints;
+ (NSArray *)parseHabits:(NSString *)text count:(NSInteger)n error:(NSString **)error;
+ (NSString *)summary;
+ (NSString *)weeklySystem;
@end
