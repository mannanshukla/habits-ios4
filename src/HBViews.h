#import <UIKit/UIKit.h>
// Shared drawing: line/bar chart, the 12-week heatmap, the slide-up drum picker, and check circles.
@interface HBChartView : UIView { NSArray *xs, *ys, *labels; BOOL bars; NSString *callout; UIColor *tint; double fixedMax; }
@property (nonatomic, assign) double fixedMax;   // > 0 pins the top of the y axis (100 for percent charts)
- (void)setXs:(NSArray *)x ys:(NSArray *)y bars:(BOOL)b labels:(NSArray *)l callout:(NSString *)c tint:(UIColor *)t;
@end
// Wall calendar on paper: one row per week, a red X on every done day. The "don't break the chain" look of 2011.
@interface HBCalendarView : UIView { NSArray *states; NSDate *start; UIColor *tint; }
- (void)setStates:(NSArray *)s start:(NSDate *)d tint:(UIColor *)t;   // states oldest first, starting on a Monday
+ (CGFloat)heightForWeeks:(int)w;
@end
// Skin: leather bars with stitching, ruled cream paper with a red margin, embossed check circles. Textures are drawn in code.
UIImage *HBLeatherImage(CGSize sz);
void HBSkinNavBar(UINavigationBar *bar);
void HBSkinPaperTable(UITableView *tv);
UIView *HBPaperStrip(CGFloat width, CGFloat height, NSString *text, BOOL bold);   // a ruled strip for headers and footers
@interface HBPaperCell : UITableViewCell @end
typedef void (^HBDrumChange)(NSInteger row);
@interface HBDrum : NSObject <UIPickerViewDataSource, UIPickerViewDelegate> { UIView *view; UIPickerView *picker; UIDatePicker *timePicker; UILabel *title; NSArray *rows; HBDrumChange onChange; void (^onDone)(void); UIToolbar *bar; }
+ (HBDrum *)shared;
- (void)showInView:(UIView *)host title:(NSString *)t rows:(NSArray *)r selected:(NSInteger)i onChange:(HBDrumChange)c onDone:(void (^)(void))d;
- (void)showTimeInView:(UIView *)host title:(NSString *)t minutes:(NSInteger)m onChange:(HBDrumChange)c onDone:(void (^)(void))d;
- (void)hide;
- (BOOL)visible;
@end
UIImage *HBCircle(UIColor *color, double progress, int state, CGFloat size);   // state: 0 open, 1 done, 2 skipped
