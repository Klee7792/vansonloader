/**
 * VansonLoader L2.3 - VLModCell 实现
 * 紧凑布局: 充分利用横向空间
 */

#import "VLModCell.h"
#import "../Utils/VLLocalization.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern void showToast(NSString *msg);

static NSString *const kDefaultSwitchOn = @"1";
static NSString *const kDefaultSwitchOff = @"0";

@interface VLModCell ()
@property(nonatomic, strong) UIView *cardView;
@property(nonatomic, strong) UIButton *enableBtn;  // 启用/禁用勾选按钮
@property(nonatomic, strong) UILabel *noteLabel;
@property(nonatomic, strong) UILabel *authorLabel;
@property(nonatomic, strong) UIButton *valueBtn;
@property(nonatomic, strong) UISlider *slider;
@property(nonatomic, strong) UISwitch *toggleSwitch;
@property(nonatomic, strong) UIButton *matchBtn;
@property(nonatomic, strong) UIButton *editBtn;
@property(nonatomic, strong) UIStackView *resultsStack;
@property(nonatomic, strong) UIActivityIndicatorView *spinner;
@property(nonatomic, strong) VModItem *item;
@property(nonatomic, copy) NSString *currentValue;
@end

@implementation VLModCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self)
    [self setupUI];
  return self;
}

