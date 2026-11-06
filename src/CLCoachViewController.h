#import <UIKit/UIKit.h>
#import "CLAIRequest.h"
@interface CLCoachViewController : UITableViewController <CLAIRequestDelegate,UITextViewDelegate> {
    NSString *source,*context,*system,*reply,*questionText; UITextView *question,*summary,*answer; CLAIRequest *request;
}
- (id)initWithSource:(NSString *)source context:(NSString *)context system:(NSString *)system;
@end
