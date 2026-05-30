/**
 * VansonLoader L2.3 - VLItemEditor 实现
 * 简装版编辑器：两行布局（标题在上，控件在下）
 */

#import "VLItemEditor.h"
#import "../Engine/VLModParser.h"
#import "../Utils/VLLocalization.h"

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

@interface VLItemEditorController
    : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) VLModItem *item;
@property(nonatomic, assign) NSInteger resultIndex;
@property(nonatomic, weak) id<VLItemEditorDelegate> delegate;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UISegmentedControl *modeSegment, *typeSegment;
@property(nonatomic, strong) UITextField *noteField, *valueField, *minField,
    *maxField, *switchOnField, *switchOffField;
@property(nonatomic, strong) UITextField *moduleField, *offsetField, *patchHexField, *origHexField;
@end

@implementation VLItemEditorController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:1.0];

  // 导航栏
  UIView *navBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 50)];
  navBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
  navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:navBar];

  UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 10, navBar.frame.size.width - 120, 30)];
  titleLabel.text = VL(@"Edit_Title");
  titleLabel.textColor = [UIColor cyanColor];
  titleLabel.font = [UIFont boldSystemFontOfSize:16];
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [navBar addSubview:titleLabel];

  UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  cancelBtn.frame = CGRectMake(10, 10, 50, 30);
  [cancelBtn setTitle:VL(@"Alert_Cancel") forState:UIControlStateNormal];
  [cancelBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
  [cancelBtn addTarget:self action:@selector(onCancel) forControlEvents:UIControlEventTouchUpInside];
  [navBar addSubview:cancelBtn];

  UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  saveBtn.frame = CGRectMake(navBar.frame.size.width - 60, 10, 50, 30);
  saveBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
  [saveBtn setTitle:VL(@"Edit_Save") forState:UIControlStateNormal];
  [saveBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
  saveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
  [saveBtn addTarget:self action:@selector(onSave) forControlEvents:UIControlEventTouchUpInside];
  [navBar addSubview:saveBtn];

  // 表格
  CGFloat tableTop = 50;
  self.tableView = [[UITableView alloc]
      initWithFrame:CGRectMake(0, tableTop, self.view.frame.size.width, self.view.frame.size.height - tableTop)
              style:UITableViewStyleGrouped];
  self.tableView.backgroundColor = [UIColor clearColor];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.view addSubview:self.tableView];

  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
  tap.cancelsTouchesInView = NO;
  [self.view addGestureRecognizer:tap];
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }
- (void)onCancel { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)segmentIndexForType:(VMDataType)type {
  switch (type) {
    case VMDataTypeI8:  return 0;
    case VMDataTypeI16: return 1;
    case VMDataTypeI32: return 2;
    case VMDataTypeI64: return 3;
    case VMDataTypeF32: return 4;
    case VMDataTypeF64: return 5;
    case VMDataTypeU8:  return 0;
    case VMDataTypeU16: return 1;
    case VMDataTypeU32: return 2;
    case VMDataTypeU64: return 3;
    default: return 2;
  }
}

