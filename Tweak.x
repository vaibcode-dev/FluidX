// MyTweak — шаблон rootless-твика для iPhone 7 (iOS 15.8.8)
//
// Здесь и будет твой код. Сейчас стоит демонстрационный хук:
// после respring SpringBoard один раз показывает окошко «Твик загружен».
// Как только проверим, что сборка и установка работают, заменим его
// на то, что ты задумал.

#import <UIKit/UIKit.h>

// Приватный класс SpringBoard: объявляем сами, т.к. заголовков системы нет.
@interface SpringBoard : UIApplication
- (void)applicationDidFinishLaunching:(id)application;
@end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
	%orig; // сначала выполняем оригинальный код SpringBoard

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
	               dispatch_get_main_queue(), ^{
		UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
		if (!root) {
			return;
		}

		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"MyTweak"
		                                                               message:@"Твик загружен ✅"
		                                                        preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK"
		                                          style:UIAlertActionStyleDefault
		                                        handler:nil]];
		[root presentViewController:alert animated:YES completion:nil];
	});
}

%end
