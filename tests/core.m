#import <Foundation/Foundation.h>
#import "CLAIRequest.h"
#import "CLIntegration.h"
#import "ORJSON.h"
#ifdef HABITS
#import "HBAI.h"
#import "HBStore.h"
@implementation HBStore
+ (NSArray *)habits { return [NSArray array]; }
+ (NSString *)uniqueId { return [[NSProcessInfo processInfo] globallyUniqueString]; }
+ (NSString *)today { return @"2026-11-06"; }
+ (void)completion:(NSDictionary *)h days:(int)n done:(int *)a due:(int *)b { *a=0;*b=0; }
+ (NSString *)describeSchedule:(NSDictionary *)h { return @"Every day"; }
+ (int)streak:(NSDictionary *)h { return 0; }
+ (double)strength:(NSDictionary *)h { return 0; }
+ (NSInteger)pomodorosInLastDays:(int)n { return 0; }
@end
#else
#import "LFAI.h"
#import "LFStore.h"
@implementation LFStore
+ (NSString *)uniqueId { return [[NSProcessInfo processInfo] globallyUniqueString]; }
+ (NSArray *)exercises { NSMutableArray *a=[NSMutableArray array];for(NSString *key in [NSArray arrayWithObjects:@"one",@"two",@"three",@"bar",@"stretch",nil])[a addObject:[NSDictionary dictionaryWithObjectsAndKeys:key,@"id",key,@"name",[key isEqual:@"bar"]?@"barbell":@"body only",@"equipment",[NSArray arrayWithObject:@"legs"],@"primary",nil]];return a; }
+ (NSDictionary *)exercise:(NSString *)key { for(NSDictionary *e in [self exercises])if([[e objectForKey:@"id"] isEqual:key])return e;return nil; }
+ (BOOL)isStretch:(NSDictionary *)e { return [[e objectForKey:@"id"] isEqual:@"stretch"]; }
+ (BOOL)useKg { return NO; }
+ (NSArray *)workouts { return [NSArray array]; }
+ (NSArray *)weeklyVolume:(int)n { return [NSArray array]; }
@end
#endif
static NSUInteger checks,closed;static int mode;
static void check(BOOL ok,const char *message) { checks++;if(!ok) { fprintf(stderr,"FAIL %s\n",message);exit(1); } }
@interface Probe:NSObject<CLAIRequestDelegate> { @public NSUInteger calls;NSString *text,*error; }
@end
@implementation Probe
- (void)aiRequest:(CLAIRequest *)r text:(NSString *)t error:(NSString *)e { calls++;[text release];text=[t copy];[error release];error=[e copy]; }
- (void)dealloc { [text release];[error release];[super dealloc]; }
@end
@interface Tracked:CLAIRequest
@end
@implementation Tracked
- (void)dealloc { closed++;[super dealloc]; }
@end
@interface Fixture:NSURLProtocol
@end
@implementation Fixture
+ (BOOL)canInitWithRequest:(NSURLRequest *)r { return [[[r URL] host] isEqual:@"api.anthropic.com"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r { return r; }
- (void)stopLoading {}
- (void)startLoading {
    if(mode==1)return;
    NSHTTPURLResponse *r=[[[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil] autorelease];
    if(mode==2) { [self.client URLProtocol:self wasRedirectedToRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://invalid.example"]] redirectResponse:r];return; }
    [self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    NSData *data=mode==3?[NSMutableData dataWithLength:512*1024+1]:[@"{\"stop_reason\":\"end_turn\",\"content\":[{\"type\":\"text\",\"text\":\"A small next step.\"}]}" dataUsingEncoding:NSUTF8StringEncoding];
    [self.client URLProtocol:self didLoadData:data];[self.client URLProtocolDidFinishLoading:self];
}
@end
static void waitFor(Probe *p) { NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!p->calls && [end timeIntervalSinceNow]>0)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]]; }
static void transport(void) {
    NSDictionary *settings=[NSDictionary dictionaryWithObjectsAndKeys:@"fixture-claude",@"ai_claude_key",@"fixture-legacy",@"hb_api_key",@"fixture-legacy",@"lf_api_key",nil];NSString *error=nil;
    NSURLRequest *r=[CLAIRequest requestForSystem:@"Instructions" user:@"Goal" settings:settings error:&error];
    check([[[r URL] host] isEqual:@"api.anthropic.com"],"Claude endpoint");check([[r valueForHTTPHeaderField:@"x-api-key"] isEqual:@"fixture-claude"] && ![r valueForHTTPHeaderField:@"Authorization"],"provider credential isolation");
    NSDictionary *body=[ORJSON parse:[[[NSString alloc] initWithData:r.HTTPBody encoding:NSUTF8StringEncoding] autorelease]];check([[body objectForKey:@"system"] isEqual:@"Instructions"] && [[[body objectForKey:@"messages"] objectAtIndex:0] objectForKey:@"content"]!=nil,"Anthropic request shape");
    NSMutableDictionary *legacy=[NSMutableDictionary dictionaryWithDictionary:settings];[legacy setObject:@"openrelay" forKey:@"ai_provider"];r=[CLAIRequest requestForSystem:@"Instructions" user:@"Goal" settings:legacy error:&error];check(![r valueForHTTPHeaderField:@"x-api-key"] && [[r valueForHTTPHeaderField:@"Authorization"] isEqual:@"Bearer fixture-legacy"],"legacy choice uses only legacy credential");
    check(![CLAIRequest requestForSystem:@"x" user:@"goal" settings:[NSDictionary dictionary] error:&error],"missing key refuses request");
    for(NSString *json in [NSArray arrayWithObjects:@"[]",@"null",@"{\"content\":\"wrong\",\"stop_reason\":\"end_turn\"}",@"{\"content\":[{\"type\":\"text\",\"text\":\"partial\"}],\"stop_reason\":\"max_tokens\"}",nil])check(![CLAIRequest textFromData:[json dataUsingEncoding:NSUTF8StringEncoding] status:200 claude:YES error:&error],"malformed and truncated replies rejected");
    [NSURLProtocol registerClass:[Fixture class]];[[NSUserDefaults standardUserDefaults] setObject:@"fixture-claude" forKey:@"ai_claude_key"];[[NSUserDefaults standardUserDefaults] setObject:@"claude" forKey:@"ai_provider"];
    for(int test=0;test<4;test++) { mode=test;Probe *p=[Probe new];Tracked *request=[Tracked new];request.delegate=p;[request startSystem:@"s" user:@"u"];
        if(test==1) { [request cancel];check(request.state==CLAICancelled && !request.running && !p->calls,"cancel has no late completion"); }
        else { waitFor(p);check(p->calls==1,"one terminal callback");check(test==0?[p->text isEqual:@"A small next step."]:p->error!=nil,"success, redirect and oversized response outcomes"); }
        request.delegate=nil;[request release];[p release]; }
    mode=1;NSUInteger before=closed;for(int i=0;i<300;i++) { NSAutoreleasePool *p=[NSAutoreleasePool new];Tracked *request=[Tracked new];[request startSystem:@"s" user:@"u"];[request release];[p drain]; }check(closed-before==300,"pending connections cannot retain abandoned requests");
    [NSURLProtocol unregisterClass:[Fixture class]];[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ai_claude_key"];[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ai_provider"];
}
static void handoff(void) {
    NSString *error=nil;NSURL *u=CLDraftURL(@"Habits",@"Café & a goal? #1",@"Read 10 pages\nA+B = a habit");NSString *text=CLDraftTextFromURL(u,&error);check([text rangeOfString:@"Café & a goal? #1"].location!=NSNotFound && [text rangeOfString:@"A+B"].location!=NSNotFound,"draft preserves Unicode and reserved characters");
    for(NSString *bad in [NSArray arrayWithObjects:@"https://compose?source=Habits&text=x",@"claude-ipod://send?source=Habits&text=x",@"claude-ipod://compose?source=Habits&text=x&send=1",@"claude-ipod://compose?source=Habits&text=x&text=y",@"claude-ipod://compose?source=Unknown&text=x",@"claude-ipod://compose?source=Sets&text=",nil])check(!CLDraftTextFromURL([NSURL URLWithString:bad],&error),"unsafe draft URL rejected");
    check(!CLDraftURL(@"Sets",@"q",[@"x" stringByPaddingToLength:12001 withString:@"x" startingAtIndex:0]),"draft size bounded");
}
static void plans(void) {
    NSString *error=nil;
#ifdef HABITS
    NSDictionary *h=[NSDictionary dictionaryWithObjectsAndKeys:@"Read a page",@"name",@"check",@"type",[NSNumber numberWithInt:1],@"target",@"",@"unit",[NSArray arrayWithObject:@"mon"],@"days",@"08:30",@"time",@"After breakfast",@"why",nil];
    NSString *valid=[ORJSON stringify:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:h] forKey:@"habits"]];check([[HBAI parseHabits:valid count:1 error:&error] count]==1,"valid habit preview");
    for(NSArray *mutation in [NSArray arrayWithObjects:[NSArray arrayWithObjects:@"target",[NSNull null],nil],[NSArray arrayWithObjects:@"days",@"everyday",nil],[NSArray arrayWithObjects:@"time",@"25:90",nil],[NSArray arrayWithObjects:@"type",@"unknown",nil],[NSArray arrayWithObjects:@"name",[NSDictionary dictionary],nil],nil]) { NSMutableDictionary *bad=[NSMutableDictionary dictionaryWithDictionary:h];[bad setObject:[mutation objectAtIndex:1] forKey:[mutation objectAtIndex:0]];check(![HBAI parseHabits:[ORJSON stringify:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:bad] forKey:@"habits"]] count:1 error:&error],"malformed habit cannot be saved"); }
    check(![HBAI parseHabits:[ORJSON stringify:[NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:h,h,nil] forKey:@"habits"]] count:2 error:&error],"duplicate habits rejected");check(![HBAI parseHabits:@"} {" count:1 error:&error],"reversed JSON range safe");
    check([[HBAI summary] rangeOfString:@"No habits"].location!=NSNotFound,"empty-history context honest");
