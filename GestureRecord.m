#import "GestureRecord.h"

@implementation GesturePoint
- (NSDictionary *)toDictionary {
    return @{
        @"fingerId": @(self.fingerId),
        @"phase": @(self.phase),
        @"x": @(self.x),
        @"y": @(self.y),
        @"ts": @(self.timestamp)
    };
}
+ (GesturePoint *)fromDictionary:(NSDictionary *)dict {
    GesturePoint *p = [[GesturePoint alloc] init];
    p.fingerId = [dict[@"fingerId"] integerValue];
    p.phase = [dict[@"phase"] integerValue];
    p.x = [dict[@"x"] floatValue];
    p.y = [dict[@"y"] floatValue];
    p.timestamp = [dict[@"ts"] doubleValue];
    return p;
}
@end

@implementation GestureRecorder
+ (instancetype)sharedInstance {
    static GestureRecorder *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[GestureRecorder alloc] init];
    });
    return inst;
}
- (void)startRecord {
    self.isRecording = YES;
    self.recordBuffer = [NSMutableArray array];
    self.baseTime = [[NSDate date] timeIntervalSince1970];
}
- (void)stopRecordAndSaveWithName:(NSString *)name {
    self.isRecording = NO;
    NSMutableArray *jsonArr = [NSMutableArray array];
    for(GesturePoint *pt in self.recordBuffer) {
        [jsonArr addObject:[pt toDictionary]];
    }
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.json", name];
    [jsonArr writeToFile:path atomically:YES];
}
- (void)receiveMultiTouch:(NSArray *)touches {
    if(!self.isRecording) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970] - self.baseTime;
    for(GesturePoint *tp in touches) {
        tp.timestamp = now;
        [self.recordBuffer addObject:tp];
    }
}

- (void)playGestureWithName:(NSString *)name {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.json", name];
    NSArray *raw = [NSArray arrayWithContentsOfFile:path];
    if(!raw) return;
    NSMutableArray<GesturePoint*> *points = [NSMutableArray array];
    for(NSDictionary *d in raw) {
        [points addObject:[GesturePoint fromDictionary:d]];
    }
    // 时序回放，按时间延迟派发多点事件
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        NSTimeInterval prevTs = 0;
        for(GesturePoint *pt in points) {
            NSTimeInterval delay = pt.timestamp - prevTs;
            if(delay < 0) delay = 0;
            prevTs = pt.timestamp;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 这里构造多点GSEvent投递，配套Tweak.xm内的投递函数
                [self sendReplayedTouch:pt];
            });
        }
    });
}

// 空壳，实现放在Tweak.xm（GSEvent私有构造放在xm，分离代码更稳定）
- (void)sendReplayedTouch:(GesturePoint *)pt {}
@end