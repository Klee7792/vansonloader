/**
 * VansonLoader L2.3 - 内存引擎
 * In-Process 内存读写
 */

#import <Foundation/Foundation.h>
#import "../Models/VLModItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface VLModEngine : NSObject

+ (instancetype)shared;

#pragma mark - 模块操作

/**
 * 获取模块基址
 * @param name 模块名，nil 或 "virtual" 表示主程序
 */
- (uint64_t)getModuleBase:(nullable NSString *)name;

/**
 * 获取模块大小
 */
- (uint64_t)getModuleSize:(nullable NSString *)name;

#pragma mark - 内存读写

/**
 * 读取内存
 */
- (nullable NSData *)readMemory:(uint64_t)address length:(size_t)length;

/**
 * 写入内存
 */
- (BOOL)writeMemory:(uint64_t)address data:(NSData *)data;

#pragma mark - 指针链操作

/**
 * 解析指针链，返回最终地址
 */
- (uint64_t)resolvePointerChain:(VModItem *)item;

/**
 * 读取指针值
 */
- (nullable NSString *)readPointerValue:(VModItem *)item;

/**
 * 写入指针值
 */
- (BOOL)writePointerValue:(VModItem *)item value:(NSString *)value;

#pragma mark - RVA 操作

/**
 * 切换 RVA 补丁状态
 */
- (BOOL)toggleRVAPatch:(VModItem *)item;

/**
 * 检查 RVA 是否已激活
 */
- (BOOL)isRVAActive:(VModItem *)item;

#pragma mark - 特征码搜索

/**
 * 搜索特征码
 * @param signature 特征码字符串 (支持 ?? 通配符)
 * @param moduleName 模块名
 * @return 匹配地址数组
 */
- (NSArray<NSNumber *> *)searchSignature:(NSString *)signature inModule:(nullable NSString *)moduleName;

/**
 * 解析特征码项目的运行时地址
 */
- (uint64_t)resolveSignatureAddress:(VModItem *)item;

/**
 * 读取特征码项目的值
 */
- (nullable NSString *)readSignatureValue:(VModItem *)item;

/**
 * 写入特征码项目的值
 */
- (BOOL)writeSignatureValue:(VModItem *)item value:(NSString *)value;

/**
 * 切换特征码 Patch
 */
- (BOOL)toggleSignaturePatch:(VModItem *)item;

/**
 * 通用切换方法 (RVA 或 Signature)
 */
- (BOOL)toggleRVA:(VModItem *)item;

#pragma mark - 锁定循环

/**
 * 更新所有锁定项
 */
- (void)updateLocks;

@end

// Backward compatibility
typedef VLModEngine VModEngine;

NS_ASSUME_NONNULL_END
