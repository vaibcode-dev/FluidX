// FluidX — жесты iPhone X для iPhone 7 (iOS 15.x, rootless)
//
// Идея: не рисовать свои распознаватели (они дают рывки и конфликты),
// а включить встроенный движок жестов SpringBoard и аккуратно
// перенастроить внешний вид полоски и Пункта управления.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <unistd.h>
#import <math.h>

extern char **environ;

// Приватные классы SpringBoard/MaterialKit. Заголовков в SDK нет,
// поэтому объявляем сами — иначе компилятор не знает их свойств.
@interface MTLumaDodgePillView : UIView
@end

@interface SBHomeGrabberView : UIView
@end

@interface SpringBoard : UIApplication
- (BOOL)_handlePhysicalButtonEvent:(id)event;
- (void)_simulateHomeButtonPress;
- (void)_simulateLockButtonPress;
- (void)relaunchSpringBoard;
- (void)takeScreenshot;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)_toggleSwitcher;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
@end

@interface SBScreenShotter : NSObject
+ (instancetype)sharedInstance;
- (BOOL)writingScreenshot;
- (void)saveScreenshot:(BOOL)animated;
- (void)takeScreenshot;
@end

#define PREFS_DOMAIN @"com.dolboebvaibcode.fluidx"
#define RELOAD_NOTIFICATION @"com.dolboebvaibcode.fluidx/ReloadPrefs"
// CFSTR() принимает только C-строку, поэтому для CoreFoundation — отдельный макрос.
#define RELOAD_NOTIFICATION_C "com.dolboebvaibcode.fluidx/ReloadPrefs"

static BOOL gEnabled = YES;
static BOOL gShowHomeBar = YES;
static double gBarHeight = 0.0; // 0 = системная высота
static double gBarWidth = 0.0;  // 0 = системная ширина
static double gBarAlpha = 1.0;  // 1 = системная прозрачность
static UIColor *gBarColor = nil; // nil = системный цвет (светлый/тёмный)
static UIImage *gBarImage = nil; // nil = без фото
static NSString *gHomeBarAnimation = @"none";
static double gAnimSpeed = 1.0;  // 1 = системная скорость
static BOOL gNoBlur = NO;        // убрать блюр подложек (экономия GPU)
static BOOL gCCEdgeFix = YES;
static BOOL gCCAnimFix = YES;
static BOOL gHideBarInGames = NO;
static NSString *gHomeButtonAction = @"system";

static NSUserDefaults *Prefs(void) {
	static NSUserDefaults *defaults;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		defaults = [[NSUserDefaults alloc] initWithSuiteName:PREFS_DOMAIN];
		[defaults registerDefaults:@{
			@"enabled"          : @YES,
			@"showHomeBar"      : @YES,
			@"homeBarHeight"    : @0.0,
			@"homeBarWidth"     : @0.0,
			@"homeBarAlpha"     : @1.0,
			@"homeBarColor"     : @"",
			@"homeBarImage"     : @"",
			@"homeBarAnimation" : @"none",
			@"homeButtonAction" : @"system",
			@"keyboardLift"     : @0.0,
			@"hideBarInGames"   : @NO,
			@"animSpeed"        : @1.0,
			@"noBlur"           : @NO,
			@"ccEdgeFix"        : @YES,
			@"ccAnimFix"        : @YES,
		}];
	});
	return defaults;
}

