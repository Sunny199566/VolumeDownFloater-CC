#import "VolumeDownModule.h"
#import "../VolumeDownFloaterPrefs.h"

@implementation VolumeDownModule

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
    // 这是一个标准红底白圈图标的 Base64 数据
    NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH6QwTFQwAAAAA";
    NSData *imgData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return [UIImage imageWithData:imgData];
}

@end