#import <UIKit/UIKit.h>

@interface CCUIToggleModule : NSObject
@property (nonatomic, assign) BOOL selected;
- (BOOL)isSelected;
- (void)setSelected:(BOOL)selected;
- (UIImage *)iconGlyph;
- (NSString *)title;
@end

@interface VolumeDownModule : CCUIToggleModule
@end