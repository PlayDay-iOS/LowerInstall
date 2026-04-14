#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <notify.h>
#import <signal.h>
#import <stdlib.h>
#import <string.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <unistd.h>

#define PLIST_PATH "/var/mobile/Library/Preferences/dev.playday3008.lowerinstall.plist"

static BOOL LISystemVersionAtLeast(NSString *version) {
    return [[[UIDevice currentDevice] systemVersion] compare:version options:NSNumericSearch] != NSOrderedAscending;
}

@interface PSListController (Private)
- (UITableView *)table;
- (void)_returnKeyPressed:(id)arg1;
@end

static void LIKillProcessByName(const char *name) {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t size = 0;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0 || size == 0) return;

    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (!procs) return;
    if (sysctl(mib, 4, procs, &size, NULL, 0) != 0) { free(procs); return; }

    pid_t self_pid = getpid();
    size_t count = size / sizeof(struct kinfo_proc);
    for (size_t i = 0; i < count; i++) {
        pid_t pid = procs[i].kp_proc.p_pid;
        if (pid > 1 && pid != self_pid &&
            strcmp(procs[i].kp_proc.p_comm, name) == 0) {
            kill(pid, SIGTERM);
        }
    }
    free(procs);
}

static void LIRespring(void) {
    LIKillProcessByName("backboardd");
    LIKillProcessByName("SpringBoard");
}

@interface LowerInstallSettingsController : PSListController {
    UILabel *_label;
    UILabel *_underLabel;
}
- (void)HeaderCell;
- (void)increaseAlpha;
@end

@implementation LowerInstallSettingsController
- (void)HeaderCell {
    @autoreleasepool {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 120)];
        CGFloat width = [[UIScreen mainScreen] bounds].size.width;

        _label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, width, 60)];
        _label.numberOfLines = 1;
        _label.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:48];
        _label.text = @"LowerInstall";
        _label.backgroundColor = [UIColor clearColor];
        _label.textColor = [UIColor blackColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.alpha = 0;

        _underLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 55, width, 60)];
        _underLabel.numberOfLines = 1;
        _underLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:14];
        _underLabel.text = @"Install Apps In Lower iOS Version";
        _underLabel.backgroundColor = [UIColor clearColor];
        _underLabel.textColor = [UIColor grayColor];
        _underLabel.textAlignment = NSTextAlignmentCenter;
        _underLabel.alpha = 0;

        [headerView addSubview:_label];
        [headerView addSubview:_underLabel];

        [[self table] setTableHeaderView:headerView];
        [NSTimer scheduledTimerWithTimeInterval:0.5
                                         target:self
                                       selector:@selector(increaseAlpha)
                                       userInfo:nil
                                        repeats:NO];
    }
}

- (void)increaseAlpha {
    [UIView animateWithDuration:0.5 animations:^{
        self->_label.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5 animations:^{
            self->_underLabel.alpha = 1;
        } completion:nil];
    }];
}