- (void)setupUI {
  self.backgroundColor = [UIColor clearColor];
  self.selectionStyle = UITableViewCellSelectionStyleNone;

  _cardView = [[UIView alloc] init];
  _cardView.backgroundColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.03];
  _cardView.layer.cornerRadius = 12;
  _cardView.layer.borderWidth = 1;
  _cardView.layer.borderColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
  _cardView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:_cardView];

  // 启用/禁用勾选按钮
  _enableBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  [_enableBtn setTitle:@"☑" forState:UIControlStateNormal];
  [_enableBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
  _enableBtn.titleLabel.font = [UIFont systemFontOfSize:18];
  _enableBtn.translatesAutoresizingMaskIntoConstraints = NO;
  _enableBtn.hidden = YES;
  [_enableBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [_enableBtn setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [_enableBtn addTarget:self
                action:@selector(onEnableTap)
      forControlEvents:UIControlEventTouchUpInside];
  [_cardView addSubview:_enableBtn];

  _noteLabel = [[UILabel alloc] init];
  _noteLabel.textColor = [UIColor cyanColor];
  _noteLabel.font = [UIFont boldSystemFontOfSize:12];
  _noteLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardView addSubview:_noteLabel];

  _authorLabel = [[UILabel alloc] init];
  _authorLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
  _authorLabel.font = [UIFont systemFontOfSize:9];
  _authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardView addSubview:_authorLabel];

  _valueBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [_valueBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
  _valueBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:13];
  _valueBtn.layer.cornerRadius = 4;
  _valueBtn.layer.borderWidth = 1;
  _valueBtn.layer.borderColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.3].CGColor;
  _valueBtn.backgroundColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.08];
  _valueBtn.contentEdgeInsets = UIEdgeInsetsMake(4, 12, 4, 12);
  _valueBtn.translatesAutoresizingMaskIntoConstraints = NO;
  [_valueBtn addTarget:self
                action:@selector(onValueTap)
      forControlEvents:UIControlEventTouchUpInside];
  [_cardView addSubview:_valueBtn];

  _slider = [[UISlider alloc] init];
  _slider.minimumTrackTintColor = [UIColor cyanColor];
  _slider.maximumTrackTintColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.2];
  _slider.thumbTintColor = [UIColor cyanColor];
  _slider.translatesAutoresizingMaskIntoConstraints = NO;
  _slider.hidden = YES;
  [_slider addTarget:self
                action:@selector(onSliderChanged:)
      forControlEvents:UIControlEventValueChanged];
  [_slider addTarget:self
                action:@selector(onSliderEnd:)
      forControlEvents:UIControlEventTouchUpInside |
                       UIControlEventTouchUpOutside];
  [_cardView addSubview:_slider];

  _toggleSwitch = [[UISwitch alloc] init];
  _toggleSwitch.onTintColor = [UIColor cyanColor];
  _toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
  _toggleSwitch.hidden = YES;
  [_toggleSwitch addTarget:self
                    action:@selector(onToggleSwitch:)
          forControlEvents:UIControlEventValueChanged];
  [_cardView addSubview:_toggleSwitch];

  _matchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  [_matchBtn setTitle:VL(@"Btn_Scan") forState:UIControlStateNormal];
  [_matchBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
  _matchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
  _matchBtn.layer.cornerRadius = 4;
  _matchBtn.layer.borderWidth = 1;
  _matchBtn.layer.borderColor = [UIColor cyanColor].CGColor;
  _matchBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
  _matchBtn.translatesAutoresizingMaskIntoConstraints = NO;
  _matchBtn.hidden = YES;
  [_matchBtn addTarget:self
                action:@selector(onMatchTap)
      forControlEvents:UIControlEventTouchUpInside];
  [_cardView addSubview:_matchBtn];

  _editBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  [_editBtn setTitle:VL(@"Btn_Edit") forState:UIControlStateNormal];
  [_editBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
  _editBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
  _editBtn.layer.borderColor = [UIColor cyanColor].CGColor;
  _editBtn.layer.borderWidth = 0.8;
  _editBtn.layer.cornerRadius = 4;
  _editBtn.backgroundColor = [UIColor clearColor];
  _editBtn.translatesAutoresizingMaskIntoConstraints = NO;
  _editBtn.hidden = YES;
  [_editBtn addTarget:self
                action:@selector(onEditTap)
      forControlEvents:UIControlEventTouchUpInside];
  [_cardView addSubview:_editBtn];

  _spinner = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _spinner.color = [UIColor cyanColor];
  _spinner.hidesWhenStopped = YES;
  _spinner.transform = CGAffineTransformMakeScale(0.6, 0.6);
  _spinner.translatesAutoresizingMaskIntoConstraints = NO;
  [_matchBtn addSubview:_spinner];

  _resultsStack = [[UIStackView alloc] init];
  _resultsStack.axis = UILayoutConstraintAxisVertical;
  _resultsStack.spacing = 6;
  _resultsStack.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardView addSubview:_resultsStack];

  [self setupConstraints];
}
- (void)setupConstraints {
  [NSLayoutConstraint activateConstraints:@[
    [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor
                                        constant:2],
    [_cardView.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor
                       constant:12],
    [_cardView.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor
                       constant:-12],
    [_cardView.bottomAnchor
        constraintEqualToAnchor:self.contentView.bottomAnchor
                       constant:-2],

    [_noteLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor
                                         constant:8],
    // noteLabel.leadingAnchor 在 configureWithItem 中根据是否有 checkbox 动态设置

    [_authorLabel.centerXAnchor
        constraintEqualToAnchor:_cardView.centerXAnchor],
    [_authorLabel.centerYAnchor
        constraintEqualToAnchor:_cardView.centerYAnchor],

    [_spinner.centerXAnchor constraintEqualToAnchor:_matchBtn.centerXAnchor],
    [_spinner.centerYAnchor constraintEqualToAnchor:_matchBtn.centerYAnchor],
    
    // enableBtn 基础约束（宽高）
    [_enableBtn.widthAnchor constraintEqualToConstant:28],
    [_enableBtn.heightAnchor constraintEqualToConstant:28],
  ]];
  [_cardView.heightAnchor constraintGreaterThanOrEqualToConstant:44].active =
      YES;
}

