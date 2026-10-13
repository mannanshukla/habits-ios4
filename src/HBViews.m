#import "HBViews.h"
#import "HBStore.h"
#import <QuartzCore/QuartzCore.h>

static NSString *fmtNum(double v) {
    if (fabs(v) >= 10000) return [NSString stringWithFormat:@"%.1fk", v / 1000];
    return v == floor(v) ? [NSString stringWithFormat:@"%.0f", v] : [NSString stringWithFormat:@"%.1f", v];
}
static NSString *fmtDay(double t) { NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; [f setDateFormat:@"MMM d"]; return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:t]]; }

@implementation HBChartView
@synthesize fixedMax;
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor whiteColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)dealloc { [xs release]; [ys release]; [labels release]; [callout release]; [tint release]; [super dealloc]; }
- (void)setXs:(NSArray *)x ys:(NSArray *)y bars:(BOOL)b labels:(NSArray *)l callout:(NSString *)c tint:(UIColor *)t {
    [xs release]; xs = [x retain]; [ys release]; ys = [y retain]; [labels release]; labels = [l retain]; bars = b; [callout release]; callout = [c retain]; [tint release]; tint = [t retain]; [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds; NSUInteger n = [ys count];
    UIColor *accent = tint ?: [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1];
    if (n < (bars ? 1 : 2)) {
        [[UIColor colorWithWhite:0.6 alpha:1] set];
        [@"Not enough data yet." drawInRect:CGRectMake(10, b.size.height / 2 - 10, b.size.width - 20, 20) withFont:[UIFont systemFontOfSize:14] lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentCenter];
        return;
    }
    CGFloat L = 40, R = 12, T = 18, B = 20;
    CGRect plot = CGRectMake(L, T, b.size.width - L - R, b.size.height - T - B);
    double ymin = 1e300, ymax = -1e300;
    for (NSNumber *v in ys) { double d = [v doubleValue]; if (d < ymin) ymin = d; if (d > ymax) ymax = d; }
    if (bars) ymin = 0;
    if (ymax - ymin < 1e-9) { ymin -= 1; ymax += 1; }
    double pad = (ymax - ymin) * 0.1; if (!bars) ymin -= pad; ymax += pad;
    if (fixedMax > 0) { ymin = 0; ymax = fixedMax; }
    UIFont *small = [UIFont systemFontOfSize:10];
    CGContextSetLineWidth(c, 1);
    for (int i = 0; i <= 2; i++) {
        double v = ymin + (ymax - ymin) * i / 2.0;
        CGFloat py = floorf(CGRectGetMaxY(plot) - (v - ymin) / (ymax - ymin) * plot.size.height) + 0.5;
        [[UIColor colorWithWhite:0.88 alpha:1] set];
        CGContextMoveToPoint(c, plot.origin.x, py); CGContextAddLineToPoint(c, CGRectGetMaxX(plot), py); CGContextStrokePath(c);
        [[UIColor colorWithWhite:0.5 alpha:1] set];
        [fmtNum(v) drawInRect:CGRectMake(0, py - 6, L - 6, 12) withFont:small lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];
    }
    double xmin = [[xs objectAtIndex:0] doubleValue], xmax = [[xs lastObject] doubleValue];
    if (bars || xmax - xmin < 1e-9) { xmin = 0; xmax = n - 1; }
    CGFloat (^px)(NSUInteger) = ^CGFloat(NSUInteger i) {
        if (bars) return plot.origin.x + plot.size.width * (i + 0.5) / n;
        double x = (xmax - xmin) > 0 ? [[xs objectAtIndex:i] doubleValue] : i;
        return plot.origin.x + (CGFloat)((x - xmin) / (xmax - xmin)) * plot.size.width;
    };
    CGFloat (^py)(NSUInteger) = ^CGFloat(NSUInteger i) { return CGRectGetMaxY(plot) - (CGFloat)(([[ys objectAtIndex:i] doubleValue] - ymin) / (ymax - ymin)) * plot.size.height; };
    if (bars) {
        CGFloat bw = floorf(plot.size.width / n * 0.62);
        for (NSUInteger i = 0; i < n; i++) {
            double v = [[ys objectAtIndex:i] doubleValue];
            CGFloat x = floorf(px(i) - bw / 2), top = py(i);
            if (v <= 0) { [[UIColor colorWithWhite:0.85 alpha:1] set]; CGContextFillRect(c, CGRectMake(x, CGRectGetMaxY(plot) - 2, bw, 2)); continue; }
            [(i == n - 1 || labels ? accent : [accent colorWithAlphaComponent:0.6]) set];
            CGContextFillRect(c, CGRectMake(x, top, bw, CGRectGetMaxY(plot) - top));
        }
    } else {
        CGContextSaveGState(c);
        CGContextMoveToPoint(c, px(0), CGRectGetMaxY(plot));
        for (NSUInteger i = 0; i < n; i++) CGContextAddLineToPoint(c, px(i), py(i));
        CGContextAddLineToPoint(c, px(n - 1), CGRectGetMaxY(plot)); CGContextClosePath(c);
        [[accent colorWithAlphaComponent:0.14] set]; CGContextFillPath(c);
        CGContextRestoreGState(c);
        [accent set]; CGContextSetLineWidth(c, 2); CGContextSetLineJoin(c, kCGLineJoinRound); CGContextSetLineCap(c, kCGLineCapRound);
        CGContextMoveToPoint(c, px(0), py(0));
        for (NSUInteger i = 1; i < n; i++) CGContextAddLineToPoint(c, px(i), py(i));
        CGContextStrokePath(c);
        if (n <= 40) for (NSUInteger i = 0; i < n; i++) {
            CGRect d = CGRectMake(px(i) - 3, py(i) - 3, 6, 6);
            [[UIColor whiteColor] set]; CGContextFillEllipseInRect(c, d);
            [accent set]; CGContextSetLineWidth(c, 1.5); CGContextStrokeEllipseInRect(c, d);
        }
    }
    if (callout) { [accent set]; [callout drawInRect:CGRectMake(plot.origin.x, 3, plot.size.width, 13) withFont:[UIFont boldSystemFontOfSize:11] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight]; }
    [[UIColor colorWithWhite:0.5 alpha:1] set];
    if (labels) {
        for (NSUInteger i = 0; i < n && i < [labels count]; i++) [[labels objectAtIndex:i] drawInRect:CGRectMake(px(i) - 20, CGRectGetMaxY(plot) + 5, 40, 12) withFont:small lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
    } else {
        [fmtDay([[xs objectAtIndex:0] doubleValue]) drawInRect:CGRectMake(plot.origin.x, CGRectGetMaxY(plot) + 5, plot.size.width / 2, 12) withFont:small lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft];
        [(bars ? @"this week" : fmtDay([[xs lastObject] doubleValue])) drawInRect:CGRectMake(CGRectGetMidX(plot), CGRectGetMaxY(plot) + 5, plot.size.width / 2, 12) withFont:small lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];
    }
}
@end

#define CELL 15
#define GAP 3
@implementation HBHeatmapView
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor whiteColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)dealloc { [states release]; [tint release]; [super dealloc]; }
+ (CGFloat)heightForWeeks:(int)w { return 16 + 7 * (CELL + GAP) + 4; }
- (void)setStates:(NSArray *)s startWeekday:(int)wd tint:(UIColor *)t { [states release]; states = [s retain]; startWeekday = wd; [tint release]; tint = [t retain]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    UIColor *accent = tint ?: [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1];
    CGFloat left = 28, top = 16;
    NSArray *dn = [NSArray arrayWithObjects:@"M", @"T", @"W", @"T", @"F", @"S", @"S", nil];
    [[UIColor colorWithWhite:0.5 alpha:1] set];
    for (int r = 0; r < 7; r++) if (r % 2 == 0) [[dn objectAtIndex:r] drawInRect:CGRectMake(0, top + r * (CELL + GAP) + 1, left - 8, 12) withFont:[UIFont systemFontOfSize:10] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];
    NSUInteger n = [states count]; int col = 0, row = startWeekday, lastLabelCol = -9; NSString *lastMonth = nil;
    NSDate *d = [HBStore addDays:-(int)(n - 1) to:[NSDate date]];
    NSDateFormatter *mf = [[[NSDateFormatter alloc] init] autorelease]; [mf setDateFormat:@"MMM"];
    for (NSUInteger i = 0; i < n; i++) {
        int s = [[states objectAtIndex:i] intValue];
        CGRect r = CGRectMake(left + col * (CELL + GAP), top + row * (CELL + GAP), CELL, CELL);
        UIColor *fill = [UIColor colorWithWhite:0.93 alpha:1];
        if (s == HBDone) fill = accent; else if (s == HBMissed) fill = [UIColor colorWithRed:0.95 green:0.80 blue:0.80 alpha:1];
        else if (s == HBSkipped) fill = [UIColor colorWithRed:0.98 green:0.90 blue:0.65 alpha:1]; else if (s == HBBeforeStart) fill = [UIColor colorWithWhite:0.97 alpha:1];
        [fill set]; CGContextFillRect(c, r);
        if (s == HBPending) { [accent set]; CGContextSetLineWidth(c, 1.5); CGContextStrokeRect(c, CGRectInset(r, 1, 1)); }
        NSString *mo = [mf stringFromDate:d];
        if (row == 0 && ![mo isEqualToString:lastMonth]) { if (col - lastLabelCol >= 2) { [[UIColor colorWithWhite:0.5 alpha:1] set]; [mo drawInRect:CGRectMake(r.origin.x, 0, 40, 12) withFont:[UIFont systemFontOfSize:10] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft]; lastLabelCol = col; } lastMonth = mo; }
        row++; if (row == 7) { row = 0; col++; }
        d = [HBStore addDays:1 to:d];
    }
}
@end

@implementation HBDrum
+ (HBDrum *)shared { static HBDrum *d = nil; if (!d) d = [[HBDrum alloc] init]; return d; }
- (void)build:(UIView *)host {
    CGRect b = host.bounds;
    if (!view) {
        view = [[UIView alloc] initWithFrame:CGRectMake(0, b.size.height, b.size.width, 260)];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, 44)]; bar.barStyle = UIBarStyleBlack; bar.translucent = NO;
        title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 170, 44)]; title.font = [UIFont boldSystemFontOfSize:14]; title.adjustsFontSizeToFitWidth = YES; title.minimumFontSize = 10; title.textColor = [UIColor whiteColor]; title.backgroundColor = [UIColor clearColor]; title.textAlignment = UITextAlignmentCenter;
        UIBarButtonItem *flex = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
        bar.items = [NSArray arrayWithObjects:flex, [[[UIBarButtonItem alloc] initWithCustomView:title] autorelease], flex, [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] autorelease], nil];
        [view addSubview:bar];
        picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 44, b.size.width, 216)]; picker.dataSource = self; picker.delegate = self; picker.showsSelectionIndicator = YES; picker.backgroundColor = [UIColor blackColor];
        timePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 44, b.size.width, 216)]; timePicker.datePickerMode = UIDatePickerModeTime; timePicker.minuteInterval = 5; [timePicker addTarget:self action:@selector(timeChanged) forControlEvents:UIControlEventValueChanged];
    }
    [view removeFromSuperview]; [host addSubview:view];
    view.frame = CGRectMake(0, b.size.height, b.size.width, 260);
    [UIView beginAnimations:nil context:NULL]; [UIView setAnimationDuration:0.3];
    view.frame = CGRectMake(0, b.size.height - 260, b.size.width, 260);
    [UIView commitAnimations];
}
- (void)showInView:(UIView *)host title:(NSString *)t rows:(NSArray *)r selected:(NSInteger)i onChange:(HBDrumChange)c onDone:(void (^)(void))d {
    [self build:host]; title.text = t;
    [rows release]; rows = [r retain]; [onChange release]; onChange = [c copy]; [onDone release]; onDone = [d copy];
    [timePicker removeFromSuperview]; [view addSubview:picker]; [picker reloadAllComponents];
    [picker selectRow:MIN((NSInteger)[rows count] - 1, MAX(0, i)) inComponent:0 animated:NO];
}
- (void)showTimeInView:(UIView *)host title:(NSString *)t minutes:(NSInteger)m onChange:(HBDrumChange)c onDone:(void (^)(void))d {
    [self build:host]; title.text = t;
    [onChange release]; onChange = [c copy]; [onDone release]; onDone = [d copy];
    [picker removeFromSuperview]; [view addSubview:timePicker];
    NSDateComponents *comp = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:[NSDate date]];
    [comp setHour:m / 60]; [comp setMinute:m % 60]; timePicker.date = [[NSCalendar currentCalendar] dateFromComponents:comp];
}
- (void)timeChanged { NSDateComponents *c = [[NSCalendar currentCalendar] components:NSHourCalendarUnit | NSMinuteCalendarUnit fromDate:timePicker.date]; if (onChange) onChange([c hour] * 60 + [c minute]); }
- (void)hide {
    if (!view || !view.superview) return;
    CGRect b = view.superview.bounds;
    [UIView beginAnimations:nil context:NULL]; [UIView setAnimationDuration:0.3];
    view.frame = CGRectMake(0, b.size.height, b.size.width, 260);
    [UIView commitAnimations];
    [view performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:0.3];
}
- (BOOL)visible { return view && view.superview && view.frame.origin.y < view.superview.bounds.size.height; }
- (void)done { void (^d)(void) = onDone; [self hide]; if (d) d(); }
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pv { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pv numberOfRowsInComponent:(NSInteger)c { return [rows count]; }
- (NSString *)pickerView:(UIPickerView *)pv titleForRow:(NSInteger)row forComponent:(NSInteger)c { return [rows objectAtIndex:row]; }
- (CGFloat)pickerView:(UIPickerView *)pv widthForComponent:(NSInteger)c { return 220; }
- (void)pickerView:(UIPickerView *)pv didSelectRow:(NSInteger)row inComponent:(NSInteger)c { if (onChange) onChange(row); }
@end

UIImage *HBCircle(UIColor *color, double progress, int state, CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect r = CGRectInset(CGRectMake(0, 0, size, size), 2, 2);
    CGContextSetLineWidth(c, 2);
    if (state == 1) {
        [color set]; CGContextFillEllipseInRect(c, r);
        [[UIColor whiteColor] set]; CGContextSetLineWidth(c, 2.5); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
        CGContextMoveToPoint(c, size * 0.28, size * 0.52); CGContextAddLineToPoint(c, size * 0.44, size * 0.68); CGContextAddLineToPoint(c, size * 0.72, size * 0.34); CGContextStrokePath(c);
    } else {
        [[UIColor colorWithWhite:0.75 alpha:1] set]; CGContextStrokeEllipseInRect(c, r);
        if (state == 2) { [[UIColor colorWithWhite:0.6 alpha:1] set]; CGContextSetLineCap(c, kCGLineCapRound); CGContextMoveToPoint(c, size * 0.33, size / 2); CGContextAddLineToPoint(c, size * 0.67, size / 2); CGContextStrokePath(c); }
        else if (progress > 0) {
            [color set]; CGContextSetLineWidth(c, 3);
            CGContextAddArc(c, size / 2, size / 2, size / 2 - 3, -M_PI_2, -M_PI_2 + 2 * M_PI * MIN(1, progress), 0); CGContextStrokePath(c);
        }
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    return img;
}
