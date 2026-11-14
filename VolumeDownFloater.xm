#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreHaptics/CoreHaptics.h>

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
@property (strong, nonatomic) UIView *mainContainer; 
@property (strong, nonatomic) UIButton *floatBtn;
@property (strong, nonatomic) UILabel *titleLabel;       
@property (strong, nonatomic) UILabel *timeBottomLabel;  
@property (strong, nonatomic) UIImageView *bgImageView;
@property (nonatomic, assign) CGFloat currentAngle;
@property (nonatomic, assign) float hapticIntensity; 
@property (nonatomic, assign) float hapticDuration;
@property (nonatomic, assign) BOOL isCustomHaptic;

// 记录上一次的真实界面方向
@property (nonatomic, assign) NSInteger lastOrientationState;

@property (strong, nonatomic) NSTimer *timeTimer;
@property (strong, nonatomic) NSTimer *orientationTimer; 
@property (strong, nonatomic) CHHapticEngine *hapticEngine;

+ (instancetype)sharedInstance;
- (void)setup;
- (void)setVisibility:(BOOL)visible;
- (void)updateUI;
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
        
        if (@available(iOS 13.0, *)) {
            if (windowScene) { self.window = [[UIWindow alloc] initWithWindowScene:windowScene]; }
        }
        if (!self.window) { self.window = [[UIWindow alloc] initWithFrame:CGRectMake(20, 150, 60, 85)]; }
        
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.rootViewController = [FloaterViewController new];
        self.window.rootViewController.view.backgroundColor = [UIColor clearColor];
        self.window.hidden = YES;

        self.hapticIntensity = 1.0;
        self.hapticDuration = 160.0;
        self.isCustomHaptic = NO;
        self.lastOrientationState = -1; // 初始未知状态

        if (@available(iOS 13.0, *)) {
            if (CHHapticEngine.capabilitiesForHardware.supportsHaptics) {
                NSError *error = nil;
                self.hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
                [self.hapticEngine startAndReturnError:&error];
            }
        }

        self.mainContainer = [[UIView alloc] init];
        self.mainContainer.backgroundColor = [UIColor clearColor];
        [self.window.rootViewController.view addSubview:self.mainContainer];

        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        self.floatBtn.layer.masksToBounds = YES;
        self.floatBtn.adjustsImageWhenHighlighted = NO;
        
        [self.floatBtn addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *panGesture [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        panGesture.cancelsTouchesInView = NO; 
        [self.floatBtn addGestureRecognizer:panGesture];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.4; 
        longPress.allowableMovement = 15; 
        [self.floatBtn addGestureRecognizer:longPress];
        
        [self.mainContainer addSubview:self.floatBtn];
        
        self.bgImageView = [[UIImageView alloc] init];
        self.bgImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.bgImageView.layer.masksToBounds = YES;
        self.bgImageView.userInteractionEnabled = NO;
        [self.floatBtn addSubview:self.bgImageView];
        
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.userInteractionEnabled = NO;
        [self.floatBtn addSubview:self.titleLabel];
        
        self.timeBottomLabel = [[UILabel alloc] init];
        self.timeBottomLabel.textColor = [UIColor whiteColor];
        self.timeBottomLabel.textAlignment = NSTextAlignmentCenter;
        self.timeBottomLabel.font = [UIFont boldSystemFontOfSize:12];
        self.timeBottomLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        self.timeBottomLabel.layer.cornerRadius = 5;
        self.timeBottomLabel.layer.masksToBounds = YES;
        self.timeBottomLabel.hidden = YES;
        self.timeBottomLabel.adjustsFontSizeToFitWidth = YES;
        [self.mainContainer addSubview:self.timeBottomLabel];
        
        self.currentAngle = 0;
        
        CGFloat px = 20, py = 150;
        NSString *pxStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_posx.txt" encoding:NSUTF8StringEncoding error:nil];
        NSString *pyStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_posy.txt" encoding:NSUTF8StringEncoding error:nil];
        if (pxStr.length > 0 && pyStr.length > 0) {
            CGFloat savedX = [pxStr floatValue];
            CGFloat savedY = [pyStr floatValue];
            if (savedX > 0 && savedX < [UIScreen mainScreen].bounds.size.width && savedY > 0 && savedY < [UIScreen mainScreen].bounds.size.height) {
                px = savedX;
                py = savedY;
            }
        }
        self.window.center = CGPointMake(px, py);

        self.orientationTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkAutoOrientation) userInfo:nil repeats:YES];

        [self updateUI];
    });
}

- (void)checkAutoOrientation {
    if (self.window.hidden) return;
    
    long long sysOrientation = 1; 
    
    // 安全读取 FBS 底层方向
    Class FBSClass = NSClassFromString(@"FBSOrientationObserver");
    if (FBSClass) {
        id observer = [[FBSClass alloc] init];
        SEL sel = NSSelectorFromString(@"activeOrientation");
        if ([observer respondsToSelector:sel]) {
            sysOrientation = ((long long (*)(id, SEL))objc_msgSend)(observer, sel);
        }
    }
    
    // 尝试直接向 UIApplication 索要真实界面方向 (上帝视角)
    if (sysOrientation == 1 || sysOrientation == 2) {
        SEL activeSel = NSSelectorFromString(@"activeInterfaceOrientation");
        if ([[UIApplication sharedApplication] respondsToSelector:activeSel]) {
            long long activeOri = ((long long (*)(id, SEL))objc_msgSend)([UIApplication sharedApplication], activeSel);
            if (activeOri == 3 || activeOri == 4) {
                sysOrientation = activeOri;
            }
        }
    }
    
    // 判断当前是横还是竖 (3和4是横屏)
    NSInteger currentState = (sysOrientation == 3 || sysOrientation == 4) ? 2 : 1;
    
    // 只有当状态发生切换时，才执行旋转
    if (currentState != self.lastOrientationState) {
        self.lastOrientationState = currentState;
        
        CGFloat targetAngle = 0;
        if (currentState == 2) {
            targetAngle = M_PI_2; // 进横屏，自动顺时针90度
        } else {
            targetAngle = 0; // 回竖屏，自动回正
        }
        
        self.currentAngle = targetAngle;
        [UIView animateWithDuration:0.3 animations:^{
            self.mainContainer.transform = CGAffineTransformMakeRotation(self.currentAngle);
        }];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self.floatBtn cancelTrackingWithEvent:nil];
        
        self.currentAngle += M_PI_2;
        if (self.currentAngle >= M_PI * 2) self.currentAngle = 0;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.mainContainer.transform = CGAffineTransformMakeRotation(self.currentAngle);
        }];
        
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
    }
}