- (id)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;

        // 1. master Enabled toggle
        spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSwitchCell
                                                edit:Nil];
        [spec setProperty:@"Enabled" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [specifiers addObject:spec];

        // 2. group: Hooks
        spec = [PSSpecifier preferenceSpecifierNamed:@"Hooks"
                                              target:self set:Nil get:Nil
                                              detail:Nil cell:PSGroupCell edit:Nil];
        [spec setProperty:@"Hooks" forKey:@"label"];
        [spec setProperty:@"Disable a subsystem to skip its method swizzles." forKey:@"footerText"];
        [specifiers addObject:spec];

        // 3. HooksInstalld
        spec = [PSSpecifier preferenceSpecifierNamed:@"Install-time bypasses"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil cell:PSSwitchCell edit:Nil];
        [spec setProperty:@"HooksInstalld" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [specifiers addObject:spec];

        // 4. HooksStore
        spec = [PSSpecifier preferenceSpecifierNamed:@"Store User-Agent spoofing"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil cell:PSSwitchCell edit:Nil];
        [spec setProperty:@"HooksStore" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [specifiers addObject:spec];

        // 5. group: Spoofed identity
        spec = [PSSpecifier preferenceSpecifierNamed:@"Spoofed identity"
                                              target:self set:Nil get:Nil
                                              detail:Nil cell:PSGroupCell edit:Nil];
        [spec setProperty:@"Spoofed identity" forKey:@"label"];
        [spec setProperty:@"Values sent to Apple's Store metadata servers. Empty = use current." forKey:@"footerText"];
        [specifiers addObject:spec];

        // runtime-read current values for defaults
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString *currentDevice  = [NSString stringWithFormat:@"%s", systemInfo.machine];
        NSString *currentVersion = [[UIDevice currentDevice] systemVersion];

        // 6. SpoofVersion
        spec = [PSSpecifier preferenceSpecifierNamed:@"iOS Version"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil cell:PSEditTextCell edit:Nil];
        [spec setProperty:@"SpoofVersion" forKey:@"key"];
        [spec setProperty:currentVersion forKey:@"placeholder"];
        [spec setProperty:@(UIKeyboardTypeNumbersAndPunctuation) forKey:@"keyboardType"];
        [spec setProperty:@(UITextAutocapitalizationTypeNone) forKey:@"autoCapsType"];
        [spec setProperty:@(UITextAutocorrectionTypeNo) forKey:@"autoCorrectionType"];
        [specifiers addObject:spec];

        // 7. SpoofDevice
        spec = [PSSpecifier preferenceSpecifierNamed:@"Device"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil cell:PSEditTextCell edit:Nil];
        [spec setProperty:@"SpoofDevice" forKey:@"key"];
        [spec setProperty:currentDevice forKey:@"placeholder"];
        [spec setProperty:@(UITextAutocapitalizationTypeNone) forKey:@"autoCapsType"];
        [spec setProperty:@(UITextAutocorrectionTypeNo) forKey:@"autoCorrectionType"];
        [specifiers addObject:spec];

        // 8. group: Reference links
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"Reference" forKey:@"label"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Device Codenames"
                                              target:self set:NULL get:NULL
                                              detail:Nil cell:PSLinkCell edit:Nil];
        spec->action = @selector(openModels);
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"iOS Firmware Versions"
                                              target:self set:NULL get:NULL
                                              detail:Nil cell:PSLinkCell edit:Nil];
        spec->action = @selector(openFirmware);
        [specifiers addObject:spec];

        // 9. empty group spacer
        [specifiers addObject:[PSSpecifier emptyGroupSpecifier]];

        // 9. Reset link
        spec = [PSSpecifier preferenceSpecifierNamed:@"Reset settings"
                                              target:self set:NULL get:NULL
                                              detail:Nil cell:PSLinkCell edit:Nil];
        spec->action = @selector(reset);
        [specifiers addObject:spec];

        // 10. footer
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"LowerInstall © julioverne 2022, PlayDay 2026" forKey:@"footerText"];
        [specifiers addObject:spec];

        _specifiers = [specifiers copy];
    }
    return _specifiers;
}
- (void)loadView {
    [super loadView];
    self.title = @"LowerInstall";
    UIColor *tint = [UIColor colorWithRed:0.09 green:0.99 blue:0.99 alpha:1.0];
    if (LISystemVersionAtLeast(@"9.0")) {
        [UISwitch appearanceWhenContainedInInstancesOfClasses:@[self.class]].onTintColor = tint;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = tint;
#pragma clang diagnostic pop
    }
    [self HeaderCell];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    @autoreleasepool {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@PLIST_PATH];
        return prefs[[specifier identifier]] ?: [specifier properties][@"default"];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @autoreleasepool {
        NSMutableDictionary *prefs =
            [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH]
                ?: [NSMutableDictionary dictionary];
        prefs[[specifier identifier]] = value;
        [prefs writeToFile:@PLIST_PATH atomically:YES];
        notify_post("dev.playday3008.lowerinstall/SettingsChanged");
        if ([[specifier properties] objectForKey:@"PromptRespring"]) {
            [self showPrompt];
        }
    }
}

- (void)showPrompt {
    if (LISystemVersionAtLeast(@"8.0")) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:self.title
                                                                   message:@"A respring is required for this option."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [ac addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            LIRespring();
        }]];
        [self presentViewController:ac animated:YES completion:nil];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title
                                                        message:@"A respring is required for this option."
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Respring", nil];
        alert.tag = 55;
        [alert show];
#pragma clang diagnostic pop
    }
}

- (void)reset {
    [@{} writeToFile:@PLIST_PATH atomically:YES];
    notify_post("dev.playday3008.lowerinstall/SettingsChanged");
    [self reloadSpecifiers];
    [self showPrompt];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 55 && buttonIndex == 1) {
        LIRespring();
    }
}
#pragma clang diagnostic pop

static void LIOpenURL(NSString *urlString) {
    NSURL *url = [NSURL URLWithString:urlString];
    if (LISystemVersionAtLeast(@"10.0")) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] openURL:url];
#pragma clang diagnostic pop
    }
}

- (void)openModels {
    LIOpenURL(@"https://theapplewiki.com/wiki/Models");
}

- (void)openFirmware {
    LIOpenURL(@"https://theapplewiki.com/wiki/Category:IOS_Firmware");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    for (PSSpecifier *spec in [self specifiers]) {
        NSString *placeholder = [spec propertyForKey:@"placeholder"];
        if (!placeholder) continue;
        UITableViewCell *cell = [self cachedCellForSpecifier:spec];
        if (cell && [cell respondsToSelector:@selector(textField)]) {
            ((UITextField *)[cell performSelector:@selector(textField)]).placeholder = placeholder;
        }
    }
}

- (void)_returnKeyPressed:(id)arg1 {
    [super _returnKeyPressed:arg1];
    [self.view endEditing:YES];
}
@end
