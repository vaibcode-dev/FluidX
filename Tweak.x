// FluidX — жесты iPhone X для iPhone 7 (iOS 15.x, rootless)
//
// Идея: не рисовать свои распознаватели (они дают рывки и конфликты),
// а включить встроенный движок жестов SpringBoard и аккуратно
// перенастроить внешний вид полоски и Пункта управления.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Приватные классы SpringBoard/MaterialKit. Заголовков в SDK нет,
// поэтому объявляем сами — иначе компилятор не знает их свойств.
@interface MTLumaDodgePillView : UIView
@end

@interface SBHomeGrabberView : UIView
@end

#define PREFS_DOMAIN @"com.dolboebvaibcode.fluidx"
#define RELOAD_NOTIFICATION "com.dolboebvaibcode.fluidx/ReloadPrefs"

static BOOL gEnabled = YES;
static BOOL gShowHomeBar = YES;
static double gBarHeight = 0.0; // 0 = системная высота
static double gBarWidth = 0.0;  // 0 = системная ширина
static double gBarAlpha = 1.0;  // 1 = системная прозрачность
static UIColor *gBarColor = nil; // nil = системный цвет (светлый/тёмный)
static double gAnimSpeed = 1.0;  // 1 = системная скорость
static BOOL gNoBlur = NO;        // убрать блюр подложек (экономия GPU)
static BOOL gCCEdgeFix = YES;
static BOOL gCCAnimFix = YES;

static NSUserDefaults *Prefs(void) {
	static NSUserDefaults *defaults;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		defaults = [[NSUserDefaults alloc] initWithSuiteName:PREFS_DOMAIN];
		[defaults registerDefaults:@{
			@"enabled"       : @YES,
			@"showHomeBar"   : @YES,
			@"homeBarHeight" : @0.0,
			@"homeBarWidth"  : @0.0,
			@"homeBarAlpha"  : @1.0,
			@"homeBarColor"  : @"",
			@"animSpeed"     : @1.0,
			@"noBlur"        : @NO,
			@"ccEdgeFix"     : @YES,
			@"ccAnimFix"     : @YES,
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

	if (gBarAlpha <= 0.0) {
		gBarAlpha = 1.0;
	}
	if (gAnimSpeed <= 0.05) {
		gAnimSpeed = 1.0;
	}

	gBarColor = ColorFromHex([d stringForKey:@"homeBarColor"]);
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

// Цвет полоски.
//
// MTLumaDodgePillView рисует системную белую/чёрную полоску своими подслоями
// (luma dodge), поэтому одного backgroundColor мало: его перекрывает штатная
// отрисовка. Плюс SpringBoard не запускает layout при смене настроек — цвет
// «залипал» до respring. Поэтому рисуем свою непрозрачную капсулу поверх,
// а системную отрисовку прячем.
static char kFXPillKey;

%hook MTLumaDodgePillView

- (void)layoutSubviews {
	%orig;

	UIView *pill = objc_getAssociatedObject(self, &kFXPillKey);

	if (!gEnabled || !gBarColor) {
		if (pill) {
			[pill removeFromSuperview];
			objc_setAssociatedObject(self, &kFXPillKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
		objc_setAssociatedObject(self, &kFXPillKey, pill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[self addSubview:pill];
	}

	// Прячем штатную отрисовку, иначе белая/чёрная полоска перекроет цвет.
	for (UIView *sub in self.subviews) {
		if (sub != pill) {
			sub.hidden = YES;
		}
	}

	pill.frame = pillRect;
	pill.backgroundColor = gBarColor;
	pill.alpha = gBarAlpha;
	pill.layer.cornerRadius = CGRectGetHeight(pillRect) / 2.0;
	pill.layer.masksToBounds = YES;
	[self bringSubviewToFront:pill];
}

%end

// Прозрачность. У цветной полоски альфу выставляем своей капсуле (см. выше) —
// иначе она умножилась бы дважды. Для системной полоски работает штатный хук.
%hook SBHomeGrabberView

- (void)setAlpha:(CGFloat)alpha {
	if (gEnabled && !gBarColor && gBarAlpha < 1.0) {
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
	                                CFSTR(RELOAD_NOTIFICATION), NULL,
	                                CFNotificationSuspensionBehaviorDeliverImmediately);
}
