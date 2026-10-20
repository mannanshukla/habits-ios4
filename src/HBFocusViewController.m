#import "HBFocusViewController.h"
#import "HBStore.h"
#import "HBViews.h"
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

static UIColor *lerp(UIColor *a, UIColor *b, double t) {
    CGFloat r1, g1, b1, a1, r2, g2, b2, a2; const CGFloat *c1 = CGColorGetComponents(a.CGColor), *c2 = CGColorGetComponents(b.CGColor);
    r1 = c1[0]; g1 = c1[1]; b1 = c1[2]; a1 = 1; r2 = c2[0]; g2 = c2[1]; b2 = c2[2]; a2 = 1;
    return [UIColor colorWithRed:r1 + (r2 - r1) * t green:g1 + (g2 - g1) * t blue:b1 + (b2 - b1) * t alpha:a1 + (a2 - a1) * t];
}
static void drawTomato(CGContextRef c, CGRect r, double ripe, BOOL dim) {
    UIColor *green = [UIColor colorWithRed:0.47 green:0.70 blue:0.22 alpha:1], *red = [UIColor colorWithRed:0.85 green:0.16 blue:0.12 alpha:1];
    UIColor *orange = [UIColor colorWithRed:0.95 green:0.60 blue:0.12 alpha:1];
    UIColor *body = ripe < 0.5 ? lerp(green, orange, ripe * 2) : lerp(orange, red, (ripe - 0.5) * 2); if (dim) body = [body colorWithAlphaComponent:0.45];
    CGRect b = CGRectMake(r.origin.x, r.origin.y + r.size.height * 0.14, r.size.width, r.size.height * 0.86);
    // shadow
    CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, 3), 6, [UIColor colorWithWhite:0 alpha:0.3].CGColor);
    [body set]; CGContextFillEllipseInRect(c, b); CGContextRestoreGState(c);
    // lobes: two soft darker ellipses give it the tomato dent
    [[[UIColor blackColor] colorWithAlphaComponent:0.07] set];
    CGContextFillEllipseInRect(c, CGRectMake(b.origin.x + b.size.width * 0.12, b.origin.y + b.size.height * 0.08, b.size.width * 0.36, b.size.height * 0.5));
    CGContextFillEllipseInRect(c, CGRectMake(b.origin.x + b.size.width * 0.52, b.origin.y + b.size.height * 0.08, b.size.width * 0.36, b.size.height * 0.5));
    // highlight
    [[[UIColor whiteColor] colorWithAlphaComponent:0.35] set];
    CGContextFillEllipseInRect(c, CGRectMake(b.origin.x + b.size.width * 0.18, b.origin.y + b.size.height * 0.10, b.size.width * 0.22, b.size.height * 0.14));
    // calyx: five leaves around the stem
    UIColor *leaf = [UIColor colorWithRed:0.30 green:0.55 blue:0.18 alpha:dim ? 0.5 : 1]; [leaf set];
    CGFloat cx = CGRectGetMidX(b), cy = b.origin.y + b.size.height * 0.06, L = r.size.width * 0.19;
    for (int i = 0; i < 5; i++) {
        CGFloat ang = -M_PI_2 + (i - 2) * 0.62;
        CGContextSaveGState(c); CGContextTranslateCTM(c, cx, cy + L * 0.25); CGContextRotateCTM(c, ang);
        CGContextFillEllipseInRect(c, CGRectMake(0, -L * 0.14, L, L * 0.28)); CGContextRestoreGState(c);
    }
    // stem
    CGContextSaveGState(c); CGContextTranslateCTM(c, cx, cy + L * 0.2); CGContextRotateCTM(c, -0.25);
    CGContextFillRect(c, CGRectMake(-L * 0.08, -L * 0.75, L * 0.16, L * 0.8)); CGContextRestoreGState(c);
}

