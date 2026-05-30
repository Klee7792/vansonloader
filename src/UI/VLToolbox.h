/**
 * VansonLoader L2.3 - VLToolbox
 * 工具箱悬浮容器 (内存、指针、RVA、特征码、脚本)
 * 独立于主面板，Tab 常驻显示
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 工具箱面板
@interface VLToolbox : NSObject
+ (void)show;
+ (void)showMinimized;  // 直接显示为悬浮图标
+ (void)hide;
+ (void)toggle;
+ (BOOL)isVisible;
+ (void)reloadData;
@end

NS_ASSUME_NONNULL_END
