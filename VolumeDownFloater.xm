#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreHaptics/CoreHaptics.h>
#import "GestureRecord.h"
#import <substrate.h>
#import <dlfcn.h>

#pragma mark - GSEvent动态加载Hook定义
static void (*orig_GSEventSendEvent)(void *event);
static void *p_GSEventSendEvent_ptr;

/// 根据iOS17.0 GSEvent结构体解析触摸点，生成GesturePoint数组
static NSArray<GesturePoint *> * parseMultiGSEvent(void *event) {
    NSMutableArray *points = [NSMutableArray array];
    if (!event) return points;

    // iOS17.0 固定结构体偏移（iPhone15Pro）
    uint32_t touchCount = *(uint32_t *)((uintptr_t)event + 0x38);
    void *touchesBuffer = (void *)((uintptr_t)event + 0x40);

    for (uint32_t i = 0; i < touchCount; i++) {
        void *singleTouch = (void *)((uintptr_t)touchesBuffer + i * 0x28);
        GesturePoint *pt = [[GesturePoint alloc] init];

        pt.fingerId = *(int32_t *)((uintptr_t)singleTouch + 0x00);
        float x = *(float *)((uintptr_t)singleTouch + 0x04);
        float y = *(float *)((uintptr_t)singleTouch + 0x08);
        pt.x = x;
        pt.y = y;

        uint8_t phaseRaw = *(uint8_t *)((uintptr_t)singleTouch + 0x10);
        switch (phaseRaw) {
            case 0: pt.phase = TouchPhaseBegan; break;
            case 1: pt.phase = TouchPhaseMoved; break;
            case 2: pt.phase = TouchPhaseEnded; break;
            case 3: pt.phase = TouchPhaseCancelled; break;
            default: pt.phase = TouchPhaseCancelled;
        }
        [points addObject:pt];
    }
    return points;
}

static void hooked_GSEventSendEvent(void *event) {
    orig_GSEventSendEvent(event);
    if ([GestureRecorder sharedInstance].isRecording) {
        NSArray *touchArray = parseMultiGSEvent(event);
        // ✅ 已修复：receiveTouchPoints 和你头文件方法名保持一致
        [[GestureRecorder sharedInstance] receiveTouchPoints:touchArray];
    }
}

static void loadGSSymbol() {
    void *gsLib = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY);
    if (!gsLib) return;
    p_GSEventSendEvent_ptr = dlsym(gsLib, "_GSEventSendEvent");
    if (p_GSEventSendEvent_ptr) {
        MSHookFunction(p_GSEventSendEvent_ptr, (void*)hooked_GSEventSendEvent, (void**)&orig_GSEventSendEvent);
    }
}

#pragma mark - 悬浮球管理器
@interface FloaterManager : NSObject
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, strong) UIButton *floaterBtn;
+ (instancetype)sharedInstance;
- (void)setup;
- (void)showFloater;
- (void)hideFloater;
@end

@implementation FloaterManager
+ (instancetype)sharedInstance {
    static FloaterManager *inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[FloaterManager alloc] init];
    });
    return inst;
}

- (void)setup {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenRect = [UIScreen mainScreen].bounds;
        CGFloat w = 60;
        CGFloat h = 60;
        CGFloat x = screenRect.size.width - 70;
        CGFloat y = screenRect.size.height / 2.0 - h / 2.0;
        self.floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(x,y,w,h)];
        self.floatWindow.windowLevel = UIWindowLevelAlert + 1000;
        self.floatWindow.hidden = YES;

        self.floaterBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floaterBtn.frame = CGRectMake(0,0,w,h);
        self.floaterBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.85];
        self.floaterBtn.layer.cornerRadius = 30;
        [self.floaterBtn setTitle:@"🔊" forState:UIControlStateNormal];
        [self.floatWindow addSubview:self.floaterBtn];
        self.floatWindow.rootViewController = [[UIViewController alloc] init];
        self.floatWindow.rootViewController.view.frame = self.floatWindow.bounds;
        self.floatWindow.rootViewController.view.hidden = NO;
    });
}

- (void)showFloater {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.floatWindow.hidden = NO;
        [self.floatWindow makeKeyWindow];
    });
}

- (void)hideFloater {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.floatWindow.hidden = YES;
    });
}
@end

#pragma mark - Darwin通知回调（独立三条指令）
static void cbStartRecord(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GestureRecorder sharedInstance] startRecord];
    });
}
static void cbStopRecord(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GestureRecorder sharedInstance] stopRecordAndSaveWithName:@"default"];
    });
}
static void cbPlay(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GestureRecorder sharedInstance] playGestureWithName:@"default"];
    });
}

#pragma mark - Tweak入口
__attribute__((constructor)) static void tweakMain() {
    CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();

    // 注册三个独立指令通知
    CFNotificationCenterAddObserver(nc, NULL, cbStartRecord, CFSTR("com.sunny.gesturecontrol.start"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(nc, NULL, cbStopRecord, CFSTR("com.sunny.gesturecontrol.stop"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(nc, NULL, cbPlay, CFSTR("com.sunny.gesturecontrol.play"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    loadGSSymbol();

    // 直接初始化悬浮球，无延时
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloaterManager sharedInstance] setup];
    });
}