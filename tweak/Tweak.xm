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

%group InstalldHooks

%hook MIDaemonConfiguration
- (BOOL)skipDeviceFamilyCheck {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIDaemonConfiguration: bypass skipDeviceFamilyCheck");
        return YES;
    }
    return %orig;
}
- (BOOL)skipThinningCheck {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIDaemonConfiguration: bypass skipThinningCheck");
        return YES;
    }
    return %orig;
}
%end

%hook MIBundle
- (NSString *)minimumOSVersion {
    NSString *ret = %orig;
    if (g_enabled && g_hooksInstalld) {
        LIInfo("MIBundle: override minimumOSVersion '%s' -> '2.0'", ret.UTF8String);
        ret = @"2.0";
    }
    return ret;
}
- (NSArray *)supportedDevices {
    NSArray *ret = %orig ?: @[];
    if (g_enabled && g_hooksInstalld && ![ret containsObject:g_state.currentDevice]) {
        LIInfo("MIBundle: inject device '%s' into supportedDevices (had: %s)",
               g_state.currentDevice.UTF8String, ret.description.UTF8String);
        NSMutableArray *m = [ret mutableCopy];
        [m addObject:g_state.currentDevice];
        ret = [[m copy] autorelease];
        [m release];
    }
    return ret;
}
- (BOOL)isCompatibleWithDeviceFamily:(int)device {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass isCompatibleWithDeviceFamily:%d", device);
        return YES;
    }
    return %orig;
}
- (BOOL)isApplicableToCurrentDeviceFamilyWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass isApplicableToCurrentDeviceFamilyWithError");
        return YES;
    }
    return %orig;
}
- (BOOL)isApplicableToCurrentOSVersionWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass isApplicableToCurrentOSVersionWithError");
        return YES;
    }
    return %orig;
}
- (BOOL)isApplicableToOSVersion:(id)arg1 error:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass isApplicableToOSVersion:%s", [arg1 description].UTF8String);
        return YES;
    }
    return %orig;
}
- (BOOL)isApplicableToCurrentDeviceCapabilitiesWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass isApplicableToCurrentDeviceCapabilitiesWithError");
        return YES;
    }
    return %orig;
}
- (BOOL)thinningMatchesCurrentDeviceWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass thinningMatchesCurrentDeviceWithError");
        return YES;
    }
    return %orig;
}
- (BOOL)validateAppMetadataWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass validateAppMetadataWithError");
        return YES;
    }
    return %orig;
}
- (BOOL)validatePluginMetadataWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIBundle: bypass validatePluginMetadataWithError");
        return YES;
    }
    return %orig;
}
%end

%hook MIInstallableBundle
- (BOOL)_validateApplicationIdentifierForNewBundleSigningInfo:(id)arg1 error:(id *)arg2 {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIInstallableBundle: bypass _validateApplicationIdentifierForNewBundleSigningInfo");
        return YES;
    }
    return %orig;
}
- (BOOL)_verifyBundleMetadataWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIInstallableBundle: bypass _verifyBundleMetadataWithError");
        return YES;
    }
    return %orig;
}
- (BOOL)_verifySubBundleMetadataWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIInstallableBundle: bypass _verifySubBundleMetadataWithError");
        return YES;
    }
    return %orig;
}
- (BOOL)_isValidWatchKitApp:(id)arg1 withVersion:(id)arg2 installableSigningInfo:(id)arg3 error:(id *)arg4 {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIInstallableBundle: bypass _isValidWatchKitApp");
        return YES;
    }
    return %orig;
}
%end

%hook MIExecutableBundle
- (BOOL)hasOnlyAllowedWatchKitAppInfoPlistKeysForWatchKitVersion:(id)arg1 error:(id *)arg2 {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIExecutableBundle: bypass hasOnlyAllowedWatchKitAppInfoPlistKeysForWatchKitVersion");
        return YES;
    }
    return %orig;
}
%end

%hook MIPluginKitPluginBundle
- (BOOL)validateBundleMetadataWithError:(id *)error {
    if (g_enabled && g_hooksInstalld) {
        LIDebug("MIPluginKitPluginBundle: bypass validateBundleMetadataWithError");
        return YES;
    }
    return %orig;
}
%end

%end   // group InstalldHooks

%group StoreHooks

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (!g_enabled || !g_hooksStore || !field || !value ||
        ![field isEqualToString:@"User-Agent"] ||
        [value rangeOfString:g_state.currentVersion].location == NSNotFound) {
        %orig(value, field);
        return;
    }
    NSString *rewritten = value;
    rewritten = [rewritten stringByReplacingOccurrencesOfString:
        [NSString stringWithFormat:@"/%@ ", g_state.currentVersion]
                  withString:[NSString stringWithFormat:@"/%@ ", g_state.spoofVersion]];
    rewritten = [rewritten stringByReplacingOccurrencesOfString:
        [NSString stringWithFormat:@"/%@ ", g_state.currentDevice]
                  withString:[NSString stringWithFormat:@"/%@ ", g_state.spoofDevice]];
    LIInfo("UA spoof: '%s' -> '%s'", value.UTF8String, rewritten.UTF8String);
    %orig(rewritten, field);
}
%end

%end   // group StoreHooks

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
