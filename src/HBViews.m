#import "HBViews.h"
#import "HBStore.h"
#import <QuartzCore/QuartzCore.h>

static NSString *fmtNum(double v) {
    if (fabs(v) >= 10000) return [NSString stringWithFormat:@"%.1fk", v / 1000];
    return v == floor(v) ? [NSString stringWithFormat:@"%.0f", v] : [NSString stringWithFormat:@"%.1f", v];
}
static NSString *fmtDay(double t) { NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; [f setDateFormat:@"MMM d"]; return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:t]]; }

// Era chart helpers: etched labels, glossy bars and dots, the way Weightbot and Nike+ drew them.
static void etched(NSString *t, CGRect r, UIFont *f, UITextAlignment a, UIColor *col) {
    CGContextRef c = UIGraphicsGetCurrentContext(); CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:1 alpha:0.9].CGColor); [col set];
    [t drawInRect:r withFont:f lineBreakMode:UILineBreakModeClip alignment:a]; CGContextRestoreGState(c);
}
static void glossBar(CGContextRef c, CGRect r, UIColor *col) {
    const CGFloat *k = CGColorGetComponents(col.CGColor); CGFloat r0 = k[0], g0 = k[1], b0 = CGColorGetNumberOfComponents(col.CGColor) >= 4 ? k[2] : k[0];
    UIColor *top = [UIColor colorWithRed:MIN(1, r0 * 1.25 + 0.08) green:MIN(1, g0 * 1.25 + 0.08) blue:MIN(1, b0 * 1.25 + 0.08) alpha:1], *bot = [UIColor colorWithRed:r0 * 0.78 green:g0 * 0.78 blue:b0 * 0.78 alpha:1];
    CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 2, [UIColor colorWithWhite:0 alpha:0.35].CGColor); [bot set]; CGContextFillRect(c, r); CGContextRestoreGState(c);
    CGContextSaveGState(c); CGContextClipToRect(c, r);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat locs[2] = {0, 1};
    CGGradientRef g = CGGradientCreateWithColors(cs, (CFArrayRef)[NSArray arrayWithObjects:(id)top.CGColor, (id)bot.CGColor, nil], locs);
    CGContextDrawLinearGradient(c, g, CGPointMake(r.origin.x, r.origin.y), CGPointMake(r.origin.x, CGRectGetMaxY(r)), 0); CGGradientRelease(g); CGColorSpaceRelease(cs);
    [[UIColor colorWithWhite:1 alpha:0.45] set]; CGContextFillRect(c, CGRectMake(r.origin.x + 1, r.origin.y, r.size.width - 2, 1)); CGContextRestoreGState(c);
    [[bot colorWithAlphaComponent:0.9] set]; CGContextSetLineWidth(c, 1); CGContextStrokeRect(c, CGRectInset(r, 0.5, 0.5));
}
static void glossDot(CGContextRef c, CGPoint p, UIColor *col) {
    CGRect d = CGRectMake(p.x - 4.5, p.y - 4.5, 9, 9);
    CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 1.5, [UIColor colorWithWhite:0 alpha:0.4].CGColor); [[UIColor whiteColor] set]; CGContextFillEllipseInRect(c, d); CGContextRestoreGState(c);
    [col set]; CGContextFillEllipseInRect(c, CGRectInset(d, 2, 2));
    [[UIColor colorWithWhite:1 alpha:0.6] set]; CGContextFillEllipseInRect(c, CGRectMake(p.x - 1.5, p.y - 2.8, 2.6, 1.6));
}
static void graphPaper(CGContextRef c, CGRect b) {   // inset panel with a fine grid and a recessed edge
    CGRect panel = CGRectInset(b, 1, 1); UIBezierPath *rr = [UIBezierPath bezierPathWithRoundedRect:panel cornerRadius:6];
    CGContextSaveGState(c); [rr addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat locs[2] = {0, 1};
    CGGradientRef g = CGGradientCreateWithColors(cs, (CFArrayRef)[NSArray arrayWithObjects:(id)[UIColor colorWithRed:0.97 green:0.97 blue:0.95 alpha:1].CGColor, (id)[UIColor colorWithRed:0.93 green:0.93 blue:0.90 alpha:1].CGColor, nil], locs);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, b.size.height), 0); CGGradientRelease(g); CGColorSpaceRelease(cs);
    [[UIColor colorWithRed:0.78 green:0.84 blue:0.90 alpha:0.55] set]; CGContextSetLineWidth(c, 1);
    for (CGFloat x = 8.5; x < b.size.width; x += 12) { CGContextMoveToPoint(c, x, 0); CGContextAddLineToPoint(c, x, b.size.height); }
    for (CGFloat y = 8.5; y < b.size.height; y += 12) { CGContextMoveToPoint(c, 0, y); CGContextAddLineToPoint(c, b.size.width, y); }
    CGContextStrokePath(c);
    CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, 2), 4, [UIColor colorWithWhite:0 alpha:0.35].CGColor);
    [[UIColor blackColor] set]; CGContextSetLineWidth(c, 3); CGContextAddPath(c, [UIBezierPath bezierPathWithRoundedRect:CGRectInset(panel, -3, -3) cornerRadius:8].CGPath); CGContextStrokePath(c); CGContextRestoreGState(c);
    CGContextRestoreGState(c);
    [[UIColor colorWithWhite:0.62 alpha:1] set]; rr.lineWidth = 1; [rr stroke];
}
@implementation HBChartView
@synthesize fixedMax;
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.opaque = NO; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)dealloc { [xs release]; [ys release]; [labels release]; [callout release]; [tint release]; [super dealloc]; }
- (void)setXs:(NSArray *)x ys:(NSArray *)y bars:(BOOL)b labels:(NSArray *)l callout:(NSString *)c tint:(UIColor *)t {
    [xs release]; xs = [x retain]; [ys release]; ys = [y retain]; [labels release]; labels = [l retain]; bars = b; [callout release]; callout = [c retain]; [tint release]; tint = [t retain]; [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds; NSUInteger n = [ys count];
    UIColor *accent = tint ?: [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1];
    graphPaper(c, b);
    if (n < (bars ? 1 : 2)) { etched(@"Not enough data yet.", CGRectMake(10, b.size.height / 2 - 10, b.size.width - 20, 20), [UIFont systemFontOfSize:14], UITextAlignmentCenter, [UIColor colorWithWhite:0.5 alpha:1]); return; }
    CGFloat L = 44, R = 14, T = 22, B = 22;
    CGRect plot = CGRectMake(L, T, b.size.width - L - R, b.size.height - T - B);
    double ymin = 1e300, ymax = -1e300;
    for (NSNumber *v in ys) { double d = [v doubleValue]; if (d < ymin) ymin = d; if (d > ymax) ymax = d; }
    if (bars) ymin = 0;
    if (ymax - ymin < 1e-9) { ymin -= 1; ymax += 1; }
    double pad = (ymax - ymin) * 0.1; if (!bars) ymin -= pad; ymax += pad;
    if (fixedMax > 0) { ymin = 0; ymax = fixedMax; }
    UIFont *small = [UIFont boldSystemFontOfSize:10]; UIColor *dim = [UIColor colorWithWhite:0.42 alpha:1];
    for (int i = 0; i <= 2; i++) {
        double v = ymin + (ymax - ymin) * i / 2.0;
        CGFloat py = floorf(CGRectGetMaxY(plot) - (v - ymin) / (ymax - ymin) * plot.size.height) + 0.5;
        [[UIColor colorWithWhite:0.55 alpha:0.5] set]; CGContextSetLineWidth(c, 1); CGContextMoveToPoint(c, plot.origin.x, py); CGContextAddLineToPoint(c, CGRectGetMaxX(plot), py); CGContextStrokePath(c);
        etched(fmtNum(v), CGRectMake(0, py - 6, L - 8, 12), small, UITextAlignmentRight, dim);
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
            double v = [[ys objectAtIndex:i] doubleValue]; CGFloat x = floorf(px(i) - bw / 2), top = floorf(py(i));
            if (v <= 0) { [[UIColor colorWithWhite:0.7 alpha:1] set]; CGContextFillRect(c, CGRectMake(x, CGRectGetMaxY(plot) - 2, bw, 2)); continue; }
            glossBar(c, CGRectMake(x, top, bw, CGRectGetMaxY(plot) - top), (i == n - 1 || labels) ? accent : [accent colorWithAlphaComponent:0.7]);
        }
    } else {
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat locs[2] = {0, 1};
        CGContextSaveGState(c);
        CGContextMoveToPoint(c, px(0), CGRectGetMaxY(plot)); for (NSUInteger i = 0; i < n; i++) CGContextAddLineToPoint(c, px(i), py(i)); CGContextAddLineToPoint(c, px(n - 1), CGRectGetMaxY(plot)); CGContextClosePath(c); CGContextClip(c);
        CGGradientRef fg = CGGradientCreateWithColors(cs, (CFArrayRef)[NSArray arrayWithObjects:(id)[accent colorWithAlphaComponent:0.55].CGColor, (id)[accent colorWithAlphaComponent:0.04].CGColor, nil], locs);
        CGContextDrawLinearGradient(c, fg, CGPointMake(0, plot.origin.y), CGPointMake(0, CGRectGetMaxY(plot)), 0); CGGradientRelease(fg); CGContextRestoreGState(c); CGColorSpaceRelease(cs);
        CGContextSetLineJoin(c, kCGLineJoinRound); CGContextSetLineCap(c, kCGLineCapRound);
        CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, 2), 3, [UIColor colorWithWhite:0 alpha:0.45].CGColor);
        [accent set]; CGContextSetLineWidth(c, 3.5); CGContextMoveToPoint(c, px(0), py(0)); for (NSUInteger i = 1; i < n; i++) CGContextAddLineToPoint(c, px(i), py(i)); CGContextStrokePath(c); CGContextRestoreGState(c);
        [[UIColor colorWithWhite:1 alpha:0.55] set]; CGContextSetLineWidth(c, 1); CGContextMoveToPoint(c, px(0), py(0) - 1.2); for (NSUInteger i = 1; i < n; i++) CGContextAddLineToPoint(c, px(i), py(i) - 1.2); CGContextStrokePath(c);
        if (n <= 40) for (NSUInteger i = 0; i < n; i++) glossDot(c, CGPointMake(px(i), py(i)), accent);
    }
    if (callout) {
        UIFont *bf = [UIFont boldSystemFontOfSize:11]; CGSize sz = [callout sizeWithFont:bf]; CGRect badge = CGRectMake(CGRectGetMaxX(plot) - sz.width - 12, 4, sz.width + 12, 16);
        glossBar(c, badge, accent); [[UIColor whiteColor] set]; CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, [UIColor colorWithWhite:0 alpha:0.5].CGColor);
        [callout drawInRect:CGRectMake(badge.origin.x, badge.origin.y + 1, badge.size.width, 14) withFont:bf lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter]; CGContextRestoreGState(c);
    }
    if (labels) { for (NSUInteger i = 0; i < n && i < [labels count]; i++) etched([labels objectAtIndex:i], CGRectMake(px(i) - 20, CGRectGetMaxY(plot) + 6, 40, 12), small, UITextAlignmentCenter, dim); }
    else {
        etched(fmtDay([[xs objectAtIndex:0] doubleValue]), CGRectMake(plot.origin.x, CGRectGetMaxY(plot) + 6, plot.size.width / 2, 12), small, UITextAlignmentLeft, dim);
        etched(bars ? @"this week" : fmtDay([[xs lastObject] doubleValue]), CGRectMake(CGRectGetMidX(plot), CGRectGetMaxY(plot) + 6, plot.size.width / 2, 12), small, UITextAlignmentRight, dim);
    }
}
@end

