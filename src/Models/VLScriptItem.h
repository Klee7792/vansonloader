/**
 * VansonLoader L2.3 - 脚本模型
 */

#import <Foundation/Foundation.h>

@interface VLScriptItem : NSObject <NSSecureCoding>

@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *scriptContent;
@property (nonatomic, copy) NSString *note;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, assign) BOOL isImported;
@property (nonatomic, assign) NSTimeInterval createdAt;
@property (nonatomic, assign) double sortOrder;  // 排序权重，0 表示未设置（用 createdAt 兜底）

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

// 兼容别名
typedef VLScriptItem VScriptItem;
