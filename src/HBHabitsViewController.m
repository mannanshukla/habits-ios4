#import "HBHabitsViewController.h"
#import "HBStore.h"
#import "HBViews.h"
#import "HBAI.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *blue(void) { return [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1]; }

@implementation HBHabitsViewController
- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"Habits"; self.tabBarItem.title = @"Habits";
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)] autorelease];
        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Generate" style:UIBarButtonItemStyleBordered target:self action:@selector(generate)] autorelease];
    }
    return self;
}
- (void)dealloc { [habits release]; [super dealloc]; }
- (void)viewDidLoad { [super viewDidLoad]; HBSkinPaperTable(self.tableView); }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [habits release]; habits = [[HBStore habits] retain]; [self.tableView reloadData]; }
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; NSString *o = [d stringForKey:@"hb_open"];
    if (o) { [d removeObjectForKey:@"hb_open"]; [d synchronize];
        if ([o isEqualToString:@"add"]) [self add]; else if ([o isEqualToString:@"gen"]) [self generate];
        else if ([o isEqualToString:@"detail"] && [habits count]) [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        else if ([o isEqualToString:@"edit"] && [habits count]) { HBEditViewController *e = [[HBEditViewController alloc] initWithHabit:[habits objectAtIndex:0]]; UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:e]; n.navigationBar.tintColor = self.navigationController.navigationBar.tintColor; HBSkinNavBar(n.navigationBar); [self presentModalViewController:n animated:YES]; [n release]; [e release]; }
    }
}
- (void)add { HBEditViewController *e = [[HBEditViewController alloc] initWithHabit:nil]; UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:e]; n.navigationBar.tintColor = self.navigationController.navigationBar.tintColor; HBSkinNavBar(n.navigationBar); [self presentModalViewController:n animated:YES]; [n release]; [e release]; }
- (void)generate { HBGenerateViewController *g = [[HBGenerateViewController alloc] init]; [self.navigationController pushViewController:g animated:YES]; [g release]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return MAX(1, (NSInteger)[habits count]); }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"h"];
    if (!c) { c = [[[HBPaperCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"h"] autorelease]; c.detailTextLabel.textColor = [UIColor colorWithWhite:0.45 alpha:1]; c.textLabel.font = [UIFont boldSystemFontOfSize:17]; c.detailTextLabel.font = [UIFont systemFontOfSize:12]; }
    if (![habits count]) { c.textLabel.text = @"No habits yet"; c.textLabel.textColor = [UIColor grayColor]; c.detailTextLabel.text = @"Tap + or Generate."; c.imageView.image = nil; c.accessoryType = UITableViewCellAccessoryNone; c.selectionStyle = UITableViewCellSelectionStyleNone; return c; }
    NSDictionary *h = [habits objectAtIndex:ip.row];
    c.textLabel.text = [h objectForKey:@"name"]; c.textLabel.textColor = [UIColor colorWithRed:0.16 green:0.12 blue:0.08 alpha:1]; c.selectionStyle = UITableViewCellSelectionStyleBlue;
    c.imageView.image = HBCircle([HBStore color:h], 1, 3, 30);
    NSInteger rem = [[h objectForKey:@"reminder"] integerValue];
    NSString *goalStr = [h objectForKey:@"type"], *tgt = [goalStr isEqualToString:@"check"] ? @"" : [NSString stringWithFormat:@" · %g %@", [[h objectForKey:@"target"] doubleValue], [h objectForKey:@"unit"]];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@%@%@ · %.0f%%", [HBStore describeSchedule:h], tgt, rem >= 0 ? [NSString stringWithFormat:@" · %@", [HBStore describeTime:rem]] : @"", [HBStore strength:h] * 100];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES]; if (![habits count]) return;
    HBDetailViewController *d = [[HBDetailViewController alloc] initWithHabit:[habits objectAtIndex:ip.row]]; [self.navigationController pushViewController:d animated:YES]; [d release];
}
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return [habits count] > 0; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)st forRowAtIndexPath:(NSIndexPath *)ip {
    if (st != UITableViewCellEditingStyleDelete) return;
    [HBStore deleteHabit:[[habits objectAtIndex:ip.row] objectForKey:@"id"]]; [habits release]; habits = [[HBStore habits] retain];
    if ([habits count]) [tv deleteRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationFade]; else [tv reloadData];
}
@end

