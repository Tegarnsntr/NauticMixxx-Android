# NauticMixxx on Android

NauticMixxx is built as an Android overlay on Mixxx 2.5.6. The supported build
host is Ubuntu 24.04, following the [Mixxx Android guide](https://github.com/mixxxdj/mixxx/wiki/Building-for-Android).

From this repository:

```sh
sh scripts/build-mixxx-rx3-android.sh
```

On macOS ARM64 or other unsupported hosts, push the branch and run the
**NauticMixxx Android APK** workflow from GitHub Actions. It uses Ubuntu 24.04
and uploads the signed APK as the `NauticMixxx-Android` workflow artifact.

The script verifies the Mixxx source archive, applies every NauticMixxx patch,
uses Mixxx's `tools/android_buildenv.sh` dependency setup, and builds the
`apk` target. Set `RX3_ANDROID_BUILD_ROOT` to move the cache or
`RX3_ANDROID_SKIP_SETUP=1` when the Android dependency environment is already
present. The signed APK is written below
`build/android-2.0.0/build/android-build/build/outputs/apk/release/`.

## DDJ-FLX4 and USB

The included `Pioneer DDJ-FLX4 - NauticMixxx RX3 browser` mapping is packaged
with the Android build. Connect the FLX4 with a USB-OTG adapter or powered hub,
grant the Android USB-device permission when prompted, then select the FLX4
MIDI input/output in Preferences → Controllers. The mapping remains editable
in Mixxx's controller preferences; its XML and JavaScript are under
`controllers/Pioneer_DDJ_FLX4_RX3/`.

Android USB permission is per device attachment. Reconnect the controller after
installing an APK or revoking permission. USB MIDI/controller access and
reading a rekordbox-exported storage device are separate: Android may expose a
storage device through the system file picker, while Mixxx still needs access to
the exported `PIONEER` catalog and audio paths. Test both the controller and the
rekordbox USB on the target phone before live use.

The build proves packaging and compilation; physical FLX4 jog, audio-output,
USB-OTG power, and Android device testing are still required for a release
claim.
