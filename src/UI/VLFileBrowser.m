/**
 * VansonLoader L2.5 - File Browser
 * 文件浏览器 - 访问当前 App 数据目录
 * 支持文件导出、导入、删除
 * 简单模态窗口，从工具页打开，无悬浮图标
 */

#import "VLFileBrowser.h"
#import "VLPanelSizeHelper.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

#pragma mark - VLFileBrowserImpl

@interface VLFileBrowserImpl : UIView <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *pathLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *currentPath;
@property (nonatomic, strong) NSString *rootPath;
@property (nonatomic, strong) NSArray<NSDictionary *> *itemInfos;
@end

static VLFileBrowserImpl *g_fileBrowserView = nil;

@implementation VLFileBrowserImpl

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        _rootPath = NSHomeDirectory();
        _currentPath = _rootPath;
        [self setupUI];
        [self loadDirectory];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLanguageChanged)
                                                     name:@"VansonLanguageChanged"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    CGFloat sw = self.bounds.size.width;
    CGFloat sh = self.bounds.size.height;
    CGFloat w = MIN(sw * 0.92, 380);
    CGFloat h = MIN(sh * 0.65, 440);

    _panelView = [[UIView alloc] initWithFrame:CGRectMake((sw - w) / 2, (sh - h) / 2, w, h)];
    _panelView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.98];
    _panelView.layer.cornerRadius = 14;
    _panelView.layer.borderWidth = 1.5;
    _panelView.layer.borderColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowRadius = 15;
    _panelView.layer.shadowOpacity = 0.25;
    _panelView.clipsToBounds = YES;
    [self addSubview:_panelView];

    // 标题
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 50, 24)];
    _titleLabel.text = VL(@"FileBrowser_Title");
    _titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:15];
    _titleLabel.textColor = [UIColor cyanColor];
    [_panelView addSubview:_titleLabel];

    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(w - 36, 6, 30, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    closeBtn.layer.cornerRadius = 15;
    closeBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:closeBtn];

    // 大中小缩放按钮
    VLPanelAddSizeButtons(_panelView, CGRectMake(0, 0, sw, sh), w, h);

    // 路径标签
    _pathLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 34, w - 24, 18)];
    _pathLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
    _pathLabel.font = [UIFont fontWithName:@"Menlo" size:9];
    _pathLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    [_panelView addSubview:_pathLabel];

    // 工具栏: 返回上级 | 导入文件 | 导入文件夹
    CGFloat toolY = 56;
    CGFloat btnW = (w - 48) / 3;

    UIButton *backBtn = [self createBtn:VL(@"FileBrowser_Back") frame:CGRectMake(12, toolY, btnW, 28) color:[UIColor cyanColor]];
    [backBtn addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:backBtn];

    UIButton *importBtn = [self createBtn:VL(@"FileBrowser_Import") frame:CGRectMake(18 + btnW, toolY, btnW, 28) color:[UIColor systemGreenColor]];
    [importBtn addTarget:self action:@selector(importFile) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:importBtn];

    UIButton *importDirBtn = [self createBtn:VL(@"FileBrowser_ImportFolder") frame:CGRectMake(24 + btnW * 2, toolY, btnW, 28) color:[UIColor systemGreenColor]];
    [importDirBtn addTarget:self action:@selector(importFolder) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:importDirBtn];

    // 文件列表
    CGFloat listTop = 92;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, listTop, w, h - listTop) style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 44;
    _tableView.showsVerticalScrollIndicator = YES;
    _tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [_panelView addSubview:_tableView];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.5;
    [_tableView addGestureRecognizer:lp];
}

- (UIButton *)createBtn:(NSString *)title frame:(CGRect)frame color:(UIColor *)color {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:color forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    b.layer.cornerRadius = 6;
    b.layer.borderColor = color.CGColor;
    b.layer.borderWidth = 1;
    b.backgroundColor = [color colorWithAlphaComponent:0.08];
    return b;
}

// 点击面板外部关闭
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01) return nil;
    CGPoint panelPoint = [self convertPoint:point toView:_panelView];
    if ([_panelView pointInside:panelPoint withEvent:event]) {
        return [_panelView hitTest:panelPoint withEvent:event];
    }
    // 点击外部关闭
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGPoint panelPoint = [self convertPoint:point toView:_panelView];
    if (![_panelView pointInside:panelPoint withEvent:event]) {
        [self close];
    }
}

