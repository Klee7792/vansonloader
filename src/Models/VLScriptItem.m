/**
 * VansonLoader L2.3 - 脚本模型实现
 */

#import "VLScriptItem.h"

@implementation VLScriptItem

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    if (self = [super init]) {
        _createdAt = [[NSDate date] timeIntervalSince1970];
        _scriptContent = @"";
        _author = @"VansonMod";
        _desc = @"VansonMod Script";
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_fileName forKey:@"fn"];
    [coder encodeObject:_bundleID forKey:@"bid"];
    [coder encodeObject:_scriptContent forKey:@"src"];
    [coder encodeObject:_note forKey:@"note"];
    [coder encodeObject:_desc forKey:@"desc"];
    [coder encodeObject:_author forKey:@"auth"];
    [coder encodeBool:_isImported forKey:@"isImported"];
    [coder encodeDouble:_createdAt forKey:@"date"];
    [coder encodeDouble:_sortOrder forKey:@"sortOrder"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _fileName = [coder decodeObjectOfClass:[NSString class] forKey:@"fn"];
        _bundleID = [coder decodeObjectOfClass:[NSString class] forKey:@"bid"];
        _scriptContent = [coder decodeObjectOfClass:[NSString class] forKey:@"src"];
        _note = [coder decodeObjectOfClass:[NSString class] forKey:@"note"];
        _desc = [coder decodeObjectOfClass:[NSString class] forKey:@"desc"];
        _author = [coder decodeObjectOfClass:[NSString class] forKey:@"auth"];
        _isImported = [coder decodeBoolForKey:@"isImported"];
        _createdAt = [coder decodeDoubleForKey:@"date"];
        _sortOrder = [coder decodeDoubleForKey:@"sortOrder"];
        
        if (!_desc) _desc = @"VansonMod Script";
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"type": @"script",
        @"fn": _fileName ?: @"",
        @"bid": _bundleID ?: @"",
        @"src": _scriptContent ?: @"",
        @"note": _note ?: @"",
        @"desc": _desc ?: @"",
        @"auth": _author ?: @"",
        @"isImported": @(_isImported),
        @"date": @(_createdAt),
        @"sortOrder": @(_sortOrder)
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    VLScriptItem *item = [[VLScriptItem alloc] init];
    item.fileName = dict[@"fn"];
    item.bundleID = dict[@"bid"];
    item.scriptContent = dict[@"src"];
    item.note = dict[@"note"];
    item.desc = dict[@"desc"];
    if (!item.desc || item.desc.length == 0) {
        item.desc = @"VansonMod Script";
    }
    item.author = dict[@"auth"];
    item.isImported = [dict[@"isImported"] boolValue];
    item.createdAt = [dict[@"date"] doubleValue];
    item.sortOrder = [dict[@"sortOrder"] doubleValue];
    return item;
}

@end
