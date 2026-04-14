# LowerInstall

Install apps that require a newer iOS version on older iOS. Bypasses
`MobileInstallation` device/iOS validation and spoofs the App Store's
outgoing User-Agent so metadata servers return IPAs for a spoofed OS.

## The problem

Two independent checks reject newer-iOS apps on older iOS:

- **Install-time.** `installd` validates the IPA's `Info.plist` against the
  running device and OS (family, thinning, `MinimumOSVersion`, metadata). A
  mismatch returns an error before the app is copied to `/var/containers`.
- **Store delivery.** The App Store client (`itunesstored` on iOS 9,
  `appstored` on iOS 10+) advertises its running OS/device in the
  `User-Agent` header. Apple's metadata servers use this to pick which
  IPA variant to return; newer apps simply aren't served to older UAs.

## The fix

**A. `installd` bypasses.** Hook `MIBundle`, `MIInstallableBundle`,
`MIExecutableBundle`, `MIPluginKitPluginBundle`, `MIDaemonConfiguration` to
force device-family / thinning / metadata validation to report success. The
`-supportedDevices` hook injects the running device into the supported list
rather than spoofing — the goal is "treat this device as supported", not
"pretend to be a different device".

**B. Store User-Agent rewrite.** Hook
`-[NSMutableURLRequest setValue:forHTTPHeaderField:]`. When the field is
`User-Agent` and the current OS version is literally present in the value,
rewrite the device / version tokens in the UA to the spoofed values. No
rewrite happens when spoof values equal current values (the default), so
the hook is cheap and idempotent on unaffected requests.

Both subsystems are individually toggleable in the settings pane.

## Building

The project uses [Theos](https://theos.dev) and builds inside a container
so no local iOS toolchain is required.

### Docker

```sh
# One-step build
docker compose up --build

# Or manually
docker build -t lowerinstall-build -f Containerfile .
docker run --rm -v "$PWD:/build:Z" lowerinstall-build
```

### Podman

```sh
# One-step build
podman-compose up --build

# Or manually
podman build -t lowerinstall-build -f Containerfile .
podman run --rm -v "$PWD:/build:Z" lowerinstall-build
```

The `.deb` is written to `packages/`.

### Local

Install [Theos](https://theos.dev) (includes toolchain and SDK):

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
```

Install the iPhoneOS 12.4 SDK:

```sh
$THEOS/bin/install-sdk iPhoneOS12.4
```

Then build:

```sh
make package FINALPACKAGE=1
```

## Installation

```sh
scp packages/*.deb root@<device>:/tmp/
ssh root@<device> 'dpkg -i /tmp/dev.playday3008.lowerinstall_*.deb'
```

The `postinst` kills `installd`, `itunesstored`, and `appstored` so
launchd respawns them under Substrate. No respring or reboot needed.

## Settings

Settings pane: **Settings → LowerInstall**.

| Toggle                            | Default | Notes |
|-----------------------------------|---------|-------|
| Enabled                           | on      | master toggle |
| Install-time bypasses             | on      | controls the `installd` hook group |
| Store User-Agent spoofing         | on      | controls the `NSMutableURLRequest` hook |
| iOS Version (spoofed)             | current | empty falls back to current |
| Device (spoofed)                  | current | e.g. `iPhone11,8` |
| Reset settings                    | —       | clears all preferences, prompts respring |

Changes are applied immediately via Darwin notification — no respring
required for toggle changes; the reset button prompts one because reading
an empty state at hook time is indistinguishable from "defaults".

## How it works

### Injection targets (Substrate filter)

- `installd` — the MobileInstallation daemon.
- `itunesstored` — iTunes Store / App Store metadata client on iOS 9.
- `appstored` — App Store metadata client on iOS 10+.

### Install-time hooks

| Class                     | Method                                                          | Override |
|---------------------------|-----------------------------------------------------------------|----------|
| `MIDaemonConfiguration`   | `-skipDeviceFamilyCheck`, `-skipThinningCheck`                  | `return YES` |
| `MIBundle`                | `-minimumOSVersion`                                             | `return @"2.0"` |
| `MIBundle`                | `-supportedDevices`                                             | append current device if missing |
| `MIBundle`                | `-isCompatibleWithDeviceFamily:` and six similar `is*/validate*` methods | `return YES` |
| `MIInstallableBundle`     | four `_validate*` / `_verify*` methods                          | `return YES` |
| `MIExecutableBundle`      | `-hasOnlyAllowedWatchKitAppInfoPlistKeysForWatchKitVersion:error:` | `return YES` |
| `MIPluginKitPluginBundle` | `-validateBundleMetadataWithError:`                             | `return YES` |

### Store hook

`-[NSMutableURLRequest setValue:forHTTPHeaderField:]` — when the field is
`User-Agent` and the value contains the current iOS version, two sequential
`stringByReplacingOccurrencesOfString:` passes rewrite `/<version> ` and
`/<device> ` tokens to the spoofed pair.

### Activation

`postinst` and `/etc/rc.d/lowerinstall` both `killall -9` the three tweaked
daemons. launchd respawns them, Substrate injects the dylib, hooks take
effect. No respring or reboot needed.

## Prior art

This approach originated in julioverne's
[LowerInstall](https://github.com/julioverne/LowerInstall). The current
repo is a clean-room-in-spirit rewrite: same method list, same Darwin
notification name, same User-Agent rewrite algorithm — but the source is
fresh, restructured around the `wifi-fix-old-iOS` project template, and
adds per-subsystem toggles. No code is copied verbatim.

## License

MIT © 2026 PlayDay. See `LICENSE`.
