/*
 * LowerInstall — install apps that require a newer iOS version.
 *
 * Two subsystems injected into launchd-managed daemons:
 *
 *   A. installd hooks (MIBundle / MIInstallableBundle / MIExecutableBundle /
 *      MIPluginKitPluginBundle / MIDaemonConfiguration) force device-family,
 *      thinning, and metadata validation to report success, letting IPAs
 *      whose Info.plist would otherwise reject this device/iOS install.
 *
 *   B. Store hooks (NSMutableURLRequest -setValue:forHTTPHeaderField:)
 *      rewrite outgoing User-Agent so Apple's metadata servers return IPAs
 *      for a spoofed iOS / device pair.  Runs in itunesstored (iOS 9) and
 *      appstored (iOS 10+).
 *
 * Preferences plist:
 *   /var/mobile/Library/Preferences/dev.playday3008.lowerinstall.plist
 *
 * Darwin reload notification:
 *   dev.playday3008.lowerinstall/SettingsChanged
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <notify.h>
#import <sys/utsname.h>
#import <syslog.h>

extern const char *__progname;

#define LILog(lvl, fmt, ...) syslog((lvl), "[LowerInstall:%s] " fmt, __progname, ##__VA_ARGS__)
#define LINotice(fmt, ...)   LILog(LOG_NOTICE, fmt, ##__VA_ARGS__)
#define LIInfo(fmt, ...)     LILog(LOG_INFO,   fmt, ##__VA_ARGS__)
#define LIDebug(fmt, ...)    LILog(LOG_DEBUG,  fmt, ##__VA_ARGS__)

#define PLIST_PATH "/var/mobile/Library/Preferences/dev.playday3008.lowerinstall.plist"

static struct {
    NSString *currentDevice;   // uname().machine, cached at %ctor
    NSString *currentVersion;  // UIDevice.currentDevice.systemVersion, cached at %ctor
    NSString *spoofDevice;     // loaded from prefs; defaults to currentDevice
    NSString *spoofVersion;    // loaded from prefs; defaults to currentVersion
} g_state;

static BOOL g_enabled       = YES;
static BOOL g_hooksInstalld = YES;
static BOOL g_hooksStore    = YES;

static void settingsChanged(CFNotificationCenterRef center,
                            void *observer,
                            CFStringRef name,
                            const void *object,
                            CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    @autoreleasepool {
        NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:@PLIST_PATH] ?: @{};

        g_enabled       = [(p[@"Enabled"]       ?: @YES) boolValue];
        g_hooksInstalld = [(p[@"HooksInstalld"] ?: @YES) boolValue];
        g_hooksStore    = [(p[@"HooksStore"]    ?: @YES) boolValue];

        NSString *sd = p[@"SpoofDevice"]  ?: g_state.currentDevice;
        NSString *sv = p[@"SpoofVersion"] ?: g_state.currentVersion;
        [g_state.spoofDevice  release]; g_state.spoofDevice  = [sd copy];
        [g_state.spoofVersion release]; g_state.spoofVersion = [sv copy];

        LINotice("reload: enabled=%d installd=%d store=%d spoof='%s'/'%s'",
                 g_enabled, g_hooksInstalld, g_hooksStore,
                 g_state.spoofDevice.UTF8String,
                 g_state.spoofVersion.UTF8String);
    }
}

%ctor {
    struct utsname systemInfo;
    uname(&systemInfo);
    g_state.currentDevice  = [[NSString alloc] initWithUTF8String:systemInfo.machine];
    g_state.currentVersion = [[[UIDevice currentDevice] systemVersion] copy];

    LINotice("loading in '%s' (device=%s, iOS=%s)",
             __progname, systemInfo.machine,
             g_state.currentVersion.UTF8String);

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, (CFNotificationCallback)settingsChanged,
        CFSTR("dev.playday3008.lowerinstall/SettingsChanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    settingsChanged(NULL, NULL, NULL, NULL, NULL);
}
