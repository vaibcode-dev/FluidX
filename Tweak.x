// CustomGestures — жесты iPhone X для iPhone 7 (iOS 15.x, rootless)
//
// Идея: не рисовать свои распознаватели (они дают рывки и конфликты),
// а включить встроенный движок жестов SpringBoard и аккуратно
// перенастроить внешний вид полоски и Пункт управления.

#import <UIKit/UIKit.h>

#define PREFS_DOMAIN @"com.angelss.customgestures"
#define RELOAD_NOTIFICATION "com.angelss.customgestures/ReloadPrefs"

static BOOL gEnabled = YES;
static BOOL gShowHomeBar = YES;
static double gBarHeight = 0.0; // 0 = системная высота
static double gBarWidth = 0.0;  // 0 = системная ширина
static BOOL gCCEdgeFix = YES;
static BOOL gCCAnimFix = YES;

static NSUserDefaults *Prefs(void) {
	static NSUserDefaults *defaults;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		defaults = [[NSUserDefaults alloc] initWithSuiteName:PREFS_DOMAIN];
		[defaults registerDefaults:@{
			@"enabled"     : @YES,
			@"showHomeBar" : @YES,
			@"homeBarHeight" : @0.0,
			@"homeBarWidth"  : @0.0,
			@"ccEdgeFix"   : @YES,
			@"ccAnimFix"   : @YES,
		}];
	});
	return defaults;
}

static void LoadPrefs(void) {
	NSUserDefaults *d = Prefs();
	gEnabled     = [d boolForKey:@"enabled"];
	gShowHomeBar = [d boolForKey:@"showHomeBar"];
	gBarHeight   = [d doubleForKey:@"homeBarHeight"];
	gBarWidth    = [d doubleForKey:@"homeBarWidth"];
	gCCEdgeFix   = [d boolForKey:@"ccEdgeFix"];
	gCCAnimFix   = [d boolForKey:@"ccAnimFix"];
}

static void PrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name,
                         const void *object, CFDictionaryRef userInfo) {
	LoadPrefs();
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

#pragma mark - Инициализация

%ctor {
	LoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
	                                (CFNotificationCallback)PrefsChanged,
	                                CFSTR(RELOAD_NOTIFICATION), NULL,
	                                CFNotificationSuspensionBehaviorDeliverImmediately);
}
