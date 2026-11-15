#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>
#import <objc/message.h>

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

@interface PassThroughWindow : UIWindow
@end
@implementation PassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) return nil; 
    return hitView;
}
@end

@interface PassThroughView : UIView
@end
@implementation PassThroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return view == self ? nil : view;
}
@end

@interface FloaterViewController : UIViewController
@end
@implementation FloaterViewController
- (BOOL)shouldAutorotate { return NO; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }
- (void)loadView {
    self.view = [[PassThroughView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}
@end

@interface FloaterManager : NSObject
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIView *mainContainer; 
@property (strong, nonatomic) UIButton *floatBtn;
@property (strong, nonatomic) UILabel *titleLabel;       
@property (strong, nonatomic) UILabel *timeBottomLabel;  
@property (strong, nonatomic) UIImageView *bgImageView;
@property (nonatomic, assign) CGFloat currentAngle;
@property (nonatomic, assign) CGFloat lastSysAngle; 
@property (nonatomic, assign) CGPoint lastTouchPoint; 
@property (strong, nonatomic) CHHapticEngine *hapticEngine; 
@property (strong, nonatomic) NSTimer *timeTimer;
@property (strong, nonatomic) NSTimer *orientationTimer; 
@property (nonatomic, assign) BOOL isAutoShowing; // 标记是否由游戏自动唤起

+ (instancetype)sharedInstance;
- (void)setup;
- (void)setVisibility:(BOOL)visible;
- (void)updateUI;
- (CGSize)getPortraitScreenSize;
- (NSString *)getFrontmostBundleId;
@end

@implementation FloaterManager

+ (instancetype)sharedInstance {
    static FloaterManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[FloaterManager alloc] init]; });
    return instance;
}

- (CGSize)getPortraitScreenSize {
    CGSize size = [UIScreen mainScreen].bounds.size;
    return CGSizeMake(MIN(size.width, size.height), MAX(size.width, size.height));
}

// 安全的获取前台包名（防止安全模式）
- (NSString *)getFrontmostBundleId {
    @try {
        Class SBClass = NSClassFromString(@"SpringBoard");
        if (SBClass) {
            id sb = ((id (*)(id, SEL))objc_msgSend)(SBClass, NSSelectorFromString(@"sharedApplication"));
            if (sb && [sb respondsToSelector:NSSelectorFromString(@"_frontmostApplication")]) {
                id frontApp = ((id (*)(id, SEL))objc_msgSend)(sb, NSSelectorFromString(@"_frontmostApplication"));
                if (frontApp && [frontApp respondsToSelector:NSSelectorFromString(@"bundleIdentifier")]) {
                    return ((NSString *(*)(id, SEL))objc_msgSend)(frontApp, NSSelectorFromString(@"bundleIdentifier"));
                }
            }
        }
    } @catch (NSException *e) {}
    return nil;
}

- (void)setup {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) { windowScene = (UIWindowScene *)scene; break; }
        }
        
        if (@available(iOS 13.0, *)) {
            if (windowScene) { self.window = [[PassThroughWindow alloc] initWithWindowScene:windowScene]; }
        }
        if (!self.window) { self.window = [[PassThroughWindow alloc] initWithFrame:CGRectMake(0, 0, 2000, 2000)]; }
        
        self.window.frame = CGRectMake(0, 0, 2000, 2000);
        CGSize pSize = [self getPortraitScreenSize];
        self.window.center = CGPointMake(pSize.width / 2.0, pSize.height / 2.0);
        
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.rootViewController = [FloaterViewController new];
        
        NSString *showPath = @"/var/mobile/Library/Preferences/volumefloater_show.txt";
        NSString *showStr = [NSString stringWithContentsOfFile:showPath encoding:NSUTF8StringEncoding error:nil];
        self.window.hidden = ![showStr isEqualToString:@"1"];
        
        // 如果用户手动开着的，标记不是自动
        self.isAutoShowing = NO;

        self.lastSysAngle = 0;
        self.currentAngle = 0;

        if (@available(iOS 13.0, *)) {
            if (CHHapticEngine.capabilitiesForHardware.supportsHaptics) {
                NSError *error = nil;
                self.hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
                if (!error) {
                    __weak typeof(self) weakSelf = self;
                    self.hapticEngine.resetHandler = ^{ [weakSelf.hapticEngine startAndReturnError:nil]; };
                } else {
                    self.hapticEngine = nil;
                }
            }
        }

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        self.mainContainer = [[UIView alloc] init];
        self.mainContainer.backgroundColor = [UIColor clearColor];
        self.mainContainer.center = CGPointMake(1000, 1000);
        [self.window.rootViewController.view addSubview:self.mainContainer];

        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        self.floatBtn.layer.masksToBounds = YES;
        self.floatBtn.adjustsImageWhenHighlighted = NO;
        [self.floatBtn addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
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
        
        if (@available(iOS 9.0, *)) {
            self.timeBottomLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightBold];
        } else {
            self.timeBottomLabel.font = [UIFont boldSystemFontOfSize:10];
        }
        
        self.timeBottomLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        self.timeBottomLabel.layer.cornerRadius = 5;
        self.timeBottomLabel.layer.masksToBounds = YES;
        self.timeBottomLabel.hidden = YES;
        self.timeBottomLabel.adjustsFontSizeToFitWidth = YES; 
        [self.mainContainer addSubview:self.timeBottomLabel];
        
        // 定时器永不销毁，专门用来监听王者荣耀
        self.orientationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkAutoOrientation) userInfo:nil repeats:YES];
        self.orientationTimer.tolerance = 0.2;
        
        [self updateUI];
    });
}

