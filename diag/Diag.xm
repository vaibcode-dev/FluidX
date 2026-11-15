// FluidX — диагностический твик для процесса Настроек (com.apple.Preferences).
//
// Зачем: раздел FluidX не появляется в Настройках, хотя plist лежит на месте.
// Этот твик запускается внутри самого приложения Настроек и записывает
// в /var/mobile/FluidX-prefs-diag.txt то, что видит система:
//   * читается ли наш plist для PreferenceLoader;
//   * как выглядят plist'ы рабочих твиков (для сравнения);
//   * находится ли наш PreferenceBundles-бандл и его бинарник;
//   * грузится ли бандл (dlopen) и с какой ошибкой, если нет.
//
// Файл только читает и пишет отчёт — на работу Настроек не влияет.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>

static NSString *const kPrefsDir   = @"/var/jb/Library/PreferenceLoader/Preferences";
static NSString *const kBundlePath = @"/var/jb/Library/PreferenceBundles/FluidXPrefs.bundle";
static NSString *const kReportPath = @"/var/mobile/FluidX-prefs-diag.txt";

static void AppendPlist(NSMutableString *out, NSString *fileName) {
	NSString *path = [kPrefsDir stringByAppendingPathComponent:fileName];
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
	if (dict) {
		[out appendFormat:@"--- %@ ---\n%@\n", fileName, dict];
	} else {
		[out appendFormat:@"--- %@ ---\n(не прочитан или отсутствует)\n", fileName];
	}
}

static void WriteReport(void) {
	NSMutableString *out = [NSMutableString string];
	NSFileManager *fm = [NSFileManager defaultManager];

	[out appendFormat:@"FluidX prefs-diag · %@\n", [NSDate date]];
	[out appendString:@"Инжект в Настройки: РАБОТАЕТ (этот файл пишет наш твик)\n"];
	[out appendFormat:@"Класс PreferenceLoader в процессе: %s\n\n",
	                  NSClassFromString(@"PreferenceLoader") ? "есть" : "нет"];

	NSArray *files = [fm contentsOfDirectoryAtPath:kPrefsDir error:NULL];
	[out appendFormat:@"plist'ов в папке PreferenceLoader: %lu\n\n",
	                  (unsigned long)files.count];

	AppendPlist(out, @"FluidX.plist");
	AppendPlist(out, @"IconTint.plist");
	AppendPlist(out, @"LineageQS.plist");
	AppendPlist(out, @"ChoicyPrefs.plist");
	AppendPlist(out, @"Zone.plist");

	[out appendFormat:@"\nbundle есть: %d\n", [fm fileExistsAtPath:kBundlePath]];

	NSBundle *bundle = [NSBundle bundleWithPath:kBundlePath];
	[out appendFormat:@"NSBundle: %@\n", bundle];
	[out appendFormat:@"executablePath: %@\n", [bundle executablePath]];
	[out appendFormat:@"bundlePath: %@\n", [bundle bundlePath]];
	[out appendFormat:@"Info.plist бандла:\n%@\n",
	                  [NSDictionary dictionaryWithContentsOfFile:
	                      [kBundlePath stringByAppendingPathComponent:@"Info.plist"]]];

	NSString *exe = [kBundlePath stringByAppendingPathComponent:@"FluidXPrefs"];
	void *handle = dlopen(exe.UTF8String, RTLD_NOW);
	if (handle) {
		[out appendString:@"dlopen бандла: OK\n"];
		[out appendFormat:@"класс FluidXRootListController: %s\n",
		                  NSClassFromString(@"FluidXRootListController") ? "найден" : "НЕ найден"];
		[out appendFormat:@"NSBundle isLoaded после dlopen: %d\n", [bundle isLoaded]];
	} else {
		const char *err = dlerror();
		[out appendFormat:@"dlopen бандла: ОШИБКА\n%s\n", err ? err : "без текста"];
	}

	[fm createFileAtPath:kReportPath contents:[out dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
	[out writeToFile:kReportPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

%ctor {
	@autoreleasepool {
		WriteReport();
	}
}
