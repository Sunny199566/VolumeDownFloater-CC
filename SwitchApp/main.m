#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UISwitch *toggleSwitch;
@property (strong, nonatomic) UISwitch *timeSwitch;
@property (strong, nonatomic) UITextField *titleTextField;
@property (strong, nonatomic) UISlider *hapticSlider;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor systemBackgroundColor];
    self.window.rootViewController = vc;
    self.window.hidden = NO;

    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, self.window.bounds.size.width, 40)];
    headerLabel.text = @"音量悬浮球控制台";
    headerLabel.font = [UIFont boldSystemFontOfSize:24];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:headerLabel];

    // 1. 显示悬浮球
    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 150, 200, 30)];
    switchLabel.text = @"显示悬浮球";
    switchLabel.font = [UIFont systemFontOfSize:18];
    [vc.view addSubview:switchLabel];
    self.toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.window.bounds.size.width - 90, 150, 51, 31)];
    self.toggleSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"toggleState"];
    [self.toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:self.toggleSwitch];

    // 2. 实时时间
    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 200, 200, 30)];
    timeLabel.text = @"显示实时时间";
    timeLabel.font = [UIFont systemFontOfSize:18];
    [vc.view addSubview:timeLabel];
    self.timeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.window.bounds.size.width - 90, 200, 51, 31)];
    self.timeSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"timeState"];
    [self.timeSwitch addTarget:self action:@selector(timeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:self.timeSwitch];

    // 3. 文字修改
    UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 250, 200, 30)];
    textLabel.text = @"悬浮球内部文字";
    textLabel.font = [UIFont systemFontOfSize:18];
    [vc.view addSubview:textLabel];

    self.titleTextField = [[UITextField alloc] initWithFrame:CGRectMake(40, 290, self.window.bounds.size.width - 80, 40)];
    self.titleTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.titleTextField.placeholder = @"输入你想显示的文字";
    self.titleTextField.textAlignment = NSTextAlignmentCenter;
    
    NSString *path = @"/var/mobile/Library/Preferences/volumefloater_title.txt";
    NSString *currentTitle = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    self.titleTextField.text = (currentTitle && currentTitle.length > 0) ? currentTitle : @"音量-";
    [self.titleTextField addTarget:self action:@selector(textChanged:) forControlEvents:UIControlEventEditingChanged];
    [vc.view addSubview:self.titleTextField];

    // 4. 震动强度调节
    UILabel *hapticLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 350, 200, 30)];
    hapticLabel.text = @"单击震动强度";
    hapticLabel.font = [UIFont systemFontOfSize:18];
    [vc.view addSubview:hapticLabel];

    self.hapticSlider = [[UISlider alloc] initWithFrame:CGRectMake(40, 390, self.window.bounds.size.width - 80, 30)];
    self.hapticSlider.minimumValue = 0.0;
    self.hapticSlider.maximumValue = 1.0;
    
    NSString *hapticPath = @"/var/mobile/Library/Preferences/volumefloater_haptic.txt";
    NSString *hapticStr = [NSString stringWithContentsOfFile:hapticPath encoding:NSUTF8StringEncoding error:nil];
    self.hapticSlider.value = (hapticStr && hapticStr.length > 0) ? [hapticStr floatValue] : 0.8; 
    
    [self.hapticSlider addTarget:self action:@selector(hapticChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:self.hapticSlider];

    // 5. 选择图片
    UIButton *imageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    imageBtn.frame = CGRectMake(40, 450, self.window.bounds.size.width - 80, 45);
    [imageBtn setTitle:@"从相册选择自定义图标" forState:UIControlStateNormal];
    imageBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    imageBtn.backgroundColor = [UIColor systemBlueColor];
    [imageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    imageBtn.layer.cornerRadius = 10;
    [imageBtn addTarget:self action:@selector(selectImage) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:imageBtn];

    // 6. 清除图片
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(40, 510, self.window.bounds.size.width - 80, 45);
    [clearBtn setTitle:@"清除自定义图标" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    clearBtn.backgroundColor = [UIColor systemRedColor];
    [clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clearBtn.layer.cornerRadius = 10;
    [clearBtn addTarget:self action:@selector(clearImage) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:clearBtn];

    [self syncState:self.toggleSwitch.isOn];
    return YES;
}

- (void)switchChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"toggleState"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self syncState:sender.isOn];
    [self triggerTestHaptic];
}

- (void)timeSwitchChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"timeState"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSString *path = @"/var/mobile/Library/Preferences/volumefloater_time.txt";
    [sender.isOn ? @"1" : @"0" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
    [self triggerTestHaptic];
}

- (void)hapticChanged:(UISlider *)sender {
    NSString *path = @"/var/mobile/Library/Preferences/volumefloater_haptic.txt";
    NSString *valStr = [NSString stringWithFormat:@"%f", sender.value];
    [valStr writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
    
    [self triggerTestHaptic];
}

- (void)triggerTestHaptic {
    if (@available(iOS 13.0, *)) {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [gen impactOccurredWithIntensity:self.hapticSlider.value];
    } else {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [gen impactOccurred];
    }
}

- (void)textChanged:(UITextField *)sender {
    NSString *newText = sender.text;
    if (newText.length == 0) newText = @" ";
    NSString *path = @"/var/mobile/Library/Preferences/volumefloater_title.txt";
    [newText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
}

- (void)selectImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self.window.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        NSData *imgData = UIImageJPEGRepresentation(image, 0.8);
        NSString *path = @"/var/mobile/Library/Preferences/volumefloater_bg.png";
        [imgData writeToFile:path atomically:YES];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
    }
}

- (void)clearImage {
    NSString *path = @"/var/mobile/Library/Preferences/volumefloater_bg.png";
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
}

- (void)syncState:(BOOL)isOn {
    if (isOn) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/show"), NULL, NULL, YES);
    } else {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/hide"), NULL, NULL, YES);
    }
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}