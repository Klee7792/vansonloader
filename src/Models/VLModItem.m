/**
 * VansonLoader L2.3 - 数据模型实现
 */

#import "VLModItem.h"

@implementation VLModItem

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)init {
  if (self = [super init]) {
    _uniqueId = [[NSUUID UUID] UUIDString];
    _createdAt = [[NSDate date] timeIntervalSince1970];
    _valueType = VMDataTypeI32;
    _uiMode = VMUIModeCard;
    _uiMin = 0;
    _uiMax = 1000;
    _switchOnValue = @"1";
    _switchOffValue = @"0";
    _isEnabled = YES;  // 默认启用
    _runtimeResults = @[];
    _resultConfig = [NSMutableDictionary dictionary];
  }
  return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeInteger:self.type forKey:@"type"];
  [coder encodeObject:self.uniqueId forKey:@"uniqueId"];
  [coder encodeObject:self.note forKey:@"note"];
  [coder encodeObject:self.author forKey:@"author"];
  [coder encodeObject:self.bundleID forKey:@"bundleID"];
  [coder encodeObject:self.appName forKey:@"appName"];
  [coder encodeObject:self.appVersion forKey:@"appVersion"];
  [coder encodeDouble:self.createdAt forKey:@"createdAt"];
  [coder encodeDouble:self.sortOrder forKey:@"sortOrder"];
  [coder encodeBool:self.isImported forKey:@"isImported"];

  [coder encodeObject:self.moduleName forKey:@"moduleName"];
  [coder encodeInt64:self.baseOffset forKey:@"baseOffset"];
  [coder encodeObject:self.offsets forKey:@"offsets"];
  [coder encodeInteger:self.valueType forKey:@"valueType"];
  [coder encodeBool:self.isEnabled forKey:@"isEnabled"];
  [coder encodeBool:self.isLocked forKey:@"isLocked"];
  [coder encodeObject:self.lockValue forKey:@"lockValue"];

  [coder encodeInteger:self.uiMode forKey:@"uiMode"];
  [coder encodeFloat:self.uiMin forKey:@"uiMin"];
  [coder encodeFloat:self.uiMax forKey:@"uiMax"];
  [coder encodeObject:self.switchOnValue forKey:@"switchOnValue"];
  [coder encodeObject:self.switchOffValue forKey:@"switchOffValue"];

  [coder encodeInt64:self.rvaOffset forKey:@"rvaOffset"];
  [coder encodeObject:self.patchHex forKey:@"patchHex"];
  [coder encodeObject:self.originalHex forKey:@"originalHex"];
  [coder encodeBool:self.isPatched forKey:@"isPatched"];

  [coder encodeObject:self.signature forKey:@"signature"];
  [coder encodeInt64:self.sigOffset forKey:@"sigOffset"];
  [coder encodeObject:self.resultTitle forKey:@"resultTitle"];
  [coder encodeObject:self.sigPatchHex forKey:@"sigPatchHex"];
  [coder encodeObject:self.sigOriginalHex forKey:@"sigOriginalHex"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  if (self = [super init]) {
    _type = [coder decodeIntegerForKey:@"type"];
    _uniqueId = [coder decodeObjectOfClass:[NSString class] forKey:@"uniqueId"];
    _note = [coder decodeObjectOfClass:[NSString class] forKey:@"note"];
    _author = [coder decodeObjectOfClass:[NSString class] forKey:@"author"];
    _bundleID = [coder decodeObjectOfClass:[NSString class] forKey:@"bundleID"];
    _appName = [coder decodeObjectOfClass:[NSString class] forKey:@"appName"];
    _appVersion = [coder decodeObjectOfClass:[NSString class] forKey:@"appVersion"];
    _createdAt = [coder decodeDoubleForKey:@"createdAt"];
    _sortOrder = [coder decodeDoubleForKey:@"sortOrder"];
    _isImported = [coder decodeBoolForKey:@"isImported"];

    _moduleName = [coder decodeObjectOfClass:[NSString class] forKey:@"moduleName"];
    _baseOffset = [coder decodeInt64ForKey:@"baseOffset"];
    _offsets = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSNumber class], nil] forKey:@"offsets"];
    _valueType = [coder decodeIntegerForKey:@"valueType"];
    _isEnabled = [coder containsValueForKey:@"isEnabled"] ? [coder decodeBoolForKey:@"isEnabled"] : YES;
    _isLocked = [coder decodeBoolForKey:@"isLocked"];
    _lockValue = [coder decodeObjectOfClass:[NSString class] forKey:@"lockValue"];

    _uiMode = [coder decodeIntegerForKey:@"uiMode"];
    _uiMin = [coder decodeFloatForKey:@"uiMin"];
    _uiMax = [coder decodeFloatForKey:@"uiMax"];
    _switchOnValue = [coder decodeObjectOfClass:[NSString class] forKey:@"switchOnValue"];
    _switchOffValue = [coder decodeObjectOfClass:[NSString class] forKey:@"switchOffValue"];

    _rvaOffset = [coder decodeInt64ForKey:@"rvaOffset"];
    _patchHex = [coder decodeObjectOfClass:[NSString class] forKey:@"patchHex"];
    _originalHex = [coder decodeObjectOfClass:[NSString class] forKey:@"originalHex"];
    _isPatched = [coder decodeBoolForKey:@"isPatched"];

    _signature = [coder decodeObjectOfClass:[NSString class] forKey:@"signature"];
    _sigOffset = [coder decodeInt64ForKey:@"sigOffset"];
    _resultTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"resultTitle"];
    _sigPatchHex = [coder decodeObjectOfClass:[NSString class] forKey:@"sigPatchHex"];
    _sigOriginalHex = [coder decodeObjectOfClass:[NSString class] forKey:@"sigOriginalHex"];

    _runtimeResults = @[];
    _resultConfig = [NSMutableDictionary dictionary];
  }
  return self;
}