- (void)prepareForReuse {
  [super prepareForReuse];
  
  // 清理结果栈
  for (UIView *v in _resultsStack.arrangedSubviews)
    [v removeFromSuperview];
  
  // 重置所有控件状态
  _slider.hidden = YES;
  _toggleSwitch.hidden = YES;
  _matchBtn.hidden = YES;
  _editBtn.hidden = YES;
  _enableBtn.hidden = YES;
  _valueBtn.hidden = NO;
  _authorLabel.hidden = NO;
  _authorLabel.alpha = 1.0;
  _authorLabel.transform = CGAffineTransformIdentity;
  _cardView.alpha = 1.0;  // 重置卡片透明度
  [_spinner stopAnimating];
  _cardView.layer.borderColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
  
  // 重置 valueBtn 样式
  _valueBtn.layer.borderWidth = 1;
  _valueBtn.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.3].CGColor;
  _valueBtn.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.08];
  _valueBtn.contentEdgeInsets = UIEdgeInsetsMake(4, 12, 4, 12);
  
  // 移除动态添加的约束（保留基础约束和宽高约束）
  NSMutableArray *toRemove = [NSMutableArray array];
  for (NSLayoutConstraint *c in _cardView.constraints) {
    // 只移除位置相关的约束，保留宽高约束
    if ((c.firstItem == _valueBtn || c.secondItem == _valueBtn ||
         c.firstItem == _slider || c.secondItem == _slider ||
         c.firstItem == _toggleSwitch || c.secondItem == _toggleSwitch ||
         c.firstItem == _editBtn || c.secondItem == _editBtn ||
         c.firstItem == _matchBtn || c.secondItem == _matchBtn ||
         c.firstItem == _enableBtn || c.secondItem == _enableBtn ||
         c.firstItem == _resultsStack || c.secondItem == _resultsStack ||
         c.firstItem == _noteLabel || c.secondItem == _noteLabel) &&
        c.firstAttribute != NSLayoutAttributeWidth &&
        c.firstAttribute != NSLayoutAttributeHeight &&
        c.secondAttribute != NSLayoutAttributeWidth &&
        c.secondAttribute != NSLayoutAttributeHeight) {
      [toRemove addObject:c];
    }
  }
  [NSLayoutConstraint deactivateConstraints:toRemove];
  
  // 重新激活基础约束 - 只设置 top，leading 在 configureWithItem 中根据类型设置
  [NSLayoutConstraint activateConstraints:@[
    [_noteLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:8],
  ]];
}

- (void)configureWithItem:(VModItem *)item currentValue:(NSString *)value {
  _item = item;
  _currentValue = value;
  _noteLabel.text = item.note ?: VL(@"Cell_Unnamed");

  // 移除布局相关约束，但保留内部宽高及基本定位
  for (NSLayoutConstraint *c in _cardView.constraints) {
    if (c.firstItem == _noteLabel || c.firstItem == _editBtn ||
        c.firstItem == _valueBtn || c.firstItem == _toggleSwitch ||
        c.firstItem == _slider || c.firstItem == _matchBtn ||
        c.firstItem == _enableBtn || c.firstItem == _resultsStack) {
      if (c.firstAttribute != NSLayoutAttributeWidth &&
          c.firstAttribute != NSLayoutAttributeHeight &&
          c.firstAttribute != NSLayoutAttributeTop &&
          c.firstAttribute != NSLayoutAttributeLeading &&
          c.firstAttribute != NSLayoutAttributeCenterX &&
          c.firstAttribute != NSLayoutAttributeCenterY) {
        c.active = NO;
      }
    }
  }

  // 备注标签设置：文字过长时在尾部截断，优先级低于按钮
  _noteLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  [_noteLabel
      setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                      forAxis:UILayoutConstraintAxisHorizontal];

  // 作者水印
  _authorLabel.text = item.author.length > 0
                          ? [NSString stringWithFormat:@"@%@", item.author]
                          : @"";
  _authorLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:16];
  _authorLabel.alpha = 0.08;
  _authorLabel.transform = CGAffineTransformMakeRotation(-M_PI / 15.0);
  _authorLabel.textColor = [UIColor cyanColor];
  _authorLabel.hidden = item.author.length == 0;

  // 指针类型显示启用/禁用勾选框
  if (item.type == VModTypePointer) {
    _enableBtn.hidden = NO;
    [_enableBtn setTitle:item.isEnabled ? @"☑" : @"☐" forState:UIControlStateNormal];
    [_enableBtn setTitleColor:item.isEnabled ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.4] forState:UIControlStateNormal];
    
    // 调整 noteLabel 位置，为 enableBtn 腾出空间
    [NSLayoutConstraint activateConstraints:@[
      [_enableBtn.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:6],
      [_enableBtn.centerYAnchor constraintEqualToAnchor:_noteLabel.centerYAnchor],
      [_noteLabel.leadingAnchor constraintEqualToAnchor:_enableBtn.trailingAnchor constant:0],
    ]];
    
    // 禁用状态下整个卡片变淡
    _cardView.alpha = item.isEnabled ? 1.0 : 0.5;
  } else {
    _enableBtn.hidden = YES;
    _cardView.alpha = 1.0;
    [NSLayoutConstraint activateConstraints:@[
      [_noteLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
    ]];
  }

  if ((item.type == VModTypePointer || item.type == VModTypeRVA)) {
    _editBtn.hidden = NO;
    [_editBtn
        setContentCompressionResistancePriority:UILayoutPriorityRequired
                                        forAxis:
                                            UILayoutConstraintAxisHorizontal];
    // 右侧需要给开关/滑块预留空间，使用固定值确保足够
    [NSLayoutConstraint activateConstraints:@[
      [_editBtn.centerYAnchor constraintEqualToAnchor:_noteLabel.centerYAnchor],
      [_editBtn.leadingAnchor constraintEqualToAnchor:_noteLabel.trailingAnchor
                                             constant:6],
      [_editBtn.widthAnchor constraintEqualToConstant:32],
      [_editBtn.heightAnchor constraintEqualToConstant:18],
      [_editBtn.trailingAnchor
          constraintLessThanOrEqualToAnchor:_cardView.trailingAnchor
                                   constant:-70]
    ]];
  } else {
    _editBtn.hidden = YES;
    // 非编辑器类型也限制 noteLabel 宽度，防止遮挡右侧视图
    [_noteLabel.trailingAnchor
        constraintLessThanOrEqualToAnchor:_cardView.trailingAnchor
                                 constant:-70]
        .active = YES;
  }

  if (item.type == VModTypePointer) {
    [self configurePointer:item value:value];
  } else if (item.type == VModTypeRVA) {
    [self configureRVA:item];
  } else if (item.type == VModTypeSignature) {
    [self configureSignature:item];
  }
}

