/**
 * VansonLoader L2.3 - VLTools 实现
 * 优化: 排版、动画、视觉效果
 */

#import "VLTools.h"
#import "VLMemorySearch.h"
#import "VLFileBrowser.h"
#import "../Utils/VLLocalization.h"
#import <mach-o/dyld.h>

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

// 全局变量
BOOL g_clickerRunning = NO;
double g_clickInterval = 0.5;
NSMutableArray *g_clickPoints = nil;

// 触摸穿透模式全局变量
BOOL g_touchPassthroughMode = NO;
static NSString *const kTouchPassthroughKey = @"Vanson_TouchPassthrough";

static UITextField *g_intervalField = nil;
static UIButton *g_btnStartClicker = nil;

#pragma mark - VLTools

@implementation VLTools

static NSString *const kLangKey = @"Vanson_Language_Setting";

+ (void)setupToolsView:(UIScrollView *)container panel:(id)panel {
  CGFloat w = container.frame.size.width;
  CGFloat y = 8;
  CGFloat boxMargin = 12;
  CGFloat boxWidth = w - boxMargin * 2;

  // ═══════════════════════════════════════════
  // 语言设置 Box (改用列表选择器)
  // ═══════════════════════════════════════════
  UIView *langBox = [self createBox:VL(@"About_Lang") y:y w:boxWidth h:70];
  langBox.frame = CGRectMake(boxMargin, y, boxWidth, 70);
  [container addSubview:langBox];

  // 当前语言显示按钮
  NSString *currentLangName = [[VLocalization shared] currentLanguageName];
  UIButton *langBtn = [self createBtn:currentLangName
                                frame:CGRectMake(10, 35, boxWidth - 20, 30)
                                color:[UIColor cyanColor]];
  langBtn.tag = 9001; // 用于后续更新
  [langBtn addTarget:self
              action:@selector(showLanguagePicker)
    forControlEvents:UIControlEventTouchUpInside];
  [langBox addSubview:langBtn];

  y += 85;

  // ═══════════════════════════════════════════
  // 配置管理 Box
  // ═══════════════════════════════════════════
  UIView *configBox = [self createBox:VL(@"Tool_Config") y:y w:boxWidth h:85];
  configBox.frame = CGRectMake(boxMargin, y, boxWidth, 85);
  [container addSubview:configBox];

  CGFloat btnWidth = (boxWidth - 30) / 2;
  UIButton *btnImport = [self createBtn:VL(@"Config_Import")
                                  frame:CGRectMake(10, 40, btnWidth, 34)
                                  color:[UIColor cyanColor]];
  [btnImport addTarget:panel
                action:@selector(importConfig)
      forControlEvents:UIControlEventTouchUpInside];
  [configBox addSubview:btnImport];

  UIButton *btnDelete =
      [self createBtn:VL(@"Config_Delete")
                frame:CGRectMake(20 + btnWidth, 40, btnWidth, 34)
                color:[UIColor cyanColor]];
  [btnDelete addTarget:panel
                action:@selector(deleteConfig)
      forControlEvents:UIControlEventTouchUpInside];
  [configBox addSubview:btnDelete];

  y += 100;

  // ═══════════════════════════════════════════
  // 文件浏览器 Box
  // ═══════════════════════════════════════════
  UIView *fileBox = [self createBox:VL(@"FileBrowser_Title") y:y w:boxWidth h:75];
  fileBox.frame = CGRectMake(boxMargin, y, boxWidth, 75);
  [container addSubview:fileBox];

  UIButton *fileBtn = [self createBtn:VL(@"FileBrowser_Open")
                                frame:CGRectMake(10, 35, boxWidth - 20, 30)
                                color:[UIColor cyanColor]];
  [fileBtn addTarget:self
              action:@selector(openFileBrowser)
    forControlEvents:UIControlEventTouchUpInside];
  [fileBox addSubview:fileBtn];

  y += 90;

  // 连点器 Box
  UIView *clickBox = [self createBox:VL(@"Tool_Clicker") y:y w:boxWidth h:130];
  clickBox.frame = CGRectMake(boxMargin, y, boxWidth, 130);
  [container addSubview:clickBox];

  // 第一行: [-] [间隔输入] [+] [添加点位]
  UIButton *btnMinus = [self createBtn:@"-"
                                 frame:CGRectMake(10, 38, 38, 34)
                                 color:[UIColor cyanColor]];
  btnMinus.titleLabel.font = [UIFont boldSystemFontOfSize:20];
  [btnMinus addTarget:self
                action:@selector(clkSub)
      forControlEvents:UIControlEventTouchUpInside];
  [clickBox addSubview:btnMinus];

  g_intervalField =
      [[UITextField alloc] initWithFrame:CGRectMake(52, 38, 75, 34)];
  g_intervalField.text = [NSString stringWithFormat:@"%.1f", g_clickInterval];
  g_intervalField.textColor = [UIColor cyanColor];
  g_intervalField.font = [UIFont fontWithName:@"Menlo" size:14];
  g_intervalField.layer.borderColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.5].CGColor;
  g_intervalField.layer.borderWidth = 1;
  g_intervalField.layer.cornerRadius = 6;
  g_intervalField.textAlignment = NSTextAlignmentCenter;
  g_intervalField.keyboardType = UIKeyboardTypeDecimalPad;
  g_intervalField.backgroundColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.08];
  UIToolbar *kbToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 280, 44)];
  kbToolbar.barStyle = UIBarStyleBlack;
  kbToolbar.tintColor = [UIColor cyanColor];
  UIBarButtonItem *kbFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
  UIBarButtonItem *kbDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:g_intervalField action:@selector(resignFirstResponder)];
  kbToolbar.items = @[kbFlex, kbDone];
  g_intervalField.inputAccessoryView = kbToolbar;
  [g_intervalField addTarget:self
                      action:@selector(onIntervalTyped)
            forControlEvents:UIControlEventEditingChanged];
  [clickBox addSubview:g_intervalField];

  // 秒标签: 叠放在输入框右侧内部
  UILabel *secLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(52 + 75 - 18, 38, 15, 34)];
  secLabel.text = @"s";
  secLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.4];
  secLabel.font = [UIFont systemFontOfSize:11];
  secLabel.textAlignment = NSTextAlignmentCenter;
  [clickBox addSubview:secLabel];

  UIButton *btnPlus = [self createBtn:@"+"
                                frame:CGRectMake(132, 38, 38, 34)
                                color:[UIColor cyanColor]];
  btnPlus.titleLabel.font = [UIFont boldSystemFontOfSize:20];
  [btnPlus addTarget:self
                action:@selector(clkAdd)
      forControlEvents:UIControlEventTouchUpInside];
  [clickBox addSubview:btnPlus];

  UIButton *btnAdd = [self createBtn:VL(@"Click_AddPt")
                               frame:CGRectMake(20 + btnWidth, 38, btnWidth, 34)
                               color:[UIColor cyanColor]];
  [btnAdd addTarget:self
                action:@selector(clkPt)
      forControlEvents:UIControlEventTouchUpInside];
  [clickBox addSubview:btnAdd];

  // 第二行: [撤销] [启动/停止]
  UIButton *btnUndo = [self createBtn:VL(@"Click_Undo")
                                frame:CGRectMake(10, 82, btnWidth, 34)
                                color:[UIColor cyanColor]];
  [btnUndo addTarget:self
                action:@selector(clkUndo)
      forControlEvents:UIControlEventTouchUpInside];
  [clickBox addSubview:btnUndo];

  NSString *btnTitle =
      g_clickerRunning ? VL(@"Click_Stop") : VL(@"Click_Start");
  UIColor *btnColor =
      g_clickerRunning ? [[UIColor cyanColor] colorWithAlphaComponent:0.6] : [UIColor cyanColor];
  g_btnStartClicker =
      [self createBtn:btnTitle
                frame:CGRectMake(20 + btnWidth, 82, btnWidth, 34)
                color:btnColor];
  [g_btnStartClicker addTarget:self
                        action:@selector(clkToggle)
              forControlEvents:UIControlEventTouchUpInside];
  [clickBox addSubview:g_btnStartClicker];

  y += 145;

  // Dump Box
  UIView *dumpBox = [self createBox:VL(@"Tool_Dump") y:y w:boxWidth h:75];
  dumpBox.frame = CGRectMake(boxMargin, y, boxWidth, 75);
  [container addSubview:dumpBox];

  UIButton *dumpBtn = [self createBtn:VL(@"Dump_Btn")
                                frame:CGRectMake(10, 35, boxWidth - 20, 30)
                                color:[UIColor cyanColor]];
  dumpBtn.titleLabel.font = [UIFont systemFontOfSize:12];
  [dumpBtn addTarget:self
                action:@selector(onDump)
      forControlEvents:UIControlEventTouchUpInside];
  [dumpBox addSubview:dumpBtn];

  y += 90;

  // ═══════════════════════════════════════════
  // 触摸穿透模式 Box
  // ═══════════════════════════════════════════
  UIView *touchBox = [self createBox:VL(@"Tool_TouchMode") y:y w:boxWidth h:85];
  touchBox.frame = CGRectMake(boxMargin, y, boxWidth, 85);
  [container addSubview:touchBox];

  // 描述标签
  UILabel *touchDesc = [[UILabel alloc] initWithFrame:CGRectMake(12, 32, boxWidth - 80, 20)];
  touchDesc.text = VL(@"Touch_Mode_Desc");
  touchDesc.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6];
  touchDesc.font = [UIFont systemFontOfSize:11];
  [touchBox addSubview:touchDesc];

  // 开关
  UISwitch *touchSwitch = [[UISwitch alloc] init];
  touchSwitch.frame = CGRectMake(boxWidth - 60, 30, 51, 31);
  touchSwitch.onTintColor = [UIColor cyanColor];
  touchSwitch.tag = 9002;
  // 从 UserDefaults 读取状态
  g_touchPassthroughMode = [[NSUserDefaults standardUserDefaults] boolForKey:kTouchPassthroughKey];
  touchSwitch.on = g_touchPassthroughMode;
  [touchSwitch addTarget:self action:@selector(onTouchModeToggle:) forControlEvents:UIControlEventValueChanged];
  [touchBox addSubview:touchSwitch];

  // 状态标签
  UILabel *touchStatus = [[UILabel alloc] initWithFrame:CGRectMake(12, 55, boxWidth - 24, 20)];
  touchStatus.tag = 9003;
  touchStatus.text = g_touchPassthroughMode ? VL(@"Touch_Mode_On") : VL(@"Touch_Mode_Off");
  touchStatus.textColor = g_touchPassthroughMode ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.5];
  touchStatus.font = [UIFont systemFontOfSize:11];
  [touchBox addSubview:touchStatus];

  y += 100;

  UILabel *licenseLabel = [[UILabel alloc]
      initWithFrame:CGRectMake(boxMargin, y, boxWidth, 16)];
  licenseLabel.text = VL(@"About_License");
  licenseLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.4];
  licenseLabel.font = [UIFont systemFontOfSize:10];
  licenseLabel.textAlignment = NSTextAlignmentCenter;
  [container addSubview:licenseLabel];

  container.contentSize = CGSizeMake(w, CGRectGetMaxY(licenseLabel.frame) + 10);
}

