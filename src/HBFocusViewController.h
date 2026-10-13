#import <UIKit/UIKit.h>
// Pomodoro timer. The tomato ripens from green to red as the session runs. Finished sessions can count toward a habit.
@interface HBTomatoView : UIView { double progress; BOOL isBreak; NSString *text, *sub; }
- (void)setProgress:(double)p isBreak:(BOOL)b text:(NSString *)t sub:(NSString *)s;
+ (UIImage *)miniTomato:(BOOL)ripe;
@end
@interface HBFocusViewController : UIViewController { HBTomatoView *tomato; UISegmentedControl *length; UIButton *linkButton; UILabel *todayLabel; UIView *dots; NSTimer *tick;
    NSInteger mode; /* 0 idle, 1 work, 2 break */ NSTimeInterval endTime, pausedRemaining; NSInteger total; }
@end
