#import <UIKit/UIKit.h>
#import <malloc/malloc.h>
#import "CLCoachViewController.h"
#ifdef HABITS
#import "HBHabitsViewController.h"
#import "HBReviewViewController.h"
#import "HBStore.h"
#import "HBAI.h"
#define Generator HBGenerateViewController
#define Review HBReviewViewController
#define Preview HBPickViewController
#else
#import "LFRoutinesViewController.h"
#import "LFProgressViewController.h"
#import "LFStore.h"
#import "LFAI.h"
#define Generator LFGenerateViewController
#define Review LFProgressViewController
#define Preview LFPlanPreviewController
#endif
static NSUInteger checks,closedGenerators,closedReviews,closedCoaches,closedPreviews;
static void check(BOOL b,const char *message) { checks++;if(!b) { fprintf(stderr,"FAIL %s\n",message);exit(1); } }
@interface TrackedGenerator:Generator @end
@implementation TrackedGenerator
- (void)dealloc { closedGenerators++;[super dealloc]; }
@end
@interface TrackedReview:Review @end
@implementation TrackedReview
- (void)dealloc { closedReviews++;[super dealloc]; }
@end
@interface TrackedCoach:CLCoachViewController @end
@implementation TrackedCoach
- (void)dealloc { closedCoaches++;[super dealloc]; }
@end
@interface TrackedPreview:Preview @end
@implementation TrackedPreview
- (void)dealloc { closedPreviews++;[super dealloc]; }
@end
@interface PendingProtocol:NSURLProtocol @end
@implementation PendingProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r { return [[[r URL] host] isEqual:@"api.anthropic.com"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r { return r; }
- (void)startLoading {}
- (void)stopLoading {}
@end
static size_t allocated(void) { malloc_statistics_t s;malloc_zone_statistics(NULL,&s);return s.size_in_use; }
static void reload(UIViewController *c) { check(c.view!=nil,"view loads");[c viewWillAppear:NO];[c viewWillDisappear:NO];[c viewDidUnload];c.view=nil;check(c.view!=nil,"view reloads after memory warning");[c viewWillAppear:NO]; }
@interface AuditDelegate:NSObject<UIApplicationDelegate> { UIWindow *window; }
@end
@implementation AuditDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts { window=[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];window.rootViewController=[[[UIViewController alloc] init] autorelease];[window makeKeyAndVisible];[self performSelector:@selector(run) withObject:nil afterDelay:.5];return YES; }
- (void)run {
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/audit.txt"];freopen([path fileSystemRepresentation],"w",stdout);freopen([path fileSystemRepresentation],"a",stderr);
    NSAutoreleasePool *outer=[NSAutoreleasePool new];[NSURLProtocol registerClass:[PendingProtocol class]];[[NSUserDefaults standardUserDefaults] setObject:@"fixture-only" forKey:@"ai_claude_key"];[[NSUserDefaults standardUserDefaults] setObject:@"claude" forKey:@"ai_provider"];
#ifdef HABITS
    [HBStore saveHabits:[NSArray array]];
    NSArray *plan=[HBAI parseHabits:@"{\"habits\":[{\"name\":\"Read one page\",\"type\":\"check\",\"target\":1,\"days\":[\"mon\"],\"time\":\"\",\"why\":\"Start small.\"}]}" count:1 error:NULL];
#else
    [LFStore saveRoutines:[NSArray array]];
    NSArray *plan=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"fixture-routine",@"id",@"Small start",@"name",[NSArray array],@"exercises",nil]];
#endif
    check([plan count]==1,"plan fixture ready");size_t baseline=0,last=0;
    for(int i=0;i<50;i++) { NSAutoreleasePool *pool=[NSAutoreleasePool new];
        TrackedGenerator *g=[TrackedGenerator new];reload(g);CLAIRequest *active=[g valueForKey:@"request"];[active startSystem:@"fixture" user:@"fixture"];check(active.running,"request started for teardown test");[g release];
        TrackedReview *r=[TrackedReview new];reload(r);[r release];
        TrackedCoach *c=[[TrackedCoach alloc] initWithSource:@"Habits" context:@"No history yet." system:@"A small next step."];reload(c);active=[c valueForKey:@"request"];[active startSystem:@"fixture" user:@"fixture"];check(active.running,"coach upload pending");[c release];
#ifdef HABITS
        TrackedPreview *p=[[TrackedPreview alloc] initWithHabits:plan goal:@"Read more"];
        check([[HBStore habits] count]==0,"preview does not save habits");
#else
        TrackedPreview *p=[[TrackedPreview alloc] initWithRoutines:plan];
        check([[LFStore routines] count]==0,"preview does not save routines");
#endif
        reload(p);[p release];[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];[pool drain];last=allocated();if(i==9)baseline=last;
        if(i%10==9) { printf("cycle %d allocated=%lu\n",i+1,(unsigned long)last);fflush(stdout); }
    }
    check(closedGenerators==50 && closedReviews==50 && closedCoaches==50 && closedPreviews==50,"all 200 controllers released, including pending requests");check(last<=baseline+512*1024,"post-warmup heap bounded");
    CLAIRequest *request=[CLAIRequest new];[request startSystem:@"fixture" user:@"fixture"];[[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];check(request.state==CLAICancelled,"background cancels transport");[request release];
    printf("PASS %lu native assertions; 200 controllers released; heap change %+ld bytes\n",(unsigned long)checks,(long)last-(long)baseline);fflush(stdout);[outer drain];exit(0);
}
- (void)dealloc { [window release];[super dealloc]; }
@end
int main(int argc,char **argv) { NSAutoreleasePool *pool=[NSAutoreleasePool new];int result=UIApplicationMain(argc,argv,nil,@"AuditDelegate");[pool drain];return result; }
