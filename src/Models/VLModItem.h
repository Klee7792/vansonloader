/**
 * VansonLoader L2.3 - 数据模型定义
 * 兼容 VansonMod 2.4 文件格式
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 数据类型枚举 (与 VM 2.4.2 保持一致)
typedef NS_ENUM(NSInteger, VMDataType) {
    VMDataTypeI8 = 0,
    VMDataTypeI16 = 1,
    VMDataTypeI32 = 2,
    VMDataTypeI64 = 3,
    VMDataTypeU8 = 4,
    VMDataTypeU16 = 5,
    VMDataTypeU32 = 6,
    VMDataTypeU64 = 7,
    VMDataTypeF32 = 8,
    VMDataTypeF64 = 9
};

// UI 模式枚举 (与 VM 2.4 保持一致)
typedef NS_ENUM(NSInteger, VMUIMode) {
    VMUIModeCard = 0,    // 默认卡片模式
    VMUIModeSlider = 1,  // 滑块模式
    VMUIModeSwitch = 2   // 开关模式
};

// 模块类型
typedef NS_ENUM(NSInteger, VModType) {
    VModTypePointer = 0,
    VModTypeRVA = 1,
    VModTypeSignature = 2
};

#pragma mark - VLModItem

@interface VLModItem : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, assign) VModType type;
@property (nonatomic, copy) NSString *uniqueId;
@property (nonatomic, copy) NSString *note;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, assign) double createdAt;
@property (nonatomic, assign) double sortOrder;  // 排序权重，0 表示未设置（用 createdAt 兜底）
@property (nonatomic, assign) BOOL isImported;

// 指针属性
@property (nonatomic, copy) NSString *moduleName;
@property (nonatomic, assign) uint64_t baseOffset;
@property (nonatomic, strong) NSArray<NSNumber *> *offsets;
@property (nonatomic, assign) VMDataType valueType;
@property (nonatomic, assign) BOOL isEnabled;  // 是否启用（勾选状态）
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, copy) NSString *lockValue;

// UI 模式属性
@property (nonatomic, assign) VMUIMode uiMode;
@property (nonatomic, assign) float uiMin;
@property (nonatomic, assign) float uiMax;
@property (nonatomic, copy) NSString *switchOnValue;
@property (nonatomic, copy) NSString *switchOffValue;

// RVA 属性
@property (nonatomic, assign) uint64_t rvaOffset;
@property (nonatomic, copy) NSString *patchHex;
@property (nonatomic, copy) NSString *originalHex;
@property (nonatomic, assign) BOOL isPatched;

// 特征码属性
@property (nonatomic, copy) NSString *signature;
@property (nonatomic, assign) int64_t sigOffset;
@property (nonatomic, copy) NSString *resultTitle;
@property (nonatomic, copy) NSString *sigPatchHex;
@property (nonatomic, copy) NSString *sigOriginalHex;

// 运行时属性 (不持久化)
@property (nonatomic, assign) uint64_t runtimeAddress;
@property (nonatomic, strong) NSArray<NSNumber *> *multiAddresses;
@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, copy, nullable) NSString *scanError;
@property (nonatomic, strong) NSArray<NSDictionary *> *runtimeResults;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDictionary *> *resultConfig;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
+ (NSString *)typeNameForDataType:(VMDataType)type;

@end

// 兼容别名
typedef VLModItem VModItem;

NS_ASSUME_NONNULL_END