#pragma mark - Language & Disclaimer

+ (void)showLanguagePicker {
  NSArray *languages = [[VLocalization shared] supportedLanguages];
  NSInteger currentIdx = [[VLocalization shared] currentLanguage];
  
  UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"About_Lang")
                                                              message:nil
                                                       preferredStyle:UIAlertControllerStyleActionSheet];
  
  for (NSInteger i = 0; i < languages.count; i++) {
    NSDictionary *lang = languages[i];
    NSString *title = lang[@"native"];
    
    // 当前选中的语言添加勾选标记
    if (i == currentIdx) {
      title = [NSString stringWithFormat:@"✓ %@", title];
    }
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *a) {
      [[VLocalization shared] setLanguage:i];
      showToast(VL(@"Msg_LangChanged"));
    }];
    
    // 设置文字颜色
    [action setValue:[UIColor cyanColor] forKey:@"titleTextColor"];
    [ac addAction:action];
  }
  
  [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel")
                                         style:UIAlertActionStyleCancel
                                       handler:nil]];
  
  // iPad 兼容
  if (ac.popoverPresentationController) {
    UIWindow *window = GetSafeWindow();
    ac.popoverPresentationController.sourceView = window;
    ac.popoverPresentationController.sourceRect = CGRectMake(window.bounds.size.width / 2, window.bounds.size.height / 2, 1, 1);
  }
  
  UIWindow *window = GetSafeWindow();
  UIViewController *vc = window.rootViewController;
  while (vc.presentedViewController) vc = vc.presentedViewController;
  [vc presentViewController:ac animated:YES completion:nil];
}

