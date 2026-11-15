- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if ([url.scheme isEqualToString:@"volumefloater"]) {
        if ([url.host isEqualToString:@"show"]) {
            [@"1" writeToFile:@"/var/mobile/Library/Preferences/volumefloater_show.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/show"), NULL, NULL, YES);
            
            // 【核心修改】：这里不再用 exit(0) 闪退回桌面，而是用 suspend 让 App 悄悄挂起到后台！
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] performSelector:@selector(suspend)];
            });
            return YES;
            
        } else if ([url.host isEqualToString:@"hide"]) {
            [@"0" writeToFile:@"/var/mobile/Library/Preferences/volumefloater_show.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.volumedownfloater/hide"), NULL, NULL, YES);
            
            // 【核心修改】：挂起后台，绝对不闪退
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] performSelector:@selector(suspend)];
            });
            return YES;
        }
    }
    return NO;
}