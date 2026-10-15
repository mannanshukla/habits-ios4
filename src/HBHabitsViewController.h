#import <UIKit/UIKit.h>
#import "HBViews.h"
@interface HBHabitsViewController : UITableViewController { NSArray *habits; }
@end
@interface HBEditViewController : UITableViewController <UITextFieldDelegate> { NSMutableDictionary *habit; BOOL isNew; UITextField *nameField, *unitField; UISegmentedControl *type; UISwitch *remind; NSMutableArray *dayButtons, *colorButtons; }
- (id)initWithHabit:(NSDictionary *)h;   // nil = new
@end
@interface HBGenerateViewController : UITableViewController <UITextFieldDelegate> { UITextField *goal; UISegmentedControl *count; BOOL busy; NSString *status; }
@end
@interface HBPickViewController : UITableViewController { NSArray *proposed; NSMutableSet *chosen; NSString *goal; }
- (id)initWithHabits:(NSArray *)h goal:(NSString *)g;
@end
@interface HBDetailViewController : UITableViewController { NSDictionary *habit; HBCalendarView *heat; HBChartView *byDay; }
- (id)initWithHabit:(NSDictionary *)h;
@end
