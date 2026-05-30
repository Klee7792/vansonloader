/**
 * VansonLoader L2.3 - File Browser
 * 文件浏览器 - 访问当前 App 数据目录
 * 支持文件导出和导入
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLFileBrowserVC : NSObject
+ (void)showFromWindow:(UIWindow *)window;
+ (void)showMinimized;
+ (void)hide;
+ (void)toggle;
+ (BOOL)isVisible;
@end

NS_ASSUME_NONNULL_END
