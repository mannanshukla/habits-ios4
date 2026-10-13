#import <UIKit/UIKit.h>
// Shared drawing: line/bar chart, the 12-week heatmap, the slide-up drum picker, and check circles.
@interface HBChartView : UIView { NSArray *xs, *ys, *labels; BOOL bars; NSString *callout; UIColor *tint; double fixedMax; }
@property (nonatomic, assign) double fixedMax;   // > 0 pins the top of the y axis (100 for percent charts)
- (void)setXs:(NSArray *)x ys:(NSArray *)y bars:(BOOL)b labels:(NSArray *)l callout:(NSString *)c tint:(UIColor *)t;
@end
@interface HBHeatmapView : UIView { NSArray *states; int startWeekday; UIColor *tint; }
- (void)setStates:(NSArray *)s startWeekday:(int)wd tint:(UIColor *)t;   // states oldest first, first entry's weekday index (0 = Mon)
+ (CGFloat)heightForWeeks:(int)w;
@end
typedef void (^HBDrumChange)(NSInteger row);
@interface HBDrum : NSObject <UIPickerViewDataSource, UIPickerViewDelegate> { UIView *view; UIPickerView *picker; UIDatePicker *timePicker; UILabel *title; NSArray *rows; HBDrumChange onChange; void (^onDone)(void); UIToolbar *bar; }
+ (HBDrum *)shared;
- (void)showInView:(UIView *)host title:(NSString *)t rows:(NSArray *)r selected:(NSInteger)i onChange:(HBDrumChange)c onDone:(void (^)(void))d;
- (void)showTimeInView:(UIView *)host title:(NSString *)t minutes:(NSInteger)m onChange:(HBDrumChange)c onDone:(void (^)(void))d;
- (void)hide;
- (BOOL)visible;
@end
UIImage *HBCircle(UIColor *color, double progress, int state, CGFloat size);   // state: 0 open, 1 done, 2 skipped