#pragma mark - Directory Loading

- (void)loadDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fm contentsOfDirectoryAtPath:_currentPath error:&error];

    if (error) {
        _itemInfos = @[];
        showToast(VL(@"FileBrowser_ReadError"));
        [_tableView reloadData];
        return;
    }

    NSMutableArray *dirs = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];

    for (NSString *name in contents) {
        if ([name hasPrefix:@"."]) continue;
        NSString *fullPath = [_currentPath stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];

        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"name"] = name;
        info[@"isDir"] = @(isDir);
        info[@"size"] = attrs[NSFileSize] ?: @(0);

        if (isDir) [dirs addObject:info];
        else [files addObject:info];
    }

    NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    [dirs sortUsingDescriptors:@[nameSort]];
    [files sortUsingDescriptors:@[nameSort]];

    NSMutableArray *all = [NSMutableArray array];
    [all addObjectsFromArray:dirs];
    [all addObjectsFromArray:files];
    _itemInfos = [all copy];

    NSString *relativePath = _currentPath;
    if ([_currentPath hasPrefix:_rootPath]) {
        relativePath = [_currentPath substringFromIndex:_rootPath.length];
        if (relativePath.length == 0) relativePath = @"/";
    }
    _pathLabel.text = relativePath;
    [_tableView reloadData];
}

#pragma mark - Actions

- (void)goBack {
    if ([_currentPath isEqualToString:_rootPath]) {
        showToast(VL(@"FileBrowser_AtRoot"));
        return;
    }
    _currentPath = [_currentPath stringByDeletingLastPathComponent];
    [self loadDirectory];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:_tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:point];
    if (!indexPath || indexPath.row >= (NSInteger)_itemInfos.count) return;

    NSDictionary *info = _itemInfos[indexPath.row];
    NSString *name = info[@"name"];
    NSString *fullPath = [_currentPath stringByAppendingPathComponent:name];
    BOOL isDir = [info[@"isDir"] boolValue];

    if (isDir) {
        [self showFolderActions:fullPath name:name];
    } else {
        [self showFileActions:fullPath name:name];
    }
}

- (void)close {
    [UIView animateWithDuration:0.2 animations:^{
        self->_panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        self->_panelView.alpha = 0;
        self.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        self.hidden = YES;
        self->_panelView.transform = CGAffineTransformIdentity;
    }];
}

- (void)importFile {
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.data"]] asCopy:YES];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:picker animated:YES completion:nil];
}

- (void)importFolder {
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        // 文件夹必须用 open 模式，copy 模式不支持文件夹
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder]];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.folder"] inMode:UIDocumentPickerModeOpen];
#pragma clang diagnostic pop
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:picker animated:YES completion:nil];
}

#pragma mark - Folder Actions

- (void)showFolderActions:(NSString *)path name:(NSString *)name {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:name
                                                               message:nil
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    // 打开文件夹
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_OpenFolder")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a) {
        self->_currentPath = path;
        [self loadDirectory];
    }]];
    // 导出文件夹 (zip)
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_ExportFolder")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a) { [self exportFolder:path name:name]; }]];
    // 删除文件夹
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_Delete")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *a) { [self confirmDelete:path name:name]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel")
                                           style:UIAlertActionStyleCancel handler:nil]];

    if (ac.popoverPresentationController) {
        UIWindow *window = GetSafeWindow();
        ac.popoverPresentationController.sourceView = window;
        ac.popoverPresentationController.sourceRect = CGRectMake(window.bounds.size.width / 2, window.bounds.size.height / 2, 1, 1);
    }
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

