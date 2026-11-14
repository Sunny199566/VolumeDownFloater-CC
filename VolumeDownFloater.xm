#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
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
@property (nonatomic, assign) BOOL isHiddenState; 

// 自定义菜单相关
@property (strong, nonatomic) UIView *menuView;
@property (strong, nonatomic) NSTimer *timeTimer;
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
        self.isHiddenState = NO;

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

        [self updateUI];
    });
}

// 长按：弹出纯 UIView 的自绘菜单，绝对不拉伸
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self.floatBtn cancelTrackingWithEvent:nil];
        [self showCustomMenu];
    }
}

// 纯手工打造极简卡片菜单，绝对不跟随系统旋转错乱
- (void)showCustomMenu {
    if (self.menuView) { [self.menuView removeFromSuperview]; self.menuView = nil; }
    
    // 获取当前屏幕最大尺寸（横屏的宽/竖屏的高）
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat maxW = MAX(screenBounds.size.width, screenBounds.size.height);
    CGFloat maxH = MAX(screenBounds.size.width, screenBounds.size.height);
    
    // 绝对铺满整个屏幕的黑色遮罩
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, maxW, maxH)];
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    
    // 强制居中，无视任何旋转
    self.menuView.center = CGPointMake(self.window.bounds.size.width/2, self.window.bounds.size.height/2);
    if (fabs(self.currentAngle) > 1.0) {
        self.menuView.center = CGPointMake(self.window.bounds.size.width/2, self.window.bounds.size.height/2);
        // 横屏时，把遮罩旋转回去
        self.menuView.transform = CGAffineTransformMakeRotation(self.currentAngle);
    }
    
    // 纯代码创建卡片
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 150)];
    card.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; // 深灰纯色
    card.layer.cornerRadius = 12;
    card.center = CGPointMake(maxW/2, maxH/2); // 强制在屏幕物理正中间
    [self.menuView addSubview:card];
    
    // 选项1：旋转
    UIButton *rotateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rotateBtn.frame = CGRectMake(0, 0, 200, 50);
    [rotateBtn setTitle:@"旋转 90 度" forState:UIControlStateNormal];
    [rotateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rotateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [rotateBtn addTarget:self action:@selector(actionRotate) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:rotateBtn];
    
    UIView *line1 = [[UIView alloc] initWithFrame:CGRectMake(0, 50, 200, 1)];
    line1.backgroundColor = [UIColor darkGrayColor];
    [card addSubview:line1];
    
    // 选项2：隐藏/恢复
    UIButton *hideBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hideBtn.frame = CGRectMake(0, 51, 200, 50);
    [hideBtn setTitle:self.isHiddenState ? @"恢复显示" : @"临时隐身" forState:UIControlStateNormal];
    [hideBtn setTitleColor:self.isHiddenState ? [UIColor systemGreenColor] : [UIColor redColor] forState:UIControlStateNormal];
    hideBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [hideBtn addTarget:self action:@selector(actionHide) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:hideBtn];
    
    UIView *line2 = [[UIView alloc] initWithFrame:CGRectMake(0, 101, 200, 1)];
    line2.backgroundColor = [UIColor darkGrayColor];
    [card addSubview:line2];
    
    // 选项3：取消
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.frame = CGRectMake(0, 102, 200, 48);
    [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [cancelBtn addTarget:self action:@selector(actionCancel) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:cancelBtn];
    
    [self.window.rootViewController.view addSubview:self.menuView];
}

- (void)actionRotate {
    [self hideMenu];
    self.currentAngle += M_PI_2;
    if (self.currentAngle >= M_PI * 2) self.currentAngle = 0;
    [UIView animateWithDuration:0.3 animations:^{
        self.mainContainer.transform = CGAffineTransformMakeRotation(self.currentAngle);
    }];
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
}

- (void)actionHide {
    [self hideMenu];
    if (!self.isHiddenState) {
        self.isHiddenState = YES;
        [UIView animateWithDuration:0.3 animations:^{ self.floatBtn.alpha = 0.02; }];
    } else {
        self.isHiddenState = NO;
        NSString *alphaStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_alpha.txt" encoding:NSUTF8StringEncoding error:nil];
        CGFloat normalAlpha = (alphaStr.length > 0) ? [alphaStr floatValue] : 0.9;
        [UIView animateWithDuration:0.3 animations:^{ self.floatBtn.alpha = normalAlpha; }];
    }
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
}

- (void)actionCancel {
    [self hideMenu];
}

- (void)hideMenu {
    if (self.menuView) {
        [UIView animateWithDuration:0.2 animations:^{
            self.menuView.alpha = 0;
        } completion:^(BOOL finished) {
            [self.menuView removeFromSuperview];
            self.menuView = nil;
        }];
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
        CGPoint oldCenter = self.window.center;
        
        self.window.frame = CGRectMake(oldCenter.x - size/2.0, oldCenter.y - totalHeight/2.0, size, totalHeight);
        
        self.mainContainer.frame = CGRectMake(0, 0, size, totalHeight);
        self.floatBtn.frame = CGRectMake(0, 0, size, size);
        self.floatBtn.layer.cornerRadius = size / 2.0;
        if (!self.isHiddenState) self.floatBtn.alpha = alpha;
        
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
    [formatter setDateFormat:@"HH:mm:ss"];
    self.timeBottomLabel.text = [formatter stringFromDate:[NSDate date]];
}

- (void)setVisibility:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = !visible;
    });
}

- (void)handleTouchUpInside {
    if (self.window.hidden || self.isHiddenState || self.menuView) return; // 菜单开着不触发脚本
    
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

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        [self.floatBtn cancelTrackingWithEvent:nil];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:self.window];
        
        CGPoint newCenter = CGPointMake(self.window.center.x + translation.x, self.window.center.y + translation.y);
        
        BOOL isRotated = fabs(self.currentAngle) > 1.0;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat screenWidth = MAX(screenBounds.size.width, screenBounds.size.height);
        CGFloat screenHeight = MAX(screenBounds.size.width, screenBounds.size.height);
        
        CGFloat winW = self.window.bounds.size.width;
        CGFloat winH = self.window.bounds.size.height;
        CGFloat ballW = isRotated ? winH : winW;
        CGFloat ballH = isRotated ? winW : winH;
        
        CGFloat minX = ballW / 2.0 + 10.0;
        CGFloat maxX = screenWidth - ballW / 2.0 - 10.0;
        CGFloat minY = ballH / 2.0 + 20.0; 
        CGFloat maxY = screenHeight - ballH / 2.0 - 10.0;
        
        newCenter.x = MAX(minX, MIN(newCenter.x, maxX));
        newCenter.y = MAX(minY, MIN(newCenter.y, maxY));
        
        self.window.center = newCenter;
        [pan setTranslation:CGPointZero inView:self.window];
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