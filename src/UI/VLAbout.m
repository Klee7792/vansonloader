/**
 * VansonLoader L2.3 - VLAbout 实现
 * 简化版: Logo + 版本 + TG链接
 * 完整模式: 包含VPanel所有工具功能（语言设置、配置管理、连点器、Dump等）
 */

#import "VLAbout.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import "VLFloatingButton.h"
#import "VLTools.h"

#ifndef VERSION_STRING
#define VERSION_STRING @"unknown"
#endif

static UIScrollView *g_aboutContainer = nil;

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

@implementation VLAbout

#pragma mark - Main Setup

+ (void)setupAboutView:(UIScrollView *)container {
  [self setupAboutView:container fullMode:NO];
}

+ (void)setupAboutView:(UIScrollView *)container fullMode:(BOOL)fullMode {
  g_aboutContainer = container;

  for (UIView *v in container.subviews) {
    [v removeFromSuperview];
  }

  CGFloat w = container.frame.size.width;

  if (fullMode) {
    // ═══════════════════════════════════════════
    // 完整模式：使用VLTools来填充（包含所有VPanel工具功能）
    // 传入container作为panel参数，用于配置导入等操作
    // ═══════════════════════════════════════════
    [VLTools setupToolsView:container panel:(id)container];
    return;
  }

  // ═══════════════════════════════════════════
  // 简化模式：Logo + 版本 + TG链接
  // ═══════════════════════════════════════════
  BOOL agreed = [[NSUserDefaults standardUserDefaults]
      boolForKey:@"Vanson_Disclaimer_Agreed"];
  CGFloat logoSize = 36;
  CGFloat contentH = logoSize + 4 + 16 + 10 + 28 + (agreed ? 28 : 0) + 12 + 14 + 4;
  CGFloat y = MAX(4, floor((container.bounds.size.height - contentH) / 2.0));
  
  // Logo (居中，更小)
  UIView *logoBox = [[UIView alloc]
      initWithFrame:CGRectMake((w - logoSize) / 2, y, logoSize, logoSize)];
  logoBox.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
  logoBox.layer.cornerRadius = 8;
  logoBox.layer.borderWidth = 1.5;
  logoBox.layer.borderColor = [UIColor cyanColor].CGColor;
  [container addSubview:logoBox];

  [self loadLogoIntoView:logoBox size:logoSize];

  y += logoSize + 4;

  // Title
  UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, w, 16)];
  titleLabel.text =
      [NSString stringWithFormat:@"%@ %@", VL(@"About_Title"), VERSION_STRING];
  titleLabel.textColor = [UIColor cyanColor];
  titleLabel.font = [UIFont boldSystemFontOfSize:13];
  titleLabel.textAlignment = NSTextAlignmentCenter;
  [container addSubview:titleLabel];

  y += 20;

  // Telegram 按钮
  UIButton *tgBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  tgBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
  tgBtn.layer.cornerRadius = 14;
  tgBtn.layer.borderWidth = 1.2;
  tgBtn.layer.borderColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.4].CGColor;
  tgBtn.translatesAutoresizingMaskIntoConstraints = NO;
  [container addSubview:tgBtn];

  UIStackView *stack = [[UIStackView alloc] init];
  stack.axis = UILayoutConstraintAxisHorizontal;
  stack.spacing = 6;
  stack.alignment = UIStackViewAlignmentCenter;
  stack.userInteractionEnabled = NO;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [tgBtn addSubview:stack];

  UIImage *tgIcon = [UIImage systemImageNamed:@"paperplane.fill"];
  UIImageView *iconIV = [[UIImageView alloc] init];
  iconIV.contentMode = UIViewContentModeScaleAspectFit;
  iconIV.tintColor = [UIColor cyanColor];
  if (tgIcon) {
    iconIV.image = tgIcon;
  } else {
    UILabel *fallback = [[UILabel alloc] init];
    fallback.text = @"✈";
    fallback.textColor = [UIColor cyanColor];
    fallback.font = [UIFont systemFontOfSize:14];
    [iconIV addSubview:fallback];
    fallback.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [fallback.centerXAnchor constraintEqualToAnchor:iconIV.centerXAnchor],
      [fallback.centerYAnchor constraintEqualToAnchor:iconIV.centerYAnchor]
    ]];
  }
  [stack addArrangedSubview:iconIV];

  UILabel *tgLbl = [[UILabel alloc] init];
  tgLbl.text = @"@VansonMod";
  tgLbl.textColor = [UIColor cyanColor];
  tgLbl.font = [UIFont boldSystemFontOfSize:12];
  [stack addArrangedSubview:tgLbl];

  [NSLayoutConstraint activateConstraints:@[
    [tgBtn.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor
                                    constant:10],
    [tgBtn.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
    [tgBtn.heightAnchor constraintEqualToConstant:28],
    [tgBtn.widthAnchor constraintGreaterThanOrEqualToConstant:120],

    [stack.centerXAnchor constraintEqualToAnchor:tgBtn.centerXAnchor],
    [stack.centerYAnchor constraintEqualToAnchor:tgBtn.centerYAnchor],
    [stack.leadingAnchor
        constraintGreaterThanOrEqualToAnchor:tgBtn.leadingAnchor
                                    constant:14],
    [stack.trailingAnchor constraintLessThanOrEqualToAnchor:tgBtn.trailingAnchor
                                                   constant:-14],

    [iconIV.widthAnchor constraintEqualToConstant:14],
    [iconIV.heightAnchor constraintEqualToConstant:14],
  ]];

  [tgBtn addTarget:self
                action:@selector(openTelegram)
      forControlEvents:UIControlEventTouchUpInside];

  y += 42;

  // ═══════════════════════════════════════════
  // 免责声明 (简洁文字样式)
  // ═══════════════════════════════════════════
  if (agreed) {
    // 已同意：显示简洁的文字 + 圆圈
    UIView *disclaimerRow = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 24)];
    disclaimerRow.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(onDisclaimerTapped)];
    [disclaimerRow addGestureRecognizer:tap];
    [container addSubview:disclaimerRow];
    
    // 文字
    UILabel *agreedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w - 30, 24)];
    agreedLabel.text = VL(@"Disclaimer_Agreed");
    agreedLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
    agreedLabel.font = [UIFont systemFontOfSize:11];
    agreedLabel.textAlignment = NSTextAlignmentCenter;
    [disclaimerRow addSubview:agreedLabel];
    
    // 圆圈指示器
    UIView *statusIcon = [[UIView alloc] initWithFrame:CGRectMake(w / 2 + 50, 5, 14, 14)];
    statusIcon.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.3];
    statusIcon.layer.cornerRadius = 7;
    statusIcon.layer.borderWidth = 1;
    statusIcon.layer.borderColor = [UIColor cyanColor].CGColor;
    [disclaimerRow addSubview:statusIcon];
    
    y += 28;
  }

  // Copyright
  UILabel *copyrightLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(0, y, w, 12)];
  copyrightLabel.text = @"© 2025 Vanson";
  copyrightLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.4];
  copyrightLabel.font = [UIFont systemFontOfSize:9];
  copyrightLabel.textAlignment = NSTextAlignmentCenter;
  [container addSubview:copyrightLabel];

  y += 14;

  UILabel *licenseLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(0, y, w, 12)];
  licenseLabel.text = VL(@"About_License");
  licenseLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.4];
  licenseLabel.font = [UIFont systemFontOfSize:9];
  licenseLabel.textAlignment = NSTextAlignmentCenter;
  [container addSubview:licenseLabel];

  y += 16;

  container.contentSize = CGSizeMake(w, MAX(CGRectGetMaxY(licenseLabel.frame) + 4, container.bounds.size.height + 1));
}

