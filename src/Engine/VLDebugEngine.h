/**
 * VansonLoader L2.3 - Debug Engine (ObjC Bridge)
 * 硬件断点监控 ObjC 接口
 * 仅越狱环境可用
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 堆栈帧
@interface VLStackFrame : NSObject
@property (nonatomic, assign) uint64_t pc;
@property (nonatomic, copy) NSString *imageName;
@property (nonatomic, assign) uint64_t imageBase;
@property (nonatomic, assign) uint64_t offset;
@end

// 断点触发记录
@interface VLWatchHit : NSObject
@property (nonatomic, assign) uint32_t slotIndex;
@property (nonatomic, assign) uint64_t pc;
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) uint64_t newValue;
@property (nonatomic, copy) NSString *imageName;
@property (nonatomic, assign) uint64_t offset;
@property (nonatomic, strong) NSArray<VLStackFrame *> *stackTrace;
@property (nonatomic, assign) double timestamp;
@end

// 监控类型
typedef NS_ENUM(NSUInteger, VLWatchType) {
    VLWatchTypeWrite = 0,
    VLWatchTypeRead = 1,
    VLWatchTypeReadWrite = 2
};

// 监控大小
typedef NS_ENUM(NSUInteger, VLWatchSize) {
    VLWatchSizeByte1 = 0,
    VLWatchSizeByte2 = 1,
    VLWatchSizeByte4 = 2,
    VLWatchSizeByte8 = 3
};

// 触发回调
typedef void (^VLWatchHitBlock)(VLWatchHit *hit);

@interface VLDebugEngine : NSObject

+ (instancetype)shared;

// 环境检测
+ (BOOL)isAvailable;  // 是否越狱环境

// 生命周期
- (BOOL)attach;
- (void)detach;
@property (nonatomic, readonly) BOOL isAttached;

// 断点管理
- (int)addWatchpoint:(uint64_t)address
                type:(VLWatchType)type
                size:(VLWatchSize)size;
- (BOOL)removeWatchpoint:(uint32_t)index;
- (void)removeAllWatchpoints;

// 状态
@property (nonatomic, readonly) uint32_t activeCount;
@property (nonatomic, readonly) uint32_t maxSlots;

// 单个槽位查询
- (BOOL)isSlotActive:(uint32_t)index;
- (uint64_t)slotAddress:(uint32_t)index;

// 触发记录
- (NSArray<VLWatchHit *> *)hitsForSlot:(uint32_t)index;
- (void)clearHitsForSlot:(uint32_t)index;
- (void)clearAllHits;

// 回调
@property (nonatomic, copy, nullable) VLWatchHitBlock hitCallback;

// 反汇编
- (NSArray<NSDictionary *> *)disassembleAt:(uint64_t)address
                               countBefore:(uint32_t)before
                                countAfter:(uint32_t)after
                                moduleName:(nullable NSString *)moduleName;

// 函数级反汇编 (自动扫描 prologue/epilogue，上限 1024 条)
- (NSArray<NSDictionary *> *)disassembleFunctionAt:(uint64_t)pc
                                        moduleName:(nullable NSString *)moduleName;

// 运行时补丁 (配合 RVA 工具箱)
- (BOOL)applyPatchAtOffset:(uint64_t)offset
                    hexCode:(NSString *)hex
                 moduleName:(nullable NSString *)moduleName
              backupOriginal:(NSString *_Nullable *_Nullable)outOriginal;

- (BOOL)restorePatchAtOffset:(uint64_t)offset
                  originalHex:(NSString *)originalHex
                   moduleName:(nullable NSString *)moduleName;

@end

NS_ASSUME_NONNULL_END
