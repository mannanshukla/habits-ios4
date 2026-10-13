#import <UIKit/UIKit.h>
@interface HBTodayViewController : UITableViewController <UIActionSheetDelegate> { NSArray *due, *rest; NSDictionary *sheetHabit; }
@end
@interface HBSettingsViewController : UITableViewController <UITextFieldDelegate> { UITextField *keyField; }
@end
