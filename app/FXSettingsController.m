#import "FXSettingsController.h"

#import <spawn.h>
#import <unistd.h>

#import "FXPrefs.h"

extern char **environ;

typedef NS_ENUM(NSInteger, FXRowType) {
	FXRowSwitch = 0,
	FXRowSlider,
	FXRowText,
	FXRowButton,
};

static NSString *FXVersionString(void) {
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	return version ?: @"0.3.1";
}

static void FXSpawn(const char *path, const char *arg1, const char *arg2) {
	if (!path || access(path, X_OK) != 0) {
		return;
	}
	const char *argv[] = { path, arg1, arg2, NULL };
	pid_t pid = 0;
	posix_spawn(&pid, path, NULL, NULL, (char *const *)argv, environ);
}

#pragma mark - Ячейка с ползунком

@interface FXSliderCell : UITableViewCell

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UISlider *slider;

@end

@implementation FXSliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (self) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;

		_titleLabel = [[UILabel alloc] init];
		_titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
		_titleLabel.adjustsFontForContentSizeCategory = YES;
		[_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
		                                             forAxis:UILayoutConstraintAxisHorizontal];

		_valueLabel = [[UILabel alloc] init];
		_valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
		_valueLabel.textColor = [UIColor secondaryLabelColor];
		_valueLabel.textAlignment = NSTextAlignmentRight;
		[_valueLabel setContentHuggingPriority:UILayoutPriorityRequired
		                               forAxis:UILayoutConstraintAxisHorizontal];

		UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[ _titleLabel, _valueLabel ]];
		top.axis = UILayoutConstraintAxisHorizontal;
		top.spacing = 8;

		_slider = [[UISlider alloc] init];
		_slider.continuous = YES;

		UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ top, _slider ]];
		stack.axis = UILayoutConstraintAxisVertical;
		stack.spacing = 8;
		stack.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:stack];

		UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
		[NSLayoutConstraint activateConstraints:@[
			[stack.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
			[stack.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
			[stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
			[stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
		]];
	}
	return self;
}

@end

#pragma mark - Контроллер настроек

@interface FXSettingsController () <UITextFieldDelegate>

@property (nonatomic, copy) NSArray<NSString *> *headers;
@property (nonatomic, copy) NSArray<NSString *> *footers;
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *sections;

@end

@implementation FXSettingsController

- (instancetype)initWithStyle:(UITableViewStyle)style {
	self = [super initWithStyle:style];
	if (self) {
		[self buildModel];
	}
	return self;
}

- (void)buildModel {
	self.headers = @[
		@"Жесты iPhone X",
		@"Домашняя полоска",
		@"Анимации",
		@"Производительность",
		@"Пункт управления",
		@"Применение",
		@"О твике",
	];

	self.footers = @[
		@"Используется родной движок жестов SpringBoard, поэтому анимации плавные и не нагружают систему.",
		@"0 — системный размер. Прозрачность 1.00 — как в системе. Цвет задаётся в HEX: FF2D55 или 00A3FF. Пустое поле — системный цвет.",
		@"1.00 — как в системе. Меньше — быстрее, больше — медленнее.",
		@"Отключает размытие подложек (Пункт управления, папки, Spotlight). На iPhone 7 легче GPU, но интерфейс выглядит плоским.",
		@"При включённых жестах свайп снизу забирает «Домой», поэтому Пункт управления переносится на свайп сверху справа.",
		@"Размеры полоски и цвет применяются после respring.",
		[NSString stringWithFormat:
		    @"FluidX %@ · com.dolboebvaibcode.fluidx · iOS 15 rootless\n\n"
		    @"Твик написан нейросетью (ИИ) в учебных целях. Автор не несёт никакой "
		    @"ответственности за ваш iPhone и последствия установки: зависания, "
		    @"циклический respring, потерю данных, необходимость перепрошивки. "
		    @"Всё на ваш страх и риск.\n\n"
		    @"Настройки хранятся в /var/mobile/Library/Preferences/"
		    @"com.dolboebvaibcode.fluidx.plist — %@.\n"
		    @"Баги — в канал @a10tweaks: если ползунки не влияют на жесты, "
		    @"пришли скриншот этого экрана.",
		    FXVersionString(),
		    [[NSFileManager defaultManager]
		        fileExistsAtPath:@"/var/mobile/Library/Preferences/com.dolboebvaibcode.fluidx.plist"]
		        ? @"файл на месте"
		        : @"файла пока нет"],
	];

	self.sections = @[
		@[
			@{ @"type" : @(FXRowSwitch), @"title" : @"Включить жесты", @"key" : @"enabled" },
			@{ @"type" : @(FXRowSwitch), @"title" : @"Показывать домашнюю полоску", @"key" : @"showHomeBar" },
		],
		@[
			@{ @"type" : @(FXRowSlider), @"title" : @"Высота", @"key" : @"homeBarHeight",
			   @"min" : @0.0, @"max" : @12.0, @"fmt" : @"%.1f" },
			@{ @"type" : @(FXRowSlider), @"title" : @"Ширина", @"key" : @"homeBarWidth",
			   @"min" : @0.0, @"max" : @220.0, @"fmt" : @"%.0f" },
			@{ @"type" : @(FXRowSlider), @"title" : @"Прозрачность", @"key" : @"homeBarAlpha",
			   @"min" : @0.1, @"max" : @1.0, @"fmt" : @"%.2f" },
			@{ @"type" : @(FXRowText), @"title" : @"Цвет (HEX)", @"key" : @"homeBarColor",
			   @"placeholder" : @"FF2D55" },
		],
		@[
			@{ @"type" : @(FXRowSlider), @"title" : @"Скорость анимаций", @"key" : @"animSpeed",
			   @"min" : @0.5, @"max" : @2.0, @"fmt" : @"%.2f" },
		],
		@[
			@{ @"type" : @(FXRowSwitch), @"title" : @"Без блюра (быстрее)", @"key" : @"noBlur" },
		],
		@[
			@{ @"type" : @(FXRowSwitch), @"title" : @"Свайп сверху справа", @"key" : @"ccEdgeFix" },
			@{ @"type" : @(FXRowSwitch), @"title" : @"Чинить анимацию Пункта управления", @"key" : @"ccAnimFix" },
		],
		@[
			@{ @"type" : @(FXRowButton), @"title" : @"Respring", @"action" : @"respring" },
			@{ @"type" : @(FXRowButton), @"title" : @"Сбросить настройки", @"action" : @"reset" },
		],
		@[
			@{ @"type" : @(FXRowButton), @"title" : @"GitHub: vaibcode-dev/FluidX", @"action" : @"github" },
			@{ @"type" : @(FXRowButton), @"title" : @"Telegram-канал: @a10tweaks", @"action" : @"telegram" },
			@{ @"type" : @(FXRowButton), @"title" : @"Последний лог сборки", @"action" : @"buildlog" },
		],
	];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = @"FluidX";
	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 60;
	self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

#pragma mark - Данные

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.sections[(NSUInteger)section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return self.headers[(NSUInteger)section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return self.footers[(NSUInteger)section];
}

- (NSDictionary *)rowForTag:(NSInteger)tag {
	NSInteger section = tag / 100;
	NSInteger row = tag % 100;
	if (section < 0 || section >= (NSInteger)self.sections.count) {
		return nil;
	}
	NSArray<NSDictionary *> *rows = self.sections[(NSUInteger)section];
	if (row < 0 || row >= (NSInteger)rows.count) {
		return nil;
	}
	return rows[(NSUInteger)row];
}

- (NSString *)formatValue:(double)value row:(NSDictionary *)row {
	NSString *format = row[@"fmt"] ?: @"%.2f";
	return [NSString stringWithFormat:format, value];
}

#pragma mark - Ячейки

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
	FXRowType type = (FXRowType)[row[@"type"] integerValue];
	NSUserDefaults *defaults = FXDefaults();
	NSInteger tag = indexPath.section * 100 + indexPath.row;

	switch (type) {
	case FXRowSwitch: {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switch"];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"switch"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		UISwitch *toggle = (UISwitch *)cell.accessoryView;
		if (![toggle isKindOfClass:[UISwitch class]]) {
			toggle = [[UISwitch alloc] init];
			[toggle addTarget:self
			           action:@selector(switchChanged:)
			 forControlEvents:UIControlEventValueChanged];
			cell.accessoryView = toggle;
		}
		cell.textLabel.text = row[@"title"];
		toggle.tag = tag;
		toggle.on = [defaults boolForKey:row[@"key"]];
		return cell;
	}

	case FXRowSlider: {
		FXSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"slider"];
		if (!cell) {
			cell = [[FXSliderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"slider"];
		}
		cell.titleLabel.text = row[@"title"];
		cell.slider.minimumValue = [row[@"min"] floatValue];
		cell.slider.maximumValue = [row[@"max"] floatValue];
		cell.slider.value = [defaults doubleForKey:row[@"key"]];
		cell.slider.tag = tag;
		[cell.slider removeTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
		[cell.slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
		cell.valueLabel.text = [self formatValue:[defaults doubleForKey:row[@"key"]] row:row];
		return cell;
	}

	case FXRowText: {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"text"];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"text"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		cell.textLabel.text = row[@"title"];

		UITextField *field = (UITextField *)cell.accessoryView;
		if (![field isKindOfClass:[UITextField class]]) {
			field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 140, 32)];
			field.textAlignment = NSTextAlignmentRight;
			field.borderStyle = UITextBorderStyleNone;
			field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
			field.autocorrectionType = UITextAutocorrectionTypeNo;
			field.spellCheckingType = UITextSpellCheckingTypeNo;
			field.returnKeyType = UIReturnKeyDone;
			field.clearButtonMode = UITextFieldViewModeWhileEditing;
			field.delegate = self;
			cell.accessoryView = field;
		}
		field.tag = tag;
		field.placeholder = row[@"placeholder"];
		field.text = [defaults stringForKey:row[@"key"]];
		return cell;
	}

	case FXRowButton:
	default: {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"button"];
		}
		cell.textLabel.text = row[@"title"];
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.textLabel.textColor = [UIColor systemBlueColor];
		return cell;
	}
	}
}

