# Switching the launcher icon

Mizan ships two marks. Choosing between them **inside the app** works today:
`Settings › Personalisation › App icon` writes to `logoVariantProvider`, and every
`MizanMark` in the app repaints immediately.

Changing the icon on the **phone's home screen** is a separate, platform-native
problem. The artwork for it is already generated and committed; the native wiring
is not. `launcherSwapSupported` in `lib/core/branding/mizan_brand.dart` is `false`
so the Settings screen says so plainly instead of offering a control that quietly
does nothing.

This document is what someone needs to finish that wiring.

## Why it was left out

Both halves of the swap are edits that break the app if they are slightly wrong,
in ways a static review cannot catch:

- A malformed `AndroidManifest.xml` means the app does not launch at all.
- `setComponentEnabledSetting(DISABLED)` on the component that is currently
  running **kills the process**. The enable and disable have to be ordered so the
  new alias is live before the old one goes away, and the failure mode is the app
  dying on the user mid-tap.
- iOS alternate icons have to be present in the built bundle. If they are not,
  `setAlternateIconName` fails at runtime rather than at build time.

None of that can be verified without a device, and there is no Flutter toolchain
in the environment these assets were generated in. Shipping the in-app half fully
working, with the native half documented and honestly disabled, is the safer
trade.

## What is already on disk

Regenerate any of it with `build_marks.py` then `export_icons.py`.

| Path | Contents |
| --- | --- |
| `assets/brand/{,2.0x/,3.0x/}mizan_icon_{navy,cream}.png` | In-app mark. Square and opaque — `MizanMark` rounds it with a `ClipRRect`. |
| `android/…/mipmap-<dpi>/ic_launcher.png` | Navy legacy icon, pre-rounded, transparent exterior. For API < 26. |
| `android/…/mipmap-<dpi>/ic_launcher_cream.png` | Cream legacy icon. |
| `android/…/mipmap-<dpi>/ic_launcher_foreground{,_cream}.png` | Adaptive foreground: glyph only on a 108dp canvas. |
| `android/…/mipmap-anydpi-v26/ic_launcher.xml` | Adaptive icon: `@color/ic_launcher_background` + navy foreground. |
| `android/…/mipmap-anydpi-v26/ic_launcher_cream.xml` | Adaptive icon, cream. |
| `android/…/values/mizan_colors.xml` | `ic_launcher_background` `#0F3B4C`, `ic_launcher_background_cream` `#FAF6EE`. |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | Navy, all 15 slots. Opaque, no alpha — the App Store rejects alpha. |
| `ios/Runner/AlternateIcons/AppIcon-Cream-*.png` | Cream, same 15 sizes, as **loose files**. Not yet in the Xcode project. |

Two details in there are deliberate and easy to undo by accident:

**The adaptive foreground carries no tile of its own.** The background layer *is*
the field colour, so a foreground that included its own rounded tile would show
that tile's corners inside the system mask. Its artwork is also fitted *radially*
— scaled until the furthest pixel sits on the 72dp mask circle — not fitted by
bounding box. The book is wide and low, so a box fit lets its bottom tips escape
a circular mask and get sheared off.

**The cream iOS icons are loose files, not an asset catalog entry.** That is the
form `CFBundleAlternateIcons` wants. It also means they are inert: nothing
references them, so they cannot break the build before the wiring below is done.

## Android

### 1. Declare an alias per alternate icon

In `android/app/src/main/AndroidManifest.xml`, the `<activity>` keeps the
`LAUNCHER` intent filter and becomes the *default* icon. Each alternate is an
`<activity-alias>` pointing at the same activity, with its own icon and its own
`LAUNCHER` filter, disabled at install time:

```xml
<activity-alias
    android:name=".MainActivityCream"
    android:targetActivity=".MainActivity"
    android:enabled="false"
    android:exported="true"
    android:icon="@mipmap/ic_launcher_cream"
    android:label="Mizan">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity-alias>
```