#pragma mark - Pointer: 左滑编辑删除，开关样式显示数值

- (void)configurePointer:(VModItem *)item value:(NSString *)value {
  // 布局: 指针类型，作者已经水印化， noteLabel 在第一行，第二行按样式显示
  // value/switch
  if (item.uiMode == VMUIModeSwitch) {
    _valueBtn.hidden = YES;
    _toggleSwitch.hidden = NO;
    _slider.hidden = YES;
    NSString *onVal =
        item.switchOnValue.length > 0 ? item.switchOnValue : kDefaultSwitchOn;
    _toggleSwitch.on = [value isEqualToString:onVal];
    [NSLayoutConstraint activateConstraints:@[
      [_toggleSwitch.centerYAnchor
          constraintEqualToAnchor:_cardView.centerYAnchor],
      [_toggleSwitch.trailingAnchor
          constraintEqualToAnchor:_cardView.trailingAnchor
                         constant:-10],
      [_noteLabel.bottomAnchor
          constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor
                                   constant:-8],
    ]];
  } else if (item.uiMode == VMUIModeSlider) {
    _valueBtn.hidden = NO;
    _toggleSwitch.hidden = YES;
    _slider.hidden = NO;
    [_valueBtn setTitle:value ?: @"?" forState:UIControlStateNormal];
    _valueBtn.layer.borderWidth = 0;
    _valueBtn.backgroundColor = [UIColor clearColor];
    _valueBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    _slider.minimumValue = item.uiMin;
    _slider.maximumValue = item.uiMax;
    _slider.value = [value floatValue];
    [NSLayoutConstraint activateConstraints:@[
      [_valueBtn.centerYAnchor
          constraintEqualToAnchor:_noteLabel.centerYAnchor],
      [_valueBtn.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor
                                               constant:-10],
      [_slider.topAnchor constraintEqualToAnchor:_noteLabel.bottomAnchor
                                        constant:6],
      [_slider.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor
                                            constant:12],
      [_slider.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor
                                             constant:-10],
      [_slider.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor
                                           constant:-10],
      [_slider.heightAnchor constraintEqualToConstant:24],
    ]];
  } else {
    _valueBtn.hidden = NO;
    _toggleSwitch.hidden = NO;
    _slider.hidden = YES;
    [_valueBtn setTitle:value ?: @"?" forState:UIControlStateNormal];
    _valueBtn.layer.borderWidth = 0;
    _valueBtn.backgroundColor = [UIColor clearColor];
    _valueBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    _toggleSwitch.on = item.isLocked;
    [NSLayoutConstraint activateConstraints:@[
      [_valueBtn.topAnchor constraintEqualToAnchor:_noteLabel.bottomAnchor
                                          constant:4],
      [_valueBtn.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor
                                              constant:12],
      [_valueBtn.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor
                                             constant:-8],
      [_valueBtn.heightAnchor constraintEqualToConstant:22],
      [_toggleSwitch.centerYAnchor
          constraintEqualToAnchor:_cardView.centerYAnchor],
      [_toggleSwitch.trailingAnchor
          constraintEqualToAnchor:_cardView.trailingAnchor
                         constant:-10],
    ]];
  }

  if (item.isLocked) {
    _cardView.layer.borderColor =
        [[UIColor cyanColor] colorWithAlphaComponent:0.4].CGColor;
  }
}