#pragma mark - Disclaimer Action

+ (void)onDisclaimerTapped {
  BOOL agreed = [[NSUserDefaults standardUserDefaults]
      boolForKey:@"Vanson_Disclaimer_Agreed"];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:VL(@"About_Disclaimer")
                                          message:VL(@"Disclaimer_Text")
                                   preferredStyle:UIAlertControllerStyleAlert];

  if (agreed) {
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Close")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
  } else {
    // 拒绝按钮
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Disclaimer_Reject")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
      // 退出所有窗口，隐藏悬浮按钮
      [self rejectDisclaimer];
    }]];
    // 同意按钮
    [alert addAction:[UIAlertAction
                         actionWithTitle:VL(@"Disclaimer_Agree")
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *action) {
                                   [[NSUserDefaults standardUserDefaults]
                                       setBool:YES
                                        forKey:@"Vanson_Disclaimer_Agreed"];
                                   [[NSUserDefaults standardUserDefaults]
                                       synchronize];
                                   showToast(VL(@"Disclaimer_Agreed"));
                                   // 刷新关于页
                                   if (g_aboutContainer) {
                                     [VAbout setupAboutView:g_aboutContainer];
                                   }
                                 }]];
  }

  UIWindow *window = GetSafeWindow();
  UIViewController *vc = window.rootViewController;
  while (vc.presentedViewController)
    vc = vc.presentedViewController;
  [vc presentViewController:alert animated:YES completion:nil];
}

