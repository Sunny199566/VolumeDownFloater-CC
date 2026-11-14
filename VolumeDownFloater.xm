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
        if (!self.window) { self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 2000, 2000)]; }
        
        self.window.frame = CGRectMake(0, 0, 2000, 2000);
        self.window.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2.0, [UIScreen mainScreen].bounds.size.height / 2.0);
        
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.rootViewController = [FloaterViewController new];
        self.window.rootViewController.view.backgroundColor = [UIColor clearColor];
        
        self.window.hidden = NO; 

        self.hapticIntensity = 1.0;
        self.hapticDuration = 160.0;
        self.isCustomHaptic = NO;
        self.lastOrientationState = -1;

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        if (@available(iOS 13.0, *)) {
            if (CHHapticEngine.capabilitiesForHardware.supportsHaptics) {
                NSError *error = nil;
                self.hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
                [self.hapticEngine startAndReturnError:&error];
            }
        }

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
        self.timeBottomLabel.font = [UIFont boldSystemFontOfSize:10];
        self.timeBottomLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        self.timeBottomLabel.layer.cornerRadius = 5;
        self.timeBottomLabel.layer.masksToBounds = YES;
        self.timeBottomLabel.hidden = YES;
        self.timeBottomLabel.adjustsFontSizeToFitWidth = YES; 
        [self.mainContainer addSubview:self.timeBottomLabel];
        
        self.currentAngle = 0;

        self.orientationTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkAutoOrientation) userInfo:nil repeats:YES];

        [self updateUI];
    });
}

- (void)checkAutoOrientation {
    if (self.window.hidden) return;
    
    long long sysOrientation = 1; 
    
    Class FBSClass = NSClassFromString(@"FBSOrientationObserver");
    if (FBSClass) {
        id observer = [[FBSClass alloc] init];
        SEL sel = NSSelectorFromString(@"activeOrientation");
        if ([observer respondsToSelector:sel]) {
            sysOrientation = ((long long (*)(id, SEL))objc_msgSend)(observer, sel);
        }
    }
    
    if (sysOrientation == 1 || sysOrientation == 2) {
        SEL activeSel = NSSelectorFromString(@"activeInterfaceOrientation");
        if ([[UIApplication sharedApplication] respondsToSelector:activeSel]) {
            long long activeOri = ((long long (*)(id, SEL))objc_msgSend)([UIApplication sharedApplication], activeSel);
            if (activeOri == 3 || activeOri == 4) {
                sysOrientation = activeOri;
            }
        }
    }
    
    NSInteger currentState = (sysOrientation == 3 || sysOrientation == 4) ? 2 : 1;
    
    if (currentState != self.lastOrientationState) {
        self.lastOrientationState = currentState;
        
        CGFloat targetAngle = 0;
        if (currentState == 2) {
            targetAngle = M_PI_2;
        } else {
            targetAngle = 0;
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

- (void)updateUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *hapticStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_haptic.txt" encoding:NSUTF8StringEncoding error:nil];
        if (hapticStr.length > 0) self.hapticIntensity = [hapticStr floatValue];

        NSString *durStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_duration.txt" encoding:NSUTF8StringEncoding error:nil];
        if (durStr.length > 0) self.hapticDuration = [durStr floatValue];
        
        NSString *customStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_customhaptic.txt" encoding:NSUTF8StringEncoding error:nil];
        self.isCustomHaptic = [customStr isEqualToString:@"1"];

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
        [self.timeTimer invalidate];
        self.timeTimer = nil;
        if (showTime) {
            self.timeBottomLabel.hidden = NO;
            [self updateTimeText];
            self.timeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeText) userInfo:nil repeats:YES];
        } else {
            self.timeBottomLabel.hidden = YES;
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
    
    self.timeBottomLabel.text = [NSString stringWithFormat:@"%@ | %d%%", timeStr, batteryPercent];
}

- (void)setVisibility:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = !visible;
    });
}

