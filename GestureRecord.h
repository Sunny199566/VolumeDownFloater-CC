#ifndef GestureRecord_h
#define GestureRecord_h
#import <Foundation/Foundation.h>

typedef enum : NSInteger {
    TouchPhaseBegan,
    TouchPhaseMoved,
    TouchPhaseEnded,
    TouchPhaseCancelled
} TouchPhase;

@interface GesturePoint : NSObject
@property (nonatomic, assign) int fingerId;
@property (nonatomic, assign) TouchPhase phase;
@property (nonatomic, assign) float x;
@property (nonatomic, assign) float y;
@end

@interface GestureRecorder : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, assign) BOOL isRecording;
- (void)startRecord;
- (void)stopRecordAndSaveWithName:(NSString *)name;
- (void)playGestureWithName:(NSString *)name;
- (void)receiveTouchPoints:(NSArray<GesturePoint *> *)points;
@end

#endif