// FluidXKeyboard — поднимает клавиатуру над домашней полоской.
//
// Клавиатура рисуется внутри процесса приложения, поэтому этот маленький
// твик ставится с фильтром по классу UIInputSetHostView и грузится в
// приложения (и в SpringBoard). Всё остальное делает основной FluidX.dylib.

#import <UIKit/UIKit.h>

@interface UIInputSetHostView : UIView
@end

#define PREFS_DOMAIN @"com.dolboebvaibcode.fluidx"
#define RELOAD_NOTIFICATION @"com.dolboebvaibcode.fluidx/ReloadPrefs"
// CFSTR() принимает только C-строку, не NSString-литерал.
#define RELOAD_NOTIFICATION_C "com.dolboebvaibcode.fluidx/ReloadPrefs"

static BOOL gEnabled = YES;
static double gKeyboardLift = 0.0;

static void LoadPrefs(void) {
	gEnabled = YES;
	gKeyboardLift = 0.0;

	// Внутри обычного (sandboxed) приложения NSUserDefaults с произвольным
	// suite может смотреть в контейнер приложения, а не в общий plist.
	// CFPreferences с kCFPreferencesCurrentUser/kCFPreferencesAnyHost читает
	// тот же домен, куда пишет FluidX.app в SpringBoard/глобальные настройки.
	CFDictionaryRef copied = CFPreferencesCopyMultiple(NULL,
	                                                   CFSTR("com.dolboebvaibcode.fluidx"),
	                                                   kCFPreferencesCurrentUser,
	                                                   kCFPreferencesAnyHost);
	NSDictionary *prefs = CFBridgingRelease(copied);

	if (![prefs isKindOfClass:[NSDictionary class]] || prefs.count == 0) {
		static NSUserDefaults *defaults;
		static dispatch_once_t once;
		dispatch_once(&once, ^{
			defaults = [[NSUserDefaults alloc] initWithSuiteName:PREFS_DOMAIN];
		});
		prefs = [defaults persistentDomainForName:PREFS_DOMAIN] ?: @{};
	}

	id enabled = prefs[@"enabled"];
	gEnabled = enabled ? [enabled boolValue] : YES;

	id lift = prefs[@"keyboardLift"];
	gKeyboardLift = lift ? [lift doubleValue] : 0.0;
	if (gKeyboardLift < 0.0) {
		gKeyboardLift = 0.0;
	}
	if (gKeyboardLift > 40.0) {
		gKeyboardLift = 40.0;
	}
}

static void PrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name,
                         const void *object, CFDictionaryRef userInfo) {
	LoadPrefs();
}

%hook UIInputSetHostView

- (void)layoutSubviews {
	%orig;

	// Сдвигаем не frame, а transform: layoutSubviews вызывается постоянно,
	// а frame-сдвиг накапливался бы и уводил клавиатуру всё выше.
	// Сравнение с текущим transform делает операцию идемпотентной.
	CGAffineTransform desired =
	    (gEnabled && gKeyboardLift > 0.0)
	        ? CGAffineTransformMakeTranslation(0, -gKeyboardLift)
	        : CGAffineTransformIdentity;

	if (!CGAffineTransformEqualToTransform(self.transform, desired)) {
		self.transform = desired;
	}
}

%end

%ctor {
	LoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
	                                (CFNotificationCallback)PrefsChanged,
	                                CFSTR(RELOAD_NOTIFICATION_C), NULL,
	                                CFNotificationSuspensionBehaviorDeliverImmediately);
}
