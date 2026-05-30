/**
 * VansonLoader L2.7 - VLPanelToolbox
 * 工具箱Tab: 子Tab、Watch Fusion、Browser Fusion、Cell、脚本操作
 */

#import "VLPanel+Internal.h"

#define BROWSER_AUTO_REFRESH_INTERVAL 0.5

static BOOL VLToolboxInputLooksHex(NSString *input) {
    NSCharacterSet *hexLetters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF"];
    return [input rangeOfCharacterFromSet:hexLetters].location != NSNotFound;
}

static uint64_t VLParseBrowserAddressInput(NSString *input) {
    NSString *trimmed = [[(input ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (trimmed.length == 0) return 0;

    if ([trimmed.lowercaseString hasPrefix:@"0x"]) {
        return strtoull([trimmed UTF8String], NULL, 16);
    }

    int base = VLToolboxInputLooksHex(trimmed) ? 16 : 10;
    return strtoull([trimmed UTF8String], NULL, base);
}

static NSAttributedString *VLToolboxBrowserAddressText(uint64_t address, uint64_t targetAddress, UIColor *accent, BOOL emphasized) {
    int64_t offset = (int64_t)address - (int64_t)targetAddress;
    NSString *line1 = [NSString stringWithFormat:@"0x%llX", address];
    NSString *line2 = nil;

    if (offset == 0) {
        line2 = @"BASE | +0x0 | +0";
    } else {
        uint64_t magnitude = (uint64_t)(offset < 0 ? -offset : offset);
        NSString *hexPart = [NSString stringWithFormat:@"%@0x%llX", offset > 0 ? @"+" : @"-", magnitude];
        NSString *decPart = [NSString stringWithFormat:@"%@%lld", offset > 0 ? @"+" : @"-", magnitude];
        line2 = [NSString stringWithFormat:@"%@ | %@", hexPart, decPart];
    }

    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.lineSpacing = 1.0;
    style.lineBreakMode = NSLineBreakByTruncatingMiddle;

    UIColor *primaryColor = emphasized ? accent : [accent colorWithAlphaComponent:0.82];
    UIColor *secondaryColor = emphasized ? [accent colorWithAlphaComponent:0.9] : [accent colorWithAlphaComponent:0.5];
    UIFont *primaryFont = [UIFont fontWithName:@"Menlo-Bold" size:9];
    UIFont *secondaryFont = [UIFont fontWithName:@"Menlo" size:8];

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", line1, line2]];
    [text addAttributes:@{
        NSFontAttributeName: primaryFont,
        NSForegroundColorAttributeName: primaryColor,
        NSParagraphStyleAttributeName: style
    } range:NSMakeRange(0, line1.length)];
    [text addAttributes:@{
        NSFontAttributeName: secondaryFont,
        NSForegroundColorAttributeName: secondaryColor,
        NSParagraphStyleAttributeName: style
    } range:NSMakeRange(line1.length + 1, line2.length)];
    return text;
}

@implementation VPanelImpl (Toolbox)

#pragma mark - Toolbox Page Setup

- (void)setupToolboxPage:(CGFloat)w {
    CGFloat bodyH = self.panelBody.frame.size.height;
    self.pageToolbox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, bodyH)];
    self.pageToolbox.hidden = YES;
    [self.panelBody addSubview:self.pageToolbox];

    CGFloat pad = 8;

    UIScrollView *subTabBar = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, 28)];
    subTabBar.showsHorizontalScrollIndicator = NO;
    subTabBar.bounces = YES;
    UIView *subSep = [[UIView alloc] initWithFrame:CGRectMake(pad, 27, w - pad * 2, 1)];
    subSep.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    [subTabBar addSubview:subSep];
    [self.pageToolbox addSubview:subTabBar];

    BOOL hasWatch = [VLDebugEngine isAvailable];
    NSMutableArray *subTitles = [NSMutableArray array];
    NSMutableArray *subMapping = [NSMutableArray array];

    [subTitles addObject:VL(@"Tab_MemBrowser")]; [subMapping addObject:@(VLToolboxSubBrowser)];
    [subTitles addObject:VL(@"Tab_Lock")];     [subMapping addObject:@(VLToolboxSubLock)];
    [subTitles addObject:VL(@"Tab_Ptr")];      [subMapping addObject:@(VLToolboxSubPtr)];
    [subTitles addObject:VL(@"Tab_RVA")];      [subMapping addObject:@(VLToolboxSubRVA)];
    [subTitles addObject:VL(@"Tab_Sig")];      [subMapping addObject:@(VLToolboxSubSig)];
    [subTitles addObject:VL(@"Tab_Script")];   [subMapping addObject:@(VLToolboxSubScript)];
    if (hasWatch) {
        [subTitles addObject:VL(@"Tab_Watch")]; [subMapping addObject:@(VLToolboxSubWatch)];
    }
    self.tbSubTabMapping = subMapping;

    NSMutableArray *subBtns = [NSMutableArray array];
    CGFloat sx = pad;
    UIFont *subTabFont = [UIFont boldSystemFontOfSize:10];
    for (NSInteger i = 0; i < (NSInteger)subTitles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat tw = [subTitles[i] sizeWithAttributes:@{NSFontAttributeName: subTabFont}].width + 18;
        btn.frame = CGRectMake(sx, 1, tw, 26);
        [btn setTitle:subTitles[i] forState:UIControlStateNormal];
        btn.titleLabel.font = subTabFont;
        btn.layer.cornerRadius = 13;
        btn.tag = [subMapping[i] integerValue];
        [btn addTarget:self action:@selector(onSubTabTap:) forControlEvents:UIControlEventTouchUpInside];
        [subTabBar addSubview:btn];
        [subBtns addObject:btn];
        sx += tw + 3;
    }
    self.tbSubTabButtons = subBtns;
    subTabBar.contentSize = CGSizeMake(sx + pad, 28);

    self.tbTable = [[UITableView alloc] initWithFrame:CGRectMake(pad, 32, w - pad * 2, bodyH - 90) style:UITableViewStylePlain];
    self.tbTable.backgroundColor = [UIColor clearColor];
    self.tbTable.delegate = self;
    self.tbTable.dataSource = self;
    self.tbTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tbTable.rowHeight = UITableViewAutomaticDimension;
    self.tbTable.estimatedRowHeight = 60;
    self.tbTable.showsVerticalScrollIndicator = NO;
    self.tbTable.tag = 2002;
    [self.pageToolbox addSubview:self.tbTable];

    UIView *tbPager = [[UIView alloc] initWithFrame:CGRectMake(pad, bodyH - 54, w - pad * 2, 24)];
    tbPager.tag = 3002;
    [self.pageToolbox addSubview:tbPager];

    UIButton *tbPrev = [self createSmallBtn:@"<" frame:CGRectMake(10, 0, 30, 24)];
    [tbPrev addTarget:self action:@selector(tbPrevPage) forControlEvents:UIControlEventTouchUpInside];
    [tbPager addSubview:tbPrev];

    self.tbPageLabel = [[UILabel alloc] initWithFrame:CGRectMake(44, 0, w - pad * 2 - 88, 24)];
    self.tbPageLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.35];
    self.tbPageLabel.font = [UIFont fontWithName:@"Menlo" size:9];
    self.tbPageLabel.textAlignment = NSTextAlignmentCenter;
    [tbPager addSubview:self.tbPageLabel];

    UIButton *tbNext = [self createSmallBtn:@">" frame:CGRectMake(w - pad * 2 - 40, 0, 30, 24)];
    [tbNext addTarget:self action:@selector(tbNextPage) forControlEvents:UIControlEventTouchUpInside];
    [tbPager addSubview:tbNext];

    UIView *tbBottom = [[UIView alloc] initWithFrame:CGRectMake(pad, bodyH - 28, w - pad * 2, 24)];
    tbBottom.tag = 3001;
    [self.pageToolbox addSubview:tbBottom];

    [self rebuildTbBottomButtons];
    [self updateSubTabHighlight];
}

