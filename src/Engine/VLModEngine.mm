/**
 * VansonLoader L2.3 - 内存引擎实现 (ObjC++ Bridge)
 * 使用 C++ 核心实现，ObjC 接口保持不变
 */

#import "VLModEngine.h"
#import "../Core/VLCore.hpp"
#import "../Utils/VLCrypto.h"
#import "../Utils/VLLocalization.h"

// 全局数据源 (在 Tweak.x 中定义)
extern NSMutableArray<VLModItem *> *g_ptrItems;
extern NSMutableArray<VLModItem *> *g_rvaItems;
extern NSMutableArray<VLModItem *> *g_sigItems;

@implementation VLModEngine

+ (instancetype)shared {
  static VLModEngine *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[VLModEngine alloc] init];
  });
  return instance;
}

#pragma mark - 模块操作

- (uint64_t)getModuleBase:(NSString *)name {
  return vcore::MemEngine::inst().modBase(name ? name.UTF8String : nullptr);
}

- (uint64_t)getModuleSize:(NSString *)name {
  return vcore::MemEngine::inst().modSize(name ? name.UTF8String : nullptr);
}

#pragma mark - 内存读写

- (NSData *)readMemory:(uint64_t)address length:(size_t)length {
  if (address == 0 || length == 0)
    return nil;

  void *buffer = malloc(length);
  if (!buffer)
    return nil;

  if (vcore::MemEngine::inst().readMem(address, buffer, length)) {
    return [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];
  }

  free(buffer);
  return nil;
}

- (BOOL)writeMemory:(uint64_t)address data:(NSData *)data {
  if (address == 0 || !data || data.length == 0)
    return NO;
  return vcore::MemEngine::inst().writeMem(address, data.bytes, data.length);
}

#pragma mark - 指针链操作

- (uint64_t)resolvePointerChain:(VModItem *)item {
  if (!item)
    return 0;

  uint64_t base = vcore::MemEngine::inst().modBase(
      item.moduleName ? item.moduleName.UTF8String : nullptr);
  if (base == 0)
    return 0;

  NSArray<NSNumber *> *offsets = item.offsets;
  if (!offsets || offsets.count == 0) {
    return base + item.baseOffset;
  }

  // 转换 offsets 为 C 数组
  size_t count = offsets.count;
  int64_t *offs = (int64_t *)malloc(count * sizeof(int64_t));
  if (!offs)
    return 0;

  for (size_t i = 0; i < count; i++) {
    offs[i] = [offsets[i] longLongValue];
  }

  uint64_t result =
      vcore::MemEngine::inst().resolveChain(base, item.baseOffset, offs, count);
  free(offs);

  return result;
}

- (NSString *)readPointerValue:(VModItem *)item {
  if (!item)
    return @"(Err)";

  uint64_t addr = [self resolvePointerChain:item];
  if (addr == 0)
    return @"(Null)";

  vcore::DataType dt;
  switch (item.valueType) {
  case VMDataTypeI8:
    dt = vcore::DT_I8;
    break;
  case VMDataTypeI16:
    dt = vcore::DT_I16;
    break;
  case VMDataTypeI32:
    dt = vcore::DT_I32;
    break;
  case VMDataTypeI64:
    dt = vcore::DT_I64;
    break;
  case VMDataTypeU8:
    dt = vcore::DT_U8;
    break;
  case VMDataTypeU16:
    dt = vcore::DT_U16;
    break;
  case VMDataTypeU32:
    dt = vcore::DT_U32;
    break;
  case VMDataTypeU64:
    dt = vcore::DT_U64;
    break;
  case VMDataTypeF32:
    dt = vcore::DT_F32;
    break;
  case VMDataTypeF64:
    dt = vcore::DT_F64;
    break;
  default:
    dt = vcore::DT_I32;
    break;
  }

  char buf[64] = {0};
  if (vcore::MemEngine::inst().readVal(addr, dt, buf, sizeof(buf))) {
    return [NSString stringWithUTF8String:buf];
  }

  return @"(Err)";
}