#pragma mark - Paper, leather, calendar
#define PAPER_W 320
#define RULE_H 44
#define MARGIN_X 50
static UIColor *paperColor(void) { return [UIColor colorWithRed:0.985 green:0.965 blue:0.90 alpha:1]; }
static UIColor *ruleColor(void) { return [UIColor colorWithRed:0.70 green:0.80 blue:0.90 alpha:1]; }
static UIColor *marginColor(void) { return [UIColor colorWithRed:0.90 green:0.45 blue:0.45 alpha:1]; }
static void drawPaper(CGContextRef c, CGRect r, BOOL rule, BOOL margin) {
    [paperColor() set]; CGContextFillRect(c, r);
    srand(11); for (int i = 0; i < r.size.width * r.size.height / 40; i++) { [[UIColor colorWithWhite:0.55 alpha:0.05] set]; CGContextFillRect(c, CGRectMake(r.origin.x + rand() % (int)r.size.width, r.origin.y + rand() % (int)MAX(1, r.size.height), 1, 1)); }
    CGContextSetLineWidth(c, 1);
    if (rule) { [ruleColor() set]; CGContextMoveToPoint(c, r.origin.x, CGRectGetMaxY(r) - 0.5); CGContextAddLineToPoint(c, CGRectGetMaxX(r), CGRectGetMaxY(r) - 0.5); CGContextStrokePath(c); }
    if (margin) { [marginColor() set]; CGContextMoveToPoint(c, r.origin.x + MARGIN_X + 0.5, r.origin.y); CGContextAddLineToPoint(c, r.origin.x + MARGIN_X + 0.5, CGRectGetMaxY(r)); CGContextMoveToPoint(c, r.origin.x + MARGIN_X + 3.5, r.origin.y); CGContextAddLineToPoint(c, r.origin.x + MARGIN_X + 3.5, CGRectGetMaxY(r)); CGContextStrokePath(c); }
}
UIImage *HBLeatherImage(CGSize sz) {
    UIGraphicsBeginImageContextWithOptions(sz, YES, 0); CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat locs[2] = {0, 1};
    CGGradientRef g = CGGradientCreateWithColors(cs, (CFArrayRef)[NSArray arrayWithObjects:(id)[UIColor colorWithRed:0.47 green:0.31 blue:0.19 alpha:1].CGColor, (id)[UIColor colorWithRed:0.30 green:0.19 blue:0.11 alpha:1].CGColor, nil], locs);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, sz.height), 0); CGGradientRelease(g); CGColorSpaceRelease(cs);
    srand(5); for (int i = 0; i < sz.width * sz.height / 3; i++) { BOOL light = rand() % 3 == 0; [[UIColor colorWithWhite:light ? 1 : 0 alpha:(rand() % 100) / 100.0 * (light ? 0.10 : 0.22)] set]; CGContextFillRect(c, CGRectMake(rand() % (int)sz.width, rand() % (int)sz.height, 1 + rand() % 2, 1)); }
    [[UIColor colorWithWhite:1 alpha:0.22] set]; CGContextFillRect(c, CGRectMake(0, 0, sz.width, 1));
    CGFloat dash[2] = {5, 4}; CGContextSetLineDash(c, 0, dash, 2); CGContextSetLineWidth(c, 1.5); CGContextSetLineCap(c, kCGLineCapRound);
    [[UIColor colorWithWhite:0 alpha:0.5] set]; CGContextMoveToPoint(c, 0, sz.height - 4.5); CGContextAddLineToPoint(c, sz.width, sz.height - 4.5); CGContextStrokePath(c);
    [[UIColor colorWithRed:0.92 green:0.84 blue:0.66 alpha:0.9] set]; CGContextMoveToPoint(c, 0, sz.height - 5.5); CGContextAddLineToPoint(c, sz.width, sz.height - 5.5); CGContextStrokePath(c);
    CGContextSetLineDash(c, 0, NULL, 0); [[UIColor colorWithWhite:0 alpha:0.6] set]; CGContextFillRect(c, CGRectMake(0, sz.height - 1, sz.width, 1));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return img;
}
void HBSkinNavBar(UINavigationBar *bar) {
    if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) { static UIImage *img = nil; if (!img) img = [HBLeatherImage(CGSizeMake(320, 44)) retain]; [bar performSelector:@selector(setBackgroundImage:forBarMetrics:) withObject:img withObject:0]; }   // iOS 5 API, absent from the 4.3 SDK
    bar.tintColor = [UIColor colorWithRed:0.40 green:0.27 blue:0.16 alpha:1];   // bar buttons in the leather's brown
}
@interface HBPaperBackground : UIView @end
@implementation HBPaperBackground
- (void)drawRect:(CGRect)r { CGContextRef c = UIGraphicsGetCurrentContext(); drawPaper(c, self.bounds, NO, YES); [ruleColor() set]; for (CGFloat y = RULE_H - 0.5; y < self.bounds.size.height; y += RULE_H) { CGContextMoveToPoint(c, 0, y); CGContextAddLineToPoint(c, self.bounds.size.width, y); } CGContextStrokePath(c); }
@end
void HBSkinPaperTable(UITableView *tv) {
    HBPaperBackground *bg = [[[HBPaperBackground alloc] initWithFrame:tv.bounds] autorelease]; bg.contentMode = UIViewContentModeRedraw; tv.backgroundView = bg; tv.backgroundColor = [UIColor clearColor];
    tv.separatorStyle = UITableViewCellSeparatorStyleNone; tv.rowHeight = RULE_H;
}
@interface HBPaperRow : UIView { BOOL selected; } @property (nonatomic, assign) BOOL selected; @end
@implementation HBPaperRow
@synthesize selected;
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.contentMode = UIViewContentModeRedraw; self.opaque = YES; } return self; }
- (void)drawRect:(CGRect)r { CGContextRef c = UIGraphicsGetCurrentContext(); drawPaper(c, self.bounds, YES, YES); if (selected) { [[UIColor colorWithWhite:0 alpha:0.06] set]; CGContextFillRect(c, self.bounds); } }
@end
UIView *HBPaperStrip(CGFloat width, CGFloat height, NSString *text, BOOL bold) {
    HBPaperRow *v = [[[HBPaperRow alloc] initWithFrame:CGRectMake(0, 0, width, height)] autorelease]; v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(MARGIN_X + 12, 0, width - MARGIN_X - 24, height)] autorelease]; l.text = text; l.font = bold ? [UIFont boldSystemFontOfSize:14] : [UIFont italicSystemFontOfSize:13]; l.numberOfLines = 0;
    l.textColor = bold ? [UIColor colorWithRed:0.45 green:0.33 blue:0.22 alpha:1] : [UIColor colorWithWhite:0.45 alpha:1]; l.backgroundColor = [UIColor clearColor]; l.shadowColor = [UIColor colorWithWhite:1 alpha:0.8]; l.shadowOffset = CGSizeMake(0, 1); l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [v addSubview:l]; return v;
}
@implementation HBPaperCell
- (id)initWithStyle:(UITableViewCellStyle)st reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:st reuseIdentifier:rid])) {
        self.backgroundView = [[[HBPaperRow alloc] initWithFrame:CGRectMake(0, 0, PAPER_W, RULE_H)] autorelease];
        HBPaperRow *sel = [[[HBPaperRow alloc] initWithFrame:CGRectMake(0, 0, PAPER_W, RULE_H)] autorelease]; sel.selected = YES; self.selectedBackgroundView = sel;
        self.backgroundColor = [UIColor clearColor]; self.textLabel.backgroundColor = [UIColor clearColor]; self.detailTextLabel.backgroundColor = [UIColor clearColor];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat w = self.contentView.bounds.size.width;
    self.imageView.frame = CGRectMake(9, 7, 30, 30);
    CGFloat x = MARGIN_X + 14, tw = w - x - 4;
    if (self.detailTextLabel.text.length) { self.textLabel.frame = CGRectMake(x, 4, tw, 20); self.detailTextLabel.frame = CGRectMake(x, 24, tw, 15); }
    else self.textLabel.frame = CGRectMake(x, 0, tw, RULE_H);
}
@end