- (void)rebuildTbBottomButtons {
    UIView *tbBottom = [self.pageToolbox viewWithTag:3001];
    if (!tbBottom) return;
    for (UIView *v in tbBottom.subviews) [v removeFromSuperview];
    CGFloat w = tbBottom.bounds.size.width;

    if (self.currentSubTab == VLToolboxSubWatch) {
        CGFloat btnW = (w - 8) / 2;
        UIButton *addBtn = [self createSmallBtn:VL(@"Watch_Add") frame:CGRectMake(0, 0, btnW, 24)];
        addBtn.layer.borderColor = [[UIColor greenColor] colorWithAlphaComponent:0.3].CGColor;
        [addBtn setTitleColor:[UIColor colorWithRed:0.29 green:0.87 blue:0.5 alpha:1] forState:UIControlStateNormal];
        addBtn.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.05];
        [addBtn addTarget:self action:@selector(onAddWatch) forControlEvents:UIControlEventTouchUpInside];
        [tbBottom addSubview:addBtn];

        UIButton *clearBtn = [self createSmallBtn:VL(@"Watch_ClearAll") frame:CGRectMake(btnW + 8, 0, btnW, 24)];
        clearBtn.layer.borderColor = [[UIColor redColor] colorWithAlphaComponent:0.3].CGColor;
        [clearBtn setTitleColor:[UIColor colorWithRed:0.97 green:0.44 blue:0.44 alpha:1] forState:UIControlStateNormal];
        clearBtn.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.05];
        [clearBtn addTarget:self action:@selector(onWatchClearAll) forControlEvents:UIControlEventTouchUpInside];
        [tbBottom addSubview:clearBtn];
    } else if (self.currentSubTab == VLToolboxSubBrowser) {
        CGFloat btnW = (w - 8) / 2;
        UIButton *selectBtn = [self createSmallBtn:(self.browserMultiSelectMode ? VL(@"Batch_Action") : VL(@"Batch_Select")) frame:CGRectMake(0, 0, btnW, 24)];
        [selectBtn addTarget:self action:@selector(onBrowserSelectButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [tbBottom addSubview:selectBtn];

        UIButton *refreshBtn = [self createSmallBtn:VL(@"Btn_Refresh") frame:CGRectMake(btnW + 8, 0, btnW, 24)];
        [refreshBtn addTarget:self action:@selector(browserManualRefresh) forControlEvents:UIControlEventTouchUpInside];
        [tbBottom addSubview:refreshBtn];
    } else {
        CGFloat btnW = (w - 12) / 2;
        UIButton *importBtn = [self createSmallBtn:VL(@"Btn_Import") frame:CGRectMake(0, 0, btnW, 24)];
        importBtn.layer.borderColor = [[UIColor greenColor] colorWithAlphaComponent:0.3].CGColor;
        [importBtn setTitleColor:[UIColor colorWithRed:0.29 green:0.87 blue:0.5 alpha:1] forState:UIControlStateNormal];
        importBtn.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.05];
        [importBtn addTarget:self action:@selector(importConfig) forControlEvents:UIControlEventTouchUpInside];
        [tbBottom addSubview:importBtn];

        UIButton *refreshBtn = [self createSmallBtn:VL(@"Btn_Refresh") frame:CGRectMake(btnW + 12, 0, btnW, 24)];
        [refreshBtn addTarget:self action:@selector(tbRefresh) forControlEvents:UIControlEventTouchUpInside];
        [tbBottom addSubview:refreshBtn];
    }
}


- (void)onSubTabTap:(UIButton *)btn {
    self.currentSubTab = (VLToolboxSubTab)btn.tag;
    self.tbPage = 0;
    [self updateSubTabHighlight];

    UIView *tbPager = [self.pageToolbox viewWithTag:3002];
    BOOL needsPager = (self.currentSubTab != VLToolboxSubWatch && self.currentSubTab != VLToolboxSubBrowser);
    tbPager.hidden = !needsPager;

    if (self.currentSubTab == VLToolboxSubWatch) {
        self.tbTable.hidden = YES; self.browserFusionView.hidden = YES;
        [self stopBrowserRefreshTimer];
        [self showWatchFusionView];
    } else if (self.currentSubTab == VLToolboxSubBrowser) {
        self.tbTable.hidden = YES; self.watchFusionView.hidden = YES;
        [self showBrowserFusionView];
    } else {
        self.tbTable.hidden = NO; self.watchFusionView.hidden = YES; self.browserFusionView.hidden = YES;
        [self stopBrowserRefreshTimer];
        [self.tbTable reloadData];
    }
    [self updateTbPager];
    [self rebuildTbBottomButtons];
}

- (void)updateSubTabHighlight {
    UIColor *cyan = [UIColor cyanColor];
    for (UIButton *btn in self.tbSubTabButtons) {
        BOOL active = (btn.tag == self.currentSubTab);
        if (active) {
            btn.backgroundColor = [cyan colorWithAlphaComponent:0.12];
            btn.layer.borderWidth = 1;
            btn.layer.borderColor = [cyan colorWithAlphaComponent:0.3].CGColor;
            [btn setTitleColor:cyan forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor clearColor];
            btn.layer.borderWidth = 0;
            [btn setTitleColor:[cyan colorWithAlphaComponent:0.4] forState:UIControlStateNormal];
        }
    }
}

#pragma mark - Toolbox Data

- (NSMutableArray *)tbDataSource {
    switch (self.currentSubTab) {
        case VLToolboxSubLock: return self.tbMemResults;
        case VLToolboxSubPtr: return g_ptrItems;
        case VLToolboxSubRVA: return g_rvaItems;
        case VLToolboxSubSig: return g_sigItems;
        case VLToolboxSubScript: return (NSMutableArray *)g_scriptItems;
        case VLToolboxSubWatch: return nil;
        case VLToolboxSubBrowser: return nil;
    }
    return nil;
}

- (void)updateTbPager {
    NSUInteger total = [self tbDataSource].count;
    NSInteger totalPages = MAX(1, (NSInteger)((total + kPageSize - 1) / kPageSize));
    self.tbPageLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)(self.tbPage + 1), (long)totalPages];
}

- (void)tbPrevPage {
    if (self.tbPage > 0) { self.tbPage--; [self.tbTable reloadData]; [self updateTbPager]; }
}

- (void)tbNextPage {
    NSUInteger total = [self tbDataSource].count;
    NSInteger totalPages = MAX(1, (NSInteger)((total + kPageSize - 1) / kPageSize));
    if (self.tbPage < totalPages - 1) { self.tbPage++; [self.tbTable reloadData]; [self updateTbPager]; }
}

- (void)tbRefresh {
    [self.tbTable reloadData]; [self updateTbPager];
    showToast(VL(@"Refresh_Done"));
}


#pragma mark - Watch Fusion View

- (void)showWatchFusionView {
    if (!self.watchFusionView) [self buildWatchFusionView];
    self.watchFusionView.hidden = NO;

    if (self.watchNavState == 1 && self.watchInspectHit) {
        [self layoutWatchFusionForInspector];
    } else {
        self.watchNavState = 0;
        if (self.watchInspectTable) self.watchInspectTable.hidden = YES;
        if (self.watchInspectToolbar) self.watchInspectToolbar.hidden = YES;
        if (self.watchBackBtn) self.watchBackBtn.hidden = YES;
        UILabel *infoLabel = [self.watchFusionView viewWithTag:3030];
        if (infoLabel) infoLabel.hidden = YES;
        self.watchSlotTable.hidden = NO; self.watchHitTable.hidden = NO;
        UILabel *slotLabel = [self.watchFusionView viewWithTag:3012];
        UILabel *hitLabel = [self.watchFusionView viewWithTag:3013];
        if (slotLabel) slotLabel.hidden = NO;
        if (hitLabel) hitLabel.hidden = NO;
        [self layoutWatchFusion];
        [self.watchSlotTable reloadData]; [self.watchHitTable reloadData];
    }
}

- (void)buildWatchFusionView {
    CGFloat w = self.pageToolbox.bounds.size.width;
    CGFloat pad = 8; CGFloat topY = 32; CGFloat bottomH = 30;
    CGFloat h = self.pageToolbox.bounds.size.height - topY - bottomH;
    UIColor *accent = [UIColor cyanColor];

    self.watchFusionView = [[UIView alloc] initWithFrame:CGRectMake(pad, topY, w - pad * 2, h)];
    self.watchFusionView.backgroundColor = [UIColor clearColor];
    [self.pageToolbox addSubview:self.watchFusionView];

    self.watchSlotTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.watchSlotTable.backgroundColor = [UIColor clearColor];
    self.watchSlotTable.delegate = self; self.watchSlotTable.dataSource = self;
    self.watchSlotTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.watchSlotTable.rowHeight = 48; self.watchSlotTable.showsVerticalScrollIndicator = NO;
    self.watchSlotTable.tag = 3010;
    self.watchSlotTable.layer.cornerRadius = 8; self.watchSlotTable.layer.borderWidth = 0.5;
    self.watchSlotTable.layer.borderColor = [accent colorWithAlphaComponent:0.1].CGColor;
    [self.watchFusionView addSubview:self.watchSlotTable];

    self.watchHitTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.watchHitTable.backgroundColor = [UIColor clearColor];
    self.watchHitTable.delegate = self; self.watchHitTable.dataSource = self;
    self.watchHitTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.watchHitTable.rowHeight = 52; self.watchHitTable.showsVerticalScrollIndicator = NO;
    self.watchHitTable.tag = 3011;
    self.watchHitTable.layer.cornerRadius = 8; self.watchHitTable.layer.borderWidth = 0.5;
    self.watchHitTable.layer.borderColor = [accent colorWithAlphaComponent:0.1].CGColor;
    [self.watchFusionView addSubview:self.watchHitTable];

    UILabel *slotLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    slotLabel.text = VL(@"Watch_Slots"); slotLabel.font = [UIFont boldSystemFontOfSize:9];
    slotLabel.textColor = [accent colorWithAlphaComponent:0.5]; slotLabel.tag = 3012;
    [self.watchFusionView addSubview:slotLabel];

    UILabel *hitLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    hitLabel.text = VL(@"Watch_Hits"); hitLabel.font = [UIFont boldSystemFontOfSize:9];
    hitLabel.textColor = [accent colorWithAlphaComponent:0.5]; hitLabel.tag = 3013;
    [self.watchFusionView addSubview:hitLabel];
}

- (void)layoutWatchFusion {
    if (!self.watchFusionView) return;
    CGFloat w = self.pageToolbox.bounds.size.width; CGFloat pad = 8;
    CGFloat topY = 32; CGFloat bottomH = 30;
    CGFloat totalH = self.pageToolbox.bounds.size.height - topY - bottomH;
    CGFloat totalW = w - pad * 2;
    self.watchFusionView.frame = CGRectMake(pad, topY, totalW, totalH);

    UILabel *slotLabel = [self.watchFusionView viewWithTag:3012];
    UILabel *hitLabel = [self.watchFusionView viewWithTag:3013];
    CGFloat gap = 6; CGFloat slotW = totalW * 0.35; CGFloat hitW = totalW - slotW - gap;
    slotLabel.frame = CGRectMake(4, 0, slotW - 8, 14);
    self.watchSlotTable.frame = CGRectMake(0, 14, slotW, totalH - 14);
    hitLabel.frame = CGRectMake(slotW + gap + 4, 0, hitW - 8, 14);
    self.watchHitTable.frame = CGRectMake(slotW + gap, 14, hitW, totalH - 14);
}