- (BOOL)writePointerValue:(VModItem *)item value:(NSString *)value {
  if (!item || !value || value.length == 0)
    return NO;

  uint64_t addr = [self resolvePointerChain:item];
  if (addr == 0)
    return NO;

  vcore::DataType dt;
  switch (item.valueType) {
  case VMDataTypeI8:
    dt = vcore::DT_I8;
    break;
  case VMDataTypeI16:
    dt = vcore::DT_I16;
    break;
  case VMDataTypeI32:
    dt = vcore::DT_I32;
    break;
  case VMDataTypeI64:
    dt = vcore::DT_I64;
    break;
  case VMDataTypeU8:
    dt = vcore::DT_U8;
    break;
  case VMDataTypeU16:
    dt = vcore::DT_U16;
    break;
  case VMDataTypeU32:
    dt = vcore::DT_U32;
    break;
  case VMDataTypeU64:
    dt = vcore::DT_U64;
    break;
  case VMDataTypeF32:
    dt = vcore::DT_F32;
    break;
  case VMDataTypeF64:
    dt = vcore::DT_F64;
    break;
  default:
    dt = vcore::DT_I32;
    break;
  }

  return vcore::MemEngine::inst().writeVal(addr, dt, value.UTF8String);
}

#pragma mark - RVA 操作

- (BOOL)toggleRVAPatch:(VModItem *)item {
  if (!item || item.type != VModTypeRVA)
    return NO;

  uint64_t base = vcore::MemEngine::inst().modBase(
      item.moduleName ? item.moduleName.UTF8String : nullptr);
  if (base == 0)
    return NO;

  uint64_t addr = base + item.rvaOffset;
  BOOL turnOn = !item.isPatched;

  NSString *hexStr = turnOn ? item.patchHex : item.originalHex;
  NSData *data = [VCrypto dataFromHexString:hexStr];
  if (!data || data.length == 0)
    return NO;

  // 首次 patch 前自动备份原始字节
  if (turnOn && (!item.originalHex || item.originalHex.length == 0)) {
    void *origBuf = malloc(data.length);
    if (origBuf && vcore::MemEngine::inst().readMem(addr, origBuf, data.length)) {
      NSData *origData = [NSData dataWithBytesNoCopy:origBuf
                                              length:data.length
                                        freeWhenDone:YES];
      item.originalHex = [VCrypto hexStringFromData:origData];
    } else {
      free(origBuf);
    }
  }

  if (vcore::MemEngine::inst().writeMem(addr, data.bytes, data.length)) {
    item.isPatched = turnOn;
    return YES;
  }

  return NO;
}

- (BOOL)isRVAActive:(VModItem *)item {
  return item.isPatched;
}

#pragma mark - 特征码搜索

- (NSArray<NSNumber *> *)searchSignature:(NSString *)signature
                                inModule:(NSString *)moduleName {
  if (!signature || signature.length == 0)
    return @[];

  std::vector<uint64_t> results = vcore::MemEngine::inst().sigScan(
      signature.UTF8String, moduleName ? moduleName.UTF8String : nullptr, 100);

  NSMutableArray<NSNumber *> *arr =
      [NSMutableArray arrayWithCapacity:results.size()];
  for (uint64_t addr : results) {
    [arr addObject:@(addr)];
  }

  return arr;
}

- (uint64_t)resolveSignatureAddress:(VModItem *)item {
  if (!item || item.type != VModTypeSignature)
    return 0;

  if (item.runtimeAddress != 0)
    return item.runtimeAddress;

  NSArray<NSNumber *> *results = [self searchSignature:item.signature
                                              inModule:item.moduleName];

  if (results.count == 0)
    return 0;

  item.multiAddresses = results;

  uint64_t addr = [results.firstObject unsignedLongLongValue] + item.sigOffset;
  item.runtimeAddress = addr;

  return addr;
}

