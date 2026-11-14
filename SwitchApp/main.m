#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UISwitch *toggleSwitch;
@property (strong, nonatomic) UISwitch *timeSwitch;
@property (strong, nonatomic) UITextField *titleTextField;
@property (strong, nonatomic) UISlider *hapticSlider;
@property (strong, nonatomic) UISlider *sizeSlider;
@property (strong, nonatomic) UISlider *alphaSlider;
@property (strong, nonatomic) NSString *currentColor;
@property (strong, nonatomic) NSMutableArray *colorButtons;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor systemBackgroundColor];
    self.window.rootViewController = vc;
    self.window.hidden = NO;

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.window.bounds];
    scrollView.contentSize = CGSizeMake(self.window.bounds.size.width, 750);
    [vc.view addSubview:scrollView];

    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 40, self.window.bounds.size.width, 40)];
    headerLabel.text = @"音量悬浮球控制台";
    headerLabel.font = [UIFont boldSystemFontOfSize:24];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    [scrollView addSubview:headerLabel];

    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 110, 200, 30)];
    switchLabel.text = @"显示悬浮球";
    switchLabel.font = [UIFont systemFontOfSize:18];
    [scrollView addSubview:switchLabel];
    self.toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.window.bounds.size.width - 90, 110, 51, 31)];
    self.toggleSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"toggleState"];
    [self.toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:self.toggleSwitch];

    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 160, 200, 30)];
    timeLabel.text = @"显示实时时间";
    timeLabel.font = [UIFont systemFontOfSize:18];
    [scrollView addSubview:timeLabel];
    self.timeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.window.bounds.size.width - 90, 160, 51, 31)];
    self.timeSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"timeState"];
    [self.timeSwitch addTarget:self action:@selector(timeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:self.timeSwitch];

    UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 210, 200, 30)];
    textLabel.text = @"悬浮球内部文字";
    textLabel.font = [UIFont systemFontOfSize:18];
    [scrollView addSubview:textLabel];
    self.titleTextField = [[UITextField alloc] initWithFrame:CGRectMake(40, 250, self.window.bounds.size.width - 80, 40)];
    self.titleTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.titleTextField.placeholder = @"输入你想显示的文字";
    self.titleTextField.textAlignment = NSTextAlignmentCenter;
    NSString *path = @"/var/mobile/Library/Preferences/volumefloater_title.txt";
    NSString *currentTitle = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    self.titleTextField.text = (currentTitle && currentTitle.length > 0) ? currentTitle : @"音量-";
    [self.titleTextField addTarget:self action:@selector(textChanged:) forControlEvents:UIControlEventEditingChanged];
    [scrollView addSubview:self.titleTextField];

    UILabel *hapticLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 310, 200, 30)];
    hapticLabel.text = @"单击震动强度";
    hapticLabel.font = [UIFont systemFontOfSize:18];
    [scrollView addSubview:hapticLabel];
    self.hapticSlider = [[UISlider alloc] initWithFrame:CGRectMake(40, 350, self.window.bounds.size.width - 80, 30)];
    self.hapticSlider.minimumValue = 0.0;
    self.hapticSlider.maximumValue = 1.0;
    NSString *hapticPath = @"/var/mobile/Library/Preferences/volumefloater_haptic.txt";
    NSString *hapticStr = [NSString stringWithContentsOfFile:hapticPath encoding:NSUTF8StringEncoding error:nil];
    self.hapticSlider.value = (hapticStr && hapticStr.length > 0) ? [hapticStr floatValue] : 1.0;
    [self.hapticSlider addTarget:self action:@selector(hapticChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:self.hapticSlider];

    UILabel *sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 400, 200, 30)];
    sizeLabel.text = @"悬浮球大小";
    sizeLabel.font = [UIFont systemFontOfSize:18];
    [scrollView addSubview:sizeLabel];
    self.sizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(40, 440, self.window.bounds.size.width - 80, 30)];
    self.sizeSlider.minimumValue = 40.0;
    self.sizeSlider.maximumValue = 80.0;
    NSString *sizePath = @"/var/mobile/Library/Preferences/volumefloater_size.txt";
    NSString *sizeStr = [NSString stringWithContentsOfFile:sizePath encoding:NSUTF8StringEncoding error:nil];
    self.sizeSlider.value = (sizeStr && sizeStr.length > 0) ? [sizeStr floatValue] : 60.0;
    [self.sizeSlider addTarget:self action:@selector(uiChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:self.sizeSlider];

    UILabel *alphaLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 490, 200, 30)];
    alphaLabel.text = @"悬浮球透明度";
    alphaLabel.font = [UIFont systemFontOfSize:18];
    [scrollView addSubview:alphaLabel];
    self.alphaSlider = [[UISlider alloc] initWithFrame:CGRectMake(40, 530, self.window.bounds.size.width - 80, 30)];
    self.alphaSlider.minimumValue = 0.3;
    self.alphaSlider.maximumValue = 1.0;
    NSString *alphaPath = @"/var/mobile/Library/Preferences/volumefloater_alpha.txt";
    NSString *alphaStr = [NSString stringWithContentsOfFile:alphaPath encoding:NSUTF8StringEncoding error:nil];
    self.alphaSlider.value = (alphaStr && alphaStr.length > 0) ? [alphaStr floatValue] : 0.9;
    [self.alphaSlider addTarget:self action:@selector(uiChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:self.alphaSlider];

    UILabel *colorLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 580, 200, 30)];
    colorLabel.text = @"悬浮球底色";
    colorLabel.font = [UIFont systemFontOfSize:18];
    [scrollView addSubview:colorLabel];
    
    self.currentColor = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/volumefloater_color.txt" encoding:NSUTF8StringEncoding error:nil];
    if (!self.currentColor || self.currentColor.length == 0) self.currentColor = @"red";

    self.colorButtons = [NSMutableArray array];
    NSArray *uiColors = @[[UIColor systemRedColor], [UIColor systemBlueColor], [UIColor systemGreenColor], [UIColor blackColor], [UIColor lightGrayColor]];
    
    for (int i = 0; i < 5; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(40 + i * 55, 620, 40, 40);
        btn.backgroundColor = uiColors[i];
        btn.layer.cornerRadius = 20;
        btn.tag = i;
        btn.layer.borderWidth = 2.0;
        btn.layer.borderColor = [UIColor clearColor].CGColor;
        [btn addTarget:self action:@selector(colorSelected:) forControlEvents:UIControlEventTouchUpInside];
        [scrollView addSubview:btn];
        [self.colorButtons addObject:btn];
    }
    [self updateColorButtonBorders];

    UIButton *imageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    imageBtn.frame = CGRectMake(40, 680, (self.window.bounds.size.width - 90) / 2, 45);
    [imageBtn setTitle:@"选择自定义图" forState:UIControlStateNormal];
    imageBtn.backgroundColor = [UIColor systemBlueColor];
    [imageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    imageBtn.layer.cornerRadius = 10;
    [imageBtn addTarget:self action:@selector(selectImage) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:imageBtn];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(50 + (self.window.bounds.size.width - 90) / 2, 680, (self.window.bounds.size.width - 90) / 2, 45);
    [clearBtn setTitle:@"清除图片" forState:UIControlStateNormal];
    clearBtn.backgroundColor = [UIColor systemRedColor];
    [clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clearBtn.layer.cornerRadius = 10;
    [clearBtn addTarget:self action:@selector(clearImage) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:clearBtn];

    [self syncState:self.toggleSwitch.isOn];
    return YES;
}

- (void)updateColorButtonBorders {
    NSArray *colors = @[@"red", @"blue", @"green", @"black", @"clear"];
    for (int i = 0; i < 5; i++) {
        UIButton *btn = self.colorButtons[i];
        if ([colors[i] isEqualToString:self.currentColor]) {
            btn.layer.borderColor = [UIColor whiteColor].CGColor;
            btn.transform = CGAffineTransformMakeScale(1.1, 1.1);
        } else {
            btn.layer.borderColor = [UIColor clearColor].CGColor;
            btn.transform = CGAffineTransformIdentity;
        }
    }
}

- (void)colorSelected:(UIButton *)sender {
    NSArray *colors = @[@"red", @"blue", @"green", @"black", @"clear"];
    self.currentColor = colors[sender.tag];
    [self.currentColor writeToFile:@"/var/mobile/Library/Preferences/volumefloater_color.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self updateColorButtonBorders];
    [self uiChanged:nil];
    [self triggerTestHaptic];
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
    [self uiChanged:nil];
}

- (void)hapticChanged:(UISlider *)sender {
    NSString *valStr = [NSString stringWithFormat:@"%f", sender.value];
    [valStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_haptic.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self triggerTestHaptic];
}

- (void)uiChanged:(UISlider *)sender {
    NSString *sizeStr = [NSString stringWithFormat:@"%f", self.sizeSlider.value];
    [sizeStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_size.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSString *alphaStr = [NSString stringWithFormat:@"%f", self.alphaSlider.value];
    [alphaStr writeToFile:@"/var/mobile/Library/Preferences/volumefloater_alpha.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/update_ui"), NULL, NULL, YES);
}

// 三段式混合震动测试
- (void)triggerTestHaptic {
    if (@available(iOS 13.0, *)) {
        UIImpactFeedbackStyle style = UIImpactFeedbackStyleMedium;
        if (self.hapticSlider.value < 0.3) {
            style = UIImpactFeedbackStyleLight;
        } else if (self.hapticSlider.value > 0.7) {
            style = UIImpactFeedbackStyleHeavy;
        }
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [gen prepare];
        [gen impactOccurredWithIntensity:self.hapticSlider.value];
    }
}

- (void)textChanged:(UITextField *)sender {
    NSString *newText = sender.text;
    if (newText.length == 0) newText = @" ";
    [newText writeToFile:@"/var/mobile/Library/Preferences/volumefloater_title.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self uiChanged:nil];
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
        [imgData writeToFile:@"/var/mobile/Library/Preferences/volumefloater_bg.png" atomically:YES];
        [self uiChanged:nil];
    }
}

- (void)clearImage {
    [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/volumefloater_bg.png" error:nil];
    [self uiChanged:nil];
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