#pragma mark - Watch Inline Inspector

- (void)layoutWatchFusionForInspector {
    if (!self.watchFusionView) return;
    CGFloat w = self.pageToolbox.bounds.size.width;
    CGFloat pad = 8;
    CGFloat topY = 32;
    CGFloat bottomH = 30;
    CGFloat totalH = self.pageToolbox.bounds.size.height - topY - bottomH;
    CGFloat totalW = w - pad * 2;
    self.watchFusionView.frame = CGRectMake(pad, topY, totalW, totalH);

    UIColor *accent = [UIColor cyanColor];

    self.watchSlotTable.hidden = YES;
    self.watchHitTable.hidden = YES;
    UILabel *slotLabel = [self.watchFusionView viewWithTag:3012];
    UILabel *hitLabel = [self.watchFusionView viewWithTag:3013];
    slotLabel.hidden = YES;
    hitLabel.hidden = YES;

    if (!self.watchBackBtn) {
        self.watchBackBtn = [self createSmallBtn:VL(@"Btn_Back") frame:CGRectZero];
        [self.watchBackBtn addTarget:self action:@selector(onWatchInspectorBack) forControlEvents:UIControlEventTouchUpInside];
        [self.watchFusionView addSubview:self.watchBackBtn];
    }
    self.watchBackBtn.hidden = NO;
    self.watchBackBtn.frame = CGRectMake(totalW - 60, 0, 60, 24);

    UILabel *infoLabel = [self.watchFusionView viewWithTag:3030];
    if (!infoLabel) {
        infoLabel = [[UILabel alloc] init];
        infoLabel.tag = 3030;
        infoLabel.font = [UIFont fontWithName:@"Menlo" size:8.5];
        infoLabel.textColor = [accent colorWithAlphaComponent:0.6];
        infoLabel.numberOfLines = 2;
        [self.watchFusionView addSubview:infoLabel];
    }
    infoLabel.hidden = NO;
    infoLabel.frame = CGRectMake(0, 0, totalW - 64, 24);
    if (self.watchInspectHit) {
        infoLabel.text = [NSString stringWithFormat:@"%@ + 0x%llX  PC: 0x%llX  Val: %llu",
                          self.watchInspectHit.imageName, self.watchInspectHit.offset,
                          self.watchInspectHit.pc, self.watchInspectHit.newValue];
    }

    CGFloat tableTop = 28;
    CGFloat toolbarH = 76;
    CGFloat tableH = totalH - tableTop - toolbarH - 4;

    if (!self.watchInspectTable) {
        self.watchInspectTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.watchInspectTable.backgroundColor = [UIColor clearColor];
        self.watchInspectTable.delegate = self; self.watchInspectTable.dataSource = self;
        self.watchInspectTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.watchInspectTable.rowHeight = 28; self.watchInspectTable.showsVerticalScrollIndicator = NO;
        self.watchInspectTable.tag = 3040;
        self.watchInspectTable.layer.cornerRadius = 6; self.watchInspectTable.layer.borderWidth = 0.5;
        self.watchInspectTable.layer.borderColor = [accent colorWithAlphaComponent:0.1].CGColor;
        [self.watchFusionView addSubview:self.watchInspectTable];
    }
    self.watchInspectTable.hidden = NO;
    self.watchInspectTable.frame = CGRectMake(0, tableTop, totalW, tableH);
    [self.watchInspectTable reloadData];

    if (self.watchInspectLines) {
        NSInteger pcRow = -1;
        for (NSInteger i = 0; i < (NSInteger)self.watchInspectLines.count; i++) {
            if ([self.watchInspectLines[i][@"isPC"] boolValue]) { pcRow = i; break; }
        }
        if (pcRow >= 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.watchInspectTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:pcRow inSection:0]
                                               atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
            });
        }
    }

    CGFloat tbY = tableTop + tableH + 4;
    if (!self.watchInspectToolbar) {
        self.watchInspectToolbar = [[UIView alloc] init];
        self.watchInspectToolbar.backgroundColor = [accent colorWithAlphaComponent:0.06];
        self.watchInspectToolbar.layer.cornerRadius = 8;
        self.watchInspectToolbar.layer.borderWidth = 0.5;
        self.watchInspectToolbar.layer.borderColor = [accent colorWithAlphaComponent:0.2].CGColor;
        [self.watchFusionView addSubview:self.watchInspectToolbar];
    }
    self.watchInspectToolbar.hidden = NO;
    self.watchInspectToolbar.frame = CGRectMake(0, tbY, totalW, toolbarH);
    [self rebuildWatchInspectToolbar];
}

- (void)rebuildWatchInspectToolbar {
    for (UIView *v in self.watchInspectToolbar.subviews) [v removeFromSuperview];

    UIColor *accent = [UIColor cyanColor];
    CGFloat tw = self.watchInspectToolbar.bounds.size.width;

    UILabel *selLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, tw - 16, 14)];
    selLabel.tag = 3041;
    selLabel.font = [UIFont fontWithName:@"Menlo" size:8.5];
    selLabel.textColor = [accent colorWithAlphaComponent:0.5];
    selLabel.text = VL(@"Inspector_PatchHint");
    selLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *selTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSelLabelTap)];
    [selLabel addGestureRecognizer:selTap];
    [self.watchInspectToolbar addSubview:selLabel];

    CGFloat inputW = tw - 80;
    UITextField *patchField = [[UITextField alloc] initWithFrame:CGRectMake(8, 20, inputW, 26)];
    patchField.tag = 3042;
    patchField.font = [UIFont fontWithName:@"Menlo" size:10];
    patchField.textColor = [UIColor whiteColor];
    patchField.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    patchField.layer.cornerRadius = 5; patchField.layer.borderWidth = 0.5;
    patchField.layer.borderColor = [accent colorWithAlphaComponent:0.2].CGColor;
    patchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, 26)];
    patchField.leftViewMode = UITextFieldViewModeAlways;
    patchField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    patchField.autocorrectionType = UITextAutocorrectionTypeNo;
    patchField.enabled = NO;
    patchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:VL(@"Inspector_PatchHint")
        attributes:@{NSForegroundColorAttributeName: [accent colorWithAlphaComponent:0.3],
                     NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:9]}];
    [self addDoneButtonTo:patchField];
    [self.watchInspectToolbar addSubview:patchField];

    UIButton *applyBtn = [self createSmallBtn:VL(@"Inspector_Patch") frame:CGRectMake(tw - 68, 20, 60, 26)];
    applyBtn.tag = 3043; applyBtn.enabled = NO; applyBtn.alpha = 0.4;
    [applyBtn addTarget:self action:@selector(onWatchInspectApply) forControlEvents:UIControlEventTouchUpInside];
    [self.watchInspectToolbar addSubview:applyBtn];

    CGFloat qY = 50;
    NSArray *qTitles = @[VL(@"Inspector_NOP"), VL(@"Inspector_RET"),
                         VL(@"Inspector_ToRVA"), VL(@"Inspector_CopyHex"), @"Offset"];
    CGFloat qBtnW = (tw - 16 - 16) / 5;
    for (NSInteger i = 0; i < 5; i++) {
        UIButton *qBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        qBtn.frame = CGRectMake(8 + i * (qBtnW + 4), qY, qBtnW, 22);
        qBtn.tag = 3050 + i;
        [qBtn setTitle:qTitles[i] forState:UIControlStateNormal];
        [qBtn setTitleColor:accent forState:UIControlStateNormal];
        qBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:8];
        qBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
        qBtn.titleLabel.minimumScaleFactor = 0.5;
        qBtn.layer.borderColor = [accent colorWithAlphaComponent:0.3].CGColor;
        qBtn.layer.borderWidth = 0.5; qBtn.layer.cornerRadius = 4;
        qBtn.enabled = NO; qBtn.alpha = 0.4;
        [qBtn addTarget:self action:@selector(onWatchInspectQuick:) forControlEvents:UIControlEventTouchUpInside];
        [self.watchInspectToolbar addSubview:qBtn];
    }
}

- (void)onSelLabelTap {
    NSString *selHex = objc_getAssociatedObject(self.watchInspectToolbar, "selHex");
    if (!selHex || selHex.length == 0) return;
    UITextField *patchField = [self.watchInspectToolbar viewWithTag:3042];
    if (patchField.enabled) patchField.text = selHex;
}

- (void)onWatchInspectorBack {
    self.watchNavState = 0;
    self.watchInspectHit = nil;
    self.watchInspectLines = nil;
    if (self.watchInspectTable) self.watchInspectTable.hidden = YES;
    if (self.watchInspectToolbar) self.watchInspectToolbar.hidden = YES;
    if (self.watchBackBtn) self.watchBackBtn.hidden = YES;
    UILabel *infoLabel = [self.watchFusionView viewWithTag:3030];
    if (infoLabel) infoLabel.hidden = YES;
    self.watchSlotTable.hidden = NO; self.watchHitTable.hidden = NO;
    UILabel *slotLabel = [self.watchFusionView viewWithTag:3012];
    UILabel *hitLabel = [self.watchFusionView viewWithTag:3013];
    slotLabel.hidden = NO; hitLabel.hidden = NO;
    [self layoutWatchFusion];
    [self.watchSlotTable reloadData]; [self.watchHitTable reloadData];
}

