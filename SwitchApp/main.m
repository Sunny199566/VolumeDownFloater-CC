#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UISwitch *toggleSwitch;
@property (strong, nonatomic) UISwitch *timeSwitch;
@property (strong, nonatomic) UITextField *titleTextField;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor systemBackgroundColor];
    self.window.rootViewController = vc;
    self.window.hidden = NO;

    // 标题
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, self.window.bounds.size.width, 40)];
    headerLabel.text = @"音量悬浮球控制台";
    headerLabel.font = [UIFont boldSystemFontOfSize:24];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:headerLabel];

    // --- 显示悬浮球开关 ---
    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 160, 200, 30)];
    switchLabel.text = @"显示悬浮球";
    switchLabel.font = [UIFont systemFontOfSize:18];
    [vc.view addSubview:switchLabel];

    self.toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.window.bounds.size.width - 90, 160, 51, 31)];
    self.toggleSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"toggleState"];
    [self.toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:self.toggleSwitch];

    // --- 时间显示开关 ---
    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 220, 200, 30)];
    timeLabel.text = @"显示实时时间";
    timeLabel.font = [UIFont systemFontOfSize:18];
    [vc.view addSubview:timeLabel];

    self.timeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.window.bounds.size.width - 90, 220, 51, 31)];
    self.timeSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"timeState"];
    [self.timeSwitch addTarget:self action:@selector(timeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [vc.view addSubview:self.timeSwitch];

    // --- 文字修改 ---
    UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 280, 200, 30)];
    textLabel.text = @"悬浮球内部文字";
    textLabel.font = [UIFont systemFontOfSize:18];
    [vc.view addSubview:textLabel];

    self.titleTextField = [[UITextField alloc] initWithFrame:CGRectMake(40, 320, self.window.bounds.size.width - 80, 40)];
    self.titleTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.titleTextField.placeholder = @"输入你想显示的文字";
    self.titleTextField.textAlignment = NSTextAlignmentCenter;
    
    // 从全局配置读取文字
    CFStringRef titleRef = CFPreferencesCopyAppValue(CFSTR("title"), CFSTR("com.yourname.volumedownfloater"));
    NSString *currentTitle = titleRef ? (__bridge_transfer NSString *)titleRef : @"音量-";
    self.titleTextField.text = currentTitle;
    
    [self.titleTextField addTarget:self action:@selector(textChanged:) forControlEvents:UIControlEventEditingChanged];
    [vc.view addSubview:self.titleTextField];

    // --- 选择自定义图片按钮 ---
    UIButton *imageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    imageBtn.frame = CGRectMake(40, 390, self.window.bounds.size.width - 80, 45);
    [imageBtn setTitle:@"从相册选择自定义图标" forState:UIControlStateNormal];
    imageBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    imageBtn.backgroundColor = [UIColor systemBlueColor];
    [imageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    imageBtn.layer.cornerRadius = 10;
    [imageBtn addTarget:self action:@selector(selectImage) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:imageBtn];

    // --- 清除图片按钮 ---
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(40, 450, self.window.bounds.size.width - 80, 45);
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
    
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
}

- (void)timeSwitchChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"timeState"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 存入 CFPreferences
    CFPreferencesSetAppValue(CFSTR("showtime"), sender.isOn ? kCFBooleanTrue : kCFBooleanFalse, CFSTR("com.yourname.volumedownfloater"));
    CFPreferencesAppSynchronize(CFSTR("com.yourname.volumedownfloater"));
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
    
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
}

- (void)textChanged:(UITextField *)sender {
    NSString *newText = sender.text;
    if (newText.length == 0) newText = @" ";
    
    // 存入 CFPreferences
    CFPreferencesSetAppValue(CFSTR("title"), (__bridge CFStringRef)newText, CFSTR("com.yourname.volumedownfloater"));
    CFPreferencesAppSynchronize(CFSTR("com.yourname.volumedownfloater"));
    
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
        // 压缩图片并转为 Base64 字符串存入 CFPreferences
        NSData *imgData = UIImageJPEGRepresentation(image, 0.8);
        NSString *base64String = [imgData base64EncodedStringWithOptions:0];
        
        CFPreferencesSetAppValue(CFSTR("custom_bg"), (__bridge CFStringRef)base64String, CFSTR("com.yourname.volumedownfloater"));
        CFPreferencesAppSynchronize(CFSTR("com.yourname.volumedownfloater"));
        
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
    }
}

- (void)clearImage {
    CFPreferencesSetAppValue(CFSTR("custom_bg"), NULL, CFSTR("com.yourname.volumedownfloater"));
    CFPreferencesAppSynchronize(CFSTR("com.yourname.volumedownfloater"));
    
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