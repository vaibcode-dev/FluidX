#import "RootListController.h"

#import <spawn.h>
#import <unistd.h>

extern char **environ;

static void SpawnCommand(const char *path, const char *arg1, const char *arg2) {
	if (!path || access(path, X_OK) != 0) {
		return;
	}

	const char *argv[] = { path, arg1, arg2, NULL };
	pid_t pid = 0;
	posix_spawn(&pid, path, NULL, NULL, (char *const *)argv, environ);
}

@implementation CustomGesturesRootListController

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

@end