+ (void)onLanguageChanged:(UISegmentedControl *)seg {
  [[VLocalization shared] setLanguage:seg.selectedSegmentIndex];
  showToast(VL(@"Msg_LangChanged"));
}

+ (void)onDisclaimerTapped {
  BOOL agreed = [[NSUserDefaults standardUserDefaults]
      boolForKey:@"Vanson_Disclaimer_Agreed"];

  // 始终显示免责声明弹窗，已同意时只显示关闭按钮
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:VL(@"About_Disclaimer")
                                          message:VL(@"Disclaimer_Text")
                                   preferredStyle:UIAlertControllerStyleAlert];

  if (agreed) {
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Close")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
  } else {
    [alert addAction:[UIAlertAction actionWithTitle:VL(@"Btn_Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
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
                                 }]];
  }

  UIWindow *window = GetSafeWindow();
  UIViewController *vc = window.rootViewController;
  while (vc.presentedViewController)
    vc = vc.presentedViewController;
  [vc presentViewController:alert animated:YES completion:nil];
}

+ (UIView *)createBox:(NSString *)title y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h {
  UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, h)];
  v.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.04];
  v.layer.cornerRadius = 10;
  v.layer.borderWidth = 1;
  v.layer.borderColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;

  // 标题标签
  UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 24, 22)];
  l.text = title;
  l.textColor = [UIColor cyanColor];
  l.font = [UIFont boldSystemFontOfSize:13];
  [v addSubview:l];

  return v;
}