- (void)exportFolder:(NSString *)folderPath name:(NSString *)name {
    showToast(VL(@"FileBrowser_Zipping"));

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *zipName = [name stringByAppendingPathExtension:@"zip"];
        NSString *zipPath = [NSTemporaryDirectory() stringByAppendingPathComponent:zipName];

        // 清理旧临时文件
        [[NSFileManager defaultManager] removeItemAtPath:zipPath error:nil];

        BOOL ok = [self zipDirectory:folderPath toPath:zipPath];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                NSURL *url = [NSURL fileURLWithPath:zipPath];
                UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
                avc.completionWithItemsHandler = ^(UIActivityType t, BOOL completed, NSArray *items, NSError *err) {
                    [[NSFileManager defaultManager] removeItemAtPath:zipPath error:nil];
                };
                if (avc.popoverPresentationController) {
                    UIWindow *window = GetSafeWindow();
                    avc.popoverPresentationController.sourceView = window;
                    avc.popoverPresentationController.sourceRect = CGRectMake(window.bounds.size.width / 2, window.bounds.size.height / 2, 1, 1);
                }
                UIViewController *root = GetSafeWindow().rootViewController;
                while (root.presentedViewController) root = root.presentedViewController;
                [root presentViewController:avc animated:YES completion:nil];
            } else {
                showToast(VL(@"FileBrowser_ZipFail"));
            }
        });
    });
}

#pragma mark - Zip Helper

- (BOOL)zipDirectory:(NSString *)dirPath toPath:(NSString *)zipPath {
    // 使用 NSFileCoordinatorReadingForUploading 来创建 zip
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    __block BOOL success = NO;
    NSError *coordError = nil;

    [coordinator coordinateReadingItemAtURL:[NSURL fileURLWithPath:dirPath]
                                    options:NSFileCoordinatorReadingForUploading
                                      error:&coordError
                                 byAccessor:^(NSURL *newURL) {
        NSError *copyError = nil;
        // NSFileCoordinator 会自动生成 zip 文件
        if ([[NSFileManager defaultManager] copyItemAtURL:newURL
                                                    toURL:[NSURL fileURLWithPath:zipPath]
                                                    error:&copyError]) {
            success = YES;
        }
    }];

    return success && !coordError;
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *firstURL = urls.firstObject;
    if (!firstURL) return;

    // open 模式下需要先获取 security scope 才能访问
    BOOL accessing = [firstURL startAccessingSecurityScopedResource];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:firstURL.path isDirectory:&isDir] && isDir) {
        if (accessing) [firstURL stopAccessingSecurityScopedResource];
        [self processFolderImport:firstURL];
        return;
    }
    if (accessing) [firstURL stopAccessingSecurityScopedResource];
    [self processImportURLs:[urls mutableCopy] imported:0];
}

- (void)processFolderImport:(NSURL *)folderURL {
    BOOL accessing = [folderURL startAccessingSecurityScopedResource];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *folderName = folderURL.lastPathComponent;
    NSString *destPath = [_currentPath stringByAppendingPathComponent:folderName];

    if ([fm fileExistsAtPath:destPath]) {
        // 同名文件夹已存在，询问覆盖
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"FileBrowser_Conflict")
                                                                   message:folderName
                                                            preferredStyle:UIAlertControllerStyleAlert];
        // 覆盖 (删除旧的，复制新的)
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_Overwrite")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *a) {
            NSError *err = nil;
            [fm removeItemAtPath:destPath error:nil];
            [fm copyItemAtURL:folderURL toURL:[NSURL fileURLWithPath:destPath] error:&err];
            if (accessing) [folderURL stopAccessingSecurityScopedResource];
            if (!err) {
                showToast([NSString stringWithFormat:VL(@"FileBrowser_Imported"), (long)1]);
            } else {
                showToast(VL(@"FileBrowser_ImportFail"));
            }
            [self loadDirectory];
        }]];
        // 合并 (递归复制，覆盖同名文件)
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_Merge")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *a) {
            NSInteger count = [self mergeDirectory:folderURL.path into:destPath];
            if (accessing) [folderURL stopAccessingSecurityScopedResource];
            if (count > 0) {
                showToast([NSString stringWithFormat:VL(@"FileBrowser_Imported"), (long)count]);
            } else {
                showToast(VL(@"FileBrowser_ImportFail"));
            }
            [self loadDirectory];
        }]];
        // 取消
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *a) {
            if (accessing) [folderURL stopAccessingSecurityScopedResource];
        }]];

        UIViewController *root = GetSafeWindow().rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        [root presentViewController:ac animated:YES completion:nil];
    } else {
        // 无冲突，直接复制整个文件夹
        NSError *err = nil;
        [fm copyItemAtURL:folderURL toURL:[NSURL fileURLWithPath:destPath] error:&err];
        if (accessing) [folderURL stopAccessingSecurityScopedResource];
        if (!err) {
            showToast([NSString stringWithFormat:VL(@"FileBrowser_Imported"), (long)1]);
        } else {
            showToast(VL(@"FileBrowser_ImportFail"));
        }
        [self loadDirectory];
    }
}