@implementation HBTomatoView
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)dealloc { [text release]; [sub release]; [super dealloc]; }
- (void)setProgress:(double)p isBreak:(BOOL)b text:(NSString *)t sub:(NSString *)s {
    if (p == progress && b == isBreak && [t isEqualToString:text] && [s isEqualToString:sub]) return;   // the clock ticks every second; an idle tomato looks the same, so don't redraw it
    progress = p; isBreak = b; [text release]; text = [t copy]; [sub release]; sub = [s copy]; [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext(); CGRect b = self.bounds;
    CGFloat size = MIN(b.size.width, b.size.height) - 24; CGRect r = CGRectMake((b.size.width - size) / 2, (b.size.height - size) / 2, size, size);
    drawTomato(c, r, isBreak ? 1 : progress, isBreak);
    // progress ring
    CGFloat cx = CGRectGetMidX(b), cy = CGRectGetMidY(b) + size * 0.07, rad = size / 2 + 8;
    [[UIColor colorWithWhite:0 alpha:0.08] set]; CGContextSetLineWidth(c, 5); CGContextAddArc(c, cx, cy, rad, 0, 2 * M_PI, 0); CGContextStrokePath(c);
    if (progress > 0) { [(isBreak ? [UIColor colorWithRed:0.30 green:0.55 blue:0.18 alpha:1] : [UIColor colorWithRed:0.55 green:0.05 blue:0.05 alpha:1]) set]; CGContextSetLineCap(c, kCGLineCapRound); CGContextAddArc(c, cx, cy, rad, -M_PI_2, -M_PI_2 + 2 * M_PI * MIN(1, progress), 0); CGContextStrokePath(c); }
    // time
    CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 2, [UIColor colorWithWhite:0 alpha:0.5].CGColor);
    [[UIColor whiteColor] set];
    [text drawInRect:CGRectMake(0, cy - 30, b.size.width, 54) withFont:[UIFont boldSystemFontOfSize:52] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
    [sub drawInRect:CGRectMake(0, cy + 24, b.size.width, 20) withFont:[UIFont boldSystemFontOfSize:15] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
    CGContextRestoreGState(c);
}
+ (UIImage *)miniTomato:(BOOL)ripe {
    static UIImage *cache[2] = {nil, nil}; if (cache[ripe ? 1 : 0]) return cache[ripe ? 1 : 0];   // only two looks; draw each once
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(22, 22), NO, 0);
    drawTomato(UIGraphicsGetCurrentContext(), CGRectMake(2, 1, 18, 18), ripe ? 1 : 0, !ripe);
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); cache[ripe ? 1 : 0] = [i retain]; return i;
}
@end