+ (UIButton *)createBtn:(NSString *)title
                  frame:(CGRect)frame
                  color:(UIColor *)color {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
  b.frame = frame;
  [b setTitle:title forState:UIControlStateNormal];
  [b setTitleColor:color forState:UIControlStateNormal];
  b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  b.layer.cornerRadius = 8;
  b.layer.borderColor = color.CGColor;
  b.layer.borderWidth = 1;
  b.backgroundColor = [color colorWithAlphaComponent:0.08];

  // 按下效果
  [b addTarget:self
                action:@selector(btnTouchDown:)
      forControlEvents:UIControlEventTouchDown];
  [b addTarget:self
                action:@selector(btnTouchUp:)
      forControlEvents:UIControlEventTouchUpInside |
                       UIControlEventTouchUpOutside |
                       UIControlEventTouchCancel];

  return b;
}

+ (void)btnTouchDown:(UIButton *)btn {
  [UIView animateWithDuration:0.1
                   animations:^{
                     btn.transform = CGAffineTransformMakeScale(0.95, 0.95);
                     btn.backgroundColor =
                         [btn.currentTitleColor colorWithAlphaComponent:0.2];
                   }];
}

+ (void)btnTouchUp:(UIButton *)btn {
  [UIView animateWithDuration:0.1
                   animations:^{
                     btn.transform = CGAffineTransformIdentity;
                     btn.backgroundColor =
                         [btn.currentTitleColor colorWithAlphaComponent:0.08];
                   }];
}

+ (void)clkSub {
  double v = [g_intervalField.text doubleValue] - 0.1;
  if (v < 0.1)
    v = 0.1;
  g_intervalField.text = [NSString stringWithFormat:@"%.1f", v];
  g_clickInterval = v;
  if (g_clickerRunning) {
    [[VClickerManager shared] updateInterval];
  }
}

+ (void)clkAdd {
  double v = [g_intervalField.text doubleValue] + 0.1;
  if (v > 10.0)
    v = 10.0;
  g_intervalField.text = [NSString stringWithFormat:@"%.1f", v];
  g_clickInterval = v;
  if (g_clickerRunning) {
    [[VClickerManager shared] updateInterval];
  }
}

+ (void)onIntervalTyped {
  g_clickInterval = [g_intervalField.text doubleValue];
  if (g_clickInterval < 0.05)
    g_clickInterval = 0.05;
  if (g_clickerRunning) {
    [[VClickerManager shared] updateInterval];
  }
}