- (void)handleTouchUpInside {
    if (self.window.hidden) return;
    
    if (@available(iOS 13.0, *)) {
        if (self.isCustomHaptic && CHHapticEngine.capabilitiesForHardware.supportsHaptics && self.hapticEngine) {
            CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:self.hapticIntensity];
            CHHapticEventParameter *sharpness = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.5];
            CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensity, sharpness] relativeTime:0 duration:(self.hapticDuration / 1000.0)];
            NSError *error = nil;
            CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
            if (!error) {
                id<CHHapticPatternPlayer> player = [self.hapticEngine createPlayerWithPattern:pattern error:&error];
                if (!error) [player startAtTime:0 error:&error];
            }
        } else {
            UIImpactFeedbackStyle style = UIImpactFeedbackStyleMedium;
            if (self.hapticIntensity < 0.3) style = UIImpactFeedbackStyleLight;
            else if (self.hapticIntensity > 0.7) style = UIImpactFeedbackStyleHeavy;
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
            [gen prepare];
            [gen impactOccurredWithIntensity:self.hapticIntensity];
            
            if (self.hapticIntensity >= 0.85) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIImpactFeedbackGenerator *gen2 = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
                    [gen2 impactOccurred];
                });
            }
        }
    }
    
    simulateVolumeDown();
}

// 终极拖拽 + 物理坐标系映射修正
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        [self.floatBtn cancelTrackingWithEvent:nil];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:pan.view];
        
        CGPoint realTranslation = translation;
        
        // 核心修复：如果在横屏状态，需要把手指的滑动方向映射到真实的系统坐标系里
        if (fabs(self.currentAngle) > 1.0) {
            if (self.currentAngle > 0) {
                // 顺时针 90 度
                realTranslation.x = translation.y;
                realTranslation.y = -translation.x;
            } else {
                // 逆时针 90 度
                realTranslation.x = -translation.y;
                realTranslation.y = translation.x;
            }
        }
        
        // 直接移动整个 Window
        CGPoint newWindowCenter = CGPointMake(self.window.center.x + realTranslation.x, self.window.center.y + realTranslation.y);
        
        BOOL isRotated = fabs(self.currentAngle) > 1.0;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat screenW = screenBounds.size.width;
        CGFloat screenH = screenBounds.size.height;
        
        CGFloat maxW = MAX(screenW, screenH);
        CGFloat minW = MIN(screenW, screenH);
        
        CGFloat visualW = isRotated ? maxW : minW;
        CGFloat visualH = isRotated ? minW : maxW;
        
        CGFloat ballW = isRotated ? self.mainContainer.bounds.size.height : self.mainContainer.bounds.size.width;
        CGFloat ballH = isRotated ? self.mainContainer.bounds.size.width : self.mainContainer.bounds.size.height;
        
        CGFloat realMinX = ballW / 2.0 + 10.0;
        CGFloat realMaxX = screenW - ballW / 2.0 - 10.0;
        CGFloat realMinY = ballH / 2.0 + 20.0;
        CGFloat realMaxY = screenH - ballH / 2.0 - 10.0;
        
        if (isRotated) {
            realMinX = ballW / 2.0 + 10.0;
            realMaxX = screenH - ballW / 2.0 - 10.0; 
            realMinY = ballH / 2.0 + 20.0;
            realMaxY = screenW - ballH / 2.0 - 10.0; 
        }
        
        newWindowCenter.x = MAX(realMinX, MIN(newWindowCenter.x, realMaxX));
        newWindowCenter.y = MAX(realMinY, MIN(newWindowCenter.y, realMaxY));
        
        self.window.center = newWindowCenter;
        
        [pan setTranslation:CGPointZero inView:pan.view];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        NSString *pxStr = [NSString stringWithFormat:@"%f", self.window.center.x];
        NSString *pyStr = [NSString stringWithFormat:@"%f", self.window.center.y];
        [pxStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posx.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [pyStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posy.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}
@end

static void showFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] setVisibility:YES];
}

static void hideFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] setVisibility:NO];
}

static void updateUI(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] updateUI];
}

__attribute__((constructor)) static void initFloater() {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, showFloater, CFSTR("com.yourname.volumedownfloater/show"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, hideFloater, CFSTR("com.yourname.volumedownfloater/hide"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, updateUI, CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [[FloaterManager sharedInstance] setup]; });
}