// "#RRGGBB" / "RRGGBB" / "#RRGGBBAA" / "#RGB" / "#RGBA" -> UIColor
static UIColor *ColorFromHex(NSString *hex) {
	if (![hex isKindOfClass:[NSString class]] || hex.length == 0) {
		return nil;
	}

	NSString *clean = [[[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
		uppercaseString];

	// Короткая запись: FFF -> FFFFFF, FF2D55AA -> как есть.
	if (clean.length == 3 || clean.length == 4) {
		NSMutableString *expanded = [NSMutableString stringWithCapacity:clean.length * 2];
		for (NSUInteger i = 0; i < clean.length; i++) {
			unichar c = [clean characterAtIndex:i];
			[expanded appendFormat:@"%C%C", c, c];
		}
		clean = expanded;
	}

	if (clean.length != 6 && clean.length != 8) {
		return nil;
	}

	// NSScanner пропускает мусор после валидных цифр ("FF00GG" -> FF00),
	// поэтому проверяем каждый символ сами.
	NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
	for (NSUInteger i = 0; i < clean.length; i++) {
		if (![hexSet characterIsMember:[clean characterAtIndex:i]]) {
			return nil;
		}
	}

	unsigned int value = 0;
	NSScanner *scanner = [NSScanner scannerWithString:clean];
	if (![scanner scanHexInt:&value]) {
		return nil;
	}

	CGFloat r, g, b, a = 1.0;
	if (clean.length == 8) {
		r = ((value >> 24) & 0xFF) / 255.0;
		g = ((value >> 16) & 0xFF) / 255.0;
		b = ((value >> 8) & 0xFF) / 255.0;
		a = (value & 0xFF) / 255.0;
	} else {
		r = ((value >> 16) & 0xFF) / 255.0;
		g = ((value >> 8) & 0xFF) / 255.0;
		b = (value & 0xFF) / 255.0;
	}
	return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

static void LoadPrefs(void) {
	NSUserDefaults *d = Prefs();
	gEnabled     = [d boolForKey:@"enabled"];
	gShowHomeBar = [d boolForKey:@"showHomeBar"];
	gBarHeight   = [d doubleForKey:@"homeBarHeight"];
	gBarWidth    = [d doubleForKey:@"homeBarWidth"];
	gBarAlpha    = [d doubleForKey:@"homeBarAlpha"];
	gAnimSpeed   = [d doubleForKey:@"animSpeed"];
	gNoBlur      = [d boolForKey:@"noBlur"];
	gCCEdgeFix   = [d boolForKey:@"ccEdgeFix"];
	gCCAnimFix   = [d boolForKey:@"ccAnimFix"];
	gHideBarInGames = [d boolForKey:@"hideBarInGames"];

	if (gBarAlpha <= 0.0) {
		gBarAlpha = 1.0;
	}
	if (gAnimSpeed <= 0.05) {
		gAnimSpeed = 1.0;
	}

	NSString *action = [d stringForKey:@"homeButtonAction"];
	gHomeButtonAction = action.length ? action : @"system";

	NSString *animation = [d stringForKey:@"homeBarAnimation"];
	gHomeBarAnimation = animation.length ? animation : @"none";

	gBarColor = ColorFromHex([d stringForKey:@"homeBarColor"]);

	// Фото грузим один раз при смене настроек, а не в каждом layoutSubviews.
	NSString *imagePath = [d stringForKey:@"homeBarImage"];
	if (imagePath.length &&
	    [[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
		gBarImage = [UIImage imageWithContentsOfFile:imagePath];
	} else {
		gBarImage = nil;
	}
}

// После изменения настроек SpringBoard не запускает layout сам, поэтому
// цвет и размеры «залипали» до respring. Обходим все окна и просим полоски
// перерисоваться — тогда настройки видно сразу.
static void RefreshGrabbersInView(UIView *view) {
	Class pillClass = NSClassFromString(@"MTLumaDodgePillView");
	Class grabberClass = NSClassFromString(@"SBHomeGrabberView");

	if ((pillClass && [view isKindOfClass:pillClass]) ||
	    (grabberClass && [view isKindOfClass:grabberClass])) {
		[view setNeedsLayout];
	}

	for (UIView *sub in view.subviews) {
		RefreshGrabbersInView(sub);
	}
}

static void RefreshGrabbers(void) {
	for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		for (UIWindow *window in ((UIWindowScene *)scene).windows) {
			RefreshGrabbersInView(window);
		}
	}
}

static void PrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name,
                         const void *object, CFDictionaryRef userInfo) {
	LoadPrefs();
	dispatch_async(dispatch_get_main_queue(), ^{
		RefreshGrabbers();
	});
}

#pragma mark - Кнопка Home: действия

static BOOL FXHasCustomHomeAction(void) {
	NSString *a = gHomeButtonAction;
	return [a isEqualToString:@"home"] ||
	       [a isEqualToString:@"switcher"] ||
	       [a isEqualToString:@"lock"] ||
	       [a isEqualToString:@"screenshot"] ||
	       [a isEqualToString:@"flashlight"] ||
	       [a isEqualToString:@"respring"] ||
	       [a isEqualToString:@"nothing"];
}

static void FXSpawn(const char *path, const char *arg1, const char *arg2) {
	if (!path || access(path, X_OK) != 0) {
		return;
	}
	const char *argv[] = { path, arg1, arg2, NULL };
	pid_t pid = 0;
	posix_spawn(&pid, path, NULL, NULL, (char *const *)argv, environ);
}

static id FXSharedInstance(NSString *className) {
	Class cls = NSClassFromString(className);
	if (!cls) {
		return nil;
	}
	if ([cls respondsToSelector:@selector(sharedInstance)]) {
		return [cls performSelector:@selector(sharedInstance)];
	}
	if ([cls respondsToSelector:@selector(sharedInstanceIfExists)]) {
		return [cls performSelector:@selector(sharedInstanceIfExists)];
	}
	return nil;
}

static void FXToggleTorch(void) {
	// Сначала пробуем родной контроллер SpringBoard: он не требует
	// разрешений камеры и работает так же, как кнопка фонарика.
	id controller = FXSharedInstance(@"SBFlashlightController");
	SEL selectors[] = { NSSelectorFromString(@"toggleFlashlight"),
	                    NSSelectorFromString(@"_toggleFlashlight") };
	for (int i = 0; i < 2; i++) {
		if (controller && [controller respondsToSelector:selectors[i]]) {
			((void (*)(id, SEL))objc_msgSend)(controller, selectors[i]);
			return;
		}
	}

	SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
	for (int i = 0; i < 2; i++) {
		if ([sb respondsToSelector:selectors[i]]) {
			((void (*)(id, SEL))objc_msgSend)(sb, selectors[i]);
			return;
		}
	}

	// Запасной путь через AVFoundation — на случай, если в прошивке
	// нет SBFlashlightController с таким селектором.
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	if (device && device.hasTorch && [device lockForConfiguration:NULL]) {
		device.torchMode = (device.torchMode == AVCaptureTorchModeOn)
		                       ? AVCaptureTorchModeOff
		                       : AVCaptureTorchModeOn;
		[device unlockForConfiguration];
	}
}

static void FXTakeScreenshot(void) {
	id shotter = FXSharedInstance(@"SBScreenShotter");
	if ([shotter respondsToSelector:@selector(saveScreenshot:)]) {
		[(SBScreenShotter *)shotter saveScreenshot:YES];
		return;
	}
	if ([shotter respondsToSelector:@selector(takeScreenshot)]) {
		[(SBScreenShotter *)shotter takeScreenshot];
		return;
	}
	SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
	if ([sb respondsToSelector:@selector(takeScreenshot)]) {
		[sb takeScreenshot];
	}
}

static BOOL gSimulatingHome = NO;

static void FXPerformHomeAction(void) {
	SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
	NSString *action = gHomeButtonAction;

	if ([action isEqualToString:@"home"]) {
		if ([sb respondsToSelector:@selector(_simulateHomeButtonPress)]) {
			// Если симулированное нажатие снова придёт в наш хук, пропускаем
			// его к системе, иначе «Домой» рекурсивно вызовет сам себя.
			gSimulatingHome = YES;
			[sb _simulateHomeButtonPress];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
			               dispatch_get_main_queue(), ^{
				               gSimulatingHome = NO;
			               });
		}
	} else if ([action isEqualToString:@"switcher"]) {
		id ui = FXSharedInstance(@"SBUIController");
		if ([ui respondsToSelector:@selector(_toggleSwitcher)]) {
			[(SBUIController *)ui _toggleSwitcher];
		}
	} else if ([action isEqualToString:@"lock"]) {
		id manager = FXSharedInstance(@"SBLockScreenManager");
		if ([manager respondsToSelector:@selector(lockUIFromSource:withOptions:)]) {
			[(SBLockScreenManager *)manager lockUIFromSource:1 withOptions:nil];
		} else if ([sb respondsToSelector:@selector(_simulateLockButtonPress)]) {
			[sb _simulateLockButtonPress];
		}
	} else if ([action isEqualToString:@"screenshot"]) {
		FXTakeScreenshot();
	} else if ([action isEqualToString:@"flashlight"]) {
		FXToggleTorch();
	} else if ([action isEqualToString:@"respring"]) {
		if ([sb respondsToSelector:@selector(relaunchSpringBoard)]) {
			[sb relaunchSpringBoard];
			return;
		}
		FXSpawn("/var/jb/usr/bin/sbreload", NULL, NULL);
		FXSpawn("/var/jb/usr/bin/killall", "-9", "SpringBoard");
	}
	// "nothing" — просто поглощаем нажатие.
}

#pragma mark - Кнопка Home: перехват

static NSTimeInterval gLastHomeAction = 0.0;

%hook SpringBoard

- (BOOL)_handlePhysicalButtonEvent:(id)event {
	// Симулированное нажатие (действие «Домой») должно пройти в систему.
	if (gSimulatingHome) {
		return %orig;
	}
	if (!gEnabled || !FXHasCustomHomeAction()) {
		return %orig;
	}

	NSInteger type = -1;
	@try {
		id presses = [event valueForKey:@"allPresses"];
		id press = nil;
		if ([presses isKindOfClass:[NSSet class]]) {
			press = [(NSSet *)presses anyObject];
		} else if ([presses isKindOfClass:[NSArray class]]) {
			press = [(NSArray *)presses firstObject];
		}
		if (!press) {
			press = event;
		}
		type = [[press valueForKey:@"type"] integerValue];
	} @catch (__unused NSException *e) {
		type = -1;
	}

	// 101 — кнопка Home (GSEvent), 5 — UIPressTypeMenu в UIPressesEvent.
	// Если тип достать не удалось, не мешаем системе.
	if (type != 101 && type != 5) {
		return %orig;
	}

	// Одно физическое нажатие иногда приходит дважды (down/up) — гасим дребезг.
	NSTimeInterval now = CFAbsoluteTimeGetCurrent();
	if (now - gLastHomeAction < 0.4) {
		return YES;
	}
	gLastHomeAction = now;

	dispatch_async(dispatch_get_main_queue(), ^{
		FXPerformHomeAction();
	});
	return YES;
}

%end

#pragma mark - Включение штатного движка жестов

%hook SBHomeGestureSettings
- (BOOL)isHomeGestureEnabled {
	if (!gEnabled) {
		return %orig;
	}
	return YES;
}
%end

%hook SBFHomeGrabberSettings
- (BOOL)isEnabled {
	if (!gEnabled) {
		return %orig;
	}
	return YES;
}
%end

#pragma mark - Скрытие полоски в играх

// Игра определяется по переднему приложению: скрытый статус-бар или
// только ландшафтные ориентации. Для системных приложений не срабатывает.
static BOOL FXIsGameForeground(void) {
	if (!gHideBarInGames) {
		return NO;
	}

	static NSString *cachedBundle = nil;
	static BOOL cachedResult = NO;
	static NSTimeInterval cachedAt = 0.0;

	NSTimeInterval now = CFAbsoluteTimeGetCurrent();
	if (cachedBundle && now - cachedAt < 0.5) {
		return cachedResult;
	}

	NSString *bundle = nil;
	@try {
		SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
		if ([sb respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
			id app = [sb performSelector:@selector(_accessibilityFrontMostApplication)];
			bundle = [[app valueForKey:@"bundleIdentifier"] description];
			if (!bundle.length) {
				bundle = [[app valueForKey:@"displayIdentifier"] description];
			}
		}
	} @catch (__unused NSException *e) {
		bundle = nil;
	}

	BOOL result = NO;
	if (bundle.length && ![bundle hasPrefix:@"com.apple."]) {
		@try {
			SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
			id app = [sb performSelector:@selector(_accessibilityFrontMostApplication)];
			NSDictionary *info = [app valueForKey:@"infoPlist"];
			if ([info isKindOfClass:[NSDictionary class]]) {
				BOOL statusBarHidden = [info[@"UIStatusBarHidden"] boolValue];
				NSArray *orientations = info[@"UISupportedInterfaceOrientations"];
				BOOL landscapeOnly = [orientations isKindOfClass:[NSArray class]] && orientations.count > 0;
				if (landscapeOnly) {
					for (NSString *orientation in orientations) {
						if ([orientation isEqualToString:@"UIInterfaceOrientationPortrait"] ||
						    [orientation isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"]) {
							landscapeOnly = NO;
							break;
						}
					}
				}
				result = statusBarHidden || landscapeOnly;
			}
		} @catch (__unused NSException *e) {
			result = NO;
		}
	}

	cachedBundle = [bundle copy];
	cachedResult = result;
	cachedAt = now;
	return result;
}

#pragma mark - Внешний вид домашней полоски

// Значения по умолчанию не трогаем, чтобы не ломать анимацию «растягивания»
// полоски во время свайпа. Переопределяем только если пользователь задал
// свои размеры или вовсе выключил полоску.
%hook MTLumaDodgePillSettings

- (void)setHeight:(double)height {
	if (!gEnabled) {
		%orig(height);
		return;
	}
	if (!gShowHomeBar) {
		%orig(0.0);
		return;
	}
	if (gBarHeight > 0.0) {
		%orig(gBarHeight);
		return;
	}
	%orig(height);
}

- (void)setMinWidth:(double)width {
	if (!gEnabled) {
		%orig(width);
		return;
	}
	if (!gShowHomeBar) {
		%orig(0.0);
		return;
	}
	if (gBarWidth > 0.0) {
		%orig(gBarWidth);
		return;
	}
	%orig(width);
}

%end

// Цвет, фото и анимация полоски.
//
// MTLumaDodgePillView рисует системную белую/чёрную полоску своими подслоями
// (luma dodge), поэтому одного backgroundColor мало: его перекрывает штатная
// отрисовка. Плюс SpringBoard не запускает layout при смене настроек — цвет
// «залипал» до respring. Поэтому рисуем свою капсулу поверх, а системную
// отрисовку прячем. Когда включено фото/анимация — капсула тоже нужна.
static char kFXPillKey;
static char kFXBarImageKey;
static char kFXAnimStateKey;

static void FXApplyBarAnimation(UIView *pill) {
	CALayer *layer = pill.layer;
	[layer removeAnimationForKey:@"fxPulse"];
	[layer removeAnimationForKey:@"fxGlowRadius"];
	[layer removeAnimationForKey:@"fxGlowOpacity"];
	[layer removeAnimationForKey:@"fxRainbow"];
	layer.shadowOpacity = 0.0;
	layer.shadowRadius = 0.0;

	NSString *animation = gHomeBarAnimation ?: @"none";
	if ([animation isEqualToString:@"none"]) {
		return;
	}

	if ([animation isEqualToString:@"pulse"]) {
		CAKeyframeAnimation *pulse = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
		pulse.values = @[ @1.0, @1.18, @1.0 ];
		pulse.keyTimes = @[ @0.0, @0.5, @1.0 ];
		pulse.duration = 1.6;
		pulse.repeatCount = INFINITY;
		pulse.timingFunction =
		    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		[layer addAnimation:pulse forKey:@"fxPulse"];
	} else if ([animation isEqualToString:@"glow"]) {
		UIColor *glowColor = gBarColor ?: [UIColor whiteColor];
		layer.shadowColor = glowColor.CGColor;
		layer.shadowOffset = CGSizeZero;
		layer.shadowOpacity = 0.6;
		layer.shadowRadius = 6.0;

		CABasicAnimation *radius = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
		radius.fromValue = @2.0;
		radius.toValue = @11.0;
		radius.duration = 1.3;
		radius.autoreverses = YES;
		radius.repeatCount = INFINITY;
		[layer addAnimation:radius forKey:@"fxGlowRadius"];

		CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
		opacity.fromValue = @0.25;
		opacity.toValue = @0.9;
		opacity.duration = 1.3;
		opacity.autoreverses = YES;
		opacity.repeatCount = INFINITY;
		[layer addAnimation:opacity forKey:@"fxGlowOpacity"];
	} else if ([animation isEqualToString:@"rainbow"]) {
		NSMutableArray *colors = [NSMutableArray array];
		for (int i = 0; i <= 6; i++) {
			UIColor *color = [UIColor colorWithHue:(CGFloat)i / 6.0
			                            saturation:0.85
			                            brightness:0.95
			                                 alpha:1.0];
			[colors addObject:(__bridge id)color.CGColor];
		}
		CAKeyframeAnimation *rainbow =
		    [CAKeyframeAnimation animationWithKeyPath:@"backgroundColor"];
		rainbow.values = colors;
		rainbow.duration = 4.0;
		rainbow.repeatCount = INFINITY;
		[layer addAnimation:rainbow forKey:@"fxRainbow"];
	}
}

%hook MTLumaDodgePillView

- (void)layoutSubviews {
	%orig;

	UIView *pill = objc_getAssociatedObject(self, &kFXPillKey);
	BOOL wantAnimation = ![gHomeBarAnimation isEqualToString:@"none"];
	BOOL wantCustom = gEnabled && gShowHomeBar &&
	                  (gBarColor != nil || gBarImage != nil || wantAnimation);

	if (!wantCustom) {
		if (pill) {
			[pill removeFromSuperview];
			objc_setAssociatedObject(self, &kFXPillKey, nil,
			                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		objc_setAssociatedObject(self, &kFXAnimStateKey, nil,
		                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		// Возвращаем штатную отрисовку: иначе после выключения цвета
		// полоска остаётся невидимой до respring.
		for (UIView *sub in self.subviews) {
			sub.hidden = NO;
		}
		return;
	}

	// Геометрия штатной полоски: объединяем кадры её подслоёв, чтобы наша
	// капсула совпадала с ней и повторяла «растягивание» во время свайпа.
	CGRect pillRect = CGRectNull;
	for (UIView *sub in self.subviews) {
		if (sub == pill) {
			continue;
		}
		pillRect = CGRectIsNull(pillRect) ? sub.frame : CGRectUnion(pillRect, sub.frame);
	}
	pillRect = CGRectIntersection(pillRect, self.bounds);
	if (CGRectIsNull(pillRect) || pillRect.size.width < 1.0 || pillRect.size.height < 1.0) {
		pillRect = self.bounds;
	}

	if (!pill) {
		pill = [[UIView alloc] initWithFrame:pillRect];
		pill.userInteractionEnabled = NO;
		objc_setAssociatedObject(self, &kFXPillKey, pill,
		                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[self addSubview:pill];
	}

	// Прячем штатную отрисовку, иначе белая/чёрная полоска перекроет цвет.
	for (UIView *sub in self.subviews) {
		if (sub != pill) {
			sub.hidden = YES;
		}
	}

	CGFloat radius = CGRectGetHeight(pillRect) / 2.0;
	pill.frame = pillRect;
	pill.alpha = (gHideBarInGames && FXIsGameForeground()) ? 0.0 : gBarAlpha;
	// Без masksToBounds: иначе анимация свечения обрезается по границам.
	pill.layer.masksToBounds = NO;
	pill.clipsToBounds = NO;
	pill.layer.cornerRadius = radius;
	pill.backgroundColor = gBarColor ?: (gBarImage ? [UIColor clearColor]
	                                               : [UIColor colorWithWhite:0.55 alpha:0.9]);

	// Фото: отдельный слой внутри капсулы, скруглённый по её форме.
	UIImageView *imageView = objc_getAssociatedObject(self, &kFXBarImageKey);
	if (gBarImage) {
		if (!imageView) {
			imageView = [[UIImageView alloc] initWithFrame:pill.bounds];
			imageView.userInteractionEnabled = NO;
			imageView.contentMode = UIViewContentModeScaleAspectFill;
			imageView.clipsToBounds = YES;
			objc_setAssociatedObject(self, &kFXBarImageKey, imageView,
			                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			[pill addSubview:imageView];
		}
		imageView.frame = pill.bounds;
		imageView.layer.cornerRadius = radius;
		imageView.layer.masksToBounds = YES;
		imageView.image = gBarImage;
		imageView.hidden = NO;
	} else if (imageView) {
		[imageView removeFromSuperview];
		objc_setAssociatedObject(self, &kFXBarImageKey, nil,
		                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	// Анимацию перезапускаем только когда пресет реально изменился:
	// layoutSubviews вызывается часто, и постоянный перезапуск «дёргал» бы её.
	NSString *applied = objc_getAssociatedObject(self, &kFXAnimStateKey);
	if (![applied isEqualToString:gHomeBarAnimation]) {
		objc_setAssociatedObject(self, &kFXAnimStateKey, gHomeBarAnimation,
		                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		FXApplyBarAnimation(pill);
	}

	[self bringSubviewToFront:pill];
}

%end

// Прозрачность. У капсулы с цветом/фото/анимацией альфу выставляем ей самой
// (см. выше) — иначе она умножилась бы дважды. Для системной полоски
// работает штатный хук. В играх полоску прячем полностью.
%hook SBHomeGrabberView

- (void)setAlpha:(CGFloat)alpha {
	if (gEnabled && gHideBarInGames && FXIsGameForeground()) {
		%orig(0.0);
		return;
	}
	BOOL custom = gBarColor != nil || gBarImage != nil ||
	              ![gHomeBarAnimation isEqualToString:@"none"];
	if (gEnabled && !custom && gBarAlpha < 1.0) {
		%orig(alpha * gBarAlpha);
		return;
	}
	%orig(alpha);
}

%end

#pragma mark - Скорость анимаций

// Умножаем длительность UIView-анимаций. При 1.0 ничего не меняется,
// поэтому по умолчанию поведение системы полностью штатное.
%hook UIView

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
	if (gEnabled && gAnimSpeed != 1.0) {
		%orig(duration * gAnimSpeed, animations);
		return;
	}
	%orig(duration, animations);
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion {
	if (gEnabled && gAnimSpeed != 1.0) {
		%orig(duration * gAnimSpeed, animations, completion);
		return;
	}
	%orig(duration, animations, completion);
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
                    options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion {
	if (gEnabled && gAnimSpeed != 1.0) {
		%orig(duration * gAnimSpeed, delay * gAnimSpeed, options, animations, completion);
		return;
	}
	%orig(duration, delay, options, animations, completion);
}

%end

#pragma mark - Блюр системных подложек (экономия GPU)

// Полностью убирает размытие в SpringBoard: Пункт управления, папки,
// Spotlight. На A10 заметно бодрее, но выглядит «плоско» — по умолчанию выключено.
%hook UIVisualEffectView

- (void)setEffect:(UIVisualEffect *)effect {
	if (gEnabled && gNoBlur && [effect isKindOfClass:NSClassFromString(@"UIBlurEffect")]) {
		%orig(nil);
		return;
	}
	%orig(effect);
}

%end

#pragma mark - Пункт управления: свайп сверху справа

%hook CCSControlCenterDefaults
- (unsigned long long)_defaultPresentationGesture {
	if (!gEnabled || !gCCEdgeFix) {
		return %orig;
	}
	return 1;
}
%end

%hook SBControlCenterController
- (unsigned long long)presentingEdge {
	if (!gEnabled || !gCCEdgeFix) {
		return %orig;
	}
	return 1;
}
%end

// Лечит дёргающийся заголовок/анимацию Пункта управления,
// который появляется при включённых жестах.
%hook CCUIOverlayStatusBarPresentationProvider
- (void)_addHeaderContentTransformAnimationToBatch:(id)batch transitionState:(id)state {
	if (gEnabled && gCCAnimFix) {
		return;
	}
	%orig;
}
%end

// Закрытие Пункта управления без анимации — приём из проверенных
// реализаций HomeGesture для iOS 13–15: иначе оверлей «дёргается»
// при свайпе сверху справа.
%hook CCUIModularControlCenterOverlayViewController
- (void)dismissAnimated:(BOOL)animated withCompletionHandler:(id)completion {
	if (gEnabled && gCCAnimFix) {
		animated = NO;
	}
	%orig(animated, completion);
}
%end

#pragma mark - Инициализация

%ctor {
	LoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
	                                (CFNotificationCallback)PrefsChanged,
	                                CFSTR(RELOAD_NOTIFICATION_C), NULL,
	                                CFNotificationSuspensionBehaviorDeliverImmediately);
}
