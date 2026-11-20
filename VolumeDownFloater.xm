#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ================= IOKit 类型与常量定义 =================
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef CFTypeRef IOHIDEventSystemClientRef;
typedef int32_t IOFixed;

typedef IOHIDEventRef (*IOHIDEventCreateKeyboardEvent_t)(CFAllocatorRef, uint64_t, uint16_t, uint16_t, Boolean, uint32_t);
typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreate_t)(CFAllocatorRef);
typedef void (*IOHIDEventSystemClientDispatchEvent_t)(IOHIDEventSystemClientRef, IOHIDEventRef);

typedef void (*IOHIDEventSystemClientEventCallback_t)(void *target, void *refcon, IOHIDEventSystemClientRef client, IOHIDEventRef event);
typedef void (*IOHIDEventSystemClientRegisterEventCallback_t)(IOHIDEventSystemClientRef, IOHIDEventSystemClientEventCallback_t, void *, void *);

typedef void (*IOHIDEventSystemClientScheduleWithRunLoop_t)(IOHIDEventSystemClientRef, CFRunLoopRef, CFStringRef);
typedef void (*IOHIDEventSystemClientUnscheduleFromRunLoop_t)(IOHIDEventSystemClientRef, CFRunLoopRef, CFStringRef);

// 使用更稳定的底层事件创建函数
typedef IOHIDEventRef (*IOHIDEventCreateDigitizerEvent_t)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, int32_t, int32_t, int32_t, int32_t, int32_t, Boolean, Boolean, Boolean);

typedef int (*IOHIDEventGetType_t)(IOHIDEventRef);
typedef int64_t (*IOHIDEventGetIntegerValue_t)(IOHIDEventRef, uint32_t);
typedef double (*IOHIDEventGetFloatValue_t)(IOHIDEventRef, uint32_t);
typedef void (*IOHIDEventSetIntegerValue_t)(IOHIDEventRef, uint32_t, int64_t);

#define kIOHIDEventTypeDigitizer 11
#define kIOHIDEventFieldDigitizerX 0x2d
#define kIOHIDEventFieldDigitizerY 0x2e
#define kIOHIDEventFieldDigitizerIndex 0x2b
#define kIOHIDEventFieldDigitizerEventMask 0x2f
#define kIOHIDEventFieldDigitizerIsDisplayIntegrated 0x3c
#define kIOHIDDigitizerEventRange (1 << 0)
#define kIOHIDDigitizerEventTouch (1 << 1)
#define kIOHIDDigitizerTransducerTypeFinger 2

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

// ================= 穿透窗口 =================
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

// ================= 核心接口前置声明 =================
@class VDFGesturePlayer;

@interface FloaterManager : NSObject
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIView *mainContainer; 
@property (strong, nonatomic) UIButton *floatBtn;
@property (strong, nonatomic) UILabel *titleLabel;       
@property (strong, nonatomic) UILabel *timeBottomLabel;  
@property (strong, nonatomic) UIImageView *bgImageView;
@property (strong, nonatomic) UIView *menuView;
@property (nonatomic, assign) CGFloat currentAngle;
@property (nonatomic, assign) CGFloat lastSysAngle; 
@property (nonatomic, assign) CGPoint lastTouchPoint; 
@property (strong, nonatomic) CHHapticEngine *hapticEngine; 
@property (strong, nonatomic) NSTimer *timeTimer;
@property (strong, nonatomic) NSTimer *orientationTimer; 
@property (nonatomic, assign) NSInteger gestureState;

+ (instancetype)sharedInstance;
- (void)setup;
- (void)setVisibility:(BOOL)visible;
- (void)updateUI;
- (CGSize)getPortraitScreenSize;
- (void)stopRecordingAndSave;
- (void)stopPlaying;
- (void)startRecording;
- (NSMutableDictionary *)loadGestureConfig;
- (void)runSelectedScript;
@end

@interface VDFGestureRecorder : NSObject
@property (nonatomic, assign) BOOL recording;
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, assign) NSTimeInterval startTime;
+ (instancetype)shared;
- (void)start;
- (NSDictionary *)stopAndBuildScript;
@end