+ (void)clkPt {
  [[VClickerManager shared] addPoint];
}
+ (void)clkUndo {
  [[VClickerManager shared] removeLastPoint];
}

+ (void)clkToggle {
  // 确保在启动前获取最新间隔
  g_clickInterval = [g_intervalField.text doubleValue];
  if (g_clickInterval < 0.05)
    g_clickInterval = 0.05;

  [[VClickerManager shared] toggleStart];

  // 延迟微秒更新 UI，确保 Manager 已经切换了全局状态 g_clickerRunning
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        if (g_clickerRunning) {
          [g_btnStartClicker setTitle:VL(@"Click_Stop")
                             forState:UIControlStateNormal];
          [g_btnStartClicker setTitleColor:[[UIColor cyanColor] colorWithAlphaComponent:0.6]
                                  forState:UIControlStateNormal];
          g_btnStartClicker.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6].CGColor;
          g_btnStartClicker.backgroundColor =
              [[UIColor cyanColor] colorWithAlphaComponent:0.15];
        } else {
          [g_btnStartClicker setTitle:VL(@"Click_Start")
                             forState:UIControlStateNormal];
          [g_btnStartClicker setTitleColor:[UIColor cyanColor]
                                  forState:UIControlStateNormal];
          g_btnStartClicker.layer.borderColor = [UIColor cyanColor].CGColor;
          g_btnStartClicker.backgroundColor =
              [[UIColor cyanColor] colorWithAlphaComponent:0.08];
        }
      });
}

+ (void)onDump {
  [VDumpManager dumpUnityFiles];
}

+ (void)openFileBrowser {
  UIWindow *w = GetSafeWindow();
  if (w) [VLFileBrowserVC showFromWindow:w];
}

+ (void)onTouchModeToggle:(UISwitch *)toggle {
  g_touchPassthroughMode = toggle.on;
  [[NSUserDefaults standardUserDefaults] setBool:g_touchPassthroughMode forKey:kTouchPassthroughKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  // 更新状态标签
  UIView *touchBox = toggle.superview;
  UILabel *statusLabel = [touchBox viewWithTag:9003];
  if (statusLabel) {
    statusLabel.text = g_touchPassthroughMode ? VL(@"Touch_Mode_On") : VL(@"Touch_Mode_Off");
    statusLabel.textColor = g_touchPassthroughMode ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.5];
  }
  
  // 发送通知让所有窗口更新触摸处理
  [[NSNotificationCenter defaultCenter] postNotificationName:@"VLTouchModeChanged" object:nil];
  
  showToast(g_touchPassthroughMode ? VL(@"Touch_Mode_On") : VL(@"Touch_Mode_Off"));
}

@end

#pragma mark - VLTargetView

@interface VLTargetView : UIView
@property(nonatomic, assign) NSInteger index;
@property(nonatomic, strong) UILabel *indexLabel;
- (instancetype)initWithIndex:(NSInteger)idx center:(CGPoint)center;
- (void)animateTap;
@end

@implementation VLTargetView

- (instancetype)initWithIndex:(NSInteger)idx center:(CGPoint)center {
  self = [super initWithFrame:CGRectMake(0, 0, 36, 36)];
  if (self) {
    self.center = center;
    self.index = idx;
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 18;
    self.layer.borderColor = [UIColor cyanColor].CGColor;
    self.layer.borderWidth = 2;
    self.layer.shadowColor = [UIColor cyanColor].CGColor;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowRadius = 6;
    self.layer.shadowOpacity = 0.4;
    self.userInteractionEnabled = YES;

    _indexLabel = [[UILabel alloc] initWithFrame:self.bounds];
    _indexLabel.text = [NSString stringWithFormat:@"%ld", (long)idx];
    _indexLabel.textColor = [UIColor cyanColor];
    _indexLabel.textAlignment = NSTextAlignmentCenter;
    _indexLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:16];
    [self addSubview:_indexLabel];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];

    // 出现动画
    self.transform = CGAffineTransformMakeScale(0.5, 0.5);
    self.alpha = 0;
    [UIView animateWithDuration:0.25
                          delay:0
         usingSpringWithDamping:0.6
          initialSpringVelocity:0.8
                        options:0
                     animations:^{
                       self.transform = CGAffineTransformIdentity;
                       self.alpha = 1;
                     }
                     completion:nil];
  }
  return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)p {
  UIView *sv = self.superview;
  CGPoint trans = [p translationInView:sv];
  self.center = CGPointMake(self.center.x + trans.x, self.center.y + trans.y);
  [p setTranslation:CGPointZero inView:sv];

  if (p.state == UIGestureRecognizerStateBegan) {
    [UIView animateWithDuration:0.1
                     animations:^{
                       self.transform = CGAffineTransformMakeScale(1.2, 1.2);
                       self.layer.shadowOpacity = 0.8;
                     }];
  } else if (p.state == UIGestureRecognizerStateEnded ||
             p.state == UIGestureRecognizerStateCancelled) {
    [UIView animateWithDuration:0.1
                     animations:^{
                       self.transform = CGAffineTransformIdentity;
                       self.layer.shadowOpacity = 0.5;
                     }];
  }
}

