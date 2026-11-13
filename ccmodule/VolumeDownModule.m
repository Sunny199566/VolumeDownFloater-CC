#import "VolumeDownModule.h"
#import "VolumeDownFloaterPrefs.h"

@implementation VolumeDownModule

- (instancetype)init {
    if ((self = [super init])) {
        // 初始化时读取当前开关状态
    }
    return self;
}

- (BOOL)isSelected {
    Boolean keyExists = NO;
    Boolean enabled = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), (__bridge CFStringRef)kVolumeDownPrefsDomain, &keyExists);
    return keyExists ? enabled : NO;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    CFPreferencesSetAppValue(CFSTR("enabled"), selected ? kCFBooleanTrue : kCFBooleanFalse, (__bridge CFStringRef)kVolumeDownPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kVolumeDownPrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(kVolumeDownToggleNotification), NULL, NULL, YES);
}

- (NSString *)title {
    return @"音量减悬浮球";
}

- (UIImage *)iconGlyph {
    return [UIImage imageNamed:@"SettingsIcon" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
}

@end