@interface VDFGesturePlayer : NSObject
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, strong) NSDictionary *script;
@property (nonatomic, assign) double speed;
@property (nonatomic, assign) NSInteger repeatCount;
@property (nonatomic, assign) double interval;
@property (nonatomic, assign) NSInteger currentLoop;
@property (nonatomic, strong) dispatch_queue_t playQueue;
@property (nonatomic, strong) NSMutableSet *activeFingers;
+ (instancetype)shared;
- (void)playScript:(NSDictionary *)script speed:(double)speed repeat:(NSInteger)repeat interval:(double)interval;
- (void)stop;
@end


// ================= 录制器实现 =================
static IOHIDEventSystemClientRef gRecordClient = NULL;
static void *gRecordHandle = NULL;
static VDFGestureRecorder *gRecorder = nil;

static void VDFRecordCallback(void *target, void *refcon, IOHIDEventSystemClientRef client, IOHIDEventRef event) {
    if (!gRecorder || !gRecorder.recording || !gRecordHandle) return;
    
    IOHIDEventGetType_t getType = (IOHIDEventGetType_t)dlsym(gRecordHandle, "IOHIDEventGetType");
    IOHIDEventGetIntegerValue_t getInt = (IOHIDEventGetIntegerValue_t)dlsym(gRecordHandle, "IOHIDEventGetIntegerValue");
    IOHIDEventGetFloatValue_t getFloat = (IOHIDEventGetFloatValue_t)dlsym(gRecordHandle, "IOHIDEventGetFloatValue");
    if (!getType || !getInt || !getFloat) return;
    
    if (getType(event) != kIOHIDEventTypeDigitizer) return;

    int finger = (int)getInt(event, kIOHIDEventFieldDigitizerIndex);
    double x = getFloat(event, kIOHIDEventFieldDigitizerX);
    double y = getFloat(event, kIOHIDEventFieldDigitizerY);
    uint32_t mask = (uint32_t)getInt(event, kIOHIDEventFieldDigitizerEventMask);

    BOOL touch = (mask & kIOHIDDigitizerEventTouch) != 0;
    BOOL range = (mask & kIOHIDDigitizerEventRange) != 0;
    NSString *phase = nil;
    if (touch && range) phase = @"down";
    else if (!touch && !range) phase = @"up";
    else phase = @"move";

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (gRecorder.startTime == 0) gRecorder.startTime = now;
    double t = (now - gRecorder.startTime) * 1000.0;

    @synchronized (gRecorder.events) {
        [gRecorder.events addObject:@{@"t": @(t), @"id": @(finger), @"phase": phase, @"x": @(x), @"y": @(y)}];
    }
}

