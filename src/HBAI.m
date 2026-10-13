#import "HBAI.h"
#import "HBStore.h"
#import "ORJSON.h"

@implementation HBAI
+ (NSString *)complete:(NSString *)system user:(NSString *)user error:(NSString **)err {
    if (![[HBStore apiKey] length]) { if (err) *err = @"Add your OpenRelay API key in Settings first."; return nil; }
    NSArray *msgs = [NSArray arrayWithObjects:
        [NSDictionary dictionaryWithObjectsAndKeys:@"system", @"role", system, @"content", nil],
        [NSDictionary dictionaryWithObjectsAndKeys:@"user", @"role", user, @"content", nil], nil];
    NSDictionary *body = [NSDictionary dictionaryWithObjectsAndKeys:@"openrelay/gpt-oss-120b", @"model", msgs, @"messages", [NSNumber numberWithBool:NO], @"stream", [NSNumber numberWithDouble:0.5], @"temperature", nil];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://inference.openrelay.inc/v1/chat/completions"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:120];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", [HBStore apiKey]] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"close" forHTTPHeaderField:@"Connection"];
    [req setHTTPBody:[[ORJSON stringify:body] dataUsingEncoding:NSUTF8StringEncoding]];
    NSHTTPURLResponse *resp = nil; NSError *e = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&e];
    if (!data) { if (err) *err = [e localizedDescription]; return nil; }
    id obj = [ORJSON parse:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
    if ([resp statusCode] != 200 || ![obj isKindOfClass:[NSDictionary class]]) {
        NSString *m = [NSString stringWithFormat:@"HTTP %d", (int)[resp statusCode]];
        id er = [obj isKindOfClass:[NSDictionary class]] ? [obj objectForKey:@"error"] : nil;
        if ([er isKindOfClass:[NSDictionary class]] && [er objectForKey:@"message"]) m = [er objectForKey:@"message"];
        if (err) *err = m; return nil;
    }
    NSArray *choices = [obj objectForKey:@"choices"];
    if (![choices count]) { if (err) *err = @"Empty reply."; return nil; }
    id content = [[[choices objectAtIndex:0] objectForKey:@"message"] objectForKey:@"content"];
    return [content isKindOfClass:[NSString class]] ? content : nil;
}
+ (NSArray *)habitsForGoal:(NSString *)goal count:(NSInteger)n error:(NSString **)err {
    NSString *system = @"You design small habit plans. Reply with JSON only, no prose, no markdown fences. "
        @"Schema: {\"habits\":[{\"name\":string,\"type\":\"check\"|\"count\"|\"measure\",\"target\":number,\"unit\":string,\"days\":[\"mon\",\"tue\",\"wed\",\"thu\",\"fri\",\"sat\",\"sun\"],\"time\":\"HH:MM\",\"why\":string}]}. "
        @"Rules: each habit is one concrete action under 30 minutes, named as a short verb phrase of at most 26 characters, no emoji. "
        @"type check is yes or no, target 1, unit empty. type count is times per day, target 2 to 10, unit a plural noun like glasses. type measure is an amount, target with a unit like minutes, pages or km. "
        @"days lists only the weekdays it is due. time is a sensible 24 hour reminder or an empty string. why is one plain sentence under 80 characters. Mix easy daily anchors with one or two harder habits on fewer days.";
    NSString *user = [NSString stringWithFormat:@"Goal: %@. Write exactly %ld habits that together move toward this goal.", goal, (long)n];
    NSString *text = [self complete:system user:user error:err];
    if (!text) return nil;
    NSRange a = [text rangeOfString:@"{"], b = [text rangeOfString:@"}" options:NSBackwardsSearch];
    if (a.location == NSNotFound || b.location == NSNotFound) { if (err) *err = @"The model did not return JSON."; return nil; }
    id obj = [ORJSON parse:[text substringWithRange:NSMakeRange(a.location, b.location - a.location + 1)]];
    NSArray *hs = [obj isKindOfClass:[NSDictionary class]] ? [obj objectForKey:@"habits"] : nil;
    if (![hs isKindOfClass:[NSArray class]] || ![hs count]) { if (err) *err = @"Could not read the habit JSON."; return nil; }
    NSArray *dayNames = [NSArray arrayWithObjects:@"mon", @"tue", @"wed", @"thu", @"fri", @"sat", @"sun", nil];
    NSMutableArray *out = [NSMutableArray array]; NSInteger color = [[HBStore habits] count];
    for (NSDictionary *h in hs) {
        if (![h isKindOfClass:[NSDictionary class]]) continue;
        NSString *name = [[[h objectForKey:@"name"] description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (![name length]) continue; if ([name length] > 40) name = [name substringToIndex:40];
        NSString *type = [[h objectForKey:@"type"] description]; if (![type isEqualToString:@"count"] && ![type isEqualToString:@"measure"]) type = @"check";
        double target = [[h objectForKey:@"target"] doubleValue]; if ([type isEqualToString:@"check"] || target < 1) target = 1; if (target > 1000) target = 1000;
        NSString *unit = [type isEqualToString:@"check"] ? @"" : ([[h objectForKey:@"unit"] isKindOfClass:[NSString class]] ? [h objectForKey:@"unit"] : @"");
        NSMutableArray *days = [NSMutableArray array]; int on = 0;
        for (int i = 0; i < 7; i++) { BOOL d = NO; for (id x in ([[h objectForKey:@"days"] isKindOfClass:[NSArray class]] ? [h objectForKey:@"days"] : [NSArray array])) if ([[[x description] lowercaseString] hasPrefix:[dayNames objectAtIndex:i]]) d = YES; [days addObject:[NSNumber numberWithBool:d]]; if (d) on++; }
        if (!on) { days = [NSMutableArray array]; for (int i = 0; i < 7; i++) [days addObject:[NSNumber numberWithBool:YES]]; }
        NSInteger rem = -1; NSString *t = [[h objectForKey:@"time"] description]; NSArray *hm = [t componentsSeparatedByString:@":"];
        if ([hm count] == 2 && [[hm objectAtIndex:0] intValue] < 24) rem = [[hm objectAtIndex:0] intValue] * 60 + [[hm objectAtIndex:1] intValue] % 60;
        NSString *why = [[h objectForKey:@"why"] isKindOfClass:[NSString class]] ? [h objectForKey:@"why"] : @"";
        [out addObject:[NSDictionary dictionaryWithObjectsAndKeys:[HBStore newId], @"id", name, @"name", type, @"type", [NSNumber numberWithDouble:target], @"target", unit, @"unit", days, @"days",
                        [NSNumber numberWithInteger:rem], @"reminder", [NSNumber numberWithInteger:color++ % 6], @"color", [HBStore today], @"created", why, @"why", nil]];
    }
    if (![out count]) { if (err) *err = @"No usable habits came back."; return nil; }
    return out;
}
+ (NSString *)weeklyNoteWithError:(NSString **)err {
    NSMutableString *data = [NSMutableString string];
    for (NSDictionary *h in [HBStore habits]) {
        int d7, u7, d30, u30; [HBStore completion:h days:7 done:&d7 due:&u7]; [HBStore completion:h days:30 done:&d30 due:&u30];
        [data appendFormat:@"- %@ (%@): this week %d of %d due days done, last 30 days %d of %d, current streak %d, strength %.0f%%\n", [h objectForKey:@"name"], [HBStore describeSchedule:h], d7, u7, d30, u30, [HBStore streak:h], [HBStore strength:h] * 100];
    }
    NSInteger pw = [HBStore pomodorosInLastDays:7]; if (pw) [data appendFormat:@"- Focus timer: %ld pomodoros finished this week\n", (long)pw];
    if (![data length]) { if (err) *err = @"Add a habit first."; return nil; }
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; [f setDateFormat:@"EEEE, MMMM d"];
    NSString *system = @"You are a kind, direct habit coach writing a short weekly note. Plain text only: 3 or 4 sentences, no markdown, no emoji, no headings, no lists. Mention habits by name. Point out what is working and one specific thing to try next week. Be honest about misses without scolding.";
    NSString *user = [NSString stringWithFormat:@"Today is %@. Habit data:\n%@\nWrite this week's note.", [f stringFromDate:[NSDate date]], data];
    NSString *t = [self complete:system user:user error:err];
    return t ? [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
}
@end
