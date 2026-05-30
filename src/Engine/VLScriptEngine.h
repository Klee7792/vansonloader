/**
 * VansonLoader L2.3 - 脚本执行引擎
 * 基于 JavaScriptCore，兼容 H5GG API
 */

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

// JS 导出协议
@protocol VLScriptExports <JSExport>

// 基础功能
- (void)log:(NSString *)msg;
- (void)toast:(NSString *)msg;
- (void)sleep:(double)seconds;

// 搜索功能
JSExportAs(search, -(NSUInteger)search:(NSString *)val type:(NSString *)type from:(NSString *)start to:(NSString *)end);
JSExportAs(searchGroup, -(NSUInteger)searchGroup:(NSString *)val type:(NSString *)type from:(NSString *)start to:(NSString *)end);
JSExportAs(searchBetween, -(NSUInteger)searchBetween:(NSString *)minVal max:(NSString *)maxVal type:(NSString *)type);
JSExportAs(refine, -(void)refine:(NSString *)val type:(NSString *)type mode:(NSString *)mode);

// 结果操作
- (long)getResultsCount;
- (long)count;
JSExportAs(getResults, -(NSArray *)getResults:(int)count skip:(int)skip);
- (void)clear;

// 读写操作
JSExportAs(getValue, -(NSString *)getValue:(NSString *)addrStr type:(NSString *)type);
JSExportAs(setValue, -(BOOL)setValue:(NSString *)addrStr val:(NSString *)val type:(NSString *)type);
JSExportAs(editAll, -(void)editAll:(NSString *)val type:(NSString *)type filter:(NSString *)filter);
JSExportAs(writeAll, -(void)writeAll:(NSString *)val type:(NSString *)type);

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

// Backward compatibility
typedef NSObject<VLScriptExports> VScriptExports;

@interface VLScriptEngine : NSObject <VLScriptExports>

+ (instancetype)shared;

// 执行脚本
- (void)runScript:(NSString *)script
       completion:(void (^)(NSString *log))completion;

// 停止执行
- (void)stopExecution;

@end

// Backward compatibility
typedef VLScriptEngine VScriptEngine;
