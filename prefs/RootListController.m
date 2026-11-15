#import "RootListController.h"

#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <unistd.h>

extern char **environ;

static NSString *const kPrefsDomain = @"com.dolboebvaibcode.fluidx";
static NSString *const kReloadNotification = @"com.dolboebvaibcode.fluidx/ReloadPrefs";

static void SpawnCommand(const char *path, const char *arg1, const char *arg2) {
	if (!path || access(path, X_OK) != 0) {
		return;
	}

	const char *argv[] = { path, arg1, arg2, NULL };
	pid_t pid = 0;
	posix_spawn(&pid, path, NULL, NULL, (char *const *)argv, environ);
}

@implementation FluidXRootListController

// PSListController по умолчанию ищет Root.plist в бандле, который может быть
// подставлен PreferenceLoader'ом (папка Preferences). Возвращаем именно свой
// бандл — там лежит Root.plist.
- (NSBundle *)bundle {
	NSBundle *own = [NSBundle bundleForClass:[self class]];
	return own ?: [super bundle];
}

- (NSString *)diagnosticText {
	NSBundle *b = [self bundle];
	NSString *rootPath = [b pathForResource:@"Root" ofType:@"plist"];
	NSDictionary *plist = rootPath ? [NSDictionary dictionaryWithContentsOfFile:rootPath] : nil;
	id items = plist[@"items"];

	return [NSString stringWithFormat:
	        @"Диагностика FluidX\n"
	        @"bundle: %@\n"
	        @"Root.plist: %@\n"
	        @"items: %@\n"
	        @"класс: %@",
	        [b bundlePath],
	        rootPath ?: @"не найден",
	        items ? [NSString stringWithFormat:@"%lu", (unsigned long)[items count]] : @"не прочитан",
	        NSStringFromClass([self class])];
}

- (void)writeDiagnostic:(NSString *)text {
	[text writeToFile:@"/var/mobile/FluidX-prefs-error.txt"
	           atomically:YES
	             encoding:NSUTF8StringEncoding
	                error:NULL];
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

		// Если по какой-то причине список пуст — показываем причину прямо
		// в Настройках и дублируем её в файл, чтобы не гадать.
		if (_specifiers.count == 0) {
			NSString *diag = [self diagnosticText];
			[self writeDiagnostic:diag];

			PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
			[group setProperty:diag forKey:@"footerText"];
			_specifiers = @[ group ];
		}
	}
	return _specifiers;
}

- (void)respring {
	// rootless-бутстрап: sbreload есть почти всегда, killall — запасной вариант
	SpawnCommand("/var/jb/usr/bin/sbreload", NULL, NULL);
	SpawnCommand("/var/jb/usr/bin/killall", "-9", "SpringBoard");
}

- (void)resetPrefs {
	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPrefsDomain];
	[defaults removePersistentDomainForName:kPrefsDomain];
	[defaults synchronize];

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
	                                     (CFStringRef)kReloadNotification, NULL, NULL, YES);

	[self reloadSpecifiers];
	[self respring];
}

- (void)openURLString:(NSString *)string {
	NSURL *url = [NSURL URLWithString:string];
	if (url) {
		[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
	}
}

- (void)openGitHub {
	[self openURLString:@"https://github.com/vaibcode-dev/FluidX"];
}

- (void)openTelegram {
	// t.me откроется в приложении Telegram, если оно установлено, иначе в Safari
	[self openURLString:@"https://t.me/angel_gtag"];
}

- (void)openBuildLog {
	[self openURLString:@"https://github.com/vaibcode-dev/FluidX/blob/ci-logs/build.log"];
}

@end
