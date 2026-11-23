#import "FXPrefs.h"

NSString *const FXDomain = @"com.dolboebvaibcode.fluidx";
NSString *const FXReloadNotification = @"com.dolboebvaibcode.fluidx/ReloadPrefs";

NSUserDefaults *FXDefaults(void) {
	static NSUserDefaults *defaults;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		defaults = [[NSUserDefaults alloc] initWithSuiteName:FXDomain];
		[defaults registerDefaults:@{
			@"enabled"       : @YES,
			@"showHomeBar"   : @YES,
			@"homeBarHeight" : @0.0,
			@"homeBarWidth"  : @0.0,
			@"homeBarAlpha"  : @1.0,
			@"homeBarColor"  : @"",
			@"homeBarImage"  : @"",
			@"homeBarAnimation" : @"none",
			@"homeButtonAction" : @"system",
			@"keyboardLift"  : @0.0,
			@"hideBarInGames" : @NO,
			@"animSpeed"     : @1.0,
			@"noBlur"        : @NO,
			@"ccEdgeFix"     : @YES,
			@"ccAnimFix"     : @YES,
		}];
	});
	return defaults;
}

void FXNotifyReload(void) {
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
	                                     (__bridge CFStringRef)FXReloadNotification,
	                                     NULL, NULL, YES);
}

void FXSetValue(NSString *key, id value) {
	NSUserDefaults *defaults = FXDefaults();
	if (value) {
		[defaults setObject:value forKey:key];
	} else {
		[defaults removeObjectForKey:key];
	}
	[defaults synchronize];
	FXNotifyReload();
}

void FXResetAll(void) {
	NSUserDefaults *defaults = FXDefaults();
	[defaults removePersistentDomainForName:FXDomain];
	[defaults synchronize];
	FXNotifyReload();
}

void FXWriteDiagnostic(NSString *tag) {
	NSMutableString *out = [NSMutableString string];
	NSBundle *bundle = [NSBundle mainBundle];

	[out appendFormat:@"FluidX.app · %@\ntag: %@\n", [NSDate date], tag ?: @"-"];
	[out appendFormat:@"bundle: %@\n", [bundle bundlePath]];
	[out appendFormat:@"bundle id: %@\n", [bundle bundleIdentifier]];
	[out appendFormat:@"NSHomeDirectory: %@\n", NSHomeDirectory()];

	NSString *globalPath = [@"/var/mobile/Library/Preferences"
	    stringByAppendingPathComponent:[FXDomain stringByAppendingPathExtension:@"plist"]];
	[out appendFormat:@"глобальный plist: %@ (есть: %d)\n",
	                  globalPath,
	                  [[NSFileManager defaultManager] fileExistsAtPath:globalPath]];

	NSDictionary *values = [FXDefaults() persistentDomainForName:FXDomain];
	[out appendFormat:@"persistentDomain:\n%@\n", values];

	[out writeToFile:@"/var/mobile/FluidX-app.txt"
	          atomically:YES
	            encoding:NSUTF8StringEncoding
	               error:NULL];
}
