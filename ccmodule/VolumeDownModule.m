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
// 用代码直接画一个红圈图标
- (UIImage *)iconGlyph {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(58, 58), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor systemRedColor].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(4, 4, 50, 50));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end