- (void)onWatchInspectSelectRow:(NSInteger)row {
    if (!self.watchInspectLines || row >= (NSInteger)self.watchInspectLines.count) return;
    NSDictionary *line = self.watchInspectLines[row];
    UIColor *accent = [UIColor cyanColor];

    UILabel *selLabel = [self.watchInspectToolbar viewWithTag:3041];
    selLabel.text = [NSString stringWithFormat:@"0x%llX  %@  %@",
                     [line[@"offset"] unsignedLongLongValue], line[@"hex"], line[@"mnemonic"]];
    selLabel.textColor = accent;

    UITextField *patchField = [self.watchInspectToolbar viewWithTag:3042];
    patchField.enabled = YES; patchField.text = @"";
    UIButton *applyBtn = [self.watchInspectToolbar viewWithTag:3043];
    applyBtn.enabled = YES; applyBtn.alpha = 1.0;
    for (NSInteger i = 0; i < 5; i++) {
        UIButton *qBtn = [self.watchInspectToolbar viewWithTag:3050 + i];
        qBtn.enabled = YES; qBtn.alpha = 1.0;
    }

    objc_setAssociatedObject(self.watchInspectToolbar, "selOffset", line[@"offset"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self.watchInspectToolbar, "selHex", line[@"hex"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self.watchInspectToolbar, "selLine", line, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self.watchInspectToolbar, "selIdx", @(row), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.watchInspectTable reloadData];
}

- (void)onWatchInspectApply {
    UITextField *patchField = [self.watchInspectToolbar viewWithTag:3042];
    NSString *input = [patchField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!input || input.length == 0) return;

    NSNumber *offsetNum = objc_getAssociatedObject(self.watchInspectToolbar, "selOffset");
    if (!offsetNum || !self.watchInspectHit) return;

    NSString *stripped = [[input stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    NSCharacterSet *hexChars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    BOOL isHex = ([stripped rangeOfCharacterFromSet:hexChars].location == NSNotFound && stripped.length > 0 && stripped.length % 2 == 0);

    if (isHex) {
        uint64_t offset = [offsetNum unsignedLongLongValue];
        NSString *origHex = nil;
        BOOL ok = [[VLDebugEngine shared] applyPatchAtOffset:offset hexCode:stripped
                                                  moduleName:self.watchInspectHit.imageName backupOriginal:&origHex];
        if (ok) {
            showToast(VL(@"Inspector_Patched"));
            self.watchInspectLines = [[VLDebugEngine shared] disassembleFunctionAt:self.watchInspectHit.pc
                                                                   moduleName:self.watchInspectHit.imageName];
            [self.watchInspectTable reloadData];
            [self rebuildWatchInspectToolbar];
        } else {
            showToast(VL(@"Inspector_PatchFail"));
        }
    } else {
        showToast(VL(@"Inspector_HexOnly"));
    }
    patchField.text = @"";
    [patchField resignFirstResponder];
}

- (void)onWatchInspectQuick:(UIButton *)sender {
    NSNumber *offsetNum = objc_getAssociatedObject(self.watchInspectToolbar, "selOffset");
    NSString *selHex = objc_getAssociatedObject(self.watchInspectToolbar, "selHex");
    NSDictionary *selLine = objc_getAssociatedObject(self.watchInspectToolbar, "selLine");
    if (!offsetNum || !self.watchInspectHit) return;

    UITextField *patchField = [self.watchInspectToolbar viewWithTag:3042];
    uint64_t offset = [offsetNum unsignedLongLongValue];

    switch (sender.tag) {
        case 3050: patchField.text = @"1F2003D5"; break;
        case 3051: patchField.text = @"C0035FD6"; break;
        case 3052: if (selLine) [self createInspectorRVAItem:selLine]; break;
        case 3053:
            if (selHex) {
                [UIPasteboard generalPasteboard].string = selHex;
                showToast([NSString stringWithFormat:@"%@ %@", VL(@"Mem_Copied"), selHex]);
            }
            break;
        case 3054: {
            NSString *offStr = [NSString stringWithFormat:@"0x%llX", offset];
            [UIPasteboard generalPasteboard].string = offStr;
            showToast([NSString stringWithFormat:@"%@ %@", VL(@"Mem_Copied"), offStr]);
            break;
        }
    }
}

- (void)createInspectorRVAItem:(NSDictionary *)line {
    if (!self.watchInspectHit) return;
    uint64_t offset = [line[@"offset"] unsignedLongLongValue];
    NSString *hex = line[@"hex"];

    if (!g_rvaItems) g_rvaItems = [NSMutableArray array];

    VLModItem *existing = nil;
    NSInteger existingIdx = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)g_rvaItems.count; i++) {
        VLModItem *p = g_rvaItems[i];
        if (p.type == VModTypeRVA &&
            [p.moduleName isEqualToString:self.watchInspectHit.imageName] &&
            p.rvaOffset == offset) {
            existing = p; existingIdx = i; break;
        }
    }

    VLModItem *item = [[VLModItem alloc] init];
    item.type = VModTypeRVA;
    item.uniqueId = existing ? existing.uniqueId : [[NSUUID UUID] UUIDString];
    item.note = [NSString stringWithFormat:@"[Inspector] %@ + 0x%llX %@",
                 self.watchInspectHit.imageName, offset, line[@"mnemonic"]];
    item.moduleName = self.watchInspectHit.imageName;
    item.rvaOffset = offset;
    item.patchHex = existing ? existing.patchHex : @"C0035FD6";
    item.originalHex = hex;
    item.isPatched = existing ? existing.isPatched : NO;
    item.bundleID = existing ? existing.bundleID : ([[NSBundle mainBundle] bundleIdentifier] ?: @"");
    item.appName = existing ? existing.appName : ([[NSBundle mainBundle] infoDictionary][@"CFBundleDisplayName"] ?: @"");
    item.createdAt = existing ? existing.createdAt : [[NSDate date] timeIntervalSince1970];
    item.author = existing ? existing.author : @"VansonMod";

    if (existing && existingIdx != NSNotFound) {
        [g_rvaItems replaceObjectAtIndex:existingIdx withObject:item];
        showToast(VL(@"Watch_RVAUpdated"));
    } else {
        [g_rvaItems addObject:item];
        showToast(VL(@"Watch_SentToRVA"));
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VLReloadList" object:nil];
}

#pragma mark - Browser Fusion View

- (void)showBrowserFusionView {
    BOOL firstBuild = !self.browserFusionView;
    if (firstBuild) [self buildBrowserFusionView];
    self.browserFusionView.hidden = NO;
    [self layoutBrowserFusion];
    if (self.browserMemoryData.count > 0) {
        [self.browserTable reloadData];
    } else if (firstBuild && self.browserTargetAddr != 0) {
        self.browserAddrField.text = [NSString stringWithFormat:@"0x%llX", self.browserTargetAddr];
        self.browserIsInitialLoad = YES;
        [self browserLoadInitialData];
    }
    [self startBrowserLockTimer];
    [self startBrowserRefreshTimer];
}

- (void)startBrowserRefreshTimer {
    if (self.browserRefreshTimer) return;
    self.browserRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:BROWSER_AUTO_REFRESH_INTERVAL
                                                               target:self
                                                             selector:@selector(refreshVisibleBrowserRowsSilently)
                                                             userInfo:nil
                                                              repeats:YES];
    if ([self.browserRefreshTimer respondsToSelector:@selector(setTolerance:)]) {
        self.browserRefreshTimer.tolerance = 0.2;
    }
}

- (void)stopBrowserRefreshTimer {
    [self.browserRefreshTimer invalidate];
    self.browserRefreshTimer = nil;
}

- (void)refreshVisibleBrowserRowsSilently {
    if (self.currentTab != VLMainTabToolbox || self.currentSubTab != VLToolboxSubBrowser) return;
    if (!self.browserFusionView || self.browserFusionView.hidden || !self.browserTable.window) return;
    if (self.browserIsLoading || self.browserIsInitialLoad) return;
    if (self.browserTable.dragging || self.browserTable.decelerating) return;

    NSArray<NSIndexPath *> *visibleRows = [self.browserTable indexPathsForVisibleRows];
    if (visibleRows.count == 0) return;

    VMemDataType type = [self browserCurrentType];
    NSMutableArray<NSIndexPath *> *changedRows = [NSMutableArray array];

    for (NSIndexPath *indexPath in visibleRows) {
        if (indexPath.row >= self.browserMemoryData.count) continue;

        NSMutableDictionary *item = self.browserMemoryData[indexPath.row];
        uint64_t addr = [item[@"addr"] unsignedLongLongValue];
        NSString *oldVal = item[@"value"] ?: @"";
        NSString *newVal = [[VLMemEngine shared] readAddress:addr type:type] ?: @"??";

        item[@"type"] = @(type);
        if (![oldVal isEqualToString:newVal]) {
            item[@"value"] = newVal;
            [changedRows addObject:indexPath];
        }
    }

    if (changedRows.count == 0) return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.browserTable reloadRowsAtIndexPaths:changedRows withRowAnimation:UITableViewRowAnimationNone];
    [CATransaction commit];
}

- (void)refreshBrowserRowsFromMemory {
    if (self.browserMemoryData.count == 0) return;

    VMemDataType type = [self browserCurrentType];
    for (NSMutableDictionary *item in self.browserMemoryData) {
        uint64_t addr = [item[@"addr"] unsignedLongLongValue];
        NSString *newVal = [[VLMemEngine shared] readAddress:addr type:type] ?: @"??";
        item[@"value"] = newVal;
        item[@"type"] = @(type);
    }
    [self.browserTable reloadData];
}

- (void)browserManualRefresh {
    [self refreshBrowserRowsFromMemory];
    showToast(VL(@"Refresh_Done"));
}

- (void)buildBrowserFusionView {
    CGFloat w = self.pageToolbox.bounds.size.width;
    CGFloat pad = 8; CGFloat topY = 32; CGFloat bottomH = 30;
    CGFloat h = self.pageToolbox.bounds.size.height - topY - bottomH;
    UIColor *accent = [UIColor cyanColor];
    CGFloat totalW = w - pad * 2;
    CGFloat y = 0;

    self.browserFusionView = [[UIView alloc] initWithFrame:CGRectMake(pad, topY, totalW, h)];
    self.browserFusionView.backgroundColor = [UIColor clearColor];
    [self.pageToolbox addSubview:self.browserFusionView];

    self.browserAddrField = [[UITextField alloc] initWithFrame:CGRectMake(0, y, totalW - 54, 28)];
    self.browserAddrField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"0x..."
        attributes:@{NSForegroundColorAttributeName: [accent colorWithAlphaComponent:0.18]}];
    self.browserAddrField.textColor = accent;
    self.browserAddrField.font = [UIFont fontWithName:@"Menlo" size:10];
    self.browserAddrField.layer.borderColor = [accent colorWithAlphaComponent:0.2].CGColor;
    self.browserAddrField.layer.borderWidth = 1; self.browserAddrField.layer.cornerRadius = 5;
    self.browserAddrField.backgroundColor = [accent colorWithAlphaComponent:0.04];
    self.browserAddrField.textAlignment = NSTextAlignmentCenter;
    self.browserAddrField.keyboardType = UIKeyboardTypeDefault;
    [self addDoneButtonTo:self.browserAddrField];
    [self.browserFusionView addSubview:self.browserAddrField];

    UIButton *goBtn = [self createSmallBtn:VL(@"Mem_Go") frame:CGRectMake(totalW - 50, y, 50, 28)];
    [goBtn addTarget:self action:@selector(onBrowserGo) forControlEvents:UIControlEventTouchUpInside];
    [self.browserFusionView addSubview:goBtn];
    y += 32;

    NSArray *types = @[@"I32", @"I64", @"F32", @"F64", @"Hex"];
    self.browserTypeSeg = [[UISegmentedControl alloc] initWithItems:types];
    self.browserTypeSeg.frame = CGRectMake(0, y, totalW, 24);
    self.browserTypeSeg.selectedSegmentIndex = 0;
    [self styleSegment:self.browserTypeSeg];
    [self.browserTypeSeg addTarget:self action:@selector(browserTypeChanged) forControlEvents:UIControlEventValueChanged];
    [self.browserFusionView addSubview:self.browserTypeSeg];
    y += 28;

    self.browserTable = [[UITableView alloc] initWithFrame:CGRectMake(0, y, totalW, h - y) style:UITableViewStylePlain];
    self.browserTable.backgroundColor = [UIColor clearColor];
    self.browserTable.delegate = self; self.browserTable.dataSource = self;
    self.browserTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.browserTable.rowHeight = 48; self.browserTable.showsVerticalScrollIndicator = NO;
    self.browserTable.tag = 3020;
    self.browserTable.layer.cornerRadius = 6; self.browserTable.layer.borderWidth = 0.5;
    self.browserTable.layer.borderColor = [accent colorWithAlphaComponent:0.1].CGColor;
    [self.browserFusionView addSubview:self.browserTable];

    UILongPressGestureRecognizer *browserLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleBrowserLongPress:)];
    [self.browserTable addGestureRecognizer:browserLongPress];
}