- (NSString *)readSignatureValue:(VModItem *)item {
  if (!item || item.type != VModTypeSignature)
    return @"(Err)";

  uint64_t addr = [self resolveSignatureAddress:item];
  if (addr == 0)
    return @"(NotFound)";

  vcore::DataType dt;
  switch (item.valueType) {
  case VMDataTypeI8:
    dt = vcore::DT_I8;
    break;
  case VMDataTypeI16:
    dt = vcore::DT_I16;
    break;
  case VMDataTypeI32:
    dt = vcore::DT_I32;
    break;
  case VMDataTypeI64:
    dt = vcore::DT_I64;
    break;
  case VMDataTypeU8:
    dt = vcore::DT_U8;
    break;
  case VMDataTypeU16:
    dt = vcore::DT_U16;
    break;
  case VMDataTypeU32:
    dt = vcore::DT_U32;
    break;
  case VMDataTypeU64:
    dt = vcore::DT_U64;
    break;
  case VMDataTypeF32:
    dt = vcore::DT_F32;
    break;
  case VMDataTypeF64:
    dt = vcore::DT_F64;
    break;
  default:
    dt = vcore::DT_I32;
    break;
  }

  char buf[64] = {0};
  if (vcore::MemEngine::inst().readVal(addr, dt, buf, sizeof(buf))) {
    return [NSString stringWithUTF8String:buf];
  }

  return @"(Err)";
}

- (BOOL)writeSignatureValue:(VModItem *)item value:(NSString *)value {
  if (!item || !value || value.length == 0)
    return NO;

  uint64_t addr = [self resolveSignatureAddress:item];
  if (addr == 0)
    return NO;

  vcore::DataType dt;
  switch (item.valueType) {
  case VMDataTypeI8:
    dt = vcore::DT_I8;
    break;
  case VMDataTypeI16:
    dt = vcore::DT_I16;
    break;
  case VMDataTypeI32:
    dt = vcore::DT_I32;
    break;
  case VMDataTypeI64:
    dt = vcore::DT_I64;
    break;
  case VMDataTypeU8:
    dt = vcore::DT_U8;
    break;
  case VMDataTypeU16:
    dt = vcore::DT_U16;
    break;
  case VMDataTypeU32:
    dt = vcore::DT_U32;
    break;
  case VMDataTypeU64:
    dt = vcore::DT_U64;
    break;
  case VMDataTypeF32:
    dt = vcore::DT_F32;
    break;
  case VMDataTypeF64:
    dt = vcore::DT_F64;
    break;
  default:
    dt = vcore::DT_I32;
    break;
  }

  return vcore::MemEngine::inst().writeVal(addr, dt, value.UTF8String);
}

- (BOOL)toggleSignaturePatch:(VModItem *)item {
  if (!item || item.type != VModTypeSignature)
    return NO;
  if (!item.sigPatchHex || !item.sigOriginalHex)
    return NO;

  uint64_t addr = [self resolveSignatureAddress:item];
  if (addr == 0)
    return NO;

  BOOL turnOn = !item.isPatched;
  NSString *hexStr = turnOn ? item.sigPatchHex : item.sigOriginalHex;
  NSData *data = [VCrypto dataFromHexString:hexStr];

  if (vcore::MemEngine::inst().writeMem(addr, data.bytes, data.length)) {
    item.isPatched = turnOn;
    return YES;
  }

  return NO;
}

- (BOOL)toggleRVA:(VModItem *)item {
  if (!item)
    return NO;

  if (item.type == VModTypeRVA) {
    return [self toggleRVAPatch:item];
  } else if (item.type == VModTypeSignature) {
    return [self toggleSignaturePatch:item];
  }

  return NO;
}

#pragma mark - 锁定循环

- (void)updateLocks {
  for (VModItem *item in g_ptrItems) {
    @try {
      if (item && item.isEnabled && item.isLocked && item.lockValue.length > 0) {
        [self writePointerValue:item value:item.lockValue];
      }
    } @catch (NSException *e) {
    }
  }

  for (VModItem *item in g_sigItems) {
    @try {
      if (item && item.isLocked && item.lockValue.length > 0) {
        BOOL hasPatchHex =
            item.sigPatchHex.length > 0 && item.sigOriginalHex.length > 0;
        if (!hasPatchHex) {
          [self writeSignatureValue:item value:item.lockValue];
        }
      }
    } @catch (NSException *e) {
    }
  }
}

@end
