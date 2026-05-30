/**
 * VansonLoader L2.3 - Script Manager
 * 脚本执行引擎 (H5GG 兼容)
 */

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VLScriptManagerExports <JSExport>

// 日志
- (void)log:(NSString *)msg;
- (void)toast:(NSString *)msg;
- (void)sleep:(double)seconds;

// 配置
- (void)setFloatTolerance:(double)tolerance;
- (void)setBaseAddress:(NSString *)addrStr;

// 搜索
- (NSUInteger)search:(NSString *)val type:(NSString *)typeStr from:(nullable NSString *)startArg to:(nullable NSString *)endArg;
- (NSUInteger)searchGroup:(NSString *)val type:(NSString *)typeStr from:(nullable NSString *)startArg to:(nullable NSString *)endArg;
- (NSUInteger)searchBetween:(NSString *)minVal max:(NSString *)maxVal type:(NSString *)typeStr;
- (NSUInteger)searchFuzzy:(NSString *)typeStr;
- (NSUInteger)searchSign:(NSString *)signature from:(nullable NSString *)startArg to:(nullable NSString *)endArg;
- (NSUInteger)nearby:(NSString *)val type:(NSString *)typeStr range:(double)range;

// 筛选
- (void)refine:(NSString *)val type:(NSString *)typeStr mode:(NSString *)modeStr;

// 结果
- (long)getResultsCount;
- (long)count;
- (NSArray *)getResults:(int)count skip:(int)skip;
- (NSArray *)getRangesList:(nullable NSString *)name;
- (void)clear;

// 读写
- (nullable NSString *)getValue:(NSString *)addrStr type:(NSString *)typeStr;
- (BOOL)setValue:(NSString *)addrStr val:(NSString *)val type:(NSString *)typeStr;
- (void)editAll:(NSString *)val type:(NSString *)typeStr filter:(nullable NSString *)filter;
- (void)editAll:(NSString *)val type:(NSString *)typeStr;
- (void)writeAll:(NSString *)val type:(NSString *)typeStr;
- (void)write:(NSString *)val type:(NSString *)typeStr offset:(int)index;

// 锁定
- (void)lock:(NSString *)val type:(NSString *)typeStr index:(int)index;
- (void)unlock:(int)index;
- (void)lockAll:(NSString *)val type:(NSString *)typeStr filter:(nullable NSString *)filter;
- (void)unlockAll;

// --- [v2.6] 指针链功能 ---
JSExportAs(resolvePointer,
           -(NSDictionary *)resolvePointer:(NSString *)moduleName
                                baseOffset:(NSString *)baseOffsetStr
                                   offsets:(NSArray *)offsets
                                      type:(NSString *)type);
JSExportAs(writePointer,
           -(BOOL)writePointer:(NSString *)moduleName
                    baseOffset:(NSString *)baseOffsetStr
                       offsets:(NSArray *)offsets
                           val:(NSString *)val
                          type:(NSString *)type);
JSExportAs(lockPointer,
           -(void)lockPointer:(NSString *)moduleName
                   baseOffset:(NSString *)baseOffsetStr
                      offsets:(NSArray *)offsets
                          val:(NSString *)val
                         type:(NSString *)type
                         note:(NSString *)note);

// --- [v2.6] RVA 补丁功能 ---
JSExportAs(patchRVA,
           -(BOOL)patchRVA:(NSString *)moduleName
                    offset:(NSString *)offsetStr
                  patchHex:(NSString *)patchHex);
JSExportAs(restoreRVA,
           -(BOOL)restoreRVA:(NSString *)moduleName
                      offset:(NSString *)offsetStr
                 originalHex:(NSString *)originalHex);
JSExportAs(readRVA,
           -(NSString *)readRVA:(NSString *)moduleName
                         offset:(NSString *)offsetStr
                         length:(int)length);

@end

@interface VLScriptManager : NSObject <VLScriptManagerExports>

+ (instancetype)shared;

/**
 * 执行脚本
 * @param script JavaScript 代码
 * @param completion 完成回调，返回控制台日志
 */
- (void)runScript:(NSString *)script
       completion:(void (^)(NSString *consoleLog))completion;

@end

// Backward compatibility
typedef VLScriptManager VScriptManager;

NS_ASSUME_NONNULL_END
