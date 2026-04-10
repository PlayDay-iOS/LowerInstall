#import <objc/runtime.h>
#import <notify.h>
#import <dlfcn.h>
#import <substrate.h>
#import <sys/utsname.h>
#import <syslog.h>

extern const char *__progname;

#define LILog(level, fmt, ...) syslog(level, "[LowerInstall:%s] " fmt, __progname, ##__VA_ARGS__)
#define LINotice(fmt, ...) LILog(LOG_NOTICE, fmt, ##__VA_ARGS__)
#define LIInfo(fmt, ...)   LILog(LOG_INFO, fmt, ##__VA_ARGS__)
#define LIDebug(fmt, ...)  LILog(LOG_DEBUG, fmt, ##__VA_ARGS__)

#define PLIST_PATH_Settings "/var/mobile/Library/Preferences/dev.playday3008.lowerinstall.plist"


static BOOL Enabled;

typedef enum {
	kUserAgent=0,
	kUserAgentFormat=1,
	kCurrentDeviceType=2,
	kCurrentiOSVersion=3,
	kSpoofDeviceType=4,
	kSpoofiOSVersion=5,
} LowerInstall_var_Num;

#define MAX_STRING_LEN 30
#define STORED_STRING LowerInstall_var7956

char STORED_STRING[10][MAX_STRING_LEN];
#define StringVal(VALUE_ST) [NSString stringWithUTF8String:STORED_STRING[VALUE_ST]]


%group itunesstoredHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
	if((Enabled && field && value) && [field isEqualToString:StringVal(kUserAgent)]) {
		if([value rangeOfString:StringVal(kCurrentiOSVersion)].location != NSNotFound) {
			NSString *originalUA = value;
			value = [value stringByReplacingOccurrencesOfString:[NSString stringWithFormat:StringVal(kUserAgentFormat), StringVal(kCurrentiOSVersion)] withString:[NSString stringWithFormat:StringVal(kUserAgentFormat), StringVal(kSpoofiOSVersion)]];
			value = [value stringByReplacingOccurrencesOfString:[NSString stringWithFormat:StringVal(kUserAgentFormat), StringVal(kCurrentDeviceType)] withString:[NSString stringWithFormat:StringVal(kUserAgentFormat), StringVal(kSpoofDeviceType)]];
			LIInfo("spoofed User-Agent: '%s' -> '%s'", originalUA.UTF8String, value.UTF8String);
		}
	}
	%orig(value, field);
}

%end

%end

%group installdHooks

%hook MIDaemonConfiguration

- (BOOL)skipDeviceFamilyCheck
{
	if(Enabled) {
		LIDebug("MIDaemonConfiguration: bypassing device family check");
		return YES;
	}
	return %orig;
}

- (BOOL)skipThinningCheck
{
	if(Enabled) {
		LIDebug("MIDaemonConfiguration: bypassing thinning check");
		return YES;
	}
	return %orig;
}

%end

%hook MIBundle

- (NSString*)minimumOSVersion
{
	NSString* ret = %orig;
	if(Enabled) {
		LIInfo("MIBundle: overriding minimumOSVersion '%s' -> '2.0'", ret.UTF8String);
		ret = @"2.0";
	}
	return ret;
}

- (NSArray *)supportedDevices
{
	NSArray* ret = %orig?:@[];
	if(Enabled && ![ret containsObject:StringVal(kCurrentDeviceType)]) {
		LIInfo("MIBundle: injecting device '%s' into supportedDevices (had: %s)",
			STORED_STRING[kCurrentDeviceType],
			ret.description.UTF8String);
		NSMutableArray* retMut = [ret mutableCopy];
		[retMut addObject:StringVal(kCurrentDeviceType)];
		ret = [retMut copy];
	}
	return ret;
}

- (BOOL)isCompatibleWithDeviceFamily:(int)device
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing isCompatibleWithDeviceFamily:%d", device);
		return YES;
	}
	return %orig;
}
- (BOOL)isApplicableToCurrentDeviceFamilyWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing isApplicableToCurrentDeviceFamilyWithError");
		return YES;
	}
	return %orig;
}
- (BOOL)isApplicableToCurrentOSVersionWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing isApplicableToCurrentOSVersionWithError");
		return YES;
	}
	return %orig;
}
- (BOOL)isApplicableToOSVersion:(id)arg1 error:(id*)error
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing isApplicableToOSVersion:%s", [arg1 description].UTF8String);
		return YES;
	}
	return %orig;
}
- (BOOL)isApplicableToCurrentDeviceCapabilitiesWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing isApplicableToCurrentDeviceCapabilitiesWithError");
		return YES;
	}
	return %orig;
}
- (BOOL)thinningMatchesCurrentDeviceWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing thinningMatchesCurrentDeviceWithError");
		return YES;
	}
	return %orig;
}

