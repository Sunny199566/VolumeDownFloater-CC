#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.backgroundColor = [UIColor blackColor];
    [self.window makeKeyAndVisible];
    
    UIView *rootView = self.window.rootViewController.view;
    CGFloat screenW = rootView.bounds.size.width;
    CGFloat btnW = screenW - 40;
    CGFloat btnH = 85;
    CGFloat startY = 220;
    CGFloat gap = 35;
    
    // ========= 按钮1：开始录制手势（橙色） =========
    UIButton *btnStart = [UIButton buttonWithType:UIButtonTypeCustom];
    btnStart.frame = CGRectMake(20, startY, btnW, btnH);
    btnStart.backgroundColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0];
    btnStart.layer.cornerRadius = 18;
    btnStart.titleLabel.font = [UIFont boldSystemFontOfSize:26];
    [btnStart setTitle:@"开始录制手势" forState:UIControlStateNormal];
    [btnStart addTarget:self action:@selector(onBtnStart:) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:btnStart];
    
    // ========= 按钮2：停止录制手势（红色） =========
    UIButton *btnStop = [UIButton buttonWithType:UIButtonTypeCustom];
    btnStop.frame = CGRectMake(20, startY + btnH + gap, btnW, btnH);
    btnStop.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
    btnStop.layer.cornerRadius = 18;
    btnStop.titleLabel.font = [UIFont boldSystemFontOfSize:26];
    [btnStop setTitle:@"停止录制手势" forState:UIControlStateNormal];
    [btnStop addTarget:self action:@selector(onBtnStop:) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:btnStop];
    
    // ========= 按钮3：回放已录制手势（绿色） =========
    UIButton *btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    btnPlay.frame = CGRectMake(20, startY + (btnH + gap)*2, btnW, btnH);
    btnPlay.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.3 alpha:1.0];
    btnPlay.layer.cornerRadius = 18;
    btnPlay.titleLabel.font = [UIFont boldSystemFontOfSize:26];
    [btnPlay setTitle:@"回放已录制手势" forState:UIControlStateNormal];
    [btnPlay addTarget:self action:@selector(onBtnPlay:) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:btnPlay];
    
    return YES;
}

#pragma mark ✅ 按钮点击回调（发送Darwin通知）
- (void)onBtnStart:(id)sender {
    CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(nc, CFSTR("com.sunny.gesturecontrol.start"), NULL, NULL, YES);
}
- (void)onBtnStop:(id)sender {
    CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(nc, CFSTR("com.sunny.gesturecontrol.stop"), NULL, NULL, YES);
}
- (void)onBtnPlay:(id)sender {
    CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(nc, CFSTR("com.sunny.gesturecontrol.play"), NULL, NULL, YES);
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}