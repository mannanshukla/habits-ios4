#import "HBReviewViewController.h"
#import "HBHabitsViewController.h"
#import "HBStore.h"
#import "HBAI.h"

@implementation HBReviewViewController
- (id)init { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { self.title = @"Review"; self.tabBarItem.title = @"Review"; } return self; }
- (void)dealloc { [habits release]; [weekly release]; [chart release]; [focusChart release]; [note release]; [error release]; [super dealloc]; }
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    [habits release]; habits = [[HBStore habits] retain]; [weekly release]; weekly = [[HBStore weeklyCompletion:10] retain];
    [note release]; note = [[HBStore note] retain];
    NSMutableArray *xs = [NSMutableArray array], *ys = [NSMutableArray array];
    for (NSDictionary *w in weekly) { [xs addObject:[w objectForKey:@"t"]]; [ys addObject:[w objectForKey:@"pct"]]; }
    if (!chart) { chart = [[HBChartView alloc] initWithFrame:CGRectMake(0, 0, 300, 160)]; chart.fixedMax = 100; }
    NSDictionary *tw = [weekly lastObject];
    [chart setXs:xs ys:ys bars:YES labels:nil callout:[NSString stringWithFormat:@"this week %d of %d", [[tw objectForKey:@"done"] intValue], [[tw objectForKey:@"dueSoFar"] intValue]] tint:nil];
    NSMutableArray *fx = [NSMutableArray array], *fy = [NSMutableArray array];
    for (NSDictionary *p in [HBStore pomodorosByDay:14]) { [fx addObject:[p objectForKey:@"t"]]; [fy addObject:[p objectForKey:@"count"]]; }
    if (!focusChart) focusChart = [[HBChartView alloc] initWithFrame:CGRectMake(0, 0, 300, 140)];
    NSInteger pw = [HBStore pomodorosInLastDays:7];
    [focusChart setXs:fx ys:fy bars:YES labels:nil callout:[NSString stringWithFormat:@"this week %ld tomato%@", (long)pw, pw == 1 ? @"" : @"es"] tint:[UIColor colorWithRed:0.85 green:0.16 blue:0.12 alpha:1]];
    [self.tableView reloadData];
}
- (void)viewDidAppear:(BOOL)a { [super viewDidAppear:a]; NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; if ([d objectForKey:@"hb_scroll"]) { [self.tableView setContentOffset:CGPointMake(0, [d floatForKey:@"hb_scroll"]) animated:NO]; [d removeObjectForKey:@"hb_scroll"]; [d synchronize]; } if ([d boolForKey:@"hb_test_note"]) { [d removeObjectForKey:@"hb_test_note"]; [d synchronize]; [self writeNote]; } }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 1 : s == 1 ? MAX(1, (NSInteger)[habits count]) : s == 2 ? 2 : (note ? 2 : 1); }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Done per week" : s == 1 ? @"Strength" : s == 2 ? @"Focus, last 14 days" : @"This week's note"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s { return s == 3 ? (error ?: @"OpenRelay reads your week and writes a few honest sentences. Nothing else leaves the iPod.") : nil; }
- (CGFloat)noteHeight { return note ? [note sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(270, 2000) lineBreakMode:UILineBreakModeWordWrap].height + 24 : 44; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 0 ? 160 : ip.section == 2 && ip.row == 0 ? 140 : ip.section == 3 && ip.row == 0 && note ? [self noteHeight] : 44; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease]; c.selectionStyle = UITableViewCellSelectionStyleNone;
    if (ip.section == 0) { chart.frame = CGRectMake(0, 0, c.contentView.bounds.size.width, 160); chart.autoresizingMask = UIViewAutoresizingFlexibleWidth; [c.contentView addSubview:chart]; return c; }
    if (ip.section == 1) {
        if (![habits count]) { c.textLabel.text = @"No habits yet"; c.textLabel.textColor = [UIColor grayColor]; return c; }
        NSDictionary *h = [habits objectAtIndex:ip.row]; double s = [HBStore strength:h];
        c.textLabel.text = [h objectForKey:@"name"]; c.detailTextLabel.text = [NSString stringWithFormat:@"%.0f%%", s * 100]; c.detailTextLabel.textColor = [HBStore color:h];
        UIView *bar = [[[UIView alloc] initWithFrame:CGRectMake(10, 38, c.contentView.bounds.size.width - 20, 3)] autorelease]; bar.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1]; bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        UIView *fill = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, bar.bounds.size.width * s, 3)] autorelease]; fill.backgroundColor = [HBStore color:h]; [bar addSubview:fill]; [c.contentView addSubview:bar];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; c.selectionStyle = UITableViewCellSelectionStyleBlue;
        return c;
    }
    if (ip.section == 2) {
        if (ip.row == 0) { focusChart.frame = CGRectMake(0, 0, c.contentView.bounds.size.width, 140); focusChart.autoresizingMask = UIViewAutoresizingFlexibleWidth; [c.contentView addSubview:focusChart]; return c; }
        NSInteger pw = [HBStore pomodorosInLastDays:7], pm = [HBStore pomodorosInLastDays:30]; NSInteger len = [[NSUserDefaults standardUserDefaults] integerForKey:@"hb_pomo_len"] ?: 25;
        c.textLabel.text = @"Focused"; c.detailTextLabel.text = [NSString stringWithFormat:@"%.1f h this week · %.1f h in 30 days", pw * len / 60.0, pm * len / 60.0]; c.detailTextLabel.adjustsFontSizeToFitWidth = YES; c.detailTextLabel.minimumFontSize = 10; c.detailTextLabel.font = [UIFont systemFontOfSize:14]; return c;
    }
    if (ip.row == 0 && note) {
        UITableViewCell *n = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease]; n.selectionStyle = UITableViewCellSelectionStyleNone;
        n.textLabel.text = note; n.textLabel.numberOfLines = 0; n.textLabel.font = [UIFont systemFontOfSize:15]; n.textLabel.lineBreakMode = UILineBreakModeWordWrap; return n;
    }
    c.textLabel.text = busy ? @"Writing..." : note ? @"Write it again" : @"Write This Week's Note"; c.textLabel.textAlignment = UITextAlignmentCenter; c.textLabel.textColor = [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1]; c.textLabel.font = [UIFont boldSystemFontOfSize:17]; c.selectionStyle = UITableViewCellSelectionStyleBlue;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 1 && [habits count]) { HBDetailViewController *d = [[HBDetailViewController alloc] initWithHabit:[habits objectAtIndex:ip.row]]; [self.navigationController pushViewController:d animated:YES]; [d release]; }
    else if (ip.section == 3 && (ip.row == 1 || !note)) [self writeNote];
}
- (void)writeNote { if (busy) return; busy = YES; [error release]; error = nil; [self.tableView reloadData]; [self performSelectorInBackground:@selector(work) withObject:nil]; }
- (void)work { NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init]; NSString *err = nil; NSString *t = [HBAI weeklyNoteWithError:&err]; [self performSelectorOnMainThread:@selector(finished:) withObject:[NSArray arrayWithObjects:(t ?: @""), (err ?: @""), nil] waitUntilDone:NO]; [p release]; }
- (void)finished:(NSArray *)r {
    busy = NO; NSString *t = [r objectAtIndex:0];
    if ([t length]) { [HBStore setNote:t]; [note release]; note = [t copy]; } else { [error release]; error = [([[r objectAtIndex:1] length] ? [r objectAtIndex:1] : @"No note came back.") copy]; }
    [self.tableView reloadData];
}
@end