- (BOOL)validateAppMetadataWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing validateAppMetadataWithError");
		return YES;
	}
	return %orig;
}

- (BOOL)validatePluginMetadataWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIBundle: bypassing validatePluginMetadataWithError");
		return YES;
	}
	return %orig;
}

%end

%hook MIInstallableBundle

-(BOOL)_validateApplicationIdentifierForNewBundleSigningInfo:(id)arg1 error:(id *)arg2
{
	if(Enabled) {
		LIDebug("MIInstallableBundle: bypassing _validateApplicationIdentifierForNewBundleSigningInfo");
		return YES;
	}
	return %orig;
}

-(BOOL)_verifyBundleMetadataWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIInstallableBundle: bypassing _verifyBundleMetadataWithError");
		return YES;
	}
	return %orig;
}

-(BOOL)_verifySubBundleMetadataWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIInstallableBundle: bypassing _verifySubBundleMetadataWithError");
		return YES;
	}
	return %orig;
}

-(BOOL)_isValidWatchKitApp:(id)arg1 withVersion:(id)arg2 installableSigningInfo:(id)arg3 error:(id *)arg4
{
	if(Enabled) {
		LIDebug("MIInstallableBundle: bypassing _isValidWatchKitApp");
		return YES;
	}
	return %orig;
}


%end


%hook MIExecutableBundle

- (BOOL)hasOnlyAllowedWatchKitAppInfoPlistKeysForWatchKitVersion:(id)arg1 error:(id*)arg2
{
	if(Enabled) {
		LIDebug("MIExecutableBundle: bypassing hasOnlyAllowedWatchKitAppInfoPlistKeysForWatchKitVersion");
		return YES;
	}
	return %orig;
}

%end


%hook MIPluginKitPluginBundle

- (BOOL)validateBundleMetadataWithError:(id*)error
{
	if(Enabled) {
		LIDebug("MIPluginKitPluginBundle: bypassing validateBundleMetadataWithError");
		return YES;
	}
	return %orig;
}

%end


%end

static void settingsChangedLowerInstall()
{
	@autoreleasepool {
		NSDictionary *LowerInstallPrefs = [[[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSDictionary dictionary] copy];
		Enabled = (BOOL)[[LowerInstallPrefs objectForKey:@"Enabled"]?:@YES boolValue];

		NSString* CurrentDeviceTypeSpoof = [LowerInstallPrefs objectForKey:@"SpoofDevice"]?:StringVal(kCurrentDeviceType);
		bzero(STORED_STRING[kSpoofDeviceType], MAX_STRING_LEN);
		memcpy(STORED_STRING[kSpoofDeviceType],(const void*)CurrentDeviceTypeSpoof.UTF8String, [CurrentDeviceTypeSpoof length]);

		NSString* CurrentiOSVersionSpoof = [LowerInstallPrefs objectForKey:@"SpoofVersion"]?:StringVal(kCurrentiOSVersion);
		bzero(STORED_STRING[kSpoofiOSVersion], MAX_STRING_LEN);
		memcpy(STORED_STRING[kSpoofiOSVersion],(const void*)CurrentiOSVersionSpoof.UTF8String, [CurrentiOSVersionSpoof length]);

		LINotice("settings reloaded: enabled=%d spoofDevice='%s' spoofVersion='%s'",
			Enabled, STORED_STRING[kSpoofDeviceType], STORED_STRING[kSpoofiOSVersion]);
	}
}

%ctor
{
	bzero(STORED_STRING[kUserAgent], MAX_STRING_LEN);
	strcpy(STORED_STRING[kUserAgent], "User-Agent");

	bzero(STORED_STRING[kUserAgentFormat], MAX_STRING_LEN);
	strcpy(STORED_STRING[kUserAgentFormat], "/%@ ");

	struct utsname systemInfo;
	uname(&systemInfo);
	bzero(STORED_STRING[kCurrentDeviceType], MAX_STRING_LEN);
	strcpy(STORED_STRING[kCurrentDeviceType], systemInfo.machine);

	bzero(STORED_STRING[kCurrentiOSVersion], MAX_STRING_LEN);
	strcpy(STORED_STRING[kCurrentiOSVersion], [NSString stringWithFormat:@"%@", [[UIDevice currentDevice] systemVersion]].UTF8String);

	LINotice("loading in process '%s' (device=%s, iOS=%s)", __progname, systemInfo.machine, STORED_STRING[kCurrentiOSVersion]);

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)settingsChangedLowerInstall, CFSTR("dev.playday3008.lowerinstall/SettingsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	settingsChangedLowerInstall();

	if(strcmp(__progname, "itunesstored") == 0 || strcmp(__progname, "appstored") == 0) {
		%init(itunesstoredHooks);
		LINotice("initialized itunesstoredHooks (store UA spoofing)");
	} else {
		%init(installdHooks);
		LINotice("initialized installdHooks (install validation bypasses)");
	}
}