@implementation HBFocusViewController
- (id)init { if ((self = [super initWithNibName:nil bundle:nil])) { self.title = @"Focus"; self.tabBarItem.title = @"Focus"; } return self; }
- (void)dealloc { [tick invalidate]; [tomato release]; [length release]; [linkButton release]; [todayLabel release]; [dots release]; [super dealloc]; }
- (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }
- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]]; root.backgroundColor = [UIColor colorWithRed:0.97 green:0.96 blue:0.93 alpha:1]; self.view = root; [root release];
    CGFloat w = root.bounds.size.width;
    tomato = [[HBTomatoView alloc] initWithFrame:CGRectMake(0, 2, w, 214)];
    [tomato addGestureRecognizer:[[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)] autorelease]];
    [root addSubview:tomato];
    length = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"15 min", @"25 min", @"45 min", nil]]; length.segmentedControlStyle = UISegmentedControlStyleBar; length.tintColor = [UIColor colorWithRed:0.55 green:0.12 blue:0.10 alpha:1];
    length.frame = CGRectMake(20, 222, w - 40, 30); NSInteger L = [[self d] integerForKey:@"hb_pomo_len"]; length.selectedSegmentIndex = L == 15 ? 0 : L == 45 ? 2 : 1;
    [length addTarget:self action:@selector(lengthChanged) forControlEvents:UIControlEventValueChanged]; [root addSubview:length];
    linkButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain]; linkButton.frame = CGRectMake(20, 258, w - 40, 36); linkButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [linkButton addTarget:self action:@selector(pickLink) forControlEvents:UIControlEventTouchUpInside]; [root addSubview:linkButton];
    todayLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 302, w - 40, 18)]; todayLabel.font = [UIFont boldSystemFontOfSize:14]; todayLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1]; todayLabel.backgroundColor = [UIColor clearColor]; todayLabel.textAlignment = UITextAlignmentCenter; [root addSubview:todayLabel];
    dots = [[UIView alloc] initWithFrame:CGRectMake(20, 322, w - 40, 24)]; [root addSubview:dots]; dotsShown = -1;

    [self restore];
}
- (NSInteger)minutes { return length.selectedSegmentIndex == 0 ? 15 : length.selectedSegmentIndex == 2 ? 45 : 25; }
- (void)lengthChanged { [[self d] setInteger:[self minutes] forKey:@"hb_pomo_len"]; [[self d] synchronize]; if (mode == 0) [self render]; }
- (void)restore {
    mode = [[self d] integerForKey:@"hb_pomo_mode"]; endTime = [[self d] doubleForKey:@"hb_pomo_end"]; pausedRemaining = [[self d] doubleForKey:@"hb_pomo_paused"]; total = [[self d] integerForKey:@"hb_pomo_total"];
    if (mode && endTime > 0 && [[NSDate date] timeIntervalSince1970] >= endTime) [self finished];   // ended while we were away
}
- (void)persist { [[self d] setInteger:mode forKey:@"hb_pomo_mode"]; [[self d] setDouble:endTime forKey:@"hb_pomo_end"]; [[self d] setDouble:pausedRemaining forKey:@"hb_pomo_paused"]; [[self d] setInteger:total forKey:@"hb_pomo_total"]; [[self d] synchronize]; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self restore]; [self render]; if (!tick) tick = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(ticked) userInfo:nil repeats:YES] retain]; }
- (void)ticked {   // nothing on screen while locked or switching away: only notice a finished tomato, draw when we're back
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) { if (mode == 1 && pausedRemaining == 0 && [self remaining] <= 0) [self finished]; return; }
    [self render];
}
- (void)viewDidAppear:(BOOL)a { [super viewDidAppear:a]; if ([[self d] boolForKey:@"hb_test_pomo"]) { [[self d] removeObjectForKey:@"hb_test_pomo"]; [[self d] synchronize]; mode = 1; total = 25 * 60; endTime = [[NSDate date] timeIntervalSince1970] + 9 * 60 + 41; pausedRemaining = 0; [self persist]; [self render]; } }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [tick invalidate]; [tick release]; tick = nil; [[HBDrum shared] hide]; }
- (NSDictionary *)linkedHabit { NSString *hid = [[self d] stringForKey:@"hb_pomo_habit"]; return hid ? [HBStore habit:hid] : nil; }
- (NSTimeInterval)remaining { if (mode == 0) return [self minutes] * 60; if (pausedRemaining > 0) return pausedRemaining; return MAX(0, endTime - [[NSDate date] timeIntervalSince1970]); }
- (void)render {
    NSTimeInterval rem = [self remaining]; NSInteger t = mode == 0 ? [self minutes] * 60 : total;
    double p = mode == 0 ? 0 : 1 - rem / (double)t;
    NSString *sub = mode == 0 ? @"tap to start" : pausedRemaining > 0 ? @"paused · tap to resume" : mode == 1 ? @"focus · tap to pause" : @"break · tap to pause";
    [tomato setProgress:p isBreak:mode == 2 text:[NSString stringWithFormat:@"%d:%02d", (int)rem / 60, (int)rem % 60] sub:sub];
    if (mode == 1 && pausedRemaining == 0 && rem <= 0) [self finished];
    // everything below changes rarely; touch the views only when it does
    NSDictionary *h = [self linkedHabit]; NSString *lt = h ? [NSString stringWithFormat:@"Counts toward: %@", [h objectForKey:@"name"]] : @"Counts toward: nothing yet";
    if (![lt isEqualToString:[linkButton titleForState:UIControlStateNormal]]) [linkButton setTitle:lt forState:UIControlStateNormal];
    NSInteger n = [HBStore pomodorosToday]; NSString *tt = n == 0 ? @"No tomatoes yet today" : [NSString stringWithFormat:@"%ld tomato%@ today", (long)n, n == 1 ? @"" : @"es"];
    if (![tt isEqualToString:todayLabel.text]) todayLabel.text = tt;
    if (n != dotsShown) {
        dotsShown = n; for (UIView *v in [NSArray arrayWithArray:dots.subviews]) [v removeFromSuperview];
        NSInteger show = MIN(12, MAX(n, 4)); CGFloat x = (dots.bounds.size.width - show * 24) / 2;
        for (NSInteger i = 0; i < show; i++) { UIImageView *iv = [[[UIImageView alloc] initWithImage:[HBTomatoView miniTomato:i < n]] autorelease]; iv.frame = CGRectMake(x + i * 24, 1, 22, 22); [dots addSubview:iv]; }
    }
    if (length.enabled != (mode == 0)) length.enabled = mode == 0;
    if ((mode == 0) != (self.navigationItem.rightBarButtonItem == nil)) self.navigationItem.rightBarButtonItem = mode == 0 ? nil : [[[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStyleBordered target:self action:@selector(reset)] autorelease];
}
- (void)tapped {
    if (mode == 0) { mode = 1; total = [self minutes] * 60; endTime = [[NSDate date] timeIntervalSince1970] + total; pausedRemaining = 0; [self schedule:@"Tomato's done. Take a break."]; }
    else if (pausedRemaining > 0) { endTime = [[NSDate date] timeIntervalSince1970] + pausedRemaining; pausedRemaining = 0; [self schedule:mode == 1 ? @"Tomato's done. Take a break." : @"Break's over. Back to it."]; }
    else { pausedRemaining = MAX(1, endTime - [[NSDate date] timeIntervalSince1970]); [self cancelNotes]; }
    [self persist]; [self render];
}
- (void)reset { mode = 0; endTime = 0; pausedRemaining = 0; [self cancelNotes]; [self persist]; [self render]; }
- (void)schedule:(NSString *)body {
    [self cancelNotes];
    UILocalNotification *n = [[[UILocalNotification alloc] init] autorelease]; n.fireDate = [NSDate dateWithTimeIntervalSince1970:endTime]; n.timeZone = [NSTimeZone defaultTimeZone]; n.alertBody = body; n.alertAction = @"Open"; n.soundName = UILocalNotificationDefaultSoundName; n.userInfo = [NSDictionary dictionaryWithObject:@"pomo" forKey:@"kind"];
    [[UIApplication sharedApplication] scheduleLocalNotification:n];
}
- (void)cancelNotes { for (UILocalNotification *n in [[UIApplication sharedApplication] scheduledLocalNotifications]) if ([[n.userInfo objectForKey:@"kind"] isEqualToString:@"pomo"]) [[UIApplication sharedApplication] cancelLocalNotification:n]; }
- (void)finished {
    if (mode == 1) {
        [HBStore addPomodoro]; NSDictionary *h = [self linkedHabit];
        if (h) { NSString *key = [HBStore today]; NSNumber *v = [HBStore value:h day:key]; double cur = v && [v doubleValue] >= 0 ? [v doubleValue] : 0; NSString *type = [h objectForKey:@"type"];
            [HBStore setValue:[NSNumber numberWithDouble:[type isEqualToString:@"measure"] ? cur + total / 60 : [type isEqualToString:@"count"] ? cur + 1 : 1] habit:h day:key]; }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate); AudioServicesPlaySystemSound(1005);
        mode = 2; total = ([[self d] integerForKey:@"hb_pomo_len"] >= 45 ? 10 : 5) * 60; endTime = [[NSDate date] timeIntervalSince1970] + total; pausedRemaining = 0; [self schedule:@"Break's over. Back to it."];
    } else { AudioServicesPlaySystemSound(1005); mode = 0; endTime = 0; pausedRemaining = 0; }
    [self persist]; [self render];
}
- (void)pickLink {
    NSMutableArray *rows = [NSMutableArray arrayWithObject:@"Nothing"], *ids = [NSMutableArray arrayWithObject:@""];
    for (NSDictionary *h in [HBStore habits]) { [rows addObject:[h objectForKey:@"name"]]; [ids addObject:[h objectForKey:@"id"]]; }
    NSString *cur = [[self d] stringForKey:@"hb_pomo_habit"] ?: @""; NSInteger sel = [ids indexOfObject:cur]; if (sel == NSNotFound) sel = 0;
    [[HBDrum shared] showInView:self.tabBarController.view title:@"Each finished tomato counts toward" rows:rows selected:sel
        onChange:^(NSInteger r) { if (r == 0) [[self d] removeObjectForKey:@"hb_pomo_habit"]; else [[self d] setObject:[ids objectAtIndex:r] forKey:@"hb_pomo_habit"]; [[self d] synchronize]; [self render]; } onDone:nil];
}
@end
