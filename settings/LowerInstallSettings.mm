#pragma clang diagnostic ignored "-Wdeprecated-declarations"

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

@interface PSListController (Private)
- (UITableView *)table;
- (void)_returnKeyPressed:(id)arg1;
@end

@interface LowerInstallSettingsController : PSListController
@end

@implementation LowerInstallSettingsController
- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [[NSMutableArray array] copy];
    }
    return _specifiers;
}
- (void)loadView {
    [super loadView];
    self.title = @"LowerInstall";
}
@end
