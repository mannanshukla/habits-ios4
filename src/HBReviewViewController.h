#import <UIKit/UIKit.h>
#import "HBViews.h"
@interface HBReviewViewController : UITableViewController { NSArray *habits, *weekly; HBChartView *chart, *focusChart; BOOL busy; NSString *note, *error; }
@end