@implementation VDFGestureRecorder
+ (instancetype)shared { 
    static VDFGestureRecorder *o; 
    static dispatch_once_t t; 
    dispatch_once(&t, ^{ o = [VDFGestureRecorder new]; }); 
    return o; 
}
- (void)start {
    if (self.recording) return;
    self.recording = YES;
    self.events = [NSMutableArray array];
    self.startTime = 0;
    gRecorder = self;

    gRecordHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!gRecordHandle) return;

    IOHIDEventSystemClientCreate_t create = (IOHIDEventSystemClientCreate_t)dlsym(gRecordHandle, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientRegisterEventCallback_t reg = (IOHIDEventSystemClientRegisterEventCallback_t)dlsym(gRecordHandle, "IOHIDEventSystemClientRegisterEventCallback");
    IOHIDEventSystemClientScheduleWithRunLoop_t sched = (IOHIDEventSystemClientScheduleWithRunLoop_t)dlsym(gRecordHandle, "IOHIDEventSystemClientScheduleWithRunLoop");
    
    if (create && reg && sched) {
        gRecordClient = create(kCFAllocatorDefault);
        if (gRecordClient) {
            reg(gRecordClient, VDFRecordCallback, NULL, NULL);
            sched(gRecordClient, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        }
    }
}

- (NSDictionary *)stopAndBuildScript {
    if (!self.recording) return nil;
    self.recording = NO;
    gRecorder = nil;

    if (gRecordClient && gRecordHandle) {
        IOHIDEventSystemClientUnscheduleFromRunLoop_t unsched = (IOHIDEventSystemClientUnscheduleFromRunLoop_t)dlsym(gRecordHandle, "IOHIDEventSystemClientUnscheduleFromRunLoop");
        if (unsched) unsched(gRecordClient, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        CFRelease(gRecordClient);
        gRecordClient = NULL;
    }
    if (gRecordHandle) {
        dlclose(gRecordHandle);
        gRecordHandle = NULL;
    }

    CGSize p = [UIScreen mainScreen].bounds.size;
    return @{
        @"version": @1,
        @"screen": @{@"w": @(p.width), @"h": @(p.height), @"scale": @([UIScreen mainScreen].scale)},
        @"events": self.events ?: @[]
    };
}
@end


// ================= 回放器实现 =================
// 修复：使用全局静态 Client 和 函数指针，避免频繁释放导致 SpringBoard 崩溃
static IOHIDEventSystemClientRef gPlayClient = NULL;
static IOHIDEventCreateDigitizerEvent_t gCreateDigitizerEvent = NULL;
static IOHIDEventSystemClientDispatchEvent_t gDispatchEvent = NULL;
static IOHIDEventSetIntegerValue_t gSetIntValue = NULL;
static void *gPlayHandle = NULL;

@implementation VDFGesturePlayer
+ (instancetype)shared {
    static VDFGesturePlayer *o;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ o = [VDFGesturePlayer new]; });
    return o;
}

- (instancetype)init {
    if (self = [super init]) {
        _playQueue = dispatch_queue_create("vdf.gesture.play", DISPATCH_QUEUE_SERIAL);
        _activeFingers = [NSMutableSet set];
    }
    return self;
}

- (void)setupHID {
    if (gPlayClient) return;
    gPlayHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!gPlayHandle) return;
    IOHIDEventSystemClientCreate_t create = (IOHIDEventSystemClientCreate_t)dlsym(gPlayHandle, "IOHIDEventSystemClientCreate");
    gDispatchEvent = (IOHIDEventSystemClientDispatchEvent_t)dlsym(gPlayHandle, "IOHIDEventSystemClientDispatchEvent");
    gCreateDigitizerEvent = (IOHIDEventCreateDigitizerEvent_t)dlsym(gPlayHandle, "IOHIDEventCreateDigitizerEvent");
    gSetIntValue = (IOHIDEventSetIntegerValue_t)dlsym(gPlayHandle, "IOHIDEventSetIntegerValue");
    if (create) gPlayClient = create(kCFAllocatorDefault);
}

- (void)playScript:(NSDictionary *)script speed:(double)speed repeat:(NSInteger)repeat interval:(double)interval {
    if (self.playing) return;
    [self setupHID]; // 初始化注入环境
    self.script = script;
    self.speed = MAX(0.1, speed);
    self.repeatCount = repeat;
    self.interval = MAX(0, interval);
    self.currentLoop = 0;
    self.playing = YES;
    [self startLoop];
}

- (void)startLoop {
    dispatch_async(self.playQueue, ^{
        if (!self.playing) return;
        NSArray *events = self.script[@"events"];
        if (!events.count) { [self finish]; return; }

        __block NSTimeInterval lastT = 0;
        __block NSInteger idx = 0;
        __weak typeof(self) weakSelf = self;

        void (^step)(void) = ^{
            if (!weakSelf.playing || idx >= events.count) {
                if (idx >= events.count) [weakSelf finishLoop];
                return;
            }
            NSDictionary *e = events[idx++];
            double t = [e[@"t"] doubleValue] / 1000.0;
            double delay = (t - lastT) / weakSelf.speed;
            lastT = t;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(delay, 0) * NSEC_PER_SEC)), weakSelf.playQueue, ^{
                if (!weakSelf.playing) return;
                [weakSelf sendTouch:[e[@"id"] intValue]
                                  x:[e[@"x"] doubleValue]
                                  y:[e[@"y"] doubleValue]
                              phase:e[@"phase"]];
                step();
            });
        };
        step();
    });
}