- (void)checkAutoOrientation {
    // 【智能检测】只在进出游戏时干预
    NSString *frontBundleId = [self getFrontmostBundleId];
    
    if (frontBundleId) {
        if ([frontBundleId isEqualToString:@"com.tencent.smfm"]) {
            // 进了王者，且球没显示 -> 强制显示，标记为自动
            if (self.window.hidden) {
                self.isAutoShowing = YES;
                dispatch_async(dispatch_get_main_queue(), ^{ [self setVisibility:YES]; });
            }
        } else {
            // 不在王者，且球显示着，并且是之前自动打开的 -> 自动关闭
            if (!self.window.hidden && self.isAutoShowing) {
                self.isAutoShowing = NO;
                dispatch_async(dispatch_get_main_queue(), ^{ [self setVisibility:NO]; });
            }
        }
    }

    if (self.window.hidden) return;

    long long sysOrientation = 1; 
    
    static id cachedObserver = nil;
    static SEL cachedActiveOrientation = nil;
    static SEL cachedActiveInterfaceOrientation = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class FBSClass = NSClassFromString(@"FBSOrientationObserver");
        if (FBSClass) {
            cachedObserver = [[FBSClass alloc] init];
            cachedActiveOrientation = NSSelectorFromString(@"activeOrientation");
            cachedActiveInterfaceOrientation = NSSelectorFromString(@"activeInterfaceOrientation");
        }
    });
    
    if (cachedObserver && cachedActiveOrientation) {
        if ([cachedObserver respondsToSelector:cachedActiveOrientation]) {
            sysOrientation = ((long long (*)(id, SEL))objc_msgSend)(cachedObserver, cachedActiveOrientation);
        }
    }
    
    if (sysOrientation == 1 || sysOrientation == 2) {
        if (cachedActiveInterfaceOrientation && [[UIApplication sharedApplication] respondsToSelector:cachedActiveInterfaceOrientation]) {
            long long activeOri = ((long long (*)(id, SEL))objc_msgSend)([UIApplication sharedApplication], cachedActiveInterfaceOrientation);
            if (activeOri >= 1 && activeOri <= 4) {
                sysOrientation = activeOri;
            }
        }
    }
    
    CGFloat targetSysAngle = 0;
    if (sysOrientation == 3) {
        targetSysAngle = M_PI_2; 
    } else if (sysOrientation == 4) {
        targetSysAngle = -M_PI_2;
    } else if (sysOrientation == 2) {
        targetSysAngle = M_PI;
    } else {
        targetSysAngle = 0;
    }
    
    if (fabs(targetSysAngle - self.lastSysAngle) > 0.1) {
        self.lastSysAngle = targetSysAngle;
        self.currentAngle = targetSysAngle;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.mainContainer.transform = CGAffineTransformMakeRotation(self.currentAngle);
        } completion:^(BOOL finished) {
            [self clampCurrentPosition];
        }];
    }
}

