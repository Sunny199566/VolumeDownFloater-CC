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
@property (strong, nonatomic) UIView *mainContainer; 
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
        
        if (@available(iOS 13.0, *)) {
            if (windowScene) { self.window = [[UIWindow alloc] initWithWindowScene:windowScene]; }
        }
        if (!self.window) { self.window = [[UIWindow alloc] initWithFrame:CGRectMake(20, 150, 60, 85)]; }
        
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.rootViewController = [FloaterViewController new];
        self.window.rootViewController.view.backgroundColor = [UIColor clearColor];
        self.window.hidden = YES;

        self.hapticIntensity = 0.8;
        self.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [self.hapticGenerator prepare];

        self.mainContainer = [[UIView alloc] init];
        self.mainContainer.backgroundColor = [UIColor clearColor];
        [self.window.rootViewController.view addSubview:self.mainContainer];

        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        self.floatBtn.layer.masksToBounds = YES;
        self.floatBtn.adjustsImageWhenHighlighted = NO;
        
        [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.5;
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
        
        // 初始化位置（读取记忆）
        NSString *pxStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_posx.txt" encoding:NSUTF8StringEncoding error:nil];
        NSString *pyStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_posy.txt" encoding:NSUTF8StringEncoding error:nil];
        CGFloat px = (pxStr && pxStr.length > 0) ? [pxStr floatValue] : 20;
        CGFloat py = (pyStr && pyStr.length > 0) ? [pyStr floatValue] : 150;
        self.window.center = CGPointMake(px, py);

        [self updateUI];
    });
}

- (void)updateUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. 读取各项配置
        NSString *hapticStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_haptic.txt" encoding:NSUTF8StringEncoding error:nil];
        if (hapticStr.length > 0) self.hapticIntensity = [hapticStr floatValue];

        NSString *sizeStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_size.txt" encoding:NSUTF8StringEncoding error:nil];
        CGFloat size = (sizeStr.length > 0) ? [sizeStr floatValue] : 60.0;

        NSString *alphaStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_alpha.txt" encoding:NSUTF8StringEncoding error:nil];
        CGFloat alpha = (alphaStr.length > 0) ? [alphaStr floatValue] : 0.9;

        NSString *colorStr = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_color.txt" encoding:NSUTF8StringEncoding error:nil];
        if (colorStr.length == 0) colorStr = @"red";

        // 2. 应用大小与透明度
        self.mainContainer.frame = CGRectMake(0, 0, size, size + 25);
        self.floatBtn.frame = CGRectMake(0, 0, size, size);
        self.floatBtn.layer.cornerRadius = size / 2.0;
        self.floatBtn.alpha = alpha;
        
        self.titleLabel.frame = self.floatBtn.bounds;
        self.titleLabel.font = [UIFont systemFontOfSize:size * 0.25 weight:UIFontWeightMedium];
        
        self.bgImageView.frame = self.floatBtn.bounds;
        self.bgImageView.layer.cornerRadius = size / 2.0;
        
        self.timeBottomLabel.frame = CGRectMake(0, size + 2, size, 20);

        // 3. 应用颜色
        UIColor *bgColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        if ([colorStr isEqualToString:@"blue"]) bgColor = [UIColor systemBlueColor];
        else if ([colorStr isEqualToString:@"green"]) bgColor = [UIColor systemGreenColor];
        else if ([colorStr isEqualToString:@"black"]) bgColor = [UIColor blackColor];
        else if ([colorStr isEqualToString:@"clear"]) bgColor = [UIColor clearColor];

        // 4. 应用图片
        NSString *imgPath = @"/var/mobile/Library/Preferences/volumefloater_bg.png";
        if ([[NSFileManager defaultManager] fileExistsAtPath:imgPath]) {
            self.bgImageView.image = [UIImage imageWithContentsOfFile:imgPath];
            self.bgImageView.hidden = NO;
            self.floatBtn.backgroundColor = [UIColor clearColor];
        } else {
            self.bgImageView.hidden = YES;
            self.floatBtn.backgroundColor = bgColor;
        }
        
        // 5. 时间
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
        
        // 6. 文字
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

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.currentAngle += M_PI_2;
        if (self.currentAngle >= M_PI * 2) self.currentAngle = 0;
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

// 拖动逻辑（带磁吸和记忆）
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

    // 核心新增：松手时磁吸边缘并保存坐标
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat targetX = (self.window.center.x < screenWidth / 2.0) ? minX : maxX;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.window.center = CGPointMake(targetX, self.window.center.y);
        } completion:^(BOOL finished) {
            // 记忆位置
            NSString *pxStr = [NSString stringWithFormat:@"%f", self.window.center.x];
            NSString *pyStr = [NSString stringWithFormat:@"%f", self.window.center.y];
            [pxStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posx.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [pyStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posy.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }];
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