#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <CoreMotion/CoreMotion.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef CFTypeRef IOHIDEventSystemClientRef;
typedef IOHIDEventRef (*IOHIDEventCreateKeyboardEvent_t)(CFAllocatorRef, uint64_t, uint16_t, uint16_t, Boolean, uint32_t);
typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreate_t)(CFAllocatorRef);
typedef void (*IOHIDEventSystemClientDispatchEvent_t)(IOHIDEventSystemClientRef, IOHIDEventRef);

void simulateVolumeDown(void) {
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!handle) return;
    IOHIDEventCreateKeyboardEvent_t createEvent = (IOHIDEventCreateKeyboardEvent_t)dlsym(handle, "IOHIDEventCreateKeyboardEvent");
    IOHIDEventSystemClientCreate_t createClient = (IOHIDEventSystemClientCreate_t)dlsym(handle, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent_t dispatchEvent = (IOHIDEventSystemClientDispatchEvent_t)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
    if (createEvent && createClient && dispatchEvent) {
        IOHIDEventSystemClientRef client = createClient(kCFAllocatorDefault);
        if (client) {
            uint64_t timestamp = mach_absolute_time();
            IOHIDEventRef downEvent = createEvent(kCFAllocatorDefault, timestamp, 0x0C, 0xEA, true, 0);
            if (downEvent) { dispatchEvent(client, downEvent); CFRelease(downEvent); }
            usleep(50000);
            IOHIDEventRef upEvent = createEvent(kCFAllocatorDefault, timestamp, 0x0C, 0xEA, false, 0);
            if (upEvent) { dispatchEvent(client, upEvent); CFRelease(upEvent); }
            CFRelease(client);
        }
    }
    dlclose(handle);
}

@interface FloaterViewController : UIViewController
@end
@implementation FloaterViewController
- (BOOL)shouldAutorotate { return NO; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }
@end

@interface FloaterManager : NSObject
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIButton *floatBtn;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UIImpactFeedbackGenerator *hapticGenerator;
@property (strong, nonatomic) CMMotionManager *motionManager;

@property (nonatomic, assign) CGFloat currentAngle;
@property (nonatomic, assign) int stableCount;
@property (nonatomic, assign) CGFloat targetMotionAngle;

+ (instancetype)sharedInstance;
- (void)setup;
- (void)setVisibility:(BOOL)visible;
- (void)updateTitle;
- (void)handleDoubleTap;
@end

@implementation FloaterManager

+ (instancetype)sharedInstance {
    static FloaterManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[FloaterManager alloc] init]; });
    return instance;
}

- (void)setup {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) { windowScene = (UIWindowScene *)scene; break; }
        }
        
        CGFloat btnSize = 60.0;
        if (@available(iOS 13.0, *)) {
            if (windowScene) { self.window = [[UIWindow alloc] initWithWindowScene:windowScene]; }
        }
        if (!self.window) { self.window = [[UIWindow alloc] initWithFrame:CGRectMake(20, 150, btnSize, btnSize)]; }
        
        self.window.frame = CGRectMake(20, 150, btnSize, btnSize);
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        
        self.window.rootViewController = [FloaterViewController new];
        self.window.rootViewController.view.backgroundColor = [UIColor clearColor];
        self.window.hidden = YES;

        self.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [self.hapticGenerator prepare];

        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.frame = CGRectMake(0, 0, btnSize, btnSize);
        self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        self.floatBtn.layer.cornerRadius = btnSize / 2.0;
        self.floatBtn.layer.masksToBounds = YES;
        self.floatBtn.adjustsImageWhenHighlighted = NO;
        
        // 单击触发音量减
        [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
        // 拖拽移动位置
        [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        
        // 终极防线：双击手动旋转（防止有些游戏彻底屏蔽系统信号）
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap)];
        doubleTap.numberOfTapsRequired = 2;
        [self.floatBtn addGestureRecognizer:doubleTap];
        
        [self.window.rootViewController.view addSubview:self.floatBtn];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, btnSize, btnSize)];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        self.titleLabel.userInteractionEnabled = NO;
        [self.floatBtn addSubview:self.titleLabel];
        
        [self updateTitle];
        
        self.currentAngle = 0;
        self.targetMotionAngle = 0;
        self.stableCount = 0;
        
        // 开启物理辅助判定（防误触版）
        self.motionManager = [[CMMotionManager alloc] init];
        if (self.motionManager.isDeviceMotionAvailable) {
            [self.motionManager startDeviceMotionUpdates];
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkMotion) userInfo:nil repeats:YES];
        }
        
        // 定时读取 UI 界面宽高比（针对普通横屏视频和 App）
        [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkUIOrientation) userInfo:nil repeats:YES];
    });
}

