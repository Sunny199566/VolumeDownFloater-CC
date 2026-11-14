#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

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
@property (strong, nonatomic) UIView *mainContainer; // 整体旋转容器
@property (strong, nonatomic) UIButton *floatBtn;
@property (strong, nonatomic) UILabel *titleLabel;       
@property (strong, nonatomic) UILabel *timeBottomLabel;  
@property (strong, nonatomic) UIImageView *bgImageView;
@property (strong, nonatomic) UIImpactFeedbackGenerator *hapticGenerator;
@property (nonatomic, assign) CGFloat currentAngle;
@property (nonatomic, assign) float hapticIntensity; 
@property (strong, nonatomic) NSTimer *timeTimer;

+ (instancetype)sharedInstance;
- (void)setup;
- (void)setVisibility:(BOOL)visible;
- (void)updateUI;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
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
        CGFloat totalHeight = 85.0;
        
        if (@available(iOS 13.0, *)) {
            if (windowScene) { self.window = [[UIWindow alloc] initWithWindowScene:windowScene]; }
        }
        if (!self.window) { self.window = [[UIWindow alloc] initWithFrame:CGRectMake(20, 150, btnSize, totalHeight)]; }
        
        self.window.frame = CGRectMake(20, 150, btnSize, totalHeight);
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        
        self.window.rootViewController = [FloaterViewController new];
        self.window.rootViewController.view.backgroundColor = [UIColor clearColor];
        self.window.hidden = YES;

        self.hapticIntensity = 0.8;
        self.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [self.hapticGenerator prepare];

        // 整体旋转容器
        self.mainContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, btnSize, totalHeight)];
        self.mainContainer.backgroundColor = [UIColor clearColor];
        [self.window.rootViewController.view addSubview:self.mainContainer];

        // 球体
        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.frame = CGRectMake(0, 0, btnSize, btnSize);
        self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        self.floatBtn.layer.cornerRadius = btnSize / 2.0;
        self.floatBtn.layer.masksToBounds = YES;
        self.floatBtn.adjustsImageWhenHighlighted = NO;
        
        [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.5;
        [self.floatBtn addGestureRecognizer:longPress];
        
        [self.mainContainer addSubview:self.floatBtn];
        
        self.bgImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, btnSize, btnSize)];
        self.bgImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.bgImageView.layer.cornerRadius = btnSize / 2.0;
        self.bgImageView.layer.masksToBounds = YES;
        self.bgImageView.userInteractionEnabled = NO;
        [self.floatBtn addSubview:self.bgImageView];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, btnSize, btnSize)];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        self.titleLabel.userInteractionEnabled = NO;
        [self.floatBtn addSubview:self.titleLabel];
        
        // 底部时间
        self.timeBottomLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, btnSize + 2, btnSize, 20)];
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
        [self updateUI];
    });
}

- (void)updateUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. 震动强度
        NSString *hapticPath = @"/var/mobile/Library/Preferences/volumefloater_haptic.txt";
        NSString *hapticStr = [NSString stringWithContentsOfFile:hapticPath encoding:NSUTF8StringEncoding error:nil];
        if (hapticStr && hapticStr.length > 0) {
            self.hapticIntensity = [hapticStr floatValue];
        }

        // 2. 图片
        NSString *imgPath = @"/var/mobile/Library/Preferences/volumefloater_bg.png";
        if ([[NSFileManager defaultManager] fileExistsAtPath:imgPath]) {
            self.bgImageView.image = [UIImage imageWithContentsOfFile:imgPath];
            self.bgImageView.hidden = NO;
            self.floatBtn.backgroundColor = [UIColor clearColor];
        } else {
            self.bgImageView.hidden = YES;
            self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        }
        
        // 3. 时间
        NSString *timePath = @"/var/mobile/Library/Preferences/volumefloater_time.txt";
        NSString *timeStatus = [NSString stringWithContentsOfFile:timePath encoding:NSUTF8StringEncoding error:nil];
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
        
        // 4. 文字
        NSString *titlePath = @"/var/mobile/Library/Preferences/volumefloater_title.txt";
        NSString *title = [NSString stringWithContentsOfFile:titlePath encoding:NSUTF8StringEncoding error:nil];
        if (!title || title.length == 0) {
            title = @"音量-";
        }
        self.titleLabel.text = title;
        self.titleLabel.hidden = NO;
    });
}

- (void)updateTimeText {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    self.timeBottomLabel.text = [formatter stringFromDate:[NSDate date]];
}

// 长按旋转（整体旋转，绝不错位）
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.currentAngle += M_PI_2;
        if (self.currentAngle >= M_PI * 2) {
            self.currentAngle = 0;
        }
        
        [UIView animateWithDuration:0.3 animations:^{
            self.mainContainer.transform = CGAffineTransformMakeRotation(self.currentAngle);
        }];
        
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
    }
}

- (void)setVisibility:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = !visible;
    });
}

// 单击触发自定义强度震动
- (void)btnTapped {
    if (self.window.hidden) return;
    
    if (@available(iOS 13.0, *)) {
        [self.hapticGenerator impactOccurredWithIntensity:self.hapticIntensity];
    } else {
        [self.hapticGenerator impactOccurred];
    }
    [self.hapticGenerator prepare]; 
    simulateVolumeDown();
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.window];
    CGPoint newCenter = CGPointMake(self.window.center.x + translation.x, self.window.center.y + translation.y);
    
    CGFloat windowWidth = self.window.bounds.size.width;
    CGFloat windowHeight = self.window.bounds.size.height;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;
    
    BOOL isRotated = fabs(self.currentAngle) > 1.0;
    CGFloat effWidth = isRotated ? windowHeight : windowWidth;
    CGFloat effHeight = isRotated ? windowWidth : windowHeight;
    
    CGFloat minX = effWidth / 2.0 + 10.0;
    CGFloat maxX = screenWidth - effWidth / 2.0 - 10.0;
    CGFloat minY = effHeight / 2.0 + 20.0; 
    CGFloat maxY = screenHeight - effHeight / 2.0 - 10.0;
    
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

static void updateUI(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] updateUI];
}

__attribute__((constructor)) static void initFloater() {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, showFloater, CFSTR("com.yourname.volumedownfloater/show"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, hideFloater, CFSTR("com.yourname.volumedownfloater/hide"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, updateUI, CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [[FloaterManager sharedInstance] setup]; });
}