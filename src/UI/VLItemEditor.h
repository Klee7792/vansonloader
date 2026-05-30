/**
 * VansonLoader L2.3 - 项目编辑器
 * 支持编辑指针的 UI 模式、数值等
 */

#import "../Models/VLModItem.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VLItemEditorDelegate <NSObject>
- (void)editorDidSaveItem:(VLModItem *)item;
- (void)editorDidDeleteItem:(VLModItem *)item;
@end

// Backward compatibility
typedef NSObject<VLItemEditorDelegate> VItemEditorDelegate;

@interface VLItemEditor : NSObject

+ (void)showEditorForItem:(VLModItem *)item
               fromWindow:(UIWindow *)window
                 delegate:(id<VLItemEditorDelegate>)delegate;
+ (void)showEditorForResult:(VLModItem *)item
                    atIndex:(NSInteger)index
                 fromWindow:(UIWindow *)window
                   delegate:(id<VLItemEditorDelegate>)delegate;

@end

// Backward compatibility
typedef VLItemEditor VItemEditor;

NS_ASSUME_NONNULL_END