- (void)clampCurrentPosition {
    CGSize screenSize = [self getPortraitScreenSize]; 
    
    BOOL isRotated = fabs(self.currentAngle) > 0.1;
    CGFloat ballW = isRotated ? self.mainContainer.bounds.size.height : self.mainContainer.bounds.size.width;
    CGFloat ballH = isRotated ? self.mainContainer.bounds.size.width : self.mainContainer.bounds.size.height;
    
    CGFloat centerX = 1000, centerY = 1000, margin = 5.0;
    
    CGFloat minX = centerX - screenSize.width / 2.0 + ballW / 2.0 + margin;
    CGFloat maxX = centerX + screenSize.width / 2.0 - ballW / 2.0 - margin;
    CGFloat minY = centerY - screenSize.height / 2.0 + ballH / 2.0 + margin;
    CGFloat maxY = centerY + screenSize.height / 2.0 - ballH / 2.0 - margin;
    
    CGPoint c = self.mainContainer.center;
    c.x = MAX(minX, MIN(c.x, maxX));
    c.y = MAX(minY, MIN(c.y, maxY));
    self.mainContainer.center = c;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self.floatBtn cancelTrackingWithEvent:nil];
        self.currentAngle += M_PI_2;
        if (self.currentAngle >= M_PI * 2) self.currentAngle -= M_PI * 2;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.mainContainer.transform = CGAffineTransformMakeRotation(self.currentAngle);
        } completion:^(BOOL finished) {
            [self clampCurrentPosition];
        }];
        
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
    }
}

- (void)updateUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *sizeStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_size.txt" encoding:NSUTF8StringEncoding error:nil];
        CGFloat size = (sizeStr.length > 0) ? [sizeStr floatValue] : 60.0;
        NSString *alphaStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_alpha.txt" encoding:NSUTF8StringEncoding error:nil];
        CGFloat alpha = (alphaStr.length > 0) ? [alphaStr floatValue] : 0.9;
        NSString *colorStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_color.txt" encoding:NSUTF8StringEncoding error:nil];
        if (colorStr.length == 0) colorStr = @"red";

        CGFloat totalHeight = size + 25;
        self.mainContainer.bounds = CGRectMake(0, 0, size, totalHeight);
        self.floatBtn.frame = CGRectMake(0, 0, size, size);
        self.floatBtn.layer.cornerRadius = size / 2.0;
        self.floatBtn.alpha = alpha;
        
        self.titleLabel.frame = self.floatBtn.bounds;
        self.titleLabel.font = [UIFont systemFontOfSize:size * 0.25 weight:UIFontWeightMedium];
        self.bgImageView.frame = self.floatBtn.bounds;
        self.bgImageView.layer.cornerRadius = size / 2.0;
        self.timeBottomLabel.frame = CGRectMake(0, size + 2, size, 20);

        UIColor *bgColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        if ([colorStr isEqualToString:@"blue"]) bgColor = [UIColor systemBlueColor];
        else if ([colorStr isEqualToString:@"green"]) bgColor = [UIColor systemGreenColor];
        else if ([colorStr isEqualToString:@"black"]) bgColor = [UIColor blackColor];
        else if ([colorStr isEqualToString:@"clear"]) bgColor = [UIColor clearColor];

        NSString *imgPath = @"/var/mobile/Library/Preferences/volumefloater_bg.png";
        if ([[NSFileManager defaultManager] fileExistsAtPath:imgPath]) {
            self.bgImageView.image = [UIImage imageWithContentsOfFile:imgPath];
            self.bgImageView.hidden = NO;
            self.floatBtn.backgroundColor = [UIColor clearColor];
        } else {
            self.bgImageView.hidden = YES;
            self.floatBtn.backgroundColor = bgColor;
        }
        
        NSString *timeStatus = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_time.txt" encoding:NSUTF8StringEncoding error:nil];
        BOOL showTime = [timeStatus isEqualToString:@"1"];
        
        if (showTime) {
            self.timeBottomLabel.hidden = NO;
            [self updateTimeText];
            if (!self.window.hidden && !self.timeTimer) {
                self.timeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeText) userInfo:nil repeats:YES];
                self.timeTimer.tolerance = 0.5;
            }
        } else {
            self.timeBottomLabel.hidden = YES;
            [self.timeTimer invalidate];
            self.timeTimer = nil;
        }
        
        NSString *title = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_title.txt" encoding:NSUTF8StringEncoding error:nil];
        if (!title || title.length == 0) title = @"音量-";
        self.titleLabel.text = title;
        self.titleLabel.hidden = NO;
    });
}

- (void)updateTimeText {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm"];
    NSString *timeStr = [formatter stringFromDate:[NSDate date]];
    float batteryLevel = [[UIDevice currentDevice] batteryLevel];
    int batteryPercent = (int)(batteryLevel * 100);
    if (batteryPercent < 0) batteryPercent = 0;
    
    self.timeBottomLabel.text = [NSString stringWithFormat:@"%@ • %d%%", timeStr, batteryPercent];
}

