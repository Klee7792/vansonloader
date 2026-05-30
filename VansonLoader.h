/**
 * VansonLoader L2.3
 * 模块化架构 - 兼容 VansonMod 2.4
 */

#ifndef VansonLoader_h
#define VansonLoader_h

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Models
#import "src/Models/VLModItem.h"
#import "src/Models/VLScriptItem.h"

// Engine
#import "src/Engine/VLModEngine.h"
#import "src/Engine/VLModParser.h"
#import "src/Engine/VLMemEngine.h"
#import "src/Engine/VLScriptEngine.h"
#import "src/Engine/VLScriptManager.h"

// Utils
#import "src/Utils/VLCrypto.h"
#import "src/Utils/VLLocalization.h"

// UI
#import "src/UI/VLModCell.h"
#import "src/UI/VLPanel.h"
#import "src/UI/VLTools.h"
#import "src/UI/VLAbout.h"
#import "src/UI/VLFloatingButton.h"
#import "src/UI/VLItemEditor.h"
#import "src/UI/VLMemorySearch.h"
#import "src/UI/VLMemoryBrowser.h"
#import "src/UI/VLWatchOverlay.h"

// 全局数据
extern NSMutableArray<VLModItem *> *g_ptrItems;
extern NSMutableArray<VLModItem *> *g_rvaItems;
extern NSMutableArray<VLModItem *> *g_sigItems;
extern NSMutableArray<VLScriptItem *> *g_scriptItems;

// 全局函数
#ifdef __cplusplus
extern "C" {
#endif
UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);
#ifdef __cplusplus
}
#endif

#endif /* VansonLoader_h */