- (NSInteger)mergeDirectory:(NSString *)srcDir into:(NSString *)dstDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger count = 0;

    // 确保目标目录存在
    if (![fm fileExistsAtPath:dstDir]) {
        [fm createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSArray *contents = [fm contentsOfDirectoryAtPath:srcDir error:nil];
    for (NSString *item in contents) {
        NSString *srcPath = [srcDir stringByAppendingPathComponent:item];
        NSString *dstPath = [dstDir stringByAppendingPathComponent:item];
        BOOL srcIsDir = NO;
        [fm fileExistsAtPath:srcPath isDirectory:&srcIsDir];

        if (srcIsDir) {
            // 递归合并子目录
            count += [self mergeDirectory:srcPath into:dstPath];
        } else {
            // 文件: 覆盖已有
            NSError *err = nil;
            if ([fm fileExistsAtPath:dstPath]) {
                [fm removeItemAtPath:dstPath error:nil];
            }
            [fm copyItemAtPath:srcPath toPath:dstPath error:&err];
            if (!err) count++;
        }
    }
    return count;
}

- (void)processImportURLs:(NSMutableArray<NSURL *> *)urls imported:(NSInteger)count {
    if (urls.count == 0) {
        if (count > 0) {
            showToast([NSString stringWithFormat:VL(@"FileBrowser_Imported"), (long)count]);
            [self loadDirectory];
        } else {
            showToast(VL(@"FileBrowser_ImportFail"));
        }
        return;
    }

    NSURL *url = urls.firstObject;
    [urls removeObjectAtIndex:0];

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL accessing = [url startAccessingSecurityScopedResource];
    NSString *destPath = [_currentPath stringByAppendingPathComponent:url.lastPathComponent];

    if ([fm fileExistsAtPath:destPath]) {
        // 同名文件存在，弹窗询问
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"FileBrowser_Conflict")
                                                                   message:url.lastPathComponent
                                                            preferredStyle:UIAlertControllerStyleAlert];
        // 覆盖
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_Overwrite")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *a) {
            NSError *error = nil;
            [fm removeItemAtPath:destPath error:nil];
            [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:&error];
            if (accessing) [url stopAccessingSecurityScopedResource];
            [self processImportURLs:urls imported:count + (error ? 0 : 1)];
        }]];
        // 重命名
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_Rename")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *a) {
            NSString *ext = [destPath pathExtension];
            NSString *base = [destPath stringByDeletingPathExtension];
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"HHmmss"];
            NSString *newPath = [NSString stringWithFormat:@"%@_%@.%@", base, [df stringFromDate:[NSDate date]], ext];
            NSError *error = nil;
            [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:newPath] error:&error];
            if (accessing) [url stopAccessingSecurityScopedResource];
            [self processImportURLs:urls imported:count + (error ? 0 : 1)];
        }]];
        // 跳过
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *a) {
            if (accessing) [url stopAccessingSecurityScopedResource];
            [self processImportURLs:urls imported:count];
        }]];

        UIViewController *root = GetSafeWindow().rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        [root presentViewController:ac animated:YES completion:nil];
    } else {
        // 无冲突，直接复制
        NSError *error = nil;
        [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:&error];
        if (accessing) [url stopAccessingSecurityScopedResource];
        [self processImportURLs:urls imported:count + (error ? 0 : 1)];
    }
}