- (void)setVisibility:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = !visible;
        
        // 如果是手动通过控制台或通知打开的，标记为手动
        NSString *showPath = @"/var/mobile/Library/Preferences/volumefloater_show.txt";
        [visible ? @"1" : @"0" writeToFile:showPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        if (visible) {
            if (!self.orientationTimer) {
                self.orientationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkAutoOrientation) userInfo:nil repeats:YES];
                self.orientationTimer.tolerance = 0.2;
            }
            [self updateUI];
        } else {
            [self.timeTimer invalidate];
            self.timeTimer = nil;
        }
    });
}

- (void)handleTouchUpInside {
    if (self.window.hidden) return;
    
    NSString *customStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_customhaptic.txt" encoding:NSUTF8StringEncoding error:nil];
    BOOL isCustom = [customStr isEqualToString:@"1"];
    
    NSString *hapticStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_haptic.txt" encoding:NSUTF8StringEncoding error:nil];
    float intensity = hapticStr.length > 0 ? [hapticStr floatValue] : 1.0;
    
    NSString *durStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_duration.txt" encoding:NSUTF8StringEncoding error:nil];
    float duration = durStr.length > 0 ? [durStr floatValue] : 160.0;
    
    if (@available(iOS 13.0, *)) {
        if (self.hapticEngine) {
            CGFloat targetSec = isCustom ? (duration / 1000.0) : 0.6;
            if (targetSec < 0.1) targetSec = 0.5;
            if (targetSec > 1.5) targetSec = 1.5; 
            
            NSError *error = nil;
            CHHapticEventParameter *intensityParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity];
            CHHapticEventParameter *sharpnessParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.2];
            
            CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensityParam, sharpnessParam] relativeTime:0 duration:targetSec];
            CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
            
            if (!error) {
                [self.hapticEngine startAndReturnError:nil]; 
                id<CHHapticPatternPlayer> player = [self.hapticEngine createPlayerWithPattern:pattern error:&error];
                if (!error) {
                    [player startAtTime:0 error:&error];
                }
            }
        } else {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [gen prepare];
            [gen impactOccurred];
        }
    }
    
    simulateVolumeDown();
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        [self.floatBtn cancelTrackingWithEvent:nil];
        self.lastTouchPoint = [pan locationInView:self.window];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint currentPoint = [pan locationInView:self.window];
        CGPoint delta = CGPointMake(currentPoint.x - self.lastTouchPoint.x, currentPoint.y - self.lastTouchPoint.y);
        self.lastTouchPoint = currentPoint;
        
        CGPoint newCenter = CGPointMake(self.mainContainer.center.x + delta.x, self.mainContainer.center.y + delta.y);
        
        BOOL isRotated = fabs(self.currentAngle) > 0.1;
        CGSize screenSize = [self getPortraitScreenSize];
        
        CGFloat ballW = isRotated ? self.mainContainer.bounds.size.height : self.mainContainer.bounds.size.width;
        CGFloat ballH = isRotated ? self.mainContainer.bounds.size.width : self.mainContainer.bounds.size.height;
        
        CGFloat centerX = 1000, centerY = 1000, margin = 5.0;
        
        CGFloat minX = centerX - screenSize.width / 2.0 + ballW / 2.0 + margin;
        CGFloat maxX = centerX + screenSize.width / 2.0 - ballW / 2.0 - margin;
        CGFloat minY = centerY - screenSize.height / 2.0 + ballH / 2.0 + margin;
        CGFloat maxY = centerY + screenSize.height / 2.0 - ballH / 2.0 - margin;
        
        newCenter.x = MAX(minX, MIN(newCenter.x, maxX));
        newCenter.y = MAX(minY, MIN(newCenter.y, maxY));
        
        self.mainContainer.center = newCenter;
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        NSString *pxStr = [NSString stringWithFormat:@"%f", self.mainContainer.center.x];
        NSString *pyStr = [NSString stringWithFormat:@"%f", self.mainContainer.center.y];
        [pxStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posx.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [pyStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posy.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}
@end

static void showFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void hideFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void updateUI(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

__attribute__((constructor)) static void initFloater() {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)showFloater, CFSTR("com.yourname.volumedownfloater/show"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)hideFloater, CFSTR("com.yourname.volumedownfloater/hide"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)updateUI, CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [[FloaterManager sharedInstance] setup]; });
}

static void showFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // 收到通知强制显示，并取消自动标记（因为是手动触发的）
    [FloaterManager sharedInstance].isAutoShowing = NO;
    [[FloaterManager sharedInstance] setVisibility:YES];
}

static void hideFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [FloaterManager sharedInstance].isAutoShowing = NO;
    [[FloaterManager sharedInstance] setVisibility:NO];
}

static void updateUI(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] updateUI];
}