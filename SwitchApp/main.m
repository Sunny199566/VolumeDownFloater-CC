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
    
    BOOL isOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"toggleState"];
    self.toggleSwitch.on = isOn;
    
    [self.toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:self.toggleSwitch];
    
    // App 启动时，如果开关是开的，强制发一次 Show 信号给悬浮球
    if (isOn) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/show"), NULL, NULL, YES);
    } else {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/hide"), NULL, NULL, YES);
    }
    
    return YES;
}

- (void)switchChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"toggleState"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 核心：根据状态发送不同的独立指令
    if (sender.isOn) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/show"), NULL, NULL, YES);
    } else {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/hide"), NULL, NULL, YES);
    }
    
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}