// 双击手动旋转兜底
- (void)handleDoubleTap {
    self.currentAngle += M_PI_2;
    if (self.currentAngle >= M_PI * 2) {
        self.currentAngle = 0;
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        self.titleLabel.transform = CGAffineTransformMakeRotation(self.currentAngle);
    }];
    
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
}

// 第一重判定：读取前台界面的宽高比（无视重力，无视物理姿态）
- (void)checkUIOrientation {
    if (self.window.hidden) return;
    
    // 只有在这个模式下才生效（针对视频 App）
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *activeScene = (UIWindowScene *)scene;
            CGRect bounds = activeScene.coordinateSpace.bounds;
            
            if (bounds.size.width > bounds.size.height) {
                // 界面变横，覆盖物理状态
                if (fabs(self.currentAngle - (-M_PI_2)) > 0.1) {
                    self.currentAngle = -M_PI_2;
                    [UIView animateWithDuration:0.3 animations:^{
                        self.titleLabel.transform = CGAffineTransformMakeRotation(self.currentAngle);
                    }];
                }
                return;
            }
        }
    }
}

// 第二重判定：物理陀螺仪防误触（针对游戏强制横屏，且系统拒绝给宽高的情况）
- (void)checkMotion {
    if (self.window.hidden) return;
    
    CMDeviceMotion *motion = self.motionManager.deviceMotion;
    if (!motion) return;
    
    double x = motion.gravity.x;
    
    CGFloat motionAngle = 0;
    if (x > 0.8) {
        motionAngle = -M_PI_2;
    } else if (x < -0.8) {
        motionAngle = M_PI_2;
    } else {
        motionAngle = 0;
    }
    
    // 防抖缓冲：如果你没横彻底，或者手抖，这里不会触发
    if (fabs(motionAngle - self.targetMotionAngle) > 0.1) {
        self.targetMotionAngle = motionAngle;
        self.stableCount = 0;
    } else {
        self.stableCount++;
        // 必须稳定保持 0.5 秒 (0.1 * 5次)
        if (self.stableCount == 5) {
            if (fabs(self.currentAngle - self.targetMotionAngle) > 0.1) {
                self.currentAngle = self.targetMotionAngle;
                [UIView animateWithDuration:0.3 animations:^{
                    self.titleLabel.transform = CGAffineTransformMakeRotation(self.currentAngle);
                }];
            }
        }
    }
}

- (void)updateTitle {
    NSString *path = @"/var/mobile/Library/Preferences/com.yourname.volumedownfloater_title.txt";
    NSString *title = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!title || title.length == 0) {
        title = @"音量-";
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.titleLabel.text = title;
    });
}

- (void)setVisibility:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = !visible;
    });
}

- (void)btnTapped {
    if (self.window.hidden) return;
    [self.hapticGenerator impactOccurred];
    [self.hapticGenerator prepare]; 
    simulateVolumeDown();
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.window];
    CGPoint newCenter = CGPointMake(self.window.center.x + translation.x, self.window.center.y + translation.y);
    
    CGFloat btnRadius = self.window.bounds.size.width / 2.0;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;
    
    CGFloat padding = 10.0;
    CGFloat minX = btnRadius + padding;
    CGFloat maxX = screenWidth - btnRadius - padding;
    CGFloat minY = btnRadius + 50.0;
    CGFloat maxY = screenHeight - btnRadius - 30.0;
    
    newCenter.x = MAX(minX, MIN(newCenter.x, maxX));
    newCenter.y = MAX(minY, MIN(newCenter.y, maxY));
    
    self.window.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.window];
}
@end

static void showFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] setVisibility:YES];
}

static void hideFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] setVisibility:NO];
}

static void updateText(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] updateTitle];
}

__attribute__((constructor)) static void initFloater() {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, showFloater, CFSTR("com.yourname.volumedownfloater/show"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, hideFloater, CFSTR("com.yourname.volumedownfloater/hide"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, updateText, CFSTR("com.yourname.volumedownfloater/update_text"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [[FloaterManager sharedInstance] setup]; });
}