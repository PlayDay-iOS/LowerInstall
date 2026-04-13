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

%ctor {
    LINotice("skeleton loaded in '%s'", __progname);
}