- (void)finishLoop {
    self.currentLoop++;
    if (self.repeatCount > 0 && self.currentLoop >= self.repeatCount) {
        [self finish];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.interval * NSEC_PER_SEC)), self.playQueue, ^{
        if (self.playing) [self startLoop];
    });
}

- (void)finish {
    dispatch_sync(self.playQueue, ^{
        [self releaseAllFingers];
        self.playing = NO;
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        FloaterManager *fm = [FloaterManager sharedInstance];
        fm.gestureState = 0;
        fm.window.hidden = NO;
    });
}

- (void)stop {
    if (!self.playing) return;
    dispatch_sync(self.playQueue, ^{
        self.playing = NO;
        [self releaseAllFingers];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        FloaterManager *fm = [FloaterManager sharedInstance];
        fm.gestureState = 0;
        fm.window.hidden = NO;
    });
}

- (void)releaseAllFingers {
    NSArray *fingers = [self.activeFingers allObjects];
    for (NSNumber *n in fingers) {
        [self sendTouch:n.intValue x:0 y:0 phase:@"up"];
    }
    [self.activeFingers removeAllObjects];
}

- (void)sendTouch:(int)originalFinger x:(double)x y:(double)y phase:(NSString *)phase {
    int finger = 8 + (originalFinger % 2); // 隔离真实手指
    if (!gPlayClient || !gCreateDigitizerEvent || !gDispatchEvent) return;

    BOOL down = [phase isEqualToString:@"down"];
    BOOL up = [phase isEqualToString:@"up"];
    
    uint32_t eventMask = kIOHIDDigitizerEventTouch;
    if (down) eventMask |= kIOHIDDigitizerEventRange;
    if (up) eventMask = 0;
    
    Boolean range = !up;
    Boolean touch = !up;

    if (down) [self.activeFingers addObject:@(finger)];

    IOHIDEventRef ev = gCreateDigitizerEvent(kCFAllocatorDefault,
                                  mach_absolute_time(),
                                  kIOHIDDigitizerTransducerTypeFinger,
                                  finger,
                                  0,
                                  eventMask,
                                  0,
                                  (IOFixed)(x * 65536.0),
                                  (IOFixed)(y * 65536.0),
                                  0,
                                  0,
                                  0,
                                  range,
                                  touch,
                                  0);
    if (ev) {
        if (gSetIntValue) gSetIntValue(ev, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
        gDispatchEvent(gPlayClient, ev);
        CFRelease(ev);
    }

    if (up) [self.activeFingers removeObject:@(finger)];
}
@end


// ================= 悬浮窗管理器实现 =================
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

        self.lastSysAngle = 0;
        self.currentAngle = 0;
        self.gestureState = 0;

        if (@available(iOS 13.0, *)) {
            if (CHHapticEngine.capabilitiesForHardware.supportsHaptics) {
                NSError *error = nil;
                self.hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
                if (!error) {
                    __weak typeof(self) weakSelf = self;
                    self.hapticEngine.resetHandler = ^{
                        [weakSelf.hapticEngine startAndReturnError:nil];
                    };
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
        
        [self.floatBtn addTarget:self action:@selector(handleSingleTap) forControlEvents:UIControlEventTouchUpInside];
        
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
        self.timeBottomLabel.userInteractionEnabled = YES; 
        
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
        
        UIPanGestureRecognizer *timeLabelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        timeLabelPan.cancelsTouchesInView = NO;
        [self.timeBottomLabel addGestureRecognizer:timeLabelPan];
        
        UILongPressGestureRecognizer *timeLabelLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTimeLabelLongPress:)];
        timeLabelLongPress.minimumPressDuration = 0.4;
        [self.timeBottomLabel addGestureRecognizer:timeLabelLongPress];
        
        [self.mainContainer addSubview:self.timeBottomLabel];
        
        if (!self.window.hidden) {
            self.orientationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkAutoOrientation) userInfo:nil repeats:YES];
            self.orientationTimer.tolerance = 0.2;
        }
        
        [self updateUI];
    });
}