#pragma mark - RVA: 第一行 note, 第二行 author + switch

- (void)configureRVA:(VModItem *)item {
  _valueBtn.hidden = YES;
  _toggleSwitch.hidden = NO;
  _toggleSwitch.on = item.isPatched;

  [NSLayoutConstraint activateConstraints:@[
    [_toggleSwitch.centerYAnchor
        constraintEqualToAnchor:_cardView.centerYAnchor],
    [_toggleSwitch.trailingAnchor
        constraintEqualToAnchor:_cardView.trailingAnchor
                       constant:-10],
    [_noteLabel.bottomAnchor
        constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor
                                 constant:-8],
  ]];

  if (item.isPatched) {
    _cardView.layer.borderColor =
        [[UIColor cyanColor] colorWithAlphaComponent:0.4].CGColor;
  }
}

#pragma mark - Signature

- (void)configureSignature:(VModItem *)item {
  _valueBtn.hidden = YES;
  _matchBtn.hidden = NO;

  [NSLayoutConstraint activateConstraints:@[
    [_matchBtn.centerYAnchor constraintEqualToAnchor:_noteLabel.centerYAnchor],
    [_matchBtn.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor
                                             constant:-8],
    [_matchBtn.widthAnchor constraintEqualToConstant:45],
    [_matchBtn.heightAnchor constraintEqualToConstant:20],

    [_resultsStack.topAnchor constraintEqualToAnchor:_noteLabel.bottomAnchor
                                            constant:6],
    [_resultsStack.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor
                                                constant:12],
    [_resultsStack.trailingAnchor
        constraintEqualToAnchor:_cardView.trailingAnchor
                       constant:-8],
    [_resultsStack.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor
                                               constant:-8],
  ]];

  if (item.isScanning) {
    [_matchBtn setTitle:@"" forState:UIControlStateNormal];
    [_spinner startAnimating];
    UILabel *lbl = [self infoLabel:VL(@"Msg_Scanning")];
    lbl.textAlignment = NSTextAlignmentCenter;
    [_resultsStack addArrangedSubview:lbl];
    return;
  }

  if (item.runtimeResults.count > 0) {
    _cardView.layer.borderColor =
        [[UIColor cyanColor] colorWithAlphaComponent:0.4].CGColor;
    [_matchBtn
        setTitle:[NSString
                     stringWithFormat:@"%lu",
                                      (unsigned long)item.runtimeResults.count]
        forState:UIControlStateNormal];

    NSInteger maxShow = MIN(item.runtimeResults.count, 5);
    for (NSInteger i = 0; i < maxShow; i++) {
      NSDictionary *res = item.runtimeResults[i];
      uint64_t addr = [res[@"addr"] unsignedLongLongValue];
      NSString *val = res[@"val"] ?: @"--";
      UIView *row = [self createResultRow:addr val:val index:i item:item];
      [_resultsStack addArrangedSubview:row];
    }
    if (item.runtimeResults.count > maxShow) {
      UILabel *more = [self
          infoLabel:[NSString
                        stringWithFormat:VL(@"Msg_MoreMatches"),
                                         (unsigned long)(item.runtimeResults
                                                             .count -
                                                         maxShow)]];
      more.textAlignment = NSTextAlignmentCenter;
      [_resultsStack addArrangedSubview:more];
    }
  } else if (item.scanError) {
    _cardView.layer.borderColor =
        [[UIColor cyanColor] colorWithAlphaComponent:0.3].CGColor;
    UILabel *err = [self infoLabel:item.scanError];
    err.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6];
    err.textAlignment = NSTextAlignmentCenter;
    [_resultsStack addArrangedSubview:err];
  } else {
    UILabel *hint = [self infoLabel:VL(@"Msg_ClickToScan")];
    hint.textAlignment = NSTextAlignmentCenter;
    [_resultsStack addArrangedSubview:hint];
  }
}