- (void)layoutBrowserFusion {
    if (!self.browserFusionView) return;
    CGFloat w = self.pageToolbox.bounds.size.width;
    CGFloat pad = 8; CGFloat topY = 32; CGFloat bottomH = 30;
    CGFloat totalH = self.pageToolbox.bounds.size.height - topY - bottomH;
    CGFloat totalW = w - pad * 2;
    self.browserFusionView.frame = CGRectMake(pad, topY, totalW, totalH);

    self.browserAddrField.frame = CGRectMake(0, 0, totalW - 54, 28);
    for (UIView *v in self.browserFusionView.subviews) {
        if ([v isKindOfClass:[UIButton class]] && v != (UIView *)self.browserTypeSeg) {
            v.frame = CGRectMake(totalW - 50, 0, 50, 28);
            break;
        }
    }
    self.browserTypeSeg.frame = CGRectMake(0, 32, totalW, 24);
    self.browserTable.frame = CGRectMake(0, 60, totalW, totalH - 60);
}

- (VMemDataType)browserCurrentType {
    switch (self.browserTypeSeg.selectedSegmentIndex) {
        case 0: return VMemDataTypeI32;
        case 1: return VMemDataTypeI64;
        case 2: return VMemDataTypeF32;
        case 3: return VMemDataTypeF64;
        default: return VMemDataTypeU8;
    }
}

- (void)browserUpdateTypeSize {
    switch (self.browserTypeSeg.selectedSegmentIndex) {
        case 0: self.browserTypeSize = 4; break;
        case 1: self.browserTypeSize = 8; break;
        case 2: self.browserTypeSize = 4; break;
        case 3: self.browserTypeSize = 8; break;
        default: self.browserTypeSize = 1; break;
    }
}

- (void)browserTypeChanged {
    [self exitBrowserMultiSelectMode];
    [self browserUpdateTypeSize];
    self.browserIsInitialLoad = YES;
    [self browserLoadInitialData];
    [self browserScrollToTarget];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.browserIsInitialLoad = NO;
    });
}

- (void)browserLoadInitialData {
    [self exitBrowserMultiSelectMode];
    [self.browserMemoryData removeAllObjects];
    [self browserUpdateTypeSize];

    self.browserMinAddr = self.browserTargetAddr - (BROWSER_PAGE_COUNT * self.browserTypeSize);
    self.browserMaxAddr = self.browserTargetAddr + (BROWSER_PAGE_COUNT * self.browserTypeSize);

    VMemDataType type = [self browserCurrentType];
    int totalRows = (int)((self.browserMaxAddr - self.browserMinAddr) / self.browserTypeSize);

    for (int i = 0; i <= totalRows; i++) {
        uint64_t addr = self.browserMinAddr + (i * self.browserTypeSize);
        NSString *val = [[VLMemEngine shared] readAddress:addr type:type];
        [self.browserMemoryData addObject:[@{
            @"addr": @(addr),
            @"value": val ?: @"??",
            @"type": @(type)
        } mutableCopy]];
    }

    [self.browserTable reloadData];
    self.browserAddrField.text = [NSString stringWithFormat:@"0x%llX", self.browserTargetAddr];
}

- (void)browserScrollToTarget {
    NSInteger targetIndex = -1;
    for (NSInteger i = 0; i < (NSInteger)self.browserMemoryData.count; i++) {
        uint64_t addr = [self.browserMemoryData[i][@"addr"] unsignedLongLongValue];
        if (addr == self.browserTargetAddr) { targetIndex = i; break; }
    }
    if (targetIndex >= 0) {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:targetIndex inSection:0];
        [self.browserTable scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [self.browserTable cellForRowAtIndexPath:ip];
            if (cell) {
                UIView *flash = [[UIView alloc] initWithFrame:cell.bounds];
                flash.backgroundColor = [[UIColor yellowColor] colorWithAlphaComponent:0.3];
                [cell insertSubview:flash atIndex:0];
                [UIView animateWithDuration:1.0 delay:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    flash.alpha = 0;
                } completion:^(BOOL f) { [flash removeFromSuperview]; }];
            }
        });
    }
}

- (void)browserLoadMoreData:(BOOL)next {
    if (self.browserIsLoading) return;
    self.browserIsLoading = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newRows = [NSMutableArray array];
        VMemDataType type = [self browserCurrentType];
        int count = BROWSER_PAGE_COUNT;

        if (next) {
            for (int i = 1; i <= count; i++) {
                uint64_t addr = self.browserMaxAddr + (i * self.browserTypeSize);
                NSString *val = [[VLMemEngine shared] readAddress:addr type:type];
                [newRows addObject:[@{@"addr": @(addr), @"value": val ?: @"??", @"type": @(type)} mutableCopy]];
            }
        } else {
            for (int i = count; i >= 1; i--) {
                uint64_t addr = self.browserMinAddr - (i * self.browserTypeSize);
                NSString *val = [[VLMemEngine shared] readAddress:addr type:type];
                [newRows addObject:[@{@"addr": @(addr), @"value": val ?: @"??", @"type": @(type)} mutableCopy]];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (newRows.count == 0) { self.browserIsLoading = NO; return; }

            if (next) {
                NSInteger startIdx = self.browserMemoryData.count;
                [self.browserMemoryData addObjectsFromArray:newRows];
                self.browserMaxAddr = [newRows.lastObject[@"addr"] unsignedLongLongValue];
                NSMutableArray *ips = [NSMutableArray array];
                for (NSInteger i = 0; i < (NSInteger)newRows.count; i++)
                    [ips addObject:[NSIndexPath indexPathForRow:startIdx + i inSection:0]];
                [CATransaction begin]; [CATransaction setDisableActions:YES];
                [self.browserTable insertRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationNone];
                [CATransaction commit];
                if (self.browserMemoryData.count > BROWSER_MAX_BUFFER) {
                    NSInteger rm = self.browserMemoryData.count - BROWSER_MAX_BUFFER;
                    [self.browserMemoryData removeObjectsInRange:NSMakeRange(0, rm)];
                    self.browserMinAddr = [self.browserMemoryData.firstObject[@"addr"] unsignedLongLongValue];
                    CGFloat removedH = rm * self.browserTable.rowHeight;
                    CGPoint cur = self.browserTable.contentOffset;
                    [CATransaction begin]; [CATransaction setDisableActions:YES];
                    [self.browserTable reloadData];
                    [self.browserTable setContentOffset:CGPointMake(cur.x, MAX(0, cur.y - removedH)) animated:NO];
                    [CATransaction commit];
                }
            } else {
                NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newRows.count)];
                [self.browserMemoryData insertObjects:newRows atIndexes:idxSet];
                self.browserMinAddr = [newRows.firstObject[@"addr"] unsignedLongLongValue];
                NSMutableArray *ips = [NSMutableArray array];
                for (NSInteger i = 0; i < (NSInteger)newRows.count; i++)
                    [ips addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                [CATransaction begin]; [CATransaction setDisableActions:YES];
                [self.browserTable insertRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationNone];
                [CATransaction commit];

                if (self.browserMemoryData.count > BROWSER_MAX_BUFFER) {
                    [self.browserMemoryData removeObjectsInRange:NSMakeRange(BROWSER_MAX_BUFFER, self.browserMemoryData.count - BROWSER_MAX_BUFFER)];
                    self.browserMaxAddr = [self.browserMemoryData.lastObject[@"addr"] unsignedLongLongValue];
                    [self.browserTable reloadData];
                }
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.browserIsLoading = NO;
            });
        });
    });
}