#else
    NSDictionary *options=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1],@"days",[NSNumber numberWithInt:20],@"minutes",@"bodyweight",@"equipment",nil];NSMutableArray *exs=[NSMutableArray array];for(NSString *key in [NSArray arrayWithObjects:@"one",@"two",@"three",nil])[exs addObject:[NSDictionary dictionaryWithObjectsAndKeys:key,@"id",[NSNumber numberWithInt:2],@"sets",@"8-12",@"reps",nil]];
    NSDictionary *routine=[NSDictionary dictionaryWithObjectsAndKeys:@"Start small",@"name",exs,@"exercises",nil];check([[LFAI parseRoutines:[ORJSON stringify:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:routine] forKey:@"routines"]] options:options error:&error] count]==1,"valid routine preview");
    for(NSArray *mutation in [NSArray arrayWithObjects:[NSArray arrayWithObjects:@"id",@"bar",nil],[NSArray arrayWithObjects:@"id",@"made-up",nil],[NSArray arrayWithObjects:@"sets",[NSNull null],nil],[NSArray arrayWithObjects:@"sets",[NSNumber numberWithInt:99],nil],[NSArray arrayWithObjects:@"reps",@"100",nil],[NSArray arrayWithObjects:@"reps",@"20-5",nil],nil]) { NSMutableDictionary *x=[NSMutableDictionary dictionaryWithDictionary:[exs objectAtIndex:0]];[x setObject:[mutation objectAtIndex:1] forKey:[mutation objectAtIndex:0]];NSMutableArray *changed=[NSMutableArray arrayWithArray:exs];[changed replaceObjectAtIndex:0 withObject:x];NSDictionary *bad=[NSDictionary dictionaryWithObjectsAndKeys:@"Bad plan",@"name",changed,@"exercises",nil];check(![LFAI parseRoutines:[ORJSON stringify:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:bad] forKey:@"routines"]] options:options error:&error],"equipment, ids, sets and reps constrained"); }
    check(![LFAI parseRoutines:@"} {" options:options error:&error],"reversed JSON range safe");check([[LFAI summary] rangeOfString:@"No completed workouts"].location!=NSNotFound,"empty-history context honest");
#endif
}
int main(void) { NSAutoreleasePool *pool=[NSAutoreleasePool new];transport();handoff();plans();printf("PASS %lu checks; 300 active requests released; transport, validation, draft handoff\n",(unsigned long)checks);[pool drain];return 0; }
