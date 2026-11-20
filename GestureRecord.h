#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TouchPhase) {
    TouchPhaseBegan,
    TouchPhaseMoved,
    TouchPhaseEnded,
    TouchPhaseCancelled
};

@interface GesturePoint : NSObject
@property (nonatomic, assign) NSInteger fingerId;
@property (nonatomic, assign) TouchPhase phase;
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) NSTimeInterval timestamp;
- (NSDictionary *)toDictionary;
+ (GesturePoint *)fromDictionary:(NSDictionary *)dict;
@end

@interface GestureRecorder : NSObject
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) NSMutableArray<GesturePoint *> *recordBuffer;
@property (nonatomic, assign) NSTimeInterval baseTime;
+ (instancetype)sharedInstance;
- (void)startRecord;
- (void)stopRecordAndSaveWithName:(NSString *)name;
- (void)playGestureWithName:(NSString *)name;
- (void)receiveMultiTouch:(NSArray *)touches;
@end