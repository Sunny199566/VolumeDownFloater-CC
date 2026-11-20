#import "GestureRecord.h"

@interface GestureRecorder ()
@property (nonatomic, strong) NSMutableArray *recordBuffer;
@property (nonatomic, assign) NSTimeInterval baseTime;
@end

@implementation GesturePoint
- (instancetype)init {
    self = [super init];
    if(self) {
        _fingerId = 0;
        _phase = TouchPhaseCancelled;
        _x = 0;
        _y = 0;
        _timestamp = 0;
    }
    return self;
}
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
    p.fingerId = [dict[@"fingerId"] intValue];
    p.phase = (TouchPhase)[dict[@"phase"] integerValue];
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

- (void)receiveTouchPoints:(NSArray<GesturePoint *> *)points {
    if (!self.isRecording) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970] - self.baseTime;
    for(GesturePoint *tp in points) {
        tp.timestamp = now;
        [self.recordBuffer addObject:tp];
    }
}

- (void)stopRecordAndSaveWithName:(NSString *)name {
    self.isRecording = NO;
    if(self.recordBuffer.count == 0) return;

    NSMutableArray *saveArr = [NSMutableArray array];
    for(GesturePoint *pt in self.recordBuffer) {
        [saveArr addObject:[pt toDictionary]];
    }
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Documents/%@.json", name];
    [saveArr writeToFile:path atomically:YES];
}

- (void)playGestureWithName:(NSString *)name {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Documents/%@.json", name];
    NSArray *raw = [NSArray arrayWithContentsOfFile:path];
    if(!raw) return;

    NSMutableArray *playPoints = [NSMutableArray array];
    for(NSDictionary *d in raw) {
        [playPoints addObject:[GesturePoint fromDictionary:d]];
    }
    if(playPoints.count == 0) return;

    __block NSTimeInterval prevTs = 0;
    for(GesturePoint *pt in playPoints) {
        NSTimeInterval delay = pt.timestamp - prevTs;
        prevTs = pt.timestamp;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // ⚠️ 注意：回放IOKit触摸事件逻辑，你可以在这里填入IOKit多点触摸回放代码
        });
    }
}
@end