Exactly one of the activity and its aliases may be enabled at a time. Two enabled
means two launcher entries; zero means the app disappears from the launcher, which
is unrecoverable without a reinstall.

Because the alias name is baked into the manifest, keep it derived from
`MizanLogoVariant.id` rather than spelled independently, or the two drift.

### 2. Toggle from Dart over a platform channel

There is no Flutter plugin worth taking a dependency on for this. A method channel
in `MainActivity.kt` is about twenty lines:

```kotlin
private fun setIcon(enable: String, disableAll: List<String>) {
    val pm = packageManager
    // Enable the target FIRST. Disabling the running component kills the process,
    // so if the order is reversed the app dies before the new alias is live.
    pm.setComponentEnabledSetting(
        ComponentName(this, enable),
        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
        PackageManager.DONT_KILL_APP,
    )
    for (name in disableAll) {
        if (name == enable) continue
        pm.setComponentEnabledSetting(
            ComponentName(this, name),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
```

`DONT_KILL_APP` is required on both calls. It is a request, not a guarantee: some
launchers still restart the task, and the icon may not refresh until the launcher
does. Expect to test on more than one launcher.

## iOS

### 1. Get the alternates into the bundle

Add `ios/Runner/AlternateIcons/` to the Runner target's **Copy Bundle Resources**
phase. They must be loose resources at the bundle root, not inside an asset
catalog — `setAlternateIconName` resolves them by filename.

### 2. Declare them in `Info.plist`

```xml
<key>CFBundleIcons</key>
<dict>
    <key>CFBundleAlternateIcons</key>
    <dict>
        <key>AppIcon-Cream</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>AppIcon-Cream-60x60</string>
                <string>AppIcon-Cream-76x76</string>
            </array>
            <key>UIPrerenderedIconFlag</key>
            <false/>
        </dict>
    </dict>
    <key>CFBundlePrimaryIcon</key>
    <dict>
        <key>CFBundleIconFiles</key>
        <array><string>AppIcon</string></array>
    </dict>
</dict>
```

`CFBundleIconFiles` lists **base names without the `@2x`/`@3x` suffix or the
extension**; iOS picks the density itself. The generated filenames follow
`AppIcon-Cream-60x60@2x.png`, so the base name is `AppIcon-Cream-60x60`. Rename on
copy if you prefer plainer names — just keep the plist and the files in agreement.

### 3. Call it

```dart
// Guard on supportsAlternateIcons; it is false on iPad in some configurations.
await const MethodChannel('mizan/icon').invokeMethod('setAlternateIcon', name);
```

Swift side: `UIApplication.shared.setAlternateIconName(name)`, with `nil` for the
primary icon.

**iOS shows a system alert every single time the icon changes**, and it is not
suppressible. Which means the Settings control should not change the launcher icon
as a side effect of changing the in-app mark — that alert on every tap while a
user browses the two options is unacceptable. Separate the two: let the in-app
mark change freely, and put the launcher swap behind its own explicit action.

## After wiring it

1. Set `launcherSwapSupported = true` in `lib/core/branding/mizan_brand.dart`.
2. `LogoVariantController.set` becomes the place to call the channel — keep the
   in-app state change unconditional and the native call best-effort, so a
   platform failure never leaves the stored preference and the UI disagreeing.
3. Test: cold start on each variant, swap while backgrounded, swap twice quickly,
   and confirm the app still appears in the launcher after each.

## Unrelated but blocking release

`android/app/build.gradle.kts` still has `applicationId = "com.example.ummahapp"`
and a matching `namespace`. Google Play rejects any `com.example.*` ID. Changing it
is not a rename-and-go: it changes the app's identity, so existing installs are
treated as a different app, and it has to be updated anywhere the package name is
registered — OAuth redirect URIs and push credentials in particular. Worth doing
early, while the install base is only you.
