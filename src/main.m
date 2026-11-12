#import <UIKit/UIKit.h>
#import "HBTodayViewController.h"
#import "HBHabitsViewController.h"
#import "HBReviewViewController.h"
#import "HBFocusViewController.h"
#import "HBStore.h"
#import "HBViews.h"

@interface HBAppDelegate : NSObject <UIApplicationDelegate> { UIWindow *window; UITabBarController *tabs; NSUInteger naps; }
@end
@implementation HBAppDelegate
- (UINavigationController *)wrap:(UIViewController *)vc { UINavigationController *n = [[[UINavigationController alloc] initWithRootViewController:vc] autorelease]; n.navigationBar.tintColor = [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1]; HBSkinNavBar(n.navigationBar); return n; }
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    tabs = [[UITabBarController alloc] init];
    HBTodayViewController *t = [[[HBTodayViewController alloc] init] autorelease];
    HBHabitsViewController *h = [[[HBHabitsViewController alloc] init] autorelease];
    HBReviewViewController *r = [[[HBReviewViewController alloc] init] autorelease]; HBFocusViewController *f = [[[HBFocusViewController alloc] init] autorelease]; f.tabBarItem.image = [UIImage imageNamed:@"tab-focus.png"];
    t.tabBarItem.image = [UIImage imageNamed:@"tab-today.png"]; h.tabBarItem.image = [UIImage imageNamed:@"tab-habits.png"]; r.tabBarItem.image = [UIImage imageNamed:@"tab-review.png"];
    tabs.viewControllers = [NSArray arrayWithObjects:[self wrap:t], [self wrap:h], [self wrap:f], [self wrap:r], nil];
    tabs.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"hb_tab"];
    if ([opts objectForKey:UIApplicationLaunchOptionsLocalNotificationKey]) tabs.selectedIndex = 0;
    [window addSubview:tabs.view]; [window makeKeyAndVisible];
    app.applicationIconBadgeNumber = 0;
    return YES;
}
- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)n { if ([[n.userInfo objectForKey:@"kind"] isEqualToString:@"pomo"]) { tabs.selectedIndex = 2; return; } tabs.selectedIndex = 0; [(UINavigationController *)[tabs.viewControllers objectAtIndex:0] popToRootViewControllerAnimated:NO]; }
- (void)applicationDidBecomeActive:(UIApplication *)app { app.applicationIconBadgeNumber = 0; }
- (void)applicationDidEnterBackground:(UIApplication *)app {   // suspended, Habits keeps no drawn bitmaps
    HBPurge(); HBSleepDrawings(NO);   // what is out of sight goes now
    // The system takes the snapshot it zooms back in from once this returns, so what is on screen goes a moment later.
    NSUInteger nap = ++naps; __block UIBackgroundTaskIdentifier task = UIBackgroundTaskInvalid;
    void (^end)(void) = ^{ if (task != UIBackgroundTaskInvalid) { [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; } };
    task = [app beginBackgroundTaskWithExpirationHandler:end];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (nap == naps && app.applicationState == UIApplicationStateBackground) { HBSleepDrawings(YES); HBPurge(); }
        end();
    });
}
- (void)applicationWillEnterForeground:(UIApplication *)app { naps++; HBWakeDrawings(); }
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)app { HBPurge(); HBSleepDrawings(NO); }
- (void)applicationWillTerminate:(UIApplication *)app { [[NSUserDefaults standardUserDefaults] setInteger:tabs.selectedIndex forKey:@"hb_tab"]; [[NSUserDefaults standardUserDefaults] synchronize]; }
- (void)dealloc { [tabs release]; [window release]; [super dealloc]; }
@end
int main(int argc, char *argv[]) { NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init]; int r = UIApplicationMain(argc, argv, nil, @"HBAppDelegate"); [p release]; return r; }