- (void)startBrowserLockTimer {
    if (self.browserLockTimer) return;
    self.browserLockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateBrowserLocks) userInfo:nil repeats:YES];
}

- (void)updateBrowserLocks {
    VMemEngine *engine = [VMemEngine shared];
    if (!engine.isReady) return;
    for (NSNumber *addrKey in self.browserLockedItems) {
        NSDictionary *info = self.browserLockedItems[addrKey];
        [engine writeAddress:[addrKey unsignedLongLongValue] value:info[@"value"] type:(VMemDataType)[info[@"type"] integerValue]];
    }
}

- (void)onBrowserLockTapped:(UIButton *)sender {
    NSNumber *addrKey = objc_getAssociatedObject(sender, "bAddr");
    NSNumber *typeNum = objc_getAssociatedObject(sender, "bType");
    NSString *value = objc_getAssociatedObject(sender, "bValue");
    if (!addrKey) return;

    if (self.browserLockedItems[addrKey]) {
        [self.browserLockedItems removeObjectForKey:addrKey];
        showToast(VL(@"Msg_Unlocked"));
    } else {
        self.browserLockedItems[addrKey] = @{@"value": value ?: @"0", @"type": typeNum ?: @(VMemDataTypeI32)};
        showToast(VL(@"Msg_Locked"));
    }
    [self.browserTable reloadData];
}

- (void)navigateBrowserToAddress:(uint64_t)addr {
    self.browserTargetAddr = addr;
    self.browserIsInitialLoad = YES;
    self.currentSubTab = VLToolboxSubBrowser;
    [self switchToTab:VLMainTabToolbox animated:YES];
    [self updateSubTabHighlight];
    self.tbTable.hidden = YES; self.watchFusionView.hidden = YES;
    [self showBrowserFusionView];
    [self browserLoadInitialData];
    [self browserScrollToTarget];
    [self rebuildTbBottomButtons];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.browserIsInitialLoad = NO;
    });
}

- (void)onBrowserGo {
    NSString *addrStr = self.browserAddrField.text;
    if (addrStr.length == 0) return;
    [self.browserAddrField resignFirstResponder];

    uint64_t addr = VLParseBrowserAddressInput(addrStr);
    [self exitBrowserMultiSelectMode];
    self.browserTargetAddr = addr;
    self.browserIsInitialLoad = YES;
    [self browserLoadInitialData];
    [self browserScrollToTarget];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.browserIsInitialLoad = NO;
    });
}

- (void)handleBrowserLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *indexPath = [self.browserTable indexPathForRowAtPoint:[gesture locationInView:self.browserTable]];
    if (!indexPath) return;

    [self enterBrowserMultiSelectMode];
    [self toggleBrowserSelectionAtIndexPath:indexPath];
}

- (void)enterBrowserMultiSelectMode {
    self.browserMultiSelectMode = YES;
    self.memMultiSelectMode = NO;
    [self.multiSelectedAddresses removeAllObjects];
    [self.multiSelectedTypes removeAllObjects];
    [self.memResultsTable reloadData];
    [self.browserTable reloadData];
    [self rebuildTbBottomButtons];
}

- (void)exitBrowserMultiSelectMode {
    if (!self.browserMultiSelectMode && self.multiSelectedAddresses.count == 0) return;
    self.browserMultiSelectMode = NO;
    [self.multiSelectedAddresses removeAllObjects];
    [self.multiSelectedTypes removeAllObjects];
    [self.browserTable reloadData];
    [self rebuildTbBottomButtons];
}

- (void)toggleBrowserSelectionAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.browserMemoryData.count) return;
    if (self.browserTypeSeg.selectedSegmentIndex == 4) return;

    NSMutableDictionary *item = self.browserMemoryData[indexPath.row];
    NSNumber *addrKey = item[@"addr"];
    if (!addrKey) return;
    VMemDataType type = [self browserCurrentType];

    if ([self.multiSelectedAddresses containsObject:addrKey]) {
        [self.multiSelectedAddresses removeObject:addrKey];
        [self.multiSelectedTypes removeObjectForKey:addrKey];
    } else {
        [self.multiSelectedAddresses addObject:addrKey];
        self.multiSelectedTypes[addrKey] = @(type);
    }
    [self.browserTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self rebuildTbBottomButtons];
}

- (void)onBrowserSelectButtonTapped {
    if (!self.browserMultiSelectMode) {
        [self enterBrowserMultiSelectMode];
        return;
    }
    [self showSelectedBatchActionsForBrowser:YES];
}

- (void)selectAllVisibleBrowserRows {
    if (self.browserTypeSeg.selectedSegmentIndex == 4) return;
    VMemDataType type = [self browserCurrentType];
    for (NSMutableDictionary *item in self.browserMemoryData) {
        NSNumber *addrKey = item[@"addr"];
        if (!addrKey) continue;
        [self.multiSelectedAddresses addObject:addrKey];
        self.multiSelectedTypes[addrKey] = @(type);
    }
    [self.browserTable reloadData];
    [self rebuildTbBottomButtons];
}

- (void)onWatchClearAll {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Watch_ClearAll")
                                                               message:VL(@"Watch_ClearAll_Msg")
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[VLDebugEngine shared] removeAllWatchpoints];
        [self.watchHits removeAllObjects];
        self.watchSelectedSlot = -1;
        [self.watchSlotTable reloadData];
        [self.watchHitTable reloadData];
        showToast(VL(@"Watch_Cleared"));
    }]];
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

- (void)onAddWatch {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Watch_Add") message:VL(@"Watch_Add_Msg") preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"0x00000000";
        tf.keyboardType = UIKeyboardTypeDefault;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *addrStr = ac.textFields.firstObject.text;
        if (addrStr.length > 0) {
            uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
            [VLWatchOverlay addWatchForAddress:addr];
        }
    }]];
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Toolbox Cells

