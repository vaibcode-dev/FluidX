#import "RootListController.h"

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

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
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