- (void)animateTap {
  [UIView animateWithDuration:0.08
      animations:^{
        self.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.backgroundColor = [UIColor cyanColor];
        self.indexLabel.textColor = [UIColor whiteColor];
      }
      completion:^(BOOL f) {
        [UIView animateWithDuration:0.12
                         animations:^{
                           self.transform = CGAffineTransformIdentity;
                           self.backgroundColor = [UIColor clearColor];
                           self.indexLabel.textColor = [UIColor cyanColor];
                         }];
      }];
}

@end

#pragma mark - VLClickerManager

@interface VLClickerManager ()
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, assign) NSInteger currentIndex;
@end

@implementation VLClickerManager

+ (instancetype)shared {
  static VClickerManager *s;
  static dispatch_once_t o;
  dispatch_once(&o, ^{
    s = [[VClickerManager alloc] init];
  });
  return s;
}

- (void)addPoint {
  if (!g_clickPoints)
    g_clickPoints = [NSMutableArray array];
  UIWindow *w = GetSafeWindow();
  VLTargetView *v = [[VLTargetView alloc] initWithIndex:g_clickPoints.count + 1
                                               center:w.center];
  [w addSubview:v];
  [w bringSubviewToFront:v];
  [g_clickPoints addObject:v];
}

- (void)removeLastPoint {
  if (g_clickPoints.count > 0) {
    VLTargetView *v = [g_clickPoints lastObject];

    // 消失动画
    [UIView animateWithDuration:0.2
        animations:^{
          v.transform = CGAffineTransformMakeScale(0.3, 0.3);
          v.alpha = 0;
        }
        completion:^(BOOL finished) {
          [v removeFromSuperview];
        }];

    [g_clickPoints removeLastObject];
  }
}

- (void)toggleStart {
  if (g_clickerRunning) {
    [self stop];
  } else {
    [self start];
  }
}

