/**
 * VansonLoader L2.3 - 模块化 Cell
 * 支持三种 UI 模式: Card / Slider / Switch
 * 支持特征码多地址展示
 */

#import <UIKit/UIKit.h>
#import "../Models/VLModItem.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VLModCellDelegate <NSObject>
// 指针/RVA 操作
- (void)cellDidRequestEdit:(VLModItem *)item;
- (void)cellDidToggleLock:(VLModItem *)item isLocked:(BOOL)locked;
- (void)cellDidToggleEnabled:(VLModItem *)item isEnabled:(BOOL)enabled;
- (void)cellDidToggleRVA:(VLModItem *)item;
- (void)cellDidChangeSlider:(VLModItem *)item value:(float)value;
- (void)cellDidToggleSwitch:(VLModItem *)item isOn:(BOOL)isOn;

// 特征码操作
- (void)cellDidRequestMatch:(VLModItem *)item;
- (void)cellDidClickResultValue:(VLModItem *)item atIndex:(NSInteger)index address:(uint64_t)addr currentValue:(NSString *)val;
- (void)cellDidChangeModeSegment:(VLModItem *)item atIndex:(NSInteger)index mode:(VMUIMode)mode;
- (void)cellDidChangeResultSlider:(VLModItem *)item atIndex:(NSInteger)index value:(NSString *)value;
- (void)cellDidChangeResultSwitch:(VLModItem *)item atIndex:(NSInteger)index isOn:(BOOL)isOn;
@end

@interface VLModCell : UITableViewCell

@property (nonatomic, weak) id<VLModCellDelegate> delegate;
@property (nonatomic, strong, readonly) VLModItem *item;

- (void)configureWithItem:(VLModItem *)item currentValue:(nullable NSString *)value;
- (void)updateValue:(NSString *)value;

@end

// 兼容别名
typedef VLModCell VModCell;
#define VModCellDelegate VLModCellDelegate

NS_ASSUME_NONNULL_END