- (void)onSave {
  if (self.noteField.text.length > 0) self.item.note = self.noteField.text;
  VMUIMode mode = (VMUIMode)self.modeSegment.selectedSegmentIndex;
  VMDataType types[] = {VMDataTypeI8, VMDataTypeI16, VMDataTypeI32, VMDataTypeI64, VMDataTypeF32, VMDataTypeF64};
  NSInteger typeIdx = self.typeSegment.selectedSegmentIndex;
  if (typeIdx < 0 || typeIdx > 5) typeIdx = 2;
  VMDataType dType = types[typeIdx];

  if (self.resultIndex < 0) {
    if (self.item.type == VModTypePointer) {
      if (self.valueField.text.length > 0) self.item.lockValue = self.valueField.text;
      self.item.uiMode = mode;
      self.item.valueType = dType;
      if (mode == VMUIModeSlider) {
        self.item.uiMin = [self.minField.text floatValue];
        self.item.uiMax = [self.maxField.text floatValue];
        if (self.item.uiMax <= self.item.uiMin) self.item.uiMax = self.item.uiMin + 100;
      }
      if (mode == VMUIModeSwitch) {
        self.item.switchOnValue = self.switchOnField.text ?: @"1";
        self.item.switchOffValue = self.switchOffField.text ?: @"0";
      }
    } else if (self.item.type == VModTypeSignature) {
      self.item.valueType = dType;
    } else if (self.item.type == VModTypeRVA) {
      if (self.moduleField.text.length > 0) self.item.moduleName = self.moduleField.text;
      if (self.offsetField.text.length > 0) {
        NSString *offStr = self.offsetField.text;
        unsigned long long val = 0;
        if ([offStr hasPrefix:@"0x"] || [offStr hasPrefix:@"0X"]) {
          [[NSScanner scannerWithString:[offStr substringFromIndex:2]] scanHexLongLong:&val];
        } else {
          [[NSScanner scannerWithString:offStr] scanHexLongLong:&val];
        }
        self.item.rvaOffset = val;
      }
      if (self.patchHexField.text.length > 0) self.item.patchHex = self.patchHexField.text;
      if (self.origHexField.text.length > 0) self.item.originalHex = self.origHexField.text;
    }
  } else {
    uint64_t addr = [self.item.runtimeResults[self.resultIndex][@"addr"] unsignedLongLongValue];
    NSMutableDictionary *cfg = [self.item.resultConfig[@(addr)] mutableCopy] ?: [NSMutableDictionary dictionary];
    cfg[@"mode"] = @(mode);
    cfg[@"lockType"] = @(dType);
    if (mode == VMUIModeSlider) {
      cfg[@"min"] = @([self.minField.text floatValue]);
      cfg[@"max"] = @([self.maxField.text floatValue]);
    }
    if (mode == VMUIModeSwitch) {
      cfg[@"switchOnValue"] = self.switchOnField.text ?: @"1";
      cfg[@"switchOffValue"] = self.switchOffField.text ?: @"0";
    }
    if (self.valueField.text.length > 0) cfg[@"lockValue"] = self.valueField.text;
    self.item.resultConfig[@(addr)] = cfg;
  }
  [VLModParser saveConfig];
  if ([self.delegate respondsToSelector:@selector(editorDidSaveItem:)])
    [self.delegate editorDidSaveItem:self.item];
  [self dismissViewControllerAnimated:YES completion:nil];
  showToast(VL(@"Msg_Saved"));
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  if (self.resultIndex >= 0 || self.item.type == VModTypePointer) {
    VMUIMode m = self.item.uiMode;
    if (self.resultIndex >= 0) {
      uint64_t addr = [self.item.runtimeResults[self.resultIndex][@"addr"] unsignedLongLongValue];
      m = (VMUIMode)[self.item.resultConfig[@(addr)][@"mode"] integerValue];
    }
    return (m == VMUIModeSlider || m == VMUIModeSwitch) ? 3 : 2;
  }
  if (self.item.type == VModTypeRVA) return 2; // Basic + RVA
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (self.resultIndex >= 0 || self.item.type == VModTypePointer) {
    if (section == 0) return 2; // 备注、数值
    if (section == 1) return 2; // UI模式、数据类型
    if (section == 2) return 2; // 滑块min/max 或 开关on/off
  }
  if (self.item.type == VModTypeRVA) {
    if (section == 0) return 2; // 备注、模块名
    if (section == 1) return 3; // Offset、Patch Hex、Original Hex
  }
  return (self.item.type == VModTypeSignature) ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (self.resultIndex >= 0 || self.item.type == VModTypePointer) {
    if (section == 0) return VL(@"Edit_Section_Basic");
    if (section == 1) return VL(@"Edit_Section_UI");
    if (section == 2) {
      VMUIMode m = self.item.uiMode;
      if (self.resultIndex >= 0) {
        uint64_t addr = [self.item.runtimeResults[self.resultIndex][@"addr"] unsignedLongLongValue];
        m = (VMUIMode)[self.item.resultConfig[@(addr)][@"mode"] integerValue];
      }
      return (m == VMUIModeSlider) ? VL(@"Edit_Section_Slider") : VL(@"Edit_Section_Switch");
    }
  }
  if (self.item.type == VModTypeRVA) {
    if (section == 0) return VL(@"Edit_Section_Basic");
    if (section == 1) return VL(@"Edit_Section_RVA");
  }
  return VL(@"Edit_Section_Basic");
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return 70; // 两行布局需要更高的cell
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
  cell.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  
  VLModItem *it = self.item;
  NSInteger resIdx = self.resultIndex;
  VMUIMode mode = it.uiMode;
  VMDataType type = it.valueType;
  NSString *note = it.note, *val = it.lockValue, *son = it.switchOnValue, *soff = it.switchOffValue;
  float min = it.uiMin, max = it.uiMax;
  
  if (resIdx >= 0) {
    NSDictionary *res = it.runtimeResults[resIdx];
    uint64_t addr = [res[@"addr"] unsignedLongLongValue];
    NSDictionary *cfg = it.resultConfig[@(addr)];
    if (cfg[@"mode"]) mode = (VMUIMode)[cfg[@"mode"] integerValue];
    if (cfg[@"lockType"]) type = (VMDataType)[cfg[@"lockType"] integerValue];
    note = res[@"note"] ?: VL(@"Cell_Unnamed");
    val = cfg[@"lockValue"] ?: res[@"val"];
    if (cfg[@"min"]) min = [cfg[@"min"] floatValue];
    if (cfg[@"max"]) max = [cfg[@"max"] floatValue];
    if (cfg[@"switchOnValue"]) son = cfg[@"switchOnValue"];
    if (cfg[@"switchOffValue"]) soff = cfg[@"switchOffValue"];
  }

  if (resIdx >= 0 || it.type == VModTypePointer) {
    if (indexPath.section == 0) {
      if (indexPath.row == 0) {
        [self setupCell:cell title:VL(@"Edit_Note") withTextField:note tag:1];
      } else {
        [self setupCell:cell title:VL(@"Edit_Value") withTextField:val tag:2];
        self.valueField.keyboardType = UIKeyboardTypeDecimalPad;
      }
    } else if (indexPath.section == 1) {
      if (indexPath.row == 0) {
        [self setupCell:cell title:VL(@"Edit_UIMode") withModeSegment:mode];
      } else {
        [self setupCell:cell title:VL(@"Edit_DataType") withTypeSegment:type];
      }
    } else if (indexPath.section == 2) {
      if (mode == VMUIModeSlider) {
        if (indexPath.row == 0) {
          [self setupCell:cell title:VL(@"Edit_Min") withTextField:[NSString stringWithFormat:@"%.0f", min] tag:3];
        } else {
          [self setupCell:cell title:VL(@"Edit_Max") withTextField:[NSString stringWithFormat:@"%.0f", max] tag:4];
        }
      } else {
        if (indexPath.row == 0) {
          [self setupCell:cell title:VL(@"Edit_OnValue") withTextField:son ?: @"1" tag:5];
        } else {
          [self setupCell:cell title:VL(@"Edit_OffValue") withTextField:soff ?: @"0" tag:6];
        }
      }
    }
  } else if (it.type == VModTypeRVA) {
    if (indexPath.section == 0) {
      if (indexPath.row == 0) {
        [self setupCell:cell title:VL(@"Edit_Note") withTextField:note tag:1];
      } else {
        [self setupCell:cell title:VL(@"Edit_Module") withTextField:it.moduleName ?: @"" tag:10];
      }
    } else if (indexPath.section == 1) {
      if (indexPath.row == 0) {
        NSString *offStr = [NSString stringWithFormat:@"0x%llX", it.rvaOffset];
        [self setupCell:cell title:VL(@"Edit_Offset") withTextField:offStr tag:11];
      } else if (indexPath.row == 1) {
        [self setupCell:cell title:VL(@"Edit_PatchHex") withTextField:it.patchHex ?: @"" tag:12];
      } else {
        [self setupCell:cell title:VL(@"Edit_OrigHex") withTextField:it.originalHex ?: @"" tag:13];
      }
    }
  } else if (it.type == VModTypeSignature) {
    if (indexPath.row == 0) {
      [self setupCell:cell title:VL(@"Edit_Note") withTextField:note tag:1];
    } else {
      [self setupCell:cell title:VL(@"Edit_DataType") withTypeSegment:type];
    }
  } else {
    [self setupCell:cell title:VL(@"Edit_Note") withTextField:note tag:1];
  }
  return cell;
}

