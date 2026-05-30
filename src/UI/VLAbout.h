/**
 * VansonLoader L2.3 - 关于页
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLAbout : NSObject

+ (void)setupAboutView:(UIView *)container;
+ (void)setupAboutView:(UIView *)container fullMode:(BOOL)fullMode;
+ (void)loadLogoIntoView:(UIView *)logoBox size:(CGFloat)logoSize;
+ (void)checkDisclaimerOnLaunch;
+ (void)onDisclaimerTapped;

@end

// 兼容别名
typedef VLAbout VAbout;

NS_ASSUME_NONNULL_END
