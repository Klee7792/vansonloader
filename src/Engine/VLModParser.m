/**
 * VansonLoader L2.3 - 配置解析器实现
 */

#import "VLModParser.h"
#import "../Models/VLScriptItem.h"

static NSString *const kPtrItemsKey = @"Vanson_PtrItems_L21";
static NSString *const kRvaItemsKey = @"Vanson_RvaItems_L21";
static NSString *const kSigItemsKey = @"Vanson_SigItems_L21";
static NSString *const kScriptItemsKey = @"Vanson_ScriptItems_L23";

// 脚本数据
NSMutableArray<VLScriptItem *> *g_scriptItems = nil;

@implementation VLModParser

+ (void)loadConfig {
    // 初始化数组
    if (!g_ptrItems) g_ptrItems = [NSMutableArray array];
    if (!g_rvaItems) g_rvaItems = [NSMutableArray array];
    if (!g_sigItems) g_sigItems = [NSMutableArray array];
    if (!g_scriptItems) g_scriptItems = [NSMutableArray array];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 加载指针
    NSData *ptrData = [defaults dataForKey:kPtrItemsKey];
    if (ptrData) {
        @try {
            NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [VModItem class], nil];
            NSMutableArray *items = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:ptrData error:nil];
            if (items) g_ptrItems = items;
        } @catch (NSException *e) {}
    }
    
    // 加载 RVA
    NSData *rvaData = [defaults dataForKey:kRvaItemsKey];
    if (rvaData) {
        @try {
            NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [VModItem class], nil];
            NSMutableArray *items = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:rvaData error:nil];
            if (items) g_rvaItems = items;
        } @catch (NSException *e) {}
    }
    
    // 加载特征码
    NSData *sigData = [defaults dataForKey:kSigItemsKey];
    if (sigData) {
        @try {
            NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [VModItem class], nil];
            NSMutableArray *items = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:sigData error:nil];
            if (items) g_sigItems = items;
        } @catch (NSException *e) {}
    }
    
    // 加载脚本
    NSData *scriptData = [defaults dataForKey:kScriptItemsKey];
    if (scriptData) {
        @try {
            NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [VScriptItem class], nil];
            NSMutableArray *items = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:scriptData error:nil];
            if (items) g_scriptItems = items;
        } @catch (NSException *e) {}
    }
    
    // sortOrder 兜底：未设置的用 createdAt 填充，然后按 sortOrder 排序
    [self normalizeSortOrder];
}

+ (void)normalizeSortOrder {
    // VLModItem: sortOrder == 0 表示未设置，用 createdAt 兜底
    for (VLModItem *item in g_ptrItems) {
        if (item.sortOrder == 0) item.sortOrder = item.createdAt;
    }
    for (VLModItem *item in g_rvaItems) {
        if (item.sortOrder == 0) item.sortOrder = item.createdAt;
    }
    for (VLModItem *item in g_sigItems) {
        if (item.sortOrder == 0) item.sortOrder = item.createdAt;
    }
    for (VLScriptItem *item in g_scriptItems) {
        if (item.sortOrder == 0) item.sortOrder = item.createdAt;
    }
    
    // 按 sortOrder 升序排序
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES];
    [g_ptrItems sortUsingDescriptors:@[sd]];
    [g_rvaItems sortUsingDescriptors:@[sd]];
    [g_sigItems sortUsingDescriptors:@[sd]];
    [g_scriptItems sortUsingDescriptors:@[sd]];
}

+ (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    @try {
        if (g_ptrItems) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:g_ptrItems requiringSecureCoding:YES error:nil];
            [defaults setObject:data forKey:kPtrItemsKey];
        }
        
        if (g_rvaItems) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:g_rvaItems requiringSecureCoding:YES error:nil];
            [defaults setObject:data forKey:kRvaItemsKey];
        }
        
        if (g_sigItems) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:g_sigItems requiringSecureCoding:YES error:nil];
            [defaults setObject:data forKey:kSigItemsKey];
        }
        
        if (g_scriptItems) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:g_scriptItems requiringSecureCoding:YES error:nil];
            [defaults setObject:data forKey:kScriptItemsKey];
        }
        
        [defaults synchronize];
    } @catch (NSException *e) {}
}

+ (NSInteger)importVM24Data:(NSData *)fileData {
    if (!fileData || fileData.length == 0) return -1;
    
    // 解析 JSON
    NSError *error;
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&error];
    if (!root || error) return -1;
    
    // 检查是否为脚本类型
    NSString *type = root[@"type"];
    if ([type isEqualToString:@"script"]) {
        return [self importScriptFromDict:root];
    }
    
    NSArray *dataItems = root[@"dataItems"];
    if (!dataItems || ![dataItems isKindOfClass:[NSArray class]]) return -1;
    
    NSInteger count = 0;
    
    for (NSDictionary *dict in dataItems) {
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        
        // 检查是否为脚本项
        NSString *itemType = dict[@"type"];
        if ([itemType isEqualToString:@"script"]) {
            if ([self importScriptFromDict:dict] > 0) count++;
            continue;
        }
        
        VModItem *item = [VModItem fromDictionary:dict];
        if (!item) continue;
        
        // 根据类型添加到对应数组
        switch (item.type) {
            case VModTypePointer:
                if (!g_ptrItems) g_ptrItems = [NSMutableArray array];
                [g_ptrItems addObject:item];
                count++;
                break;
                
            case VModTypeRVA:
                if (!g_rvaItems) g_rvaItems = [NSMutableArray array];
                [g_rvaItems addObject:item];
                count++;
                break;
                
            case VModTypeSignature:
                if (!g_sigItems) g_sigItems = [NSMutableArray array];
                [g_sigItems addObject:item];
                count++;
                break;
        }
    }
    
    if (count > 0) {
        [self saveConfig];
    }
    
    return count;
}

+ (NSInteger)importScriptFromDict:(NSDictionary *)dict {
    if (!dict) return 0;
    
    VScriptItem *script = [VScriptItem fromDictionary:dict];
    if (!script || !script.scriptContent || script.scriptContent.length == 0) {
        return 0;
    }
    
    script.isImported = YES;
    
    if (!g_scriptItems) g_scriptItems = [NSMutableArray array];
    [g_scriptItems addObject:script];
    [self saveConfig];
    
    return 1;
}

+ (void)clearAllConfig {
    g_ptrItems = [NSMutableArray array];
    g_rvaItems = [NSMutableArray array];
    g_sigItems = [NSMutableArray array];
    g_scriptItems = [NSMutableArray array];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kPtrItemsKey];
    [defaults removeObjectForKey:kRvaItemsKey];
    [defaults removeObjectForKey:kSigItemsKey];
    [defaults removeObjectForKey:kScriptItemsKey];
    [defaults synchronize];
}

+ (BOOL)importData:(NSData *)data {
    return [self importVM24Data:data] > 0;
}

@end