- (void)checkAutoOrientation {
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
    BOOL isCollapsed = self.floatBtn.hidden;
    
    CGPoint c = self.mainContainer.center;
    CGFloat centerX = 1000, centerY = 1000, margin = 5.0;
    
    if (isCollapsed) {
        CGFloat size = self.mainContainer.bounds.size.width;
        CGFloat labelW = isRotated ? 20 : size;
        CGFloat labelH = isRotated ? size : 20;
        
        CGPoint offset = CGPointMake(0, size/2 - 0.5);
        CGPoint rotatedOffset = CGPointApplyAffineTransform(offset, CGAffineTransformMakeRotation(self.currentAngle));
        
        CGFloat labelCenterX = c.x + rotatedOffset.x;
        CGFloat labelCenterY = c.y + rotatedOffset.y;
        
        CGFloat minLabelX = centerX - screenSize.width / 2.0 + labelW / 2.0 + margin;
        CGFloat maxLabelX = centerX + screenSize.width / 2.0 - labelW / 2.0 - margin;
        CGFloat minLabelY = centerY - screenSize.height / 2.0 + labelH / 2.0 + margin;
        CGFloat maxLabelY = centerY + screenSize.height / 2.0 - labelH / 2.0 - margin;
        
        labelCenterX = MAX(minLabelX, MIN(labelCenterX, maxLabelX));
        labelCenterY = MAX(minLabelY, MIN(labelCenterY, maxLabelY));
        
        c.x = labelCenterX - rotatedOffset.x;
        c.y = labelCenterY - rotatedOffset.y;
    } else {
        CGFloat ballW = isRotated ? self.mainContainer.bounds.size.height : self.mainContainer.bounds.size.width;
        CGFloat ballH = isRotated ? self.mainContainer.bounds.size.width : self.mainContainer.bounds.size.height;
        
        CGFloat minX = centerX - screenSize.width / 2.0 + ballW / 2.0 + margin;
        CGFloat maxX = centerX + screenSize.width / 2.0 - ballW / 2.0 - margin;
        CGFloat minY = centerY - screenSize.height / 2.0 + ballH / 2.0 + margin;
        CGFloat maxY = centerY + screenSize.height / 2.0 - ballH / 2.0 - margin;
        
        c.x = MAX(minX, MIN(c.x, maxX));
        c.y = MAX(minY, MIN(c.y, maxY));
    }
    self.mainContainer.center = c;
}

- (void)collapseFloater {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    
    self.floatBtn.hidden = YES;
    self.timeBottomLabel.hidden = NO; 
    
    if (!self.timeTimer) {
        [self updateTimeText];
        self.timeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeText) userInfo:nil repeats:YES];
        self.timeTimer.tolerance = 0.5;
    }
    [self clampCurrentPosition];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    if (self.menuView) {
        [self.menuView removeFromSuperview];
        self.menuView = nil;
        return;
    }

    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 140, 200)];
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    self.menuView.layer.cornerRadius = 12;
    self.menuView.layer.masksToBounds = YES;
    
    NSArray *titles = @[@"折叠隐藏", @"录制手势", @"选择脚本", @"脚本设置"];
    CGFloat btnH = 50;
    
    for (int i = 0; i < titles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(0, i * btnH, 140, btnH);
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        btn.tag = i + 100;
        [btn addTarget:self action:@selector(menuBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.menuView addSubview:btn];
        
        if (i > 0) {
            UIView *line = [[UIView alloc] initWithFrame:CGRectMake(10, i * btnH, 120, 0.5)];
            line.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
            [self.menuView addSubview:line];
        }
    }
    
    CGPoint ballCenter = self.mainContainer.center;
    CGFloat menuX = ballCenter.x;
    CGFloat menuY = ballCenter.y;
    
    if (menuX > [UIScreen mainScreen].bounds.size.width / 2.0) {
        menuX -= 100;
    } else {
        menuX += 100;
    }
    self.menuView.center = CGPointMake(menuX, menuY);
    [self.window.rootViewController.view addSubview:self.menuView];
}

