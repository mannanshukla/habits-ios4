#import "HBTodayViewController.h"
#import "HBHabitsViewController.h"
#import "HBStore.h"
#import "HBViews.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation HBTodayViewController
- (id)init { if ((self = [super initWithStyle:UITableViewStylePlain])) { self.title = @"Today"; self.tabBarItem.title = @"Today"; self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Today" style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease]; } return self; }
- (void)dealloc { [due release]; [rest release]; [sheetHabit release]; [super dealloc]; }
- (void)reload {
    NSMutableArray *d = [NSMutableArray array], *r = [NSMutableArray array];
    for (NSDictionary *h in [HBStore habits]) { if ([HBStore isDue:h on:[NSDate date]]) [d addObject:h]; else [r addObject:h]; }
    [due release]; due = [d retain]; [rest release]; rest = [r retain];
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; [f setDateFormat:@"EEEE, MMMM d"];
    self.navigationItem.title = [f stringFromDate:[NSDate date]];
    [self.tableView reloadData];
}
- (void)viewDidLoad {
    [super viewDidLoad]; HBSkinPaperTable(self.tableView);
    UILongPressGestureRecognizer *lp = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)] autorelease];
    [self.tableView addGestureRecognizer:lp];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self reload]; }
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d boolForKey:@"hb_test_sheet"] && [due count]) { [d removeObjectForKey:@"hb_test_sheet"]; [d synchronize]; [self showSheetFor:[due objectAtIndex:0]]; }
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [[HBDrum shared] hide]; }
- (NSDictionary *)habitAt:(NSIndexPath *)ip { NSArray *a = ip.section == 0 ? due : rest; return ip.row < (NSInteger)[a count] ? [a objectAtIndex:ip.row] : nil; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return [rest count] ? 2 : 1; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? MAX(1, (NSInteger)[due count]) : [rest count]; }
- (NSString *)footerText {
    if (![due count]) return ![[HBStore habits] count] ? @"Tap to add a habit, or let OpenRelay write a plan for a goal in the Habits tab." : nil;
    int done = 0; for (NSDictionary *h in due) if ([HBStore isDone:h day:[HBStore today]]) done++;
    return done == (int)[due count] ? @"All done today. Hold a habit to skip or clear it." : [NSString stringWithFormat:@"%d of %lu done. Tap to check off, hold to skip.", done, (unsigned long)[due count]];
}
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s { return s == 1 ? HBPaperStrip(tv.bounds.size.width, 44, @"Not scheduled today", YES) : nil; }
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return s == 1 ? 44 : 0; }
- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)s { NSString *t = s == 0 ? [self footerText] : nil; return t ? HBPaperStrip(tv.bounds.size.width, 44, t, NO) : nil; }
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s { return s == 0 && [self footerText] ? 44 : 0; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *h = [self habitAt:ip];
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"t"];
    if (!c) { c = [[[HBPaperCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"t"] autorelease]; c.detailTextLabel.textColor = [UIColor colorWithWhite:0.45 alpha:1]; c.textLabel.font = [UIFont boldSystemFontOfSize:17]; c.detailTextLabel.font = [UIFont systemFontOfSize:12]; }
    if (!h) { c.textLabel.text = @"Add a habit"; c.textLabel.textColor = [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1]; c.detailTextLabel.text = @"Nothing is due today."; c.imageView.image = nil; c.accessoryType = UITableViewCellAccessoryNone; return c; }
    NSString *key = [HBStore today]; NSNumber *v = [HBStore value:h day:key]; double val = v ? [v doubleValue] : 0, target = [[h objectForKey:@"target"] doubleValue];
    BOOL done = [HBStore isDone:h day:key], skipped = v && val < 0;
    c.imageView.image = HBCircle([HBStore color:h], target > 0 ? val / target : 0, done ? 1 : skipped ? 2 : 0, 30);
    c.textLabel.text = [h objectForKey:@"name"]; c.textLabel.textColor = done || skipped ? [UIColor colorWithWhite:0.55 alpha:1] : [UIColor colorWithRed:0.16 green:0.12 blue:0.08 alpha:1];
    NSString *type = [h objectForKey:@"type"]; int streak = [HBStore streak:h];
    NSString *progress = skipped ? @"Skipped today" : [type isEqualToString:@"check"] ? (done ? @"Done" : [HBStore describeSchedule:h])
        : [NSString stringWithFormat:@"%@ of %@ %@", v && val >= 0 ? [NSString stringWithFormat:@"%g", val] : @"0", [NSString stringWithFormat:@"%g", target], [h objectForKey:@"unit"]];
    c.detailTextLabel.text = streak > 0 ? [NSString stringWithFormat:@"%@ · %d day streak", progress, streak] : progress;
    c.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *h = [self habitAt:ip];
    if (!h) { HBEditViewController *e = [[HBEditViewController alloc] initWithHabit:nil]; UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:e]; n.navigationBar.tintColor = self.navigationController.navigationBar.tintColor; HBSkinNavBar(n.navigationBar); [self presentModalViewController:n animated:YES]; [n release]; [e release]; return; }
    NSString *key = [HBStore today], *type = [h objectForKey:@"type"]; NSNumber *v = [HBStore value:h day:key]; double target = [[h objectForKey:@"target"] doubleValue];
    if ([type isEqualToString:@"check"]) { [HBStore setValue:[HBStore isDone:h day:key] ? nil : [NSNumber numberWithInt:1] habit:h day:key]; if (![HBStore isDone:h day:key]) {} else AudioServicesPlaySystemSound(1057); [self reload]; return; }
    if ([type isEqualToString:@"count"]) {
        double cur = v && [v doubleValue] >= 0 ? [v doubleValue] : 0;
        if (cur >= target) { [HBStore setValue:nil habit:h day:key]; } else { [HBStore setValue:[NSNumber numberWithDouble:cur + 1] habit:h day:key]; if (cur + 1 >= target) AudioServicesPlaySystemSound(1057); }
        [self reload]; return;
    }
    // measure: spin a value
    double step = target >= 200 ? 5 : target >= 30 ? 1 : 0.5, maxv = target * 2; NSMutableArray *rows = [NSMutableArray array];
    for (double x = 0; x <= maxv + 1e-9; x += step) [rows addObject:[NSString stringWithFormat:@"%g %@", x, [h objectForKey:@"unit"]]];
    double cur = v && [v doubleValue] >= 0 ? [v doubleValue] : 0;
    [[HBDrum shared] showInView:self.tabBarController.view title:[h objectForKey:@"name"] rows:rows selected:(NSInteger)(cur / step + 0.5)
        onChange:^(NSInteger row) { double nv = row * step; BOOL was = [HBStore isDone:h day:key]; [HBStore setValue:nv > 0 ? [NSNumber numberWithDouble:nv] : nil habit:h day:key]; if (!was && [HBStore isDone:h day:key]) AudioServicesPlaySystemSound(1057); [self reload]; }
        onDone:^{ [self reload]; }];
}
- (void)tableView:(UITableView *)tv accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)ip {
    NSDictionary *h = [self habitAt:ip]; if (!h) return;
    HBDetailViewController *d = [[HBDetailViewController alloc] initWithHabit:h]; [self.navigationController pushViewController:d animated:YES]; [d release];
}
- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:[g locationInView:self.tableView]]; NSDictionary *h = ip ? [self habitAt:ip] : nil;
    if (h) [self showSheetFor:h];
}
- (void)showSheetFor:(NSDictionary *)h {
    [sheetHabit release]; sheetHabit = [h retain];
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:[h objectForKey:@"name"] delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Skip today", @"Clear today", @"Mark yesterday done", nil] autorelease];
    [s showFromTabBar:self.tabBarController.tabBar];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (!sheetHabit) return;
    if (i == 0) [HBStore setValue:[NSNumber numberWithInt:-1] habit:sheetHabit day:[HBStore today]];
    else if (i == 1) [HBStore setValue:nil habit:sheetHabit day:[HBStore today]];
    else if (i == 2) [HBStore setValue:[NSNumber numberWithDouble:MAX(1, [[sheetHabit objectForKey:@"target"] doubleValue])] habit:sheetHabit day:[HBStore dayKey:[HBStore addDays:-1 to:[NSDate date]]]];
    [self reload];
}
@end