- (UIView *)createResultRow:(uint64_t)addr
                        val:(NSString *)val
                      index:(NSInteger)idx
                       item:(VModItem *)it {
  UIView *row = [[UIView alloc] init];
  row.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.05];
  row.layer.cornerRadius = 6;
  row.layer.borderWidth = 1;
  row.layer.borderColor =
      [[UIColor cyanColor] colorWithAlphaComponent:0.15].CGColor;
  row.translatesAutoresizingMaskIntoConstraints = NO;
  [row.heightAnchor constraintEqualToConstant:36].active = YES;
  UILabel *aL = [[UILabel alloc] init];
  aL.text =
      [NSString stringWithFormat:@"%@ %ld", VL(@"Sig_Addr"), (long)(idx + 1)];
  aL.font = [UIFont boldSystemFontOfSize:11];
  aL.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.8];
  aL.translatesAutoresizingMaskIntoConstraints = NO;
  [row addSubview:aL];
  UIButton *eB = [UIButton buttonWithType:UIButtonTypeCustom];
  [eB setTitle:VL(@"Btn_Edit") forState:UIControlStateNormal];
  [eB setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
  eB.titleLabel.font = [UIFont boldSystemFontOfSize:10];
  eB.layer.borderColor = [UIColor cyanColor].CGColor;
  eB.layer.borderWidth = 0.8;
  eB.layer.cornerRadius = 4;
  eB.backgroundColor = [UIColor clearColor];
  eB.tag = idx;
  eB.translatesAutoresizingMaskIntoConstraints = NO;
  objc_setAssociatedObject(eB, "addr", @(addr),
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(eB, "val", val, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [eB addTarget:self
                action:@selector(onResultEditTap:)
      forControlEvents:UIControlEventTouchUpInside];
  [row addSubview:eB];
  NSDictionary *cfg = it.resultConfig[@(addr)];
  VMUIMode mode =
      cfg[@"mode"] ? (VMUIMode)[cfg[@"mode"] integerValue] : VMUIModeCard;
  [NSLayoutConstraint activateConstraints:@[
    [aL.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:8],
    [aL.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    [eB.leadingAnchor constraintEqualToAnchor:aL.trailingAnchor constant:6],
    [eB.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    [eB.widthAnchor constraintEqualToConstant:32],
    [eB.heightAnchor constraintEqualToConstant:18]
  ]];
  if (mode == VMUIModeSlider) {
    UISlider *sl = [[UISlider alloc] init];
    sl.minimumTrackTintColor = [UIColor cyanColor];
    sl.thumbTintColor = [UIColor cyanColor];
    sl.translatesAutoresizingMaskIntoConstraints = NO;
    sl.tag = idx;
    objc_setAssociatedObject(sl, "addr", @(addr),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sl.minimumValue = cfg[@"min"] ? [cfg[@"min"] floatValue] : 0;
    sl.maximumValue = cfg[@"max"] ? [cfg[@"max"] floatValue] : 100;
    sl.value = [val floatValue];
    [sl addTarget:self
                  action:@selector(onResultSliderChanged:)
        forControlEvents:UIControlEventValueChanged];
    [sl addTarget:self
                  action:@selector(onResultSliderEnd:)
        forControlEvents:UIControlEventTouchUpInside |
                         UIControlEventTouchUpOutside];
    [row addSubview:sl];
    [NSLayoutConstraint activateConstraints:@[
      [sl.leadingAnchor constraintEqualToAnchor:eB.trailingAnchor constant:8],
      [sl.trailingAnchor constraintEqualToAnchor:row.trailingAnchor
                                        constant:-8],
      [sl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
      [sl.heightAnchor constraintEqualToConstant:20]
    ]];
  } else if (mode == VMUIModeSwitch) {
    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = [UIColor cyanColor];
    sw.transform = CGAffineTransformMakeScale(0.7, 0.7);
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    sw.tag = idx;
    objc_setAssociatedObject(sw, "addr", @(addr),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSString *onV = cfg[@"switchOnValue"] ?: @"1";
    sw.on = [val isEqualToString:onV];
    [sw addTarget:self
                  action:@selector(onResultSwitchChanged:)
        forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    [NSLayoutConstraint activateConstraints:@[
      [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor
                                        constant:-4],
      [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];
  } else {
    UILabel *vL = [[UILabel alloc] init];
    vL.text = val;
    vL.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
    vL.textColor = [UIColor cyanColor];
    vL.textAlignment = NSTextAlignmentRight;
    vL.translatesAutoresizingMaskIntoConstraints = NO;
    vL.tag = idx;
    vL.userInteractionEnabled = YES;
    objc_setAssociatedObject(vL, "addr", @(addr),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [row addSubview:vL];
    [vL addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                 initWithTarget:self
                                         action:@selector(onResultLabelTap:)]];
    [NSLayoutConstraint activateConstraints:@[
      [vL.trailingAnchor constraintEqualToAnchor:row.trailingAnchor
                                        constant:-8],
      [vL.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
      [vL.leadingAnchor constraintGreaterThanOrEqualToAnchor:eB.trailingAnchor
                                                    constant:6]
    ]];
  }
  return row;
}

- (void)onResultEditTap:(UIButton *)btn {
  NSInteger idx = btn.tag;
  NSNumber *addrNum = objc_getAssociatedObject(btn, "addr");
  NSString *val = objc_getAssociatedObject(btn, "val");
  uint64_t addr = [addrNum unsignedLongLongValue];

  if ([_delegate respondsToSelector:@selector
                 (cellDidClickResultValue:atIndex:address:currentValue:)]) {
    [_delegate cellDidClickResultValue:_item
                               atIndex:idx
                               address:addr
                          currentValue:val];
  }
}

- (void)onResultLabelTap:(UITapGestureRecognizer *)tap {
  UILabel *lbl = (UILabel *)tap.view;
  NSInteger idx = lbl.tag;
  NSNumber *addrNum = objc_getAssociatedObject(lbl, "addr");
  uint64_t addr = [addrNum unsignedLongLongValue];
  NSString *val = lbl.text;

  if ([_delegate respondsToSelector:@selector
                 (cellDidClickResultValue:atIndex:address:currentValue:)]) {
    [_delegate cellDidClickResultValue:_item
                               atIndex:idx
                               address:addr
                          currentValue:val];
  }
}

- (UILabel *)infoLabel:(NSString *)text {
  UILabel *lbl = [[UILabel alloc] init];
  lbl.text = text;
  lbl.font = [UIFont systemFontOfSize:10];
  lbl.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
  return lbl;
}

#pragma mark - Actions

- (void)onValueTap {
  if ([_delegate respondsToSelector:@selector(cellDidRequestEdit:)]) {
    [_delegate cellDidRequestEdit:_item];
  }
}

- (void)onEnableTap {
  BOOL newEnabled = !_item.isEnabled;
  [_enableBtn setTitle:newEnabled ? @"☑" : @"☐" forState:UIControlStateNormal];
  [_enableBtn setTitleColor:newEnabled ? [UIColor cyanColor] : [[UIColor cyanColor] colorWithAlphaComponent:0.4] forState:UIControlStateNormal];
  _cardView.alpha = newEnabled ? 1.0 : 0.5;
  
  if ([_delegate respondsToSelector:@selector(cellDidToggleEnabled:isEnabled:)]) {
    [_delegate cellDidToggleEnabled:_item isEnabled:newEnabled];
  }
}

- (void)onEditTap {
  if ([_delegate respondsToSelector:@selector(cellDidRequestEdit:)]) {
    [_delegate cellDidRequestEdit:_item];
  }
}

- (void)onSliderChanged:(UISlider *)sl {
  [_valueBtn setTitle:[NSString stringWithFormat:@"%.0f", sl.value]
             forState:UIControlStateNormal];
}

- (void)onSliderEnd:(UISlider *)sl {
  if ([_delegate respondsToSelector:@selector(cellDidChangeSlider:value:)]) {
    [_delegate cellDidChangeSlider:_item value:sl.value];
  }
}

- (void)onToggleSwitch:(UISwitch *)sw {
  [UIView animateWithDuration:0.2
                   animations:^{
                     self.cardView.layer.borderColor =
                         sw.on
                             ? [[UIColor cyanColor] colorWithAlphaComponent:0.4]
                                   .CGColor
                             : [[UIColor cyanColor] colorWithAlphaComponent:0.2]
                                   .CGColor;
                   }];

  if (_item.type == VModTypeRVA) {
    if ([_delegate respondsToSelector:@selector(cellDidToggleRVA:)]) {
      [_delegate cellDidToggleRVA:_item];
    }
  } else if (_item.type == VModTypePointer) {
    // 指针类型: 开关控制锁定
    if ([_delegate respondsToSelector:@selector(cellDidToggleLock:isLocked:)]) {
      [_delegate cellDidToggleLock:_item isLocked:sw.on];
    }
  } else {
    if ([_delegate respondsToSelector:@selector(cellDidToggleSwitch:isOn:)]) {
      [_delegate cellDidToggleSwitch:_item isOn:sw.on];
    }
  }
}

- (void)onMatchTap {
  [UIView animateWithDuration:0.1
      animations:^{
        self.matchBtn.transform = CGAffineTransformMakeScale(0.9, 0.9);
      }
      completion:^(BOOL f) {
        [UIView animateWithDuration:0.1
                         animations:^{
                           self.matchBtn.transform = CGAffineTransformIdentity;
                         }];
      }];
  if ([_delegate respondsToSelector:@selector(cellDidRequestMatch:)]) {
    [_delegate cellDidRequestMatch:_item];
  }
}

- (void)onResultSliderChanged:(UISlider *)sl {
  // 逻辑由 VModCellDelegate 处理，暂不实现局部 UI 更新，推荐代理处理
}
- (void)onResultSliderEnd:(UISlider *)sl {
  NSInteger idx = sl.tag;
  NSString *val = [NSString stringWithFormat:@"%.0f", sl.value];
  if ([_delegate respondsToSelector:@selector
                 (cellDidChangeResultSlider:atIndex:value:)])
    [_delegate cellDidChangeResultSlider:_item atIndex:idx value:val];
}
- (void)onResultSwitchChanged:(UISwitch *)sw {
  NSInteger idx = sw.tag;
  if ([_delegate respondsToSelector:@selector
                 (cellDidChangeResultSwitch:atIndex:isOn:)]) {
    [_delegate cellDidChangeResultSwitch:_item atIndex:idx isOn:sw.on];
  }
}

- (void)updateValue:(NSString *)value {
  _currentValue = value;
  [_valueBtn setTitle:value forState:UIControlStateNormal];
  if (_item.uiMode == VMUIModeSlider) {
    _slider.value = [value floatValue];
  } else if (_item.uiMode == VMUIModeSwitch) {
    NSString *onVal =
        _item.switchOnValue.length > 0 ? _item.switchOnValue : kDefaultSwitchOn;
    _toggleSwitch.on = [value isEqualToString:onVal];
  }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
  [super setHighlighted:highlighted animated:animated];
  [UIView
      animateWithDuration:0.1
               animations:^{
                 self.cardView.backgroundColor =
                     highlighted
                         ? [[UIColor cyanColor] colorWithAlphaComponent:0.08]
                         : [[UIColor cyanColor] colorWithAlphaComponent:0.03];
               }];
}

@end