- (void)menuBtnTapped:(UIButton *)sender {
    [self.menuView removeFromSuperview];
    self.menuView = nil;
    
    NSInteger tag = sender.tag - 100;
    if (tag == 0) {
        [self collapseFloater]; 
    } else if (tag == 1) {
        [self startRecording];  
    } else if (tag == 2) {
        [self showScriptList];  
    } else if (tag == 3) {
        [self showScriptSettings]; 
    }
}

- (UIViewController *)getTopViewController {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { keyWindow = window; break; }
    }
    if (!keyWindow) return self.window.rootViewController;
    
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

- (void)handleTimeLabelLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
        
        self.floatBtn.hidden = NO;
        
        NSString *timeStatus = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_time.txt" encoding:NSUTF8StringEncoding error:nil];
        if (![timeStatus isEqualToString:@"1"]) {
            self.timeBottomLabel.hidden = YES;
            [self.timeTimer invalidate];
            self.timeTimer = nil;
        }
        [self clampCurrentPosition];
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
        BOOL isCollapsed = self.floatBtn.hidden;
        
        if (isCollapsed) {
            self.timeBottomLabel.hidden = NO;
        } else {
            self.timeBottomLabel.hidden = !showTime;
        }
        
        if (self.timeBottomLabel.hidden) {
            [self.timeTimer invalidate];
            self.timeTimer = nil;
        } else if (!self.window.hidden && !self.timeTimer) {
            [self updateTimeText];
            self.timeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeText) userInfo:nil repeats:YES];
            self.timeTimer.tolerance = 0.5;
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
        
        if (visible) {
            self.floatBtn.hidden = NO; 
            if (!self.orientationTimer) {
                self.orientationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkAutoOrientation) userInfo:nil repeats:YES];
                self.orientationTimer.tolerance = 0.2;
            }
            [self updateUI]; 
        } else {
            [self.orientationTimer invalidate];
            self.orientationTimer = nil;
            [self.timeTimer invalidate];
            self.timeTimer = nil;
        }
    });
}

- (void)handleSingleTap {
    if (self.window.hidden) return;
    if (self.gestureState == 1) { [self stopRecordingAndSave]; return; }
    if (self.gestureState == 2) { [self stopPlaying]; return; }

    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
    }

    NSMutableDictionary *cfg = [self loadGestureConfig];
    NSString *selected = cfg[@"selected"];
    if (selected.length > 0) {
        [self runSelectedScript];
    } else {
        simulateVolumeDown();
    }
}

// ================= 手势脚本核心逻辑 =================
- (NSString *)gestureDir {
    NSString *dir = @"/var/mobile/Library/Preferences/VolumeDownFloater/gestures";
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)configPath {
    return @"/var/mobile/Library/Preferences/VolumeDownFloater/gesture_config.plist";
}

- (NSMutableDictionary *)loadGestureConfig {
    NSMutableDictionary *cfg = [NSMutableDictionary dictionaryWithContentsOfFile:[self configPath]];
    if (!cfg) cfg = [NSMutableDictionary dictionary];
    if (!cfg[@"selected"]) cfg[@"selected"] = @"";
    if (!cfg[@"repeat"]) cfg[@"repeat"] = @1;      
    if (!cfg[@"speed"]) cfg[@"speed"] = @1.0;     
    if (!cfg[@"interval"]) cfg[@"interval"] = @0.2; 
    return cfg;
}

- (void)saveGestureConfig:(NSDictionary *)cfg {
    [cfg writeToFile:[self configPath] atomically:YES];
}

- (void)startRecording {
    if (self.gestureState != 0) return;
    self.gestureState = 1;
    self.window.hidden = YES; 
    [[VDFGestureRecorder shared] start];
}