@implementation HBEditViewController
- (id)initWithHabit:(NSDictionary *)h {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        isNew = !h; self.title = isNew ? @"New Habit" : @"Edit Habit";
        if (h) habit = [[NSMutableDictionary alloc] initWithDictionary:h];
        else {
            NSMutableArray *days = [NSMutableArray array]; for (int i = 0; i < 7; i++) [days addObject:[NSNumber numberWithBool:YES]];
            habit = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[HBStore uniqueId], @"id", @"", @"name", @"check", @"type", [NSNumber numberWithInt:1], @"target", @"", @"unit", days, @"days", [NSNumber numberWithInt:-1], @"reminder", [NSNumber numberWithInteger:[[HBStore habits] count] % 6], @"color", [HBStore today], @"created", nil];
        }
        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)] autorelease];
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)] autorelease];
    }
    return self;
}
- (void)dealloc { [habit release]; [nameField release]; [unitField release]; [type release]; [remind release]; [dayButtons release]; [colorButtons release]; [super dealloc]; }
- (UITextField *)newField:(NSString *)ph text:(NSString *)t {
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 260, 30)]; f.placeholder = ph; f.text = t; f.font = [UIFont systemFontOfSize:16]; f.delegate = self; f.returnKeyType = UIReturnKeyDone; f.clearButtonMode = UITextFieldViewModeWhileEditing; f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter; f.autocapitalizationType = UITextAutocapitalizationTypeSentences; return f;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    nameField = [self newField:@"Drink water" text:[habit objectForKey:@"name"]];
    unitField = [self newField:@"glasses" text:[habit objectForKey:@"unit"]]; unitField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    type = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Yes / No", @"Count", @"Measure", nil]]; type.segmentedControlStyle = UISegmentedControlStyleBar; type.tintColor = [UIColor colorWithWhite:0.35 alpha:1];
    NSString *t = [habit objectForKey:@"type"]; type.selectedSegmentIndex = [t isEqualToString:@"count"] ? 1 : [t isEqualToString:@"measure"] ? 2 : 0;
    [type addTarget:self action:@selector(typeChanged) forControlEvents:UIControlEventValueChanged];
    remind = [[UISwitch alloc] initWithFrame:CGRectZero]; remind.on = [[habit objectForKey:@"reminder"] integerValue] >= 0; [remind addTarget:self action:@selector(remindChanged) forControlEvents:UIControlEventValueChanged];
    dayButtons = [[NSMutableArray alloc] init]; NSArray *dn = [NSArray arrayWithObjects:@"M", @"T", @"W", @"T", @"F", @"S", @"S", nil];
    for (int i = 0; i < 7; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.tag = i; [b setTitle:[dn objectAtIndex:i] forState:UIControlStateNormal]; b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        b.layer.cornerRadius = 17; [b addTarget:self action:@selector(toggleDay:) forControlEvents:UIControlEventTouchUpInside]; [dayButtons addObject:b];
    }
    colorButtons = [[NSMutableArray alloc] init];
    for (int i = 0; i < 6; i++) { UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.tag = i; b.layer.cornerRadius = 15; b.backgroundColor = [[HBStore palette] objectAtIndex:i]; [b addTarget:self action:@selector(pickColor:) forControlEvents:UIControlEventTouchUpInside]; [colorButtons addObject:b]; }
    [self styleButtons];
}
- (void)styleButtons {
    NSArray *days = [habit objectForKey:@"days"]; UIColor *col = [HBStore color:habit];
    for (UIButton *b in dayButtons) { BOOL on = [[days objectAtIndex:b.tag] boolValue]; b.backgroundColor = on ? col : [UIColor colorWithWhite:0.9 alpha:1]; [b setTitleColor:on ? [UIColor whiteColor] : [UIColor colorWithWhite:0.5 alpha:1] forState:UIControlStateNormal]; }
    NSInteger ci = [[habit objectForKey:@"color"] integerValue];
    for (UIButton *b in colorButtons) { b.layer.borderWidth = b.tag == ci ? 3 : 0; b.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor; }
}
- (void)toggleDay:(UIButton *)b { NSMutableArray *days = [NSMutableArray arrayWithArray:[habit objectForKey:@"days"]]; [days replaceObjectAtIndex:b.tag withObject:[NSNumber numberWithBool:![[days objectAtIndex:b.tag] boolValue]]]; [habit setObject:days forKey:@"days"]; [self styleButtons]; }
- (void)pickColor:(UIButton *)b { [habit setObject:[NSNumber numberWithInteger:b.tag] forKey:@"color"]; [self styleButtons]; }
- (void)typeChanged { NSArray *k = [NSArray arrayWithObjects:@"check", @"count", @"measure", nil]; [habit setObject:[k objectAtIndex:type.selectedSegmentIndex] forKey:@"type"]; if (type.selectedSegmentIndex == 0) [habit setObject:[NSNumber numberWithInt:1] forKey:@"target"]; else if ([[habit objectForKey:@"target"] doubleValue] <= 1) [habit setObject:[NSNumber numberWithInt:type.selectedSegmentIndex == 1 ? 3 : 20] forKey:@"target"]; [self.tableView reloadData]; }
- (void)remindChanged { [habit setObject:[NSNumber numberWithInteger:remind.on ? ([[habit objectForKey:@"reminder"] integerValue] >= 0 ? [[habit objectForKey:@"reminder"] integerValue] : 8 * 60) : -1] forKey:@"reminder"]; if (!remind.on) [habit setObject:[NSNumber numberWithInt:-1] forKey:@"reminder"]; [self.tableView reloadData]; }
- (void)cancel { [[HBDrum shared] hide]; [self dismissModalViewControllerAnimated:YES]; }
- (void)save {
    [self.view endEditing:YES]; [[HBDrum shared] hide];
    NSString *n = [nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![n length]) { [[[[UIAlertView alloc] initWithTitle:@"Name it" message:@"Give the habit a short name." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show]; return; }
    [habit setObject:n forKey:@"name"]; [habit setObject:(unitField.text ?: @"") forKey:@"unit"];
    [HBStore upsertHabit:habit]; [self dismissModalViewControllerAnimated:YES];
}
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [tf resignFirstResponder]; return YES; }
- (void)textFieldDidBeginEditing:(UITextField *)tf { [[HBDrum shared] hide]; }
- (BOOL)isCheck { return type.selectedSegmentIndex == 0; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return isNew ? 5 : 6; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 1 ? ([self isCheck] ? 1 : 3) : s == 3 ? (remind.on ? 2 : 1) : 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { NSArray *t = [NSArray arrayWithObjects:@"Name", @"Type", @"Days", @"Reminder", @"Color", nil]; return s < 5 ? [t objectAtIndex:s] : nil; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s { return s == 1 ? ([self isCheck] ? @"Tap once a day to check it off." : type.selectedSegmentIndex == 1 ? @"Each tap adds one. Done when you reach the target." : @"Spin the wheel to log an amount. Done at the target.") : nil; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 2 || ip.section == 4 ? 54 : 44; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
    c.selectionStyle = UITableViewCellSelectionStyleNone; CGFloat w = c.contentView.bounds.size.width;
    if (ip.section == 0) { nameField.frame = CGRectMake(10, 7, w - 20, 30); nameField.autoresizingMask = UIViewAutoresizingFlexibleWidth; [c.contentView addSubview:nameField]; }
    else if (ip.section == 1) {
        if (ip.row == 0) { type.frame = CGRectMake(8, 7, w - 16, 30); type.autoresizingMask = UIViewAutoresizingFlexibleWidth; [c.contentView addSubview:type]; }
        else if (ip.row == 1) { c.textLabel.text = @"Target"; c.detailTextLabel.text = [NSString stringWithFormat:@"%g", [[habit objectForKey:@"target"] doubleValue]]; c.selectionStyle = UITableViewCellSelectionStyleBlue; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
        else { c.textLabel.text = @"Unit"; unitField.frame = CGRectMake(w - 170, 7, 160, 30); unitField.textAlignment = UITextAlignmentRight; unitField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin; [c.contentView addSubview:unitField]; }
    } else if (ip.section == 2) {
        CGFloat cw = MIN(w, tv.bounds.size.width - 20), bw = 34, gap = (cw - 7 * bw) / 8;   // a fresh grouped cell reports the full 320 until it is laid out
        for (UIButton *b in dayButtons) { b.frame = CGRectMake(gap + b.tag * (bw + gap), 10, bw, bw); [c.contentView addSubview:b]; }
    } else if (ip.section == 3) {
        if (ip.row == 0) { c.textLabel.text = @"Remind me"; c.accessoryView = remind; }
        else { c.textLabel.text = @"Time"; c.detailTextLabel.text = [HBStore describeTime:[[habit objectForKey:@"reminder"] integerValue]]; c.selectionStyle = UITableViewCellSelectionStyleBlue; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    } else if (ip.section == 4) {
        CGFloat bw = 30, gap = (MIN(w, tv.bounds.size.width - 20) - 6 * bw) / 7;
        for (UIButton *b in colorButtons) { b.frame = CGRectMake(gap + b.tag * (bw + gap), 12, bw, bw); [c.contentView addSubview:b]; }
    } else { c.textLabel.text = @"Delete Habit"; c.textLabel.textAlignment = UITextAlignmentCenter; c.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.1 blue:0.1 alpha:1]; c.selectionStyle = UITableViewCellSelectionStyleBlue; }
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES]; [self.view endEditing:YES];
    UIView *host = self.navigationController.view;
    if (ip.section == 1 && ip.row == 1) {
        NSMutableArray *rows = [NSMutableArray array]; int maxv = type.selectedSegmentIndex == 1 ? 50 : 500;
        for (int i = 1; i <= maxv; i++) [rows addObject:[NSString stringWithFormat:@"%d", i]];
        [[HBDrum shared] showInView:host title:@"Target per day" rows:rows selected:(NSInteger)[[habit objectForKey:@"target"] doubleValue] - 1
            onChange:^(NSInteger r) { [habit setObject:[NSNumber numberWithInt:(int)r + 1] forKey:@"target"]; [tv reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationNone]; } onDone:nil];
    } else if (ip.section == 3 && ip.row == 1) {
        [[HBDrum shared] showTimeInView:host title:@"Reminder time" minutes:[[habit objectForKey:@"reminder"] integerValue]
            onChange:^(NSInteger m) { [habit setObject:[NSNumber numberWithInteger:m] forKey:@"reminder"]; [tv reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationNone]; } onDone:nil];
    } else if (ip.section == 5) {
        [HBStore deleteHabit:[habit objectForKey:@"id"]]; [self dismissModalViewControllerAnimated:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HBHabitDeleted" object:nil];
    }
}
@end

@implementation HBGenerateViewController
- (id)init { if((self=[super initWithStyle:UITableViewStyleGrouped])) { self.title=@"Claude Plan";request=[CLAIRequest new];request.delegate=self; }return self; }
- (void)saveInputs { if(!goal)return;NSUserDefaults *d=[NSUserDefaults standardUserDefaults];[d setObject:goal.text?:@"" forKey:@"hb_goal"];[d setObject:constraints.text?:@"" forKey:@"hb_constraints"];[d setInteger:count.selectedSegmentIndex forKey:@"hb_plan_count"];[d synchronize]; }
- (void)releaseInputs { goal.delegate=constraints.delegate=nil;[goal release];goal=nil;[constraints release];constraints=nil;[count release];count=nil; }
- (void)viewDidUnload { [request cancel];[self saveInputs];[self releaseInputs];[super viewDidUnload]; }
- (void)viewWillDisappear:(BOOL)a { [self saveInputs];[request cancel];[goal resignFirstResponder];[constraints resignFirstResponder];[super viewWillDisappear:a]; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a];self.title=[NSString stringWithFormat:@"%@ Plan",[CLAIRequest providerName]];[self.tableView reloadData]; }
- (void)dealloc { request.delegate=nil;[request cancel];[request release];[self releaseInputs];[pendingGoal release];[status release];[super dealloc]; }
- (UITextField *)newField:(NSString *)placeholder { UITextField *f=[[UITextField alloc] initWithFrame:CGRectZero];f.placeholder=placeholder;f.font=[UIFont systemFontOfSize:15];f.delegate=self;f.returnKeyType=UIReturnKeyDone;f.clearButtonMode=UITextFieldViewModeWhileEditing;f.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter;f.autocapitalizationType=UITextAutocapitalizationTypeSentences;return f; }
- (void)viewDidLoad { [super viewDidLoad];NSUserDefaults *d=[NSUserDefaults standardUserDefaults];goal=[self newField:@"Sleep better, read more, finish a 10k…"];goal.text=[d stringForKey:@"hb_goal"]?:@"";constraints=[self newField:@"10 minutes after breakfast; busy evenings"];constraints.text=[d stringForKey:@"hb_constraints"]?:@"";count=[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"3 habits",@"5 habits",@"7 habits",nil]];count.segmentedControlStyle=UISegmentedControlStyleBar;count.selectedSegmentIndex=MAX(0,MIN(2,[d integerForKey:@"hb_plan_count"]));count.tintColor=[UIColor colorWithWhite:.35 alpha:1]; }
- (BOOL)textFieldShouldReturn:(UITextField *)f { [f resignFirstResponder];return YES; }
- (BOOL)textField:(UITextField *)f shouldChangeCharactersInRange:(NSRange)r replacementString:(NSString *)t { return [f.text length]-r.length+[t length]<=500; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 4; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return 1; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return s==0?@"Your goal":s==1?@"Time, schedule and barriers":s==2?@"How many":nil; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return s==3?(status?:[NSString stringWithFormat:@"%@ receives your goal, constraints and a summary of existing habits and progress. Review the suggestions and choose which to add.",[CLAIRequest providerName]]):nil; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p { UITableViewCell *c=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];c.selectionStyle=UITableViewCellSelectionStyleNone;CGFloat w=c.contentView.bounds.size.width;if(p.section<2) { UITextField *f=p.section==0?goal:constraints;f.enabled=!request.running;f.frame=CGRectMake(10,7,w-20,30);f.autoresizingMask=UIViewAutoresizingFlexibleWidth;[c.contentView addSubview:f]; }else if(p.section==2) { count.enabled=!request.running;count.frame=CGRectMake(8,7,w-16,30);count.autoresizingMask=UIViewAutoresizingFlexibleWidth;[c.contentView addSubview:count]; }else { c.selectionStyle=UITableViewCellSelectionStyleBlue;c.textLabel.text=request.running?@"Stop":@"Suggest My Habits";c.textLabel.textAlignment=UITextAlignmentCenter;c.textLabel.textColor=blue(); }return c; }
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p { [t deselectRowAtIndexPath:p animated:YES];if(p.section==3)[self run]; }
- (void)run { if(request.running) { [request cancel];[self.tableView reloadData];return; }NSString *g=[goal.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];if(![g length]) { [goal becomeFirstResponder];return; }[goal resignFirstResponder];[constraints resignFirstResponder];[self saveInputs];[pendingGoal release];pendingGoal=[g copy];pendingCount=count.selectedSegmentIndex==0?3:count.selectedSegmentIndex==1?5:7;[status release];status=nil;[request startSystem:[HBAI habitSystem] user:[HBAI goalPrompt:g count:pendingCount constraints:constraints.text]];[self.tableView reloadData]; }
- (void)aiRequest:(CLAIRequest *)r text:(NSString *)text error:(NSString *)error { if(r!=request)return;NSString *failure=error;NSArray *habits=text?[HBAI parseHabits:text count:pendingCount error:&failure]:nil;if([habits count]) { HBPickViewController *p=[[[HBPickViewController alloc] initWithHabits:habits goal:pendingGoal] autorelease];[self.navigationController pushViewController:p animated:YES]; }else { [status release];status=[(failure?:@"No plan came back.") copy]; }[self.tableView reloadData]; }
@end

@implementation HBPickViewController
- (id)initWithHabits:(NSArray *)h goal:(NSString *)g {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) { proposed = [h retain]; goal = [g copy]; chosen = [[NSMutableSet alloc] init]; for (NSDictionary *x in h) [chosen addObject:[x objectForKey:@"id"]]; self.title = @"Your Plan";
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Add" style:UIBarButtonItemStyleDone target:self action:@selector(add)] autorelease]; }
    return self;
}
- (void)dealloc { [proposed release]; [goal release]; [chosen release]; [super dealloc]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [proposed count]; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return goal; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s { return @"Tap to leave one out. Add puts the rest on your list with reminders set."; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 64; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *h = [proposed objectAtIndex:ip.row]; BOOL on = [chosen containsObject:[h objectForKey:@"id"]];
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil] autorelease];
    c.imageView.image = HBCircle([HBStore color:h], 0, on ? 1 : 0, 30);
    c.textLabel.text = [h objectForKey:@"name"]; c.textLabel.textColor = on ? [UIColor blackColor] : [UIColor grayColor];
    NSInteger rem = [[h objectForKey:@"reminder"] integerValue]; NSString *t = [h objectForKey:@"type"];
    NSString *tgt = [t isEqualToString:@"check"] ? @"" : [NSString stringWithFormat:@"%g %@ · ", [[h objectForKey:@"target"] doubleValue], [h objectForKey:@"unit"]];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@%@%@\n%@", tgt, [HBStore describeSchedule:h], rem >= 0 ? [NSString stringWithFormat:@" · %@", [HBStore describeTime:rem]] : @"", [h objectForKey:@"why"]];
    c.detailTextLabel.numberOfLines = 2; c.detailTextLabel.font = [UIFont systemFontOfSize:12]; c.detailTextLabel.textColor = [UIColor colorWithWhite:0.45 alpha:1];
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES]; NSString *hid = [[proposed objectAtIndex:ip.row] objectForKey:@"id"];
    if ([chosen containsObject:hid]) [chosen removeObject:hid]; else [chosen addObject:hid];
    self.navigationItem.rightBarButtonItem.enabled=[chosen count]>0;
    [tv reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationNone];
}
- (void)add {
    NSMutableArray *all = [NSMutableArray arrayWithArray:[HBStore habits]];
    for (NSDictionary *h in proposed) if ([chosen containsObject:[h objectForKey:@"id"]]) [all addObject:h];
    if(![chosen count])return;
    if(![HBStore saveHabits:all]) { [[[[UIAlertView alloc] initWithTitle:@"Could not save" message:@"Your habits were not changed. Free some storage and try again." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];return; }[chosen removeAllObjects];self.navigationItem.rightBarButtonItem.enabled=NO;[self.navigationController popToRootViewControllerAnimated:YES];
}
@end

@implementation HBDetailViewController
- (id)initWithHabit:(NSDictionary *)h { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { habit = [h retain]; self.title = [h objectForKey:@"name"]; self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStyleBordered target:self action:@selector(edit)] autorelease];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleted) name:@"HBHabitDeleted" object:nil]; } return self; }   // once: viewDidLoad runs again after a memory warning, and a second observer would pop twice
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [habit release]; [heat release]; [byDay release]; [super dealloc]; }
- (void)deleted { [self.navigationController popViewControllerAnimated:NO]; }
- (void)edit { HBEditViewController *e = [[HBEditViewController alloc] initWithHabit:habit]; UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:e]; n.navigationBar.tintColor = self.navigationController.navigationBar.tintColor; HBSkinNavBar(n.navigationBar); [self presentModalViewController:n animated:YES]; [n release]; [e release]; }
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    NSDictionary *fresh = [HBStore habit:[habit objectForKey:@"id"]]; if (fresh) { [habit release]; habit = [fresh retain]; self.title = [habit objectForKey:@"name"]; }
    NSDate *today = [NSDate date]; NSDate *start = [HBStore addDays:-(11 * 7 + [HBStore weekdayIndex:today]) to:today];
    if (!heat) heat = [[HBCalendarView alloc] initWithFrame:CGRectMake(0, 0, 300, [HBCalendarView heightForWeeks:12])];
    [heat setStates:[HBStore dayStates:habit from:start to:today] start:start tint:[HBStore color:habit]];
    // completion by weekday over the last 12 weeks
    int done[7] = {0}, due[7] = {0}; NSDate *d = start;
    for (int i = 0; i < 84; i++) { int s = [HBStore state:habit on:d], wd = [HBStore weekdayIndex:d]; if (s == HBDone) { done[wd]++; due[wd]++; } else if (s == HBMissed) due[wd]++; d = [HBStore addDays:1 to:d]; }
    NSMutableArray *xs = [NSMutableArray array], *ys = [NSMutableArray array];
    for (int i = 0; i < 7; i++) { [xs addObject:[NSNumber numberWithInt:i]]; [ys addObject:[NSNumber numberWithDouble:due[i] ? 100.0 * done[i] / due[i] : 0]]; }
    if (!byDay) { byDay = [[HBChartView alloc] initWithFrame:CGRectMake(0, 0, 300, 150)]; byDay.fixedMax = 100; }
    [byDay setXs:xs ys:ys bars:YES labels:[NSArray arrayWithObjects:@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun", nil] callout:@"% done by weekday" tint:[HBStore color:habit]];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 3 : 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 1 ? @"Last 12 weeks" : s == 2 ? @"By weekday" : nil; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 0) { NSString *why = [habit objectForKey:@"why"]; return [why length] ? why : nil; }
    return s == 1 ? @"An X is a day done, a dot a miss, a dash a skip. Strength is a moving average, so one miss dents it instead of zeroing it." : nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 1 ? [HBCalendarView heightForWeeks:12] : ip.section == 2 ? 150 : 44; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease]; c.selectionStyle = UITableViewCellSelectionStyleNone;
    if (ip.section == 0) {
        if (ip.row == 0) { c.textLabel.text = @"Strength"; c.detailTextLabel.text = [NSString stringWithFormat:@"%.0f%%", [HBStore strength:habit] * 100]; }
        else if (ip.row == 1) { int s = [HBStore streak:habit], b = [HBStore bestStreak:habit]; c.textLabel.text = @"Streak"; c.detailTextLabel.text = [NSString stringWithFormat:@"%d day%@ · best %d", s, s == 1 ? @"" : @"s", b]; }
        else { int dn, du; [HBStore completion:habit days:30 done:&dn due:&du]; c.textLabel.text = @"Last 30 days"; c.detailTextLabel.text = [NSString stringWithFormat:@"%d of %d", dn, du]; }
        c.detailTextLabel.textColor = [HBStore color:habit];
    } else { UIView *v = ip.section == 1 ? (UIView *)heat : (UIView *)byDay; v.frame = CGRectMake(0, 0, c.contentView.bounds.size.width, ip.section == 1 ? [HBCalendarView heightForWeeks:12] : 150); v.autoresizingMask = UIViewAutoresizingFlexibleWidth; [c.contentView addSubview:v]; }
    return c;
}
@end
