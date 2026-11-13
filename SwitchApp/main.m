#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UISwitch *toggleSwitch;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor systemBackgroundColor];
    self.window.rootViewController = vc;
    self.window.hidden = NO;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 150, self.window.bounds.size.width, 40)];
    titleLabel.text = @"音量悬浮球开关";
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:titleLabel];

    self.toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 31)];
    self.toggleSwitch.center = CGPointMake(self.window.bounds.size.width/2, 250);
    self.toggleSwitch.transform = CGAffineTransformMakeScale(1.5, 1.5);
    
    // App 内部自己存状态（这样关掉 App 再打开，开关状态还在）
    BOOL isOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"toggleState"];
    self.toggleSwitch.on = isOn;
    
    [self.toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:self.toggleSwitch];
    
    // 每次打开 App 时，强制同步一次当前状态给 Tweak
    [self syncState:self.toggleSwitch.isOn];
    
    return YES;
}

- (void)switchChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"toggleState"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self syncState:sender.isOn];
    
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
}

- (void)syncState:(BOOL)isOn {
    CFStringRef stateString = isOn ? CFSTR("1") : CFSTR("0");
    // 核心：利用 Notification 传参，完全绕过沙盒！
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/toggle"), stateString, NULL, YES);
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}