#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _itemInfos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"VLFileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor cyanColor];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:13];
        cell.detailTextLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
        cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:9];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    NSDictionary *info = _itemInfos[indexPath.row];
    BOOL isDir = [info[@"isDir"] boolValue];
    NSString *name = info[@"name"];

    cell.textLabel.text = isDir ? [NSString stringWithFormat:@"📁 %@", name] : [NSString stringWithFormat:@"📄 %@", name];

    if (isDir) {
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        unsigned long long size = [info[@"size"] unsignedLongLongValue];
        cell.detailTextLabel.text = [self formatSize:size];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (NSString *)formatSize:(unsigned long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    if (bytes < 1024 * 1024 * 1024) return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    return [NSString stringWithFormat:@"%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *info = _itemInfos[indexPath.row];
    BOOL isDir = [info[@"isDir"] boolValue];
    NSString *name = info[@"name"];
    NSString *fullPath = [_currentPath stringByAppendingPathComponent:name];

    if (isDir) {
        _currentPath = fullPath;
        [self loadDirectory];
    } else {
        [self showFileActions:fullPath name:name];
    }
}

- (void)showFileActions:(NSString *)path name:(NSString *)name {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:name
                                                               message:nil
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_Export")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a) { [self exportFile:path]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"FileBrowser_Delete")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *a) { [self confirmDelete:path name:name]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel")
                                           style:UIAlertActionStyleCancel handler:nil]];

    if (ac.popoverPresentationController) {
        UIWindow *window = GetSafeWindow();
        ac.popoverPresentationController.sourceView = window;
        ac.popoverPresentationController.sourceRect = CGRectMake(window.bounds.size.width / 2, window.bounds.size.height / 2, 1, 1);
    }
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

- (void)exportFile:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (avc.popoverPresentationController) {
        UIWindow *window = GetSafeWindow();
        avc.popoverPresentationController.sourceView = window;
        avc.popoverPresentationController.sourceRect = CGRectMake(window.bounds.size.width / 2, window.bounds.size.height / 2, 1, 1);
    }
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:avc animated:YES completion:nil];
}

- (void)confirmDelete:(NSString *)path name:(NSString *)name {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"FileBrowser_DeleteConfirm")
                                                               message:name
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *a) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        if (!error) {
            showToast(VL(@"FileBrowser_Deleted"));
            [self loadDirectory];
        } else {
            showToast(VL(@"FileBrowser_DeleteFail"));
        }
    }]];
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *info = _itemInfos[indexPath.row];
        NSString *name = info[@"name"];
        NSString *fullPath = [_currentPath stringByAppendingPathComponent:name];
        [self confirmDelete:fullPath name:name];
    }
}

#pragma mark - Language Change

- (void)onLanguageChanged {
    for (UIView *v in _panelView.subviews) [v removeFromSuperview];
    [_panelView removeFromSuperview];
    _panelView = nil;
    [self setupUI];
    [self loadDirectory];
}

#pragma mark - Show/Hide

- (void)showWithAnimation {
    self.hidden = NO;
    self.backgroundColor = [UIColor clearColor];
    _panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    _panelView.alpha = 0;
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:0 animations:^{
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        self->_panelView.transform = CGAffineTransformIdentity;
        self->_panelView.alpha = 1;
    } completion:nil];
}

@end

#pragma mark - VLFileBrowserVC (Public API)

@implementation VLFileBrowserVC

+ (void)showFromWindow:(UIWindow *)window {
    if (!g_fileBrowserView) {
        g_fileBrowserView = [[VLFileBrowserImpl alloc] initWithFrame:window.bounds];
    }
    if (!g_fileBrowserView.superview) {
        [window addSubview:g_fileBrowserView];
    }
    // 确保在最顶层
    [g_fileBrowserView.superview bringSubviewToFront:g_fileBrowserView];
    [g_fileBrowserView showWithAnimation];
}

+ (void)showMinimized {
    // 文件浏览器不支持最小化，直接忽略
}

+ (void)hide {
    if (g_fileBrowserView && !g_fileBrowserView.hidden) {
        [g_fileBrowserView close];
    }
}

+ (void)toggle {
    if (g_fileBrowserView && g_fileBrowserView.superview && !g_fileBrowserView.hidden) {
        [g_fileBrowserView close];
    } else {
        UIWindow *w = GetSafeWindow();
        if (w) [self showFromWindow:w];
    }
}

+ (BOOL)isVisible {
    return g_fileBrowserView && g_fileBrowserView.superview && !g_fileBrowserView.hidden;
}

@end
