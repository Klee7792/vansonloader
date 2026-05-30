/**
 * VansonLoader L2.3 - 配置解析器
 * 支持 VM 2.4 加密格式 + vmsc 脚本
 */

#import <Foundation/Foundation.h>
#import "../Models/VLModItem.h"

@class VLScriptItem;

NS_ASSUME_NONNULL_BEGIN

// 全局数据源声明
extern NSMutableArray<VLModItem *> *g_ptrItems;
extern NSMutableArray<VLModItem *> *g_rvaItems;
extern NSMutableArray<VLModItem *> *g_sigItems;
extern NSMutableArray<VLScriptItem *> *g_scriptItems;

@interface VLModParser : NSObject

/**
 * 加载保存的配置
 */
+ (void)loadConfig;

/**
 * 保存配置
 */
+ (void)saveConfig;

/**
 * 导入 VM 2.4 格式文件
 * @param data 文件数据
 * @return 导入的项目数量，-1 表示失败
 */
+ (NSInteger)importVM24Data:(NSData *)data;

/**
 * 导入脚本
 */
+ (NSInteger)importScriptFromDict:(NSDictionary *)dict;

/**
 * 导入数据 (兼容接口)
 */
+ (BOOL)importData:(NSData *)data;

/**
 * 清空所有配置
 */
+ (void)clearAllConfig;

@end

// Backward compatibility
typedef VLModParser VModParser;

NS_ASSUME_NONNULL_END