#pragma mark - Действия

- (void)switchChanged:(UISwitch *)toggle {
	NSDictionary *row = [self rowForTag:toggle.tag];
	if (row) {
		FXSetValue(row[@"key"], @(toggle.isOn));
	}
}

- (void)sliderChanged:(UISlider *)slider {
	NSDictionary *row = [self rowForTag:slider.tag];
	if (!row) {
		return;
	}
	FXSetValue(row[@"key"], @(slider.value));

	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:slider.tag % 100 inSection:slider.tag / 100];
	FXSliderCell *cell = (FXSliderCell *)[self.tableView cellForRowAtIndexPath:indexPath];
	if ([cell isKindOfClass:[FXSliderCell class]]) {
		cell.valueLabel.text = [self formatValue:slider.value row:row];
	}
}

- (void)textFieldDidEndEditing:(UITextField *)field {
	NSDictionary *row = [self rowForTag:field.tag];
	if (!row) {
		return;
	}

	NSString *value = [[field.text stringByTrimmingCharactersInSet:
	                       [NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
	value = [value stringByReplacingOccurrencesOfString:@"#" withString:@""];

	NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
	NSCharacterSet *other = [hex invertedSet];
	if ([value rangeOfCharacterFromSet:other].location != NSNotFound) {
		value = @"";
	}

	FXSetValue(row[@"key"], value);
	field.text = value;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	[field resignFirstResponder];
	return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSDictionary *row = self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
	if ((FXRowType)[row[@"type"] integerValue] != FXRowButton) {
		return;
	}

	NSString *action = row[@"action"];
	if ([action isEqualToString:@"respring"]) {
		[self respring];
	} else if ([action isEqualToString:@"reset"]) {
		[self confirmReset];
	} else if ([action isEqualToString:@"github"]) {
		[self openURLString:@"https://github.com/vaibcode-dev/FluidX"];
	} else if ([action isEqualToString:@"telegram"]) {
		[self openURLString:@"https://t.me/a10tweaks"];
	} else if ([action isEqualToString:@"buildlog"]) {
		[self openURLString:@"https://github.com/vaibcode-dev/FluidX/blob/ci-logs/build.log"];
	}
}

#pragma mark - Кнопки

- (void)respring {
	FXSpawn("/var/jb/usr/bin/sbreload", NULL, NULL);
	FXSpawn("/var/jb/usr/bin/killall", "-9", "SpringBoard");
}

- (void)confirmReset {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Сбросить настройки?"
	                                                              message:@"Все значения вернутся к системным. После этого — respring."
	                                                       preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Сбросить"
	                                          style:UIAlertActionStyleDestructive
	                                        handler:^(UIAlertAction *action) {
		                                        FXResetAll();
		                                        [self.tableView reloadData];
		                                        [self respring];
	                                        }]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)openURLString:(NSString *)string {
	NSURL *url = [NSURL URLWithString:string];
	if (!url) {
		return;
	}
	[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
