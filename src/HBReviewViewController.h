#import <UIKit/UIKit.h>
#import "HBViews.h"
#import "CLAIRequest.h"
@interface HBReviewViewController : UITableViewController <CLAIRequestDelegate> { NSArray *habits, *weekly; HBChartView *chart, *focusChart; CLAIRequest *request; NSString *note, *error; }
@end