- (void)stopRecordingAndSave {
    if (self.gestureState != 1) return;
    NSDictionary *script = [[VDFGestureRecorder shared] stopAndBuildScript];
    self.gestureState = 0;
    self.window.hidden = NO;
    if (!script || ![script[@"events"] count]) return;

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"MMdd_HHmmss"];
    NSString *name = [NSString stringWithFormat:@"script_%@", [fmt stringFromDate:[NSDate date]]];
    
    NSString *path = [[self gestureDir] stringByAppendingPathComponent:[name stringByAppendingString:@".json"]];
    NSData *data = [NSJSONSerialization dataWithJSONObject:script options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:path atomically:YES];

    NSMutableDictionary *cfg = [self loadGestureConfig];
    cfg[@"selected"] = [name stringByAppendingString:@".json"];
    [self saveGestureConfig:cfg];
}

- (void)showScriptList {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self gestureDir] error:nil];
    NSMutableArray *jsonFiles = [NSMutableArray array];
    for (NSString *f in files) if ([f.pathExtension isEqualToString:@"json"]) [jsonFiles addObject:f];
    if (!jsonFiles.count) return;

    NSMutableDictionary *cfg = [self loadGestureConfig];
    NSString *selected = cfg[@"selected"];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择脚本（单击运行）" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *f in jsonFiles) {
        NSString *title = f.stringByDeletingPathExtension;
        if ([f isEqualToString:selected]) title = [title stringByAppendingString:@" ✓"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            NSMutableDictionary *c = [self loadGestureConfig];
            c[@"selected"] = f;
            [self saveGestureConfig:c];
        }]];
    }
    
    // === 新增：删除脚本入口 ===
    [sheet addAction:[UIAlertAction actionWithTitle:@"❌ 删除脚本" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self showDeleteScriptList];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *topVC = [self getTopViewController];
    [topVC presentViewController:sheet animated:YES completion:nil];
}