// 拒绝免责声明：退出所有窗口，隐藏悬浮按钮
+ (void)rejectDisclaimer {
  // 隐藏所有窗口
  Class panelClass = NSClassFromString(@"VLPanel");
  if (panelClass && [panelClass respondsToSelector:@selector(hide)]) {
    [panelClass performSelector:@selector(hide)];
  }
  
  Class memSearchClass = NSClassFromString(@"VLMemorySearchVC");
  if (memSearchClass && [memSearchClass respondsToSelector:@selector(hide)]) {
    [memSearchClass performSelector:@selector(hide)];
  }
  
  Class memResultsClass = NSClassFromString(@"VLMemResults");
  if (memResultsClass && [memResultsClass respondsToSelector:@selector(hide)]) {
    [memResultsClass performSelector:@selector(hide)];
  }
  
  Class toolboxClass = NSClassFromString(@"VLToolbox");
  if (toolboxClass && [toolboxClass respondsToSelector:@selector(hide)]) {
    [toolboxClass performSelector:@selector(hide)];
  }
  
  Class browserClass = NSClassFromString(@"VLMemoryBrowserVC");
  if (browserClass && [browserClass respondsToSelector:@selector(hide)]) {
    [browserClass performSelector:@selector(hide)];
  }
  
  // 隐藏悬浮按钮
  VFloatingButton *btn = [VFloatingButton sharedButton];
  btn.hidden = YES;
  
  showToast(VL(@"Disclaimer_Rejected"));
}

// 检查免责声明状态，未同意则弹窗
+ (void)checkDisclaimerOnLaunch {
  BOOL agreed = [[NSUserDefaults standardUserDefaults]
      boolForKey:@"Vanson_Disclaimer_Agreed"];
  
  if (!agreed) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self onDisclaimerTapped];
    });
  }
}

#pragma mark - Logo Loading

+ (void)loadLogoIntoView:(UIView *)logoBox size:(CGFloat)logoSize {
  // 优先使用用户选择的图标
  NSString *selectedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"Vanson_SelectedIcon"] ?: @"floating_button";
  UIImage *icon = IC(selectedKey);
  if (!icon) icon = IC(@"floating_button");
  if (!icon) {
    // 备用：使用 VLFloatingButton 的图标
    icon = [VFloatingButton iconImage];
  }
  
  if (icon) {
    UIImageView *iv = [[UIImageView alloc] initWithFrame:logoBox.bounds];
    iv.image = icon;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    iv.layer.cornerRadius = logoBox.layer.cornerRadius - 1;
    [logoBox addSubview:iv];
  } else {
    UILabel *vLabel = [[UILabel alloc] initWithFrame:logoBox.bounds];
    vLabel.text = @"V";
    vLabel.textColor = [UIColor cyanColor];
    vLabel.font = [UIFont boldSystemFontOfSize:logoSize * 0.45];
    vLabel.textAlignment = NSTextAlignmentCenter;
    [logoBox addSubview:vLabel];
  }
}

#pragma mark - Actions

+ (void)openTelegram {
  NSURL *url = [NSURL URLWithString:@"https://t.me/VansonMod"];
  if ([[UIApplication sharedApplication] canOpenURL:url]) {
    [[UIApplication sharedApplication] openURL:url
                                       options:@{}
                             completionHandler:nil];
  }
}

@end
