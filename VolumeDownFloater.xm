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

    // iOS17.0 固定偏移（适配你的iPhone15Pro 17.0）
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

#pragma mark - 悬浮球管理器（原有逻辑保留）
@interface FloaterManager : NSObject
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, strong) UIButton *floaterBtn;
+ (instancetype)sharedInstance;
- (void)setup;
- (void)showFloater;
- (void)hideFloater;
- (void)updateUI;
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
    CGRect screen = [UIScreen mainScreen].bounds;
    self.floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(screen.size.width - 70, screen.size.height/2, 60, 60)];
    self.floatWindow.windowLevel = UIWindowLevelAlert + 1000;
    self.floatWindow.hidden = YES;

    self.floaterBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floaterBtn.frame = self.floatWindow.bounds;
    self.floaterBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.85];
    self.floaterBtn.layer.cornerRadius = 30;
    [self.floaterBtn setTitle:@"🔊" forState:UIControlStateNormal];
    self.floatWindow addSubview:self.floaterBtn];
    self.floatWindow.rootViewController = [[UIViewController alloc] init];
}

- (void)showFloater {
    self.floatWindow.hidden = NO;
    [self.floatWindow makeKeyAndVisible];
}
- (void)hideFloater {
    self.floatWindow.hidden = YES;
}
- (void)updateUI {
    // 自定义UI刷新逻辑在这里
}
@end

#pragma mark - Darwin通知回调
static void showFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloaterManager sharedInstance] showFloater];
    });
}
static void hideFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloaterManager sharedInstance] hideFloater];
    });
}
static void updateUI(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloaterManager sharedInstance] updateUI];
    });
}

static void GestureNotifyCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *info = (__bridge NSDictionary *)userInfo;
        NSString *cmd = info[@"cmd"];
        if ([cmd isEqualToString:@"startRecord"]) {
            [[GestureRecorder sharedInstance] startRecord];
        } else if ([cmd isEqualToString:@"stopRecord"]) {
            [[GestureRecorder sharedInstance] stopRecordAndSaveWithName:@"default"];
        } else if ([cmd isEqualToString:@"play"]) {
            [[GestureRecorder sharedInstance] playGestureWithName:@"default"];
        }
    });
}

#pragma mark - Tweak Constructor
__attribute__((constructor)) static void initFloater() {
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, showFloater, CFSTR("com.yourname.volumedownfloater/show"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(center, NULL, hideFloater, CFSTR("com.yourname.volumedownfloater/hide"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(center, NULL, updateUI, CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, CFNotificationSuspensionBehaviorCoalesce);

    CFNotificationCenterAddObserver(center, NULL, GestureNotifyCallback, CFSTR("com.sunny.gesturecontrol"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    // ✅ 动态加载GraphicsServices符号
    loadGSSymbol();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FloaterManager sharedInstance] setup];
    });
}