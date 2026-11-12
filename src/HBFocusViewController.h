#import <UIKit/UIKit.h>
#import "HBViews.h"
// Pomodoro timer. The tomato ripens from green to red as the session runs. Finished sessions can count toward a habit.
@interface HBTomatoView : HBDrawingView { double progress; BOOL isBreak; NSString *text, *sub; }   // 1.1 MB of bitmap at 2x
- (void)setProgress:(double)p isBreak:(BOOL)b text:(NSString *)t sub:(NSString *)s;
+ (UIImage *)miniTomato:(BOOL)ripe;
@end
@interface HBFocusViewController : UIViewController { HBTomatoView *tomato; UISegmentedControl *length; UIButton *linkButton; UILabel *todayLabel; UIView *dots; NSTimer *tick;
    NSInteger mode; /* 0 idle, 1 work, 2 break */ NSTimeInterval endTime, pausedRemaining; NSInteger total, dotsShown; }
@end