#pragma mark - Dictionary Conversion

- (NSDictionary *)toDictionary {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  if (self.uniqueId) dict[@"uniqueId"] = self.uniqueId;
  if (self.note) dict[@"note"] = self.note;
  if (self.author) dict[@"author"] = self.author;
  if (self.bundleID) dict[@"bundleID"] = self.bundleID;
  if (self.appName) dict[@"appName"] = self.appName;
  if (self.appVersion) dict[@"appVersion"] = self.appVersion;
  dict[@"createdAt"] = @(self.createdAt);
  dict[@"sortOrder"] = @(self.sortOrder);
  dict[@"isImported"] = @(self.isImported);

  if (self.type == VModTypePointer) {
    dict[@"type"] = @"pointer";
    if (self.moduleName) dict[@"moduleName"] = self.moduleName;
    dict[@"baseOffset"] = @(self.baseOffset);
    if (self.offsets) dict[@"offsets"] = self.offsets;
    dict[@"lockType"] = @(self.valueType);
    dict[@"isEnabled"] = @(self.isEnabled);
    dict[@"lockEnabled"] = @(self.isLocked);
    if (self.lockValue) dict[@"lockValue"] = self.lockValue;
    dict[@"uiMode"] = @(self.uiMode);
    dict[@"uiMin"] = @(self.uiMin);
    dict[@"uiMax"] = @(self.uiMax);
    if (self.switchOnValue) dict[@"switchOnValue"] = self.switchOnValue;
    if (self.switchOffValue) dict[@"switchOffValue"] = self.switchOffValue;
  } else if (self.type == VModTypeRVA) {
    dict[@"type"] = @"rva";
    if (self.moduleName) dict[@"moduleName"] = self.moduleName;
    dict[@"offset"] = @(self.rvaOffset);
    if (self.patchHex) dict[@"patchHex"] = self.patchHex;
    if (self.originalHex) dict[@"originalHex"] = self.originalHex;
    dict[@"isOn"] = @(self.isPatched);
  } else if (self.type == VModTypeSignature) {
    dict[@"type"] = @"signature";
    if (self.signature) dict[@"signature"] = self.signature;
    if (self.moduleName) dict[@"moduleName"] = self.moduleName;
    dict[@"offset"] = @(self.sigOffset);
    dict[@"lockType"] = @(self.valueType);
    if (self.resultTitle) dict[@"resultTitle"] = self.resultTitle;
    if (self.sigPatchHex) dict[@"patchHex"] = self.sigPatchHex;
    if (self.sigOriginalHex) dict[@"originalHex"] = self.sigOriginalHex;
    dict[@"uiMode"] = @(self.uiMode);
    dict[@"uiMin"] = @(self.uiMin);
    dict[@"uiMax"] = @(self.uiMax);
    if (self.switchOnValue) dict[@"switchOnValue"] = self.switchOnValue;
    if (self.switchOffValue) dict[@"switchOffValue"] = self.switchOffValue;
  }

  return dict;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
  if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;

  VLModItem *item = [[VLModItem alloc] init];

  item.uniqueId = dict[@"uniqueId"] ?: [[NSUUID UUID] UUIDString];
  item.note = dict[@"note"];
  item.author = dict[@"author"];
  item.bundleID = dict[@"bundleID"];
  item.appName = dict[@"appName"];
  item.appVersion = dict[@"appVersion"];
  item.createdAt = [dict[@"createdAt"] doubleValue];
  item.sortOrder = [dict[@"sortOrder"] doubleValue];
  item.isImported = [dict[@"isImported"] boolValue];

  NSString *typeStr = dict[@"type"];
  NSString *valType = [[dict[@"valType"] description] lowercaseString];

  if ([typeStr isEqualToString:@"pointer"]) {
    item.type = VModTypePointer;
    item.moduleName = dict[@"moduleName"];
    item.baseOffset = [dict[@"baseOffset"] unsignedLongLongValue];
    item.offsets = dict[@"offsets"];
    item.valueType = [dict[@"lockType"] integerValue];
    item.isEnabled = dict[@"isEnabled"] ? [dict[@"isEnabled"] boolValue] : YES;
    item.isLocked = [dict[@"lockEnabled"] boolValue];
    item.lockValue = dict[@"lockValue"];
    item.uiMode = [dict[@"uiMode"] integerValue];
    item.uiMin = dict[@"uiMin"] ? [dict[@"uiMin"] floatValue] : 0;
    item.uiMax = dict[@"uiMax"] ? [dict[@"uiMax"] floatValue] : 1000;
    item.switchOnValue = dict[@"switchOnValue"] ?: @"1";
    item.switchOffValue = dict[@"switchOffValue"] ?: @"0";
    if ([valType isEqualToString:@"slider"]) {
      item.uiMode = VMUIModeSlider;
    } else if ([valType isEqualToString:@"switch"]) {
      item.uiMode = VMUIModeSwitch;
    } else if ([valType isEqualToString:@"card"] || [valType isEqualToString:@"input"]) {
      item.uiMode = VMUIModeCard;
    }
  } else if ([typeStr isEqualToString:@"rva"]) {
    item.type = VModTypeRVA;
    item.moduleName = dict[@"moduleName"];
    item.rvaOffset = [dict[@"offset"] unsignedLongLongValue];
    item.patchHex = dict[@"patchHex"];
    item.originalHex = dict[@"originalHex"];
    item.isPatched = [dict[@"isOn"] boolValue];
  } else if ([typeStr isEqualToString:@"signature"]) {
    item.type = VModTypeSignature;
    item.signature = dict[@"signature"];
    item.moduleName = dict[@"moduleName"];
    item.sigOffset = [dict[@"offset"] longLongValue];
    item.valueType = [dict[@"lockType"] integerValue];
    item.resultTitle = dict[@"resultTitle"];
    item.sigPatchHex = dict[@"patchHex"];
    item.sigOriginalHex = dict[@"originalHex"];
    item.uiMode = [dict[@"uiMode"] integerValue];
    item.uiMin = dict[@"uiMin"] ? [dict[@"uiMin"] floatValue] : 0;
    item.uiMax = dict[@"uiMax"] ? [dict[@"uiMax"] floatValue] : 1000;
    item.switchOnValue = dict[@"switchOnValue"] ?: @"1";
    item.switchOffValue = dict[@"switchOffValue"] ?: @"0";
  }

  return item;
}

+ (NSString *)typeNameForDataType:(VMDataType)type {
  switch (type) {
    case VMDataTypeI8: return @"I8";
    case VMDataTypeI16: return @"I16";
    case VMDataTypeI32: return @"I32";
    case VMDataTypeI64: return @"I64";
    case VMDataTypeU8: return @"U8";
    case VMDataTypeU16: return @"U16";
    case VMDataTypeU32: return @"U32";
    case VMDataTypeU64: return @"U64";
    case VMDataTypeF32: return @"F32";
    case VMDataTypeF64: return @"F64";
    default: return @"??";
  }
}

@end
