/**
 * VansonLoader L2.3 - 工具页
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLTools : NSObject

+ (void)setupToolsView:(UIView *)container panel:(id)panel;
+ (void)showLanguagePicker;
+ (void)clkSub;
+ (void)clkAdd;
+ (void)clkPt;
+ (void)clkUndo;
+ (void)clkToggle;
+ (void)onTouchModeToggle:(UISwitch *)toggle;

@end

// 连点器管理
@interface VLClickerManager : NSObject
+ (instancetype)shared;
- (void)addPoint;
- (void)removeLastPoint;
- (void)toggleStart;
- (void)updateInterval;
- (void)hideAllPoints:(BOOL)hidden;
@end

// Dump 管理
@interface VLDumpManager : NSObject
+ (void)dumpUnityFiles;
@end

// 兼容别名
typedef VLTools VTools;
typedef VLClickerManager VClickerManager;
typedef VLDumpManager VDumpManager;

NS_ASSUME_NONNULL_END
