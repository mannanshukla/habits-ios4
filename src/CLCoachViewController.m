#import "CLCoachViewController.h"
#import "CLIntegration.h"
@implementation CLCoachViewController
- (id)initWithSource:(NSString *)s context:(NSString *)c system:(NSString *)p {
    if((self=[super initWithStyle:UITableViewStyleGrouped])) { source=[s copy];context=[c copy];system=[p copy];self.title=@"Claude Coach";request=[CLAIRequest new];request.delegate=self;reply=[[[NSUserDefaults standardUserDefaults] stringForKey:@"ai_last_review"] copy]; }return self;
}
- (UITextView *)newTextView:(NSString *)text editable:(BOOL)editable { UITextView *v=[[UITextView alloc] initWithFrame:CGRectZero];v.text=text;v.editable=editable;v.font=[UIFont systemFontOfSize:15];v.backgroundColor=[UIColor clearColor];v.autoresizingMask=UIViewAutoresizingFlexibleWidth;return v; }
- (void)viewDidLoad { [super viewDidLoad];question=[self newTextView:questionText?:@"What is working, and what should I change next week to move toward my goal?" editable:YES];question.delegate=self;summary=[self newTextView:context editable:NO];answer=[self newTextView:reply?:@"" editable:NO]; }
- (void)viewDidUnload { [request cancel];[questionText release];questionText=[question.text copy];question.delegate=nil;[question release];question=nil;[summary release];summary=nil;[answer release];answer=nil;[super viewDidUnload]; }
- (void)viewWillDisappear:(BOOL)a { [request cancel];[question resignFirstResponder];[super viewWillDisappear:a]; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a];self.title=[NSString stringWithFormat:@"%@ Coach",[CLAIRequest providerName]];question.editable=!request.running;[self.tableView reloadData]; }
- (void)dealloc { request.delegate=nil;[request cancel];[request release];question.delegate=nil;[question release];[summary release];[answer release];[source release];[context release];[system release];[reply release];[questionText release];[super dealloc]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return [reply length]?4:3; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return s==2?2:1; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return s==0?@"Ask about your goal":s==1?@"Progress to share":s==3?@"Coach’s note":nil; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return s==1?[NSString stringWithFormat:@"Only this summary and your question are sent to %@ when you tap Ask. Plans and logs stay unchanged.",[CLAIRequest providerName]]:s==2?@"Discuss in Claude opens a draft for review. Tap Send there when you are ready.":nil; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)p { return p.section==0?100:p.section==1?160:p.section==3?240:44; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];cell.selectionStyle=UITableViewCellSelectionStyleNone;
    if(p.section!=2) { UITextView *v=p.section==0?question:p.section==1?summary:answer;v.frame=CGRectMake(5,3,cell.contentView.bounds.size.width-10,[self tableView:t heightForRowAtIndexPath:p]-6);[cell.contentView addSubview:v]; }
    else { cell.textLabel.text=p.row==1?@"Discuss in Claude":request.running?@"Stop":[NSString stringWithFormat:@"Ask %@",[CLAIRequest providerName]];cell.textLabel.textAlignment=UITextAlignmentCenter;cell.textLabel.textColor=[UIColor colorWithRed:.67 green:.31 blue:.20 alpha:1];cell.selectionStyle=UITableViewCellSelectionStyleBlue; }return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];if(p.section!=2)return;
    [question resignFirstResponder];NSString *q=[question.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(p.row==1) {
        NSURL *url=CLDraftURL(source,q,context);
        if(!url || ![[UIApplication sharedApplication] canOpenURL:url]) { [[[[UIAlertView alloc] initWithTitle:@"Claude" message:@"Install Claude 3.1 or newer to discuss this progress in a chat." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];return; }
        [request cancel];[[UIApplication sharedApplication] openURL:url];return;
    }
    if(request.running) { [request cancel];question.editable=YES;[t reloadData];return; }
    if(![q length] || [q length]>2000) { [question becomeFirstResponder];return; }
    [request startSystem:system user:[NSString stringWithFormat:@"Question: %@\n<progress>\n%@</progress>",q,context]];
    question.editable=!request.running;[t reloadData];
}
- (BOOL)textView:(UITextView *)v shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text { return [v.text length]-range.length+[text length]<=2000; }
- (void)aiRequest:(CLAIRequest *)r text:(NSString *)text error:(NSString *)error {
    if(r!=request)return;[reply release];reply=[(text?:error?:@"No response.") copy];answer.text=reply;question.editable=YES;
    if(text) { [[NSUserDefaults standardUserDefaults] setObject:text forKey:@"ai_last_review"];[[NSUserDefaults standardUserDefaults] synchronize]; }
    [self.tableView reloadData];[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:3] atScrollPosition:UITableViewScrollPositionTop animated:YES];
}
@end