#pragma mark - Cell Setup (两行布局)

- (void)setupCell:(UITableViewCell *)cell title:(NSString *)title withTextField:(NSString *)text tag:(NSInteger)tag {
  // 标题标签 - 第一行
  UILabel *titleLabel = [[UILabel alloc] init];
  titleLabel.text = title;
  titleLabel.textColor = [UIColor lightGrayColor];
  titleLabel.font = [UIFont systemFontOfSize:13];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [cell.contentView addSubview:titleLabel];
  
  // 输入框 - 第二行，全宽
  UITextField *tf = [[UITextField alloc] init];
  tf.text = text;
  tf.textColor = [UIColor cyanColor];
  tf.font = [UIFont fontWithName:@"Menlo" size:14];
  tf.borderStyle = UITextBorderStyleNone;
  tf.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
  tf.layer.cornerRadius = 6;
  tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
  tf.leftViewMode = UITextFieldViewModeAlways;
  tf.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
  tf.rightViewMode = UITextFieldViewModeAlways;
  tf.returnKeyType = UIReturnKeyDone;
  tf.translatesAutoresizingMaskIntoConstraints = NO;
  [cell.contentView addSubview:tf];
  
  // 键盘工具栏
  UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
  toolbar.barStyle = UIBarStyleBlack;
  toolbar.tintColor = [UIColor cyanColor];
  UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
  UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:VL(@"Btn_Done") style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
  toolbar.items = @[flex, done];
  tf.inputAccessoryView = toolbar;
  
  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
    [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
    [titleLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
    [tf.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
    [tf.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
    [tf.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
    [tf.heightAnchor constraintEqualToConstant:32],
  ]];
  
  // 保存引用
  switch (tag) {
    case 1: self.noteField = tf; break;
    case 2: self.valueField = tf; break;
    case 3: self.minField = tf; break;
    case 4: self.maxField = tf; break;
    case 5: self.switchOnField = tf; break;
    case 6: self.switchOffField = tf; break;
    case 10: self.moduleField = tf; break;
    case 11: self.offsetField = tf; break;
    case 12: self.patchHexField = tf; break;
    case 13: self.origHexField = tf; break;
  }
  
}

- (void)setupCell:(UITableViewCell *)cell title:(NSString *)title withModeSegment:(VMUIMode)mode {
  UILabel *titleLabel = [[UILabel alloc] init];
  titleLabel.text = title;
  titleLabel.textColor = [UIColor lightGrayColor];
  titleLabel.font = [UIFont systemFontOfSize:13];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [cell.contentView addSubview:titleLabel];
  
  self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[VL(@"Mode_Card"), VL(@"Mode_Slider"), VL(@"Mode_Switch")]];
  self.modeSegment.selectedSegmentIndex = mode;
  self.modeSegment.selectedSegmentTintColor = [UIColor cyanColor];
  [self.modeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:12]} forState:UIControlStateSelected];
  [self.modeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor lightGrayColor] colorWithAlphaComponent:0.7], NSFontAttributeName: [UIFont systemFontOfSize:12]} forState:UIControlStateNormal];
  [self.modeSegment addTarget:self action:@selector(onModeChanged) forControlEvents:UIControlEventValueChanged];
  self.modeSegment.translatesAutoresizingMaskIntoConstraints = NO;
  [cell.contentView addSubview:self.modeSegment];
  
  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
    [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
    [self.modeSegment.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
    [self.modeSegment.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
    [self.modeSegment.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
    [self.modeSegment.heightAnchor constraintEqualToConstant:30],
  ]];
}

- (void)setupCell:(UITableViewCell *)cell title:(NSString *)title withTypeSegment:(VMDataType)type {
  UILabel *titleLabel = [[UILabel alloc] init];
  titleLabel.text = title;
  titleLabel.textColor = [UIColor lightGrayColor];
  titleLabel.font = [UIFont systemFontOfSize:13];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [cell.contentView addSubview:titleLabel];
  
  self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[@"I8", @"I16", @"I32", @"I64", @"F32", @"F64"]];
  self.typeSegment.selectedSegmentIndex = [self segmentIndexForType:type];
  self.typeSegment.selectedSegmentTintColor = [UIColor cyanColor];
  [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:11]} forState:UIControlStateSelected];
  [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor lightGrayColor] colorWithAlphaComponent:0.7], NSFontAttributeName: [UIFont systemFontOfSize:11]} forState:UIControlStateNormal];
  self.typeSegment.translatesAutoresizingMaskIntoConstraints = NO;
  [cell.contentView addSubview:self.typeSegment];
  
  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
    [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
    [self.typeSegment.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
    [self.typeSegment.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
    [self.typeSegment.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
    [self.typeSegment.heightAnchor constraintEqualToConstant:30],
  ]];
}

- (void)onModeChanged {
  if (self.resultIndex >= 0) {
    uint64_t addr = [self.item.runtimeResults[self.resultIndex][@"addr"] unsignedLongLongValue];
    NSMutableDictionary *cfg = [self.item.resultConfig[@(addr)] mutableCopy] ?: [NSMutableDictionary dictionary];
    cfg[@"mode"] = @(self.modeSegment.selectedSegmentIndex);
    self.item.resultConfig[@(addr)] = cfg;
  } else {
    self.item.uiMode = (VMUIMode)self.modeSegment.selectedSegmentIndex;
  }
  [self.tableView reloadData];
}

@end

#pragma mark - VLItemEditor

@implementation VLItemEditor

+ (void)showEditorForItem:(VLModItem *)item fromWindow:(UIWindow *)window delegate:(id<VLItemEditorDelegate>)delegate {
  VLItemEditorController *vc = [[VLItemEditorController alloc] init];
  vc.item = item;
  vc.resultIndex = -1;
  vc.delegate = delegate;
  vc.modalPresentationStyle = UIModalPresentationFormSheet;
  if (@available(iOS 15.0, *)) {
    if (vc.sheetPresentationController) {
      vc.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
      vc.sheetPresentationController.prefersGrabberVisible = YES;
    }
  }
  [[window rootViewController] presentViewController:vc animated:YES completion:nil];
}

+ (void)showEditorForResult:(VLModItem *)item atIndex:(NSInteger)index fromWindow:(UIWindow *)window delegate:(id<VLItemEditorDelegate>)delegate {
  VLItemEditorController *vc = [[VLItemEditorController alloc] init];
  vc.item = item;
  vc.resultIndex = index;
  vc.delegate = delegate;
  vc.modalPresentationStyle = UIModalPresentationFormSheet;
  if (@available(iOS 15.0, *)) {
    if (vc.sheetPresentationController) {
      vc.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
      vc.sheetPresentationController.prefersGrabberVisible = YES;
    }
  }
  [[window rootViewController] presentViewController:vc animated:YES completion:nil];
}

@end