- (UITableViewCell *)tbCellForIndex:(NSInteger)row {
    if (self.currentSubTab == VLToolboxSubWatch || self.currentSubTab == VLToolboxSubBrowser) {
        return [[UITableViewCell alloc] init];
    }

    NSUInteger idx = self.tbPage * kPageSize + row;
    NSMutableArray *ds = [self tbDataSource];
    if (idx >= ds.count) return [[UITableViewCell alloc] init];

    if (self.currentSubTab == VLToolboxSubLock) return [self tbMemCellForItem:ds[idx]];
    if (self.currentSubTab == VLToolboxSubScript) return [self tbScriptCellForItem:ds[idx] atIndex:idx];

    VModCell *cell = [self.tbTable dequeueReusableCellWithIdentifier:@"VModCell"];
    if (!cell) cell = [[VModCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"VModCell"];
    cell.delegate = self;

    VModItem *item = ds[idx];
    NSString *value = nil;
    if (item.type == VModTypePointer) {
        value = [[VModEngine shared] readPointerValue:item];
    } else if (item.type == VModTypeSignature) {
        BOOL hasPatchHex = item.sigPatchHex.length > 0 && item.sigOriginalHex.length > 0;
        if (!hasPatchHex) value = [[VModEngine shared] readSignatureValue:item];
    }
    [cell configureWithItem:item currentValue:value];
    return cell;
}

- (UITableViewCell *)tbMemCellForItem:(VLPanelMemItem *)item {
    static NSString *cellId = @"TbMemCell";
    UITableViewCell *cell = [self.tbTable dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6; cell.layer.borderWidth = 0.5;
        cell.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08].CGColor;

        UILabel *addrLabel = [[UILabel alloc] init];
        addrLabel.font = [UIFont fontWithName:@"Menlo" size:9];
        addrLabel.textColor = [UIColor cyanColor]; addrLabel.tag = 201;
        [cell.contentView addSubview:addrLabel];

        UILabel *valLabel = [[UILabel alloc] init];
        valLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:10];
        valLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.8];
        valLabel.textAlignment = NSTextAlignmentRight; valLabel.tag = 202;
        [cell.contentView addSubview:valLabel];

        UIButton *lockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        lockBtn.titleLabel.font = [UIFont systemFontOfSize:9]; lockBtn.tag = 203;
        [cell.contentView addSubview:lockBtn];

        UIButton *browseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        browseBtn.titleLabel.font = [UIFont systemFontOfSize:9]; browseBtn.tag = 204;
        [cell.contentView addSubview:browseBtn];

        UIButton *watchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        watchBtn.titleLabel.font = [UIFont systemFontOfSize:9]; watchBtn.tag = 205;
        [cell.contentView addSubview:watchBtn];
    }

    UILabel *addrLabel = [cell.contentView viewWithTag:201];
    UILabel *valLabel = [cell.contentView viewWithTag:202];
    UIButton *lockBtn = [cell.contentView viewWithTag:203];
    UIButton *browseBtn = [cell.contentView viewWithTag:204];
    UIButton *watchBtn = [cell.contentView viewWithTag:205];

    CGFloat cw = self.tbTable.bounds.size.width - 4;
    CGFloat btnW = 36;
    BOOL hasWatch = [VLDebugEngine isAvailable];
    CGFloat btnsW = hasWatch ? (btnW * 3 + 6) : (btnW * 2 + 3);

    NSString *val = [[VMemEngine shared] readAddress:item.address type:item.dataType];
    if (val) item.currentValue = val;

    NSString *lockPrefix = item.isLocked ? [NSString stringWithFormat:@"[%@]", VL(@"UI_Locked")] : @"";
    addrLabel.text = [NSString stringWithFormat:@"%@0x%llX", lockPrefix, item.address];
    addrLabel.frame = CGRectMake(8, 4, cw * 0.45, 40);

    NSString *typeName = [self shortNameForType:item.dataType];
    valLabel.text = [NSString stringWithFormat:@"%@:%@", typeName, item.currentValue ?: @"--"];
    valLabel.frame = CGRectMake(cw * 0.45, 4, cw - cw * 0.45 - btnsW - 12, 16);

    CGFloat bx = cw - btnsW - 4; CGFloat by = 20;
    lockBtn.frame = CGRectMake(bx, by, btnW, 22);
    [lockBtn setTitle:item.isLocked ? VL(@"UI_Locked") : VL(@"UI_Unlocked") forState:UIControlStateNormal];
    [lockBtn setTitleColor:item.isLocked ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.5] forState:UIControlStateNormal];
    objc_setAssociatedObject(lockBtn, "addr", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [lockBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [lockBtn addTarget:self action:@selector(onTbLockToggle:) forControlEvents:UIControlEventTouchUpInside];

    browseBtn.frame = CGRectMake(bx + btnW + 3, by, btnW, 22);
    [browseBtn setTitle:VL(@"Mem_Browser") forState:UIControlStateNormal];
    [browseBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    objc_setAssociatedObject(browseBtn, "addr", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [browseBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [browseBtn addTarget:self action:@selector(onMemResultBrowse:) forControlEvents:UIControlEventTouchUpInside];

    if (hasWatch) {
        watchBtn.hidden = NO;
        watchBtn.frame = CGRectMake(bx + btnW * 2 + 6, by, btnW, 22);
        [watchBtn setTitle:VL(@"Watch_Btn") forState:UIControlStateNormal];
        [watchBtn setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
        objc_setAssociatedObject(watchBtn, "addr", @(item.address), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [watchBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [watchBtn addTarget:self action:@selector(onMemResultWatch:) forControlEvents:UIControlEventTouchUpInside];
    } else { watchBtn.hidden = YES; }

    cell.backgroundColor = item.isLocked ? [[UIColor cyanColor] colorWithAlphaComponent:0.15] : [[UIColor cyanColor] colorWithAlphaComponent:0.05];
    return cell;
}

- (UITableViewCell *)tbScriptCellForItem:(VScriptItem *)script atIndex:(NSUInteger)idx {
    static NSString *cellId = @"TbScriptCell";
    UITableViewCell *cell = [self.tbTable dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.08];
        cell.textLabel.textColor = [UIColor greenColor];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
        cell.detailTextLabel.textColor = [[UIColor greenColor] colorWithAlphaComponent:0.6];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:10];
        cell.detailTextLabel.numberOfLines = 2;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6; cell.layer.borderWidth = 0.5;
        cell.layer.borderColor = [[UIColor greenColor] colorWithAlphaComponent:0.2].CGColor;
    }

    NSString *title = script.note.length > 0 ? script.note : script.fileName;
    if (!title || title.length == 0) title = VL(@"Script_Untitled");

    cell.textLabel.text = title;
    NSMutableArray *details = [NSMutableArray array];
    if (script.author.length > 0) [details addObject:[NSString stringWithFormat:@"by %@", script.author]];
    if (script.desc.length > 0) [details addObject:script.desc];
    cell.detailTextLabel.text = [details componentsJoinedByString:@" · "];
    return cell;
}

#pragma mark - Watch Fusion Cells

- (UITableViewCell *)watchFusionSlotCellForRow:(NSInteger)row {
    UIColor *accent = [UIColor cyanColor];
    static NSString *cellId = @"WFSlotCell";
    UITableViewCell *cell = [self.watchSlotTable dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6;
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:10];
        cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:8];
        cell.detailTextLabel.textColor = [accent colorWithAlphaComponent:0.5];

        UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        delBtn.tag = 300; delBtn.titleLabel.font = [UIFont systemFontOfSize:9];
        [delBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        [cell.contentView addSubview:delBtn];
    }

    uint32_t idx = (uint32_t)row;
    VLDebugEngine *engine = [VLDebugEngine shared];
    BOOL active = [engine isSlotActive:idx];
    BOOL selected = (self.watchSelectedSlot == idx);

    if (active) {
        uint64_t addr = [engine slotAddress:idx];
        NSArray<VLWatchHit *> *hits = [engine hitsForSlot:idx];
        cell.textLabel.text = [NSString stringWithFormat:@"[%u] 0x%llX", idx, addr];
        cell.textLabel.textColor = accent;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %lu", VL(@"Watch_Hits"), (unsigned long)hits.count];
        if (selected) {
            cell.backgroundColor = [accent colorWithAlphaComponent:0.2];
            cell.layer.borderWidth = 1; cell.layer.borderColor = [accent colorWithAlphaComponent:0.4].CGColor;
        } else {
            cell.backgroundColor = [accent colorWithAlphaComponent:0.08]; cell.layer.borderWidth = 0;
        }
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"[%u] %@", idx, VL(@"Watch_Empty")];
        cell.textLabel.textColor = [accent colorWithAlphaComponent:0.3];
        cell.detailTextLabel.text = @"--";
        cell.backgroundColor = [accent colorWithAlphaComponent:0.02]; cell.layer.borderWidth = 0;
    }

    UIButton *delBtn = [cell.contentView viewWithTag:300];
    CGFloat cw = self.watchSlotTable.bounds.size.width - 8;
    delBtn.frame = CGRectMake(cw - 40, 8, 36, 28);
    [delBtn setTitle:VL(@"Btn_Delete") forState:UIControlStateNormal];
    delBtn.hidden = !active;
    objc_setAssociatedObject(delBtn, "slotIdx", @(idx), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [delBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [delBtn addTarget:self action:@selector(onWatchDeleteSlot:) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

- (UITableViewCell *)watchFusionHitCellForRow:(NSInteger)row {
    UIColor *accent = [UIColor cyanColor];
    NSArray<VLWatchHit *> *hits;
    if (self.watchSelectedSlot >= 0) {
        hits = [[VLDebugEngine shared] hitsForSlot:(uint32_t)self.watchSelectedSlot];
    } else {
        hits = self.watchHits;
    }

    static NSString *cellId = @"WFHitCell";
    UITableViewCell *cell = [self.watchHitTable dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6;
        cell.backgroundColor = [accent colorWithAlphaComponent:0.04];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:10];
        cell.textLabel.textColor = accent;
        cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:8];
        cell.detailTextLabel.textColor = [accent colorWithAlphaComponent:0.5];
        cell.detailTextLabel.numberOfLines = 2;

        UIButton *inspBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        inspBtn.tag = 301; inspBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:8];
        [inspBtn setTitleColor:accent forState:UIControlStateNormal];
        inspBtn.layer.borderColor = [accent colorWithAlphaComponent:0.3].CGColor;
        inspBtn.layer.borderWidth = 0.5; inspBtn.layer.cornerRadius = 4;
        [cell.contentView addSubview:inspBtn];
    }

    if (row < (NSInteger)hits.count) {
        VLWatchHit *hit = hits[row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@ + 0x%llX", hit.imageName, hit.offset];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"PC: 0x%llX | Val: %llu (0x%llX)",
                                     hit.pc, hit.newValue, hit.newValue];
        UIButton *inspBtn = [cell.contentView viewWithTag:301];
        CGFloat cw = self.watchHitTable.bounds.size.width - 8;
        inspBtn.frame = CGRectMake(cw - 50, 10, 46, 28);
        [inspBtn setTitle:VL(@"Inspector_Title") forState:UIControlStateNormal];
        inspBtn.hidden = NO;
        objc_setAssociatedObject(inspBtn, "hitObj", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [inspBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [inspBtn addTarget:self action:@selector(onWatchInspectHit:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        cell.textLabel.text = @"--"; cell.detailTextLabel.text = @"";
        UIButton *inspBtn = [cell.contentView viewWithTag:301]; inspBtn.hidden = YES;
    }
    return cell;
}

- (void)onWatchInspectHit:(UIButton *)sender {
    VLWatchHit *hit = objc_getAssociatedObject(sender, "hitObj");
    if (hit) [self openCodeInspectorForHit:hit];
}

- (void)openCodeInspectorForHit:(VLWatchHit *)hit {
    self.watchInspectHit = hit;
    self.watchInspectLines = [[VLDebugEngine shared] disassembleFunctionAt:hit.pc moduleName:hit.imageName];
    self.watchNavState = 1;
    [self layoutWatchFusionForInspector];
}

- (void)onWatchDeleteSlot:(UIButton *)sender {
    NSNumber *idx = objc_getAssociatedObject(sender, "slotIdx");
    if (!idx) return;
    [[VLDebugEngine shared] removeWatchpoint:[idx unsignedIntValue]];
    if (self.watchSelectedSlot == [idx integerValue]) self.watchSelectedSlot = -1;
    [self.watchSlotTable reloadData]; [self.watchHitTable reloadData];
    showToast(VL(@"Watch_Removed"));
}

#pragma mark - Browser Fusion Cell

- (UITableViewCell *)browserFusionCellForRow:(NSInteger)row {
    UIColor *accent = [UIColor cyanColor];
    static NSString *cellId = @"BFCell";
    UITableViewCell *cell = [self.browserTable dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 4;

        UILabel *addrLabel = [[UILabel alloc] init];
        addrLabel.font = [UIFont fontWithName:@"Menlo" size:9];
        addrLabel.textColor = [accent colorWithAlphaComponent:0.7]; addrLabel.tag = 201;
        addrLabel.numberOfLines = 2;
        addrLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [cell.contentView addSubview:addrLabel];

        UILabel *valueLabel = [[UILabel alloc] init];
        valueLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:10];
        valueLabel.textColor = accent; valueLabel.textAlignment = NSTextAlignmentRight; valueLabel.tag = 202;
        [cell.contentView addSubview:valueLabel];

        UIButton *lockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        lockBtn.titleLabel.font = [UIFont systemFontOfSize:9]; lockBtn.tag = 203;
        [cell.contentView addSubview:lockBtn];
    }

    if (row >= (NSInteger)self.browserMemoryData.count) return cell;

    NSDictionary *item = self.browserMemoryData[row];
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    NSNumber *addrKey = @(addr);
    BOOL isLocked = self.browserLockedItems[addrKey] != nil;
    BOOL isSelected = self.browserMultiSelectMode && [self.multiSelectedAddresses containsObject:addrKey];
    BOOL isTarget = (addr == self.browserTargetAddr);

    UILabel *addrLabel = [cell.contentView viewWithTag:201];
    UILabel *valueLabel = [cell.contentView viewWithTag:202];
    UIButton *lockBtn = [cell.contentView viewWithTag:203];

    CGFloat cw = self.browserTable.bounds.size.width;
    CGFloat lockW = 42;
    CGFloat addrW = MIN(150.0, MAX(122.0, cw * 0.45));
    CGFloat valW = MAX(72.0, cw - addrW - lockW - 22);

    addrLabel.frame = CGRectMake(6, 2, addrW, self.browserTable.rowHeight - 4);
    valueLabel.frame = CGRectMake(addrW + 8, 0, valW, self.browserTable.rowHeight);
    lockBtn.frame = CGRectMake(cw - lockW - 6, 10, lockW, 28);

    addrLabel.attributedText = VLToolboxBrowserAddressText(addr, self.browserTargetAddr, accent, isTarget);
    valueLabel.text = item[@"value"];

    if (isSelected) cell.backgroundColor = [[UIColor systemYellowColor] colorWithAlphaComponent:0.16];
    else if (isTarget) cell.backgroundColor = [[UIColor yellowColor] colorWithAlphaComponent:0.12];
    else if (isLocked) cell.backgroundColor = [accent colorWithAlphaComponent:0.1];
    else cell.backgroundColor = [accent colorWithAlphaComponent:0.025];

    [lockBtn setTitle:isLocked ? VL(@"UI_Locked") : VL(@"UI_Unlocked") forState:UIControlStateNormal];
    [lockBtn setTitleColor:isLocked ? accent : [accent colorWithAlphaComponent:0.5] forState:UIControlStateNormal];
    objc_setAssociatedObject(lockBtn, "bAddr", addrKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(lockBtn, "bType", item[@"type"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(lockBtn, "bValue", item[@"value"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [lockBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [lockBtn addTarget:self action:@selector(onBrowserLockTapped:) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

#pragma mark - Watch Inspect Cell

- (UITableViewCell *)watchInspectCellForRow:(NSInteger)row {
    UIColor *accent = [UIColor cyanColor];
    static NSString *cellId = @"WInspCell";
    UITableViewCell *cell = [self.watchInspectTable dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:9];
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.6;
    }

    if (self.watchInspectLines && row < (NSInteger)self.watchInspectLines.count) {
        NSDictionary *l = self.watchInspectLines[row];
        BOOL isPC = [l[@"isPC"] boolValue];
        NSNumber *selIdx = objc_getAssociatedObject(self.watchInspectToolbar, "selIdx");
        BOOL isSel = (selIdx && [selIdx integerValue] == row);
        NSString *marker = isPC ? @">" : (isSel ? @"*" : @" ");
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %08llX  %@  %@",
                               marker, [l[@"offset"] unsignedLongLongValue], l[@"hex"], l[@"mnemonic"]];
        if (isSel) {
            cell.backgroundColor = [accent colorWithAlphaComponent:0.15];
            cell.textLabel.textColor = [UIColor whiteColor];
        } else if (isPC) {
            cell.backgroundColor = [accent colorWithAlphaComponent:0.08];
            cell.textLabel.textColor = [UIColor whiteColor];
        } else {
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = [accent colorWithAlphaComponent:0.8];
        }
    }
    return cell;
}

#pragma mark - Toolbox Lock Toggle

- (void)onTbLockToggle:(UIButton *)sender {
    NSNumber *addrNum = objc_getAssociatedObject(sender, "addr");
    if (!addrNum) return;
    uint64_t address = [addrNum unsignedLongLongValue];

    for (VLPanelMemItem *mi in self.tbMemResults) {
        if (mi.address == address) {
            mi.isLocked = !mi.isLocked;
            NSNumber *addrKey = @(address);
            if (mi.isLocked) {
                NSString *val = mi.currentValue ?: @"0";
                mi.lockValue = val;
                self.memLockedItems[addrKey] = @{@"value": val, @"type": @(mi.dataType)};
                showToast(VL(@"Msg_Locked"));
            } else {
                mi.lockValue = nil;
                [self.memLockedItems removeObjectForKey:addrKey];
                showToast(VL(@"Msg_Unlocked"));
            }
            break;
        }
    }
    [self.tbTable reloadData];
    [self.memResultsTable reloadData];
}

#pragma mark - Toolbox Item Actions

- (void)showTbMemItemActions:(VLPanelMemItem *)item atIndex:(NSUInteger)idx {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", item.address] message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Modify") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        UIAlertController *edit = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"0x%llX", item.address] message:nil preferredStyle:UIAlertControllerStyleAlert];
        [edit addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.text = item.currentValue;
            tf.keyboardType = UIKeyboardTypeDecimalPad;
        }];
        [edit addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [edit addAction:[UIAlertAction actionWithTitle:VL(@"Mem_Write") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a2) {
            NSString *val = edit.textFields.firstObject.text;
            if (val.length > 0) {
                [[VMemEngine shared] writeAddress:item.address value:val type:item.dataType];
                item.currentValue = val;
                if (item.isLocked) item.lockValue = val;
                [self.tbTable reloadData];
            }
        }]];
        [[GetSafeWindow() rootViewController] presentViewController:edit animated:YES completion:nil];
    }]];

    NSString *lockTitle = item.isLocked ? VL(@"Msg_Unlocked") : VL(@"Msg_Locked");
    [ac addAction:[UIAlertAction actionWithTitle:lockTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        item.isLocked = !item.isLocked;
        if (item.isLocked) item.lockValue = item.currentValue;
        showToast(item.isLocked ? VL(@"Msg_Locked") : VL(@"Msg_Unlocked"));
        [self.tbTable reloadData];
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self.tbMemResults removeObjectAtIndex:idx];
        [self.tbTable reloadData];
        [self updateTbPager];
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (ac.popoverPresentationController) ac.popoverPresentationController.sourceView = self.tbTable;
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

- (void)showScriptActions:(VScriptItem *)script atIndex:(NSUInteger)idx {
    NSString *title = script.note.length > 0 ? script.note : script.fileName;
    if (!title || title.length == 0) title = VL(@"Script_Untitled");

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:script.desc preferredStyle:UIAlertControllerStyleActionSheet];

    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Script_Run") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self runScript:script];
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Script_ViewSource") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *source = script.scriptContent ?: @"(empty)";
        if (source.length > 2000) source = [[source substringToIndex:2000] stringByAppendingString:@"\n..."];
        UIAlertController *src = [UIAlertController alertControllerWithTitle:title message:source preferredStyle:UIAlertControllerStyleAlert];
        [src addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDefault handler:nil]];
        [[GetSafeWindow() rootViewController] presentViewController:src animated:YES completion:nil];
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [g_scriptItems removeObjectAtIndex:idx];
        [VModParser saveConfig];
        [self.tbTable reloadData];
        [self updateTbPager];
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (ac.popoverPresentationController) ac.popoverPresentationController.sourceView = self.tbTable;
    [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
}

- (void)runScript:(VScriptItem *)script {
    if (!script.scriptContent || script.scriptContent.length == 0) {
        showToast(VL(@"Script_Empty"));
        return;
    }
    showToast(VL(@"Script_Running"));
    [[VScriptEngine shared] runScript:script.scriptContent completion:^(NSString *log) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:script.note ?: @"Script" message:log preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDefault handler:nil]];
        [[GetSafeWindow() rootViewController] presentViewController:ac animated:YES completion:nil];
    }];
}

@end
