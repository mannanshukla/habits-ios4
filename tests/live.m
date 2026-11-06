#import <UIKit/UIKit.h>
#import "CLAIRequest.h"
#import "CLCoachViewController.h"
#ifdef HABITS
#import "HBAI.h"
#import "HBStore.h"
#import "HBHabitsViewController.h"
#else
#import "LFAI.h"
#import "LFStore.h"
#import "LFRoutinesViewController.h"
#import "LFSkin.h"
#endif
@interface LiveDelegate:NSObject<UIApplicationDelegate,CLAIRequestDelegate> { UIWindow *window;UINavigationController *nav;CLAIRequest *request;NSArray *plan;NSDictionary *options;int phase; }
@end
@implementation LiveDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
 window=[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];nav=[[UINavigationController alloc] initWithRootViewController:[[[UIViewController alloc] init] autorelease]];window.rootViewController=nav;[window makeKeyAndVisible];[self performSelector:@selector(run) withObject:nil afterDelay:1];return YES;
}
- (void)run {
 NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/live.txt"];freopen([path fileSystemRepresentation],"w",stdout);freopen([path fileSystemRepresentation],"a",stderr);setbuf(stdout,NULL);
 if(![[NSUserDefaults standardUserDefaults] stringForKey:@"ai_claude_key"]){puts("No test credential configured");return;}request=[CLAIRequest new];request.delegate=self;
#ifdef HABITS
 [[NSUserDefaults standardUserDefaults] setObject:@"Read more books and walk daily" forKey:@"hb_goal"];[[NSUserDefaults standardUserDefaults] setObject:@"15 minutes after breakfast; busy evenings" forKey:@"hb_constraints"];
 nav.navigationBar.tintColor=[UIColor colorWithRed:.25 green:.4 blue:.3 alpha:1];
 [request startSystem:[HBAI habitSystem] user:[HBAI goalPrompt:@"Read more books and walk daily" count:3 constraints:@"15 minutes after breakfast; busy evenings"]];
#else
 LFSkinNavBar(nav.navigationBar);options=[[NSDictionary alloc] initWithObjectsAndKeys:@"general fitness",@"goal",@"beginner",@"level",@"bodyweight",@"equipment",[NSNumber numberWithInt:2],@"days",[NSNumber numberWithInt:30],@"minutes",@"Short sessions at home",@"notes",nil];[[NSUserDefaults standardUserDefaults] setObject:options forKey:@"ai_training_goal"];[request startSystem:[LFAI routineSystem] user:[LFAI routinePrompt:options]];
#endif
 puts("Live request started with synthetic goal and empty test history");
}
- (void)aiRequest:(CLAIRequest *)r text:(NSString *)text error:(NSString *)error {
 if(error){printf("FAIL live transport: %s\n",[error UTF8String]);return;}
 if(phase==0){NSString *problem=nil;
#ifdef HABITS
 plan=[[HBAI parseHabits:text count:3 error:&problem] retain];BOOL unchanged=[[HBStore habits] count]==0;
#else
 plan=[[LFAI parseRoutines:text options:options error:&problem] retain];BOOL unchanged=[[LFStore routines] count]==0;
#endif
 if(!plan || !unchanged){printf("FAIL live plan validation: %s\n",[problem UTF8String]);return;}printf("PASS live plan: %lu valid suggestions; existing data unchanged\n",(unsigned long)[plan count]);phase=1;
#ifdef HABITS
 [request startSystem:[HBAI weeklySystem] user:[HBAI summary]];
#else
 [request startSystem:[LFAI reviewSystem] user:[LFAI summary]];
#endif
 }else{printf("PASS live coaching: %lu characters\n",(unsigned long)[text length]);[[NSUserDefaults standardUserDefaults] setObject:text forKey:@"ai_last_review"];
#ifdef HABITS
 HBPickViewController *preview=[[[HBPickViewController alloc] initWithHabits:plan goal:@"Read more books and walk daily"] autorelease];
#else
 LFPlanPreviewController *preview=[[[LFPlanPreviewController alloc] initWithRoutines:plan] autorelease];
#endif
 [nav pushViewController:preview animated:NO];puts("PASS native preview displayed, awaiting explicit Add");}
}
- (void)dealloc {request.delegate=nil;[request cancel];[request release];[plan release];[options release];[nav release];[window release];[super dealloc];}
@end
int main(int argc,char **argv){NSAutoreleasePool *p=[NSAutoreleasePool new];int r=UIApplicationMain(argc,argv,nil,@"LiveDelegate");[p drain];return r;}
