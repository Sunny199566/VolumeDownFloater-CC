#import "GestureRecord.h"

@interface GestureRecorder()
@property (nonatomic, strong) NSMutableArray<GesturePoint*> *recordBuffer;
@property (nonatomic, assign) NSTimeInterval baseTime;
@end

@implementation GestureRecorder
+ (instancetype)sharedInstance {
    static GestureRecorder *ins;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ins = [GestureRecorder new]; });
    return ins;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _recordBuffer = [NSMutableArray new];
        _baseTime = 0;
    }
    return self;
}

- (BOOL)isRecording {
    return _baseTime > 0;
}

- (void)startRecord {
    [_recordBuffer removeAllObjects];
    _baseTime = [[NSDate date] timeIntervalSince1970];
}

- (void)receiveTouchEvent:(CGPoint)pos finger:(int)fid phase:(GGTouchPhase)phase time:(NSTimeInterval)ts {
    if(!self.isRecording) return;
    GesturePoint *p = [GesturePoint new];
    p.point = pos;
    p.timestamp = ts - _baseTime;
    p.fingerID = fid;
    p.phase = phase;
    [_recordBuffer addObject:p];
}

- (void)stopRecordAndSaveWithName:(NSString *)name {
    _baseTime = 0;
    NSMutableArray *jsonArr = [NSMutableArray new];
    for(GesturePoint *pt in _recordBuffer) {
        [jsonArr addObject:@{
            @"x":@(pt.point.x),
            @"y":@(pt.point.y),
            @"finger":@(pt.fingerID),
            @"phase":@(pt.phase),
            @"time":@(pt.timestamp)
        }];
    }
    NSString *savePath = [NSString stringWithFormat:@"/var/jb/var/mobile/Documents/%@.json",name];
    [jsonArr writeToFile:savePath atomically:YES];
}

- (void)playGestureWithName:(NSString *)name {
    NSString *path = [NSString stringWithFormat:@"/var/jb/var/mobile/Documents/%@.json",name];
    NSArray *data = [NSArray arrayWithContentsOfFile:path];
    if (!data) return;
    // ========== 回放事件发送预留位置，后续填入GSEvent发送代码 ==========
}
@end

@implementation GesturePoint
@end