#define CAL_LEFT 34
#define CAL_TOP 20
#define CAL_ROW 22
@implementation HBCalendarView
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor whiteColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)dealloc { [states release]; [start release]; [tint release]; [super dealloc]; }
+ (CGFloat)heightForWeeks:(int)w { return CAL_TOP + w * CAL_ROW + 6; }
- (void)setStates:(NSArray *)s start:(NSDate *)d tint:(UIColor *)t { [states release]; states = [s retain]; [start release]; start = [d retain]; [tint release]; tint = [t retain]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext(); CGRect b = self.bounds;
    drawPaper(c, b, NO, NO);
    CGFloat cw = (b.size.width - CAL_LEFT - 8) / 7; int weeks = ((int)[states count] + 6) / 7;
    UIFont *tiny = [UIFont boldSystemFontOfSize:9], *num = [UIFont systemFontOfSize:10];
    NSArray *dows = [NSArray arrayWithObjects:@"M", @"T", @"W", @"T", @"F", @"S", @"S", nil];
    [[UIColor colorWithWhite:0.5 alpha:1] set];
    for (int i = 0; i < 7; i++) [[dows objectAtIndex:i] drawInRect:CGRectMake(CAL_LEFT + i * cw, 4, cw, 12) withFont:tiny lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
    // grid
    [ruleColor() set]; CGContextSetLineWidth(c, 1);
    for (int r = 0; r <= weeks; r++) { CGFloat y = floorf(CAL_TOP + r * CAL_ROW) + 0.5; CGContextMoveToPoint(c, CAL_LEFT, y); CGContextAddLineToPoint(c, CAL_LEFT + 7 * cw, y); }
    for (int i = 0; i <= 7; i++) { CGFloat x = floorf(CAL_LEFT + i * cw) + 0.5; CGContextMoveToPoint(c, x, CAL_TOP); CGContextAddLineToPoint(c, x, CAL_TOP + weeks * CAL_ROW); }
    CGContextStrokePath(c);
    NSCalendar *cal = [NSCalendar currentCalendar]; NSDateFormatter *mf = [[[NSDateFormatter alloc] init] autorelease]; [mf setDateFormat:@"MMM"];
    UIColor *red = [UIColor colorWithRed:0.80 green:0.12 blue:0.10 alpha:1];
    for (NSUInteger i = 0; i < [states count]; i++) {
        int r = (int)i / 7, col = (int)i % 7; CGRect cell = CGRectMake(CAL_LEFT + col * cw, CAL_TOP + r * CAL_ROW, cw, CAL_ROW);
        NSDate *d = [NSDate dateWithTimeInterval:i * 86400 + 43200 sinceDate:start];
        NSDateComponents *dc = [cal components:NSDayCalendarUnit fromDate:d]; int st = [[states objectAtIndex:i] intValue];
        if (dc.day == 1 || (i == 0 && dc.day < 25)) { [[UIColor colorWithRed:0.45 green:0.33 blue:0.22 alpha:1] set]; [[mf stringFromDate:d] drawInRect:CGRectMake(2, cell.origin.y + 5, CAL_LEFT - 6, 12) withFont:tiny lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight]; }
        [(st == HBNotDue || st == HBBeforeStart ? [UIColor colorWithWhite:0.72 alpha:1] : [UIColor colorWithWhite:0.35 alpha:1]) set];
        [[NSString stringWithFormat:@"%d", (int)dc.day] drawInRect:CGRectMake(cell.origin.x + 2, cell.origin.y + 1, cw - 4, 11) withFont:num lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft];
        if (st == HBDone) {   // a marker X, slightly hand-drawn
            CGFloat j = ((i * 7) % 5) * 0.4; CGRect x = CGRectInset(cell, 5, 4);
            [red set]; CGContextSetLineWidth(c, 2.2); CGContextSetLineCap(c, kCGLineCapRound);
            CGContextMoveToPoint(c, x.origin.x + j, x.origin.y + 1); CGContextAddLineToPoint(c, CGRectGetMaxX(x) - j * 0.5, CGRectGetMaxY(x));
            CGContextMoveToPoint(c, CGRectGetMaxX(x) - 1, x.origin.y + j); CGContextAddLineToPoint(c, x.origin.x + j * 0.5, CGRectGetMaxY(x) - 1); CGContextStrokePath(c);
        } else if (st == HBSkipped) { [red set]; CGContextSetLineWidth(c, 2); CGContextMoveToPoint(c, cell.origin.x + 8, CGRectGetMidY(cell) + 3); CGContextAddLineToPoint(c, CGRectGetMaxX(cell) - 8, CGRectGetMidY(cell) + 3); CGContextStrokePath(c); }
        else if (st == HBMissed) { [[UIColor colorWithWhite:0.6 alpha:1] set]; CGContextFillEllipseInRect(c, CGRectMake(CGRectGetMidX(cell) - 1.5, CGRectGetMidY(cell) + 2, 3, 3)); }
        else if (st == HBPending) { [[tint ?: red colorWithAlphaComponent:0.7] set]; CGContextSetLineWidth(c, 1.2); CGContextStrokeEllipseInRect(c, CGRectInset(cell, 7, 5)); }
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
    // Reminders-style: a recessed ring pressed into the paper; done fills it with a glossy colour and a white check
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext(); CGRect r = CGRectInset(CGRectMake(0, 0, size, size), 2.5, 2.5);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat locs[2] = {0, 1};
    if (state == 3) r = CGRectInset(r, 5, 5);   // a plain glossy bead in the habit's colour, for lists
    if (state == 1 || state == 3) {
        const CGFloat *k = CGColorGetComponents(color.CGColor); CGFloat r0 = k[0], g0 = k[1], b0 = CGColorGetNumberOfComponents(color.CGColor) >= 4 ? k[2] : k[0];
        CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 1.5, [UIColor colorWithWhite:0 alpha:0.4].CGColor); [color set]; CGContextFillEllipseInRect(c, r); CGContextRestoreGState(c);
        CGContextSaveGState(c); CGContextAddEllipseInRect(c, r); CGContextClip(c);
        CGGradientRef g = CGGradientCreateWithColors(cs, (CFArrayRef)[NSArray arrayWithObjects:(id)[UIColor colorWithRed:MIN(1, r0 * 1.3 + 0.1) green:MIN(1, g0 * 1.3 + 0.1) blue:MIN(1, b0 * 1.3 + 0.1) alpha:1].CGColor, (id)[UIColor colorWithRed:r0 * 0.75 green:g0 * 0.75 blue:b0 * 0.75 alpha:1].CGColor, nil], locs);
        CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)), 0); CGGradientRelease(g);
        [[UIColor colorWithWhite:1 alpha:0.35] set]; CGContextFillEllipseInRect(c, CGRectMake(r.origin.x + 3, r.origin.y + 1.5, r.size.width - 6, r.size.height * 0.42)); CGContextRestoreGState(c);
        if (state == 1) { CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, [UIColor colorWithWhite:0 alpha:0.35].CGColor);
        [[UIColor whiteColor] set]; CGContextSetLineWidth(c, 2.8); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
        CGContextMoveToPoint(c, size * 0.28, size * 0.52); CGContextAddLineToPoint(c, size * 0.44, size * 0.68); CGContextAddLineToPoint(c, size * 0.72, size * 0.34); CGContextStrokePath(c); CGContextRestoreGState(c); }
    } else {
        // recessed ring: dark inner edge at the top, light edge at the bottom
        [[UIColor colorWithWhite:1 alpha:0.9] set]; CGContextSetLineWidth(c, 1.5); CGContextStrokeEllipseInRect(c, CGRectOffset(r, 0, 1));
        CGContextSaveGState(c); CGContextAddEllipseInRect(c, r); CGContextClip(c);
        CGGradientRef g = CGGradientCreateWithColors(cs, (CFArrayRef)[NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.80 alpha:1].CGColor, (id)[UIColor colorWithWhite:0.97 alpha:1].CGColor, nil], locs);
        CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)), 0); CGGradientRelease(g);
        CGContextSetShadowWithColor(c, CGSizeMake(0, 1.5), 2.5, [UIColor colorWithWhite:0 alpha:0.5].CGColor); [[UIColor blackColor] set]; CGContextSetLineWidth(c, 3); CGContextStrokeEllipseInRect(c, CGRectInset(r, -2, -2)); CGContextRestoreGState(c);
        [[UIColor colorWithWhite:0.55 alpha:1] set]; CGContextSetLineWidth(c, 1); CGContextStrokeEllipseInRect(c, r);
        if (state == 2) { [[UIColor colorWithWhite:0.55 alpha:1] set]; CGContextSetLineWidth(c, 2); CGContextSetLineCap(c, kCGLineCapRound); CGContextMoveToPoint(c, size * 0.33, size / 2); CGContextAddLineToPoint(c, size * 0.67, size / 2); CGContextStrokePath(c); }
        else if (progress > 0) { [color set]; CGContextSetLineWidth(c, 3); CGContextSetLineCap(c, kCGLineCapRound); CGContextAddArc(c, size / 2, size / 2, size / 2 - 4.5, -M_PI_2, -M_PI_2 + 2 * M_PI * MIN(1, progress), 0); CGContextStrokePath(c); }
    }
    CGColorSpaceRelease(cs);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    return img;
}
