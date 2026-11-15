#import "FXAppDelegate.h"

#import "FXPrefs.h"
#import "FXSettingsController.h"

@implementation FXAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	FXWriteDiagnostic(@"launch");

	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

	FXSettingsController *root = [[FXSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
	nav.navigationBar.prefersLargeTitles = YES;

	self.window.rootViewController = nav;
	[self.window makeKeyAndVisible];
	return YES;
}

@end