// === 新增：删除脚本列表 ===
- (void)showDeleteScriptList {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self gestureDir] error:nil];
    NSMutableArray *jsonFiles = [NSMutableArray array];
    for (NSString *f in files) if ([f.pathExtension isEqualToString:@"json"]) [jsonFiles addObject:f];
    if (!jsonFiles.count) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择要删除的脚本" message:@"删除后不可恢复" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *f in jsonFiles) {
        [sheet addAction:[UIAlertAction actionWithTitle:f.stringByDeletingPathExtension style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            NSString *path = [[self gestureDir] stringByAppendingPathComponent:f];
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            
            NSMutableDictionary *cfg = [self loadGestureConfig];
            if ([cfg[@"selected"] isEqualToString:f]) {
                cfg[@"selected"] = @"";
                [self saveGestureConfig:cfg];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *topVC = [self getTopViewController];
    [topVC presentViewController:sheet animated:YES completion:nil];
}

- (void)showScriptSettings {
    NSMutableDictionary *cfg = [self loadGestureConfig];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"脚本设置" message:@"修改循环次数、速度、间隔" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"循环次数（0=无限）";
        tf.text = [cfg[@"repeat"] stringValue];
        tf.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"速度 0.5~3.0";
        tf.text = [cfg[@"speed"] stringValue];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"循环间隔秒";
        tf.text = [cfg[@"interval"] stringValue];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSMutableDictionary *c = [self loadGestureConfig];
        c[@"repeat"] = @([alert.textFields[0].text integerValue]);
        c[@"speed"] = @(MAX(0.1, [alert.textFields[1].text doubleValue]));
        c[@"interval"] = @(MAX(0, [alert.textFields[2].text doubleValue]));
        [self saveGestureConfig:c];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *topVC = [self getTopViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (void)runSelectedScript {
    if (self.gestureState != 0) return;
    NSMutableDictionary *cfg = [self loadGestureConfig];
    NSString *selected = cfg[@"selected"];
    if (selected.length == 0) return;

    NSString *path = [[self gestureDir] stringByAppendingPathComponent:selected];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return;
    NSDictionary *script = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!script) return;

    self.gestureState = 2;
    self.window.hidden = YES; 
    [[VDFGesturePlayer shared] playScript:script
                                    speed:[cfg[@"speed"] doubleValue]
                                   repeat:[cfg[@"repeat"] integerValue]
                                 interval:[cfg[@"interval"] doubleValue]];
}

- (void)stopPlaying {
    if (self.gestureState != 2) return;
    [[VDFGesturePlayer shared] stop];
    self.gestureState = 0;
    self.window.hidden = NO;
}

- (void)playClickHapticAndVolumeDown {
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
                if (!error) [player startAtTime:0 error:&error];
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
        BOOL isCollapsed = self.floatBtn.hidden;
        CGSize screenSize = [self getPortraitScreenSize];
        CGFloat centerX = 1000, centerY = 1000, margin = 5.0;
        
        if (isCollapsed) {
            CGFloat size = self.mainContainer.bounds.size.width;
            CGFloat labelW = isRotated ? 20 : size;
            CGFloat labelH = isRotated ? size : 20;
            
            CGPoint offset = CGPointMake(0, size/2 - 0.5);
            CGPoint rotatedOffset = CGPointApplyAffineTransform(offset, CGAffineTransformMakeRotation(self.currentAngle));
            
            CGFloat labelCenterX = newCenter.x + rotatedOffset.x;
            CGFloat labelCenterY = newCenter.y + rotatedOffset.y;
            
            CGFloat minLabelX = centerX - screenSize.width / 2.0 + labelW / 2.0 + margin;
            CGFloat maxLabelX = centerX + screenSize.width / 2.0 - labelW / 2.0 - margin;
            CGFloat minLabelY = centerY - screenSize.height / 2.0 + labelH / 2.0 + margin;
            CGFloat maxLabelY = centerY + screenSize.height / 2.0 - labelH / 2.0 - margin;
            
            labelCenterX = MAX(minLabelX, MIN(labelCenterX, maxLabelX));
            labelCenterY = MAX(minLabelY, MIN(labelCenterY, maxLabelY));
            
            newCenter.x = labelCenterX - rotatedOffset.x;
            newCenter.y = labelCenterY - rotatedOffset.y;
        } else {
            CGFloat ballW = isRotated ? self.mainContainer.bounds.size.height : self.mainContainer.bounds.size.width;
            CGFloat ballH = isRotated ? self.mainContainer.bounds.size.width : self.mainContainer.bounds.size.height;
            
            CGFloat minX = centerX - screenSize.width / 2.0 + ballW / 2.0 + margin;
            CGFloat maxX = centerX + screenSize.width / 2.0 - ballW / 2.0 - margin;
            CGFloat minY = centerY - screenSize.height / 2.0 + ballH / 2.0 + margin;
            CGFloat maxY = centerY + screenSize.height / 2.0 - ballH / 2.0 - margin;
            
            newCenter.x = MAX(minX, MIN(newCenter.x, maxX));
            newCenter.y = MAX(minY, MIN(newCenter.y, maxY));
        }
        
        self.mainContainer.center = newCenter;
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        NSString *pxStr = [NSString stringWithFormat:@"%f", self.mainContainer.center.x];
        NSString *pyStr = [NSString stringWithFormat:@"%f", self.mainContainer.center.y];
        [pxStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posx.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [pyStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_posy.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}
@end


// ================= Hook 拦截物理音量键 =================
%hook SBVolumeControl
- (void)decreaseVolume {
    FloaterManager *fm = [FloaterManager sharedInstance];
    if (fm.gestureState == 1) { [fm stopRecordingAndSave]; return; }
    if (fm.gestureState == 2) { [fm stopPlaying]; return; }
    %orig;
}
- (void)_decreaseVolume {
    FloaterManager *fm = [FloaterManager sharedInstance];
    if (fm.gestureState == 1) { [fm stopRecordingAndSave]; return; }
    if (fm.gestureState == 2) { [fm stopPlaying]; return; }
    %orig;
}
%end

// ================= 初始化 =================
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
    [[FloaterManager sharedInstance] setVisibility:YES];
}

static void hideFloater(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] setVisibility:NO];
}

static void updateUI(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FloaterManager sharedInstance] updateUI];
}