- (void)start {
  if (!g_clickPoints || g_clickPoints.count == 0) {
    showToast(VL(@"Click_NoPoints"));
    return;
  }

  // 更新间隔
  g_clickInterval = [g_intervalField.text doubleValue];
  if (g_clickInterval < 0.05)
    g_clickInterval = 0.05;

  g_clickerRunning = YES;
  _currentIndex = 0;
  self.timer = [NSTimer scheduledTimerWithTimeInterval:g_clickInterval
                                                target:self
                                              selector:@selector(onTick)
                                              userInfo:nil
                                               repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
  showToast(VL(@"Click_Start"));
}

- (void)stop {
  g_clickerRunning = NO;
  if (self.timer) {
    [self.timer invalidate];
    self.timer = nil;
  }
  showToast(VL(@"Click_Stop"));
}

- (void)updateInterval {
  if (!g_clickerRunning)
    return;
  if (self.timer) {
    [self.timer invalidate];
    self.timer = nil;
  }

  // 按照新间隔重新启动定时器
  self.timer = [NSTimer scheduledTimerWithTimeInterval:g_clickInterval
                                                target:self
                                              selector:@selector(onTick)
                                              userInfo:nil
                                               repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)onTick {
  if (g_clickPoints.count == 0) {
    [self stop];
    return;
  }
  if (_currentIndex >= g_clickPoints.count)
    _currentIndex = 0;

  VLTargetView *target = g_clickPoints[_currentIndex];
  [target animateTap];
  [self touchAt:target.center];
  _currentIndex++;
}

- (void)touchAt:(CGPoint)point {
  UIWindow *window = GetSafeWindow();
  if (!window)
    return;

  UIView *targetView = [window hitTest:point withEvent:nil];
  if (!targetView || [targetView isKindOfClass:[VLTargetView class]]) {
    targetView = window.rootViewController.view;
  }
  if (!targetView)
    return;

  @try {
    UITouch *touch = [[UITouch alloc] init];
    [touch setValue:window forKey:@"window"];
    [touch setValue:targetView forKey:@"view"];
    [touch setValue:@(1) forKey:@"tapCount"];
    [touch setValue:@(UITouchPhaseBegan) forKey:@"phase"];
    [touch setValue:[NSValue valueWithCGPoint:point]
             forKey:@"locationInWindow"];
    [touch setValue:@([[NSProcessInfo processInfo] systemUptime])
             forKey:@"timestamp"];

    NSSet *touches = [NSSet setWithObject:touch];
    if ([targetView respondsToSelector:@selector(touchesBegan:withEvent:)]) {
      [targetView touchesBegan:touches withEvent:nil];
    }

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          @try {
            [touch setValue:@(UITouchPhaseEnded) forKey:@"phase"];
            if ([targetView respondsToSelector:@selector(touchesEnded:
                                                            withEvent:)]) {
              [targetView touchesEnded:touches withEvent:nil];
            }
          } @catch (NSException *e) {
          }
        });
  } @catch (NSException *e) {
    // 移除日志输出
  }
}

- (void)hideAllPoints:(BOOL)hidden {
  for (UIView *v in g_clickPoints)
    v.hidden = hidden;
}

@end

#pragma mark - VLDumpManager

@implementation VLDumpManager

+ (void)dumpUnityFiles {
  showToast(VL(@"Msg_Scanning"));

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];

        // 查找 global-metadata.dat
        NSString *mp =
            [[NSBundle mainBundle] pathForResource:@"global-metadata"
                                            ofType:@"dat"
                                       inDirectory:@"Data/Managed/Metadata"];
        if (![fm fileExistsAtPath:mp]) {
          mp = [[[NSBundle mainBundle] bundlePath]
              stringByAppendingPathComponent:
                  @"Data/Managed/Metadata/global-metadata.dat"];
        }
        if (![fm fileExistsAtPath:mp]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            showToast(VL(@"Msg_NoResult"));
          });
          return;
        }

        // 查找 UnityFramework
        NSString *bp = nil;
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
          const char *name = _dyld_get_image_name(i);
          if (name && [[NSString stringWithUTF8String:name]
                          containsString:@"UnityFramework"]) {
            bp = [NSString stringWithUTF8String:name];
            break;
          }
        }
        if (!bp)
          bp = [[NSBundle mainBundle] executablePath];

        // 创建导出目录
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: @"App";
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyyMMdd_HHmmss"];
        NSString *dirName =
            [NSString stringWithFormat:@"%@_Unity_%@", appName,
                                       [df stringFromDate:[NSDate date]]];
        NSString *exportDir =
            [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];

        [fm createDirectoryAtPath:exportDir
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:nil];
        [fm copyItemAtPath:mp
                    toPath:[exportDir stringByAppendingPathComponent:
                                          @"global-metadata.dat"]
                     error:nil];
        [fm copyItemAtPath:bp
                    toPath:[exportDir stringByAppendingPathComponent:
                                          bp.lastPathComponent]
                     error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
          NSURL *u = [NSURL fileURLWithPath:exportDir];
          UIDocumentPickerViewController *p;
          if (@available(iOS 14.0, *)) {
            p = [[UIDocumentPickerViewController alloc]
                initForExportingURLs:@[ u ]
                              asCopy:YES];
          } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            p = [[UIDocumentPickerViewController alloc]
                initWithURL:u
                     inMode:UIDocumentPickerModeExportToService];
#pragma clang diagnostic pop
          }
          [[GetSafeWindow() rootViewController] presentViewController:p
                                                             animated:YES
                                                           completion:nil];
          showToast(VL(@"Msg_ScanComplete"));
        });
      });
}

@end
