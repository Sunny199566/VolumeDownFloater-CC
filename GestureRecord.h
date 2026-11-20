#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, GGTouchPhase) {
    GGTouchPhaseBegan,
    GGTouchPhaseMoved,
    GGTouchPhaseEnded
};

@interface GesturePoint : NSObject
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) NSInteger fingerID;
@property (nonatomic, assign) GGTouchPhase phase;
@end

@interface GestureRecorder : NSObject
@property (nonatomic, readonly) BOOL isRecording;
+ (instancetype)sharedInstance;
- (void)startRecord;
- (void)stopRecordAndSaveWithName:(NSString *)name;
- (void)playGestureWithName:(NSString *)name;
- (void)receiveTouchEvent:(CGPoint)pos finger:(int)fid phase:(GGTouchPhase)phase time:(NSTimeInterval)ts;
@end