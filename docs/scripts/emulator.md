# Android Emulator — CLI Usage

The `emulator` binary ships with the Android SDK at `~/Library/Android/sdk/emulator/emulator`.

---

## List available AVDs

```bash
emulator -list-avds
```

## Start an AVD

```bash
# With GUI
emulator -avd Pixel_8_API_34

# Headless (no window, no audio) — useful for experiments
emulator -avd Pixel_8_API_34 -no-window -no-audio
```

## Set ADB_SERIAL for a running emulator

Emulators always get a serial in the form `emulator-<port>`.

```bash
# Find the serial
adb devices

# Target it
export ADB_SERIAL=emulator-5554
```

## Stop the emulator

```bash
# Graceful shutdown
adb -s emulator-5554 emu kill

# Or if ADB_SERIAL is already set
adb_cmd emu kill
```

## Typical experiment flow

```bash
emulator -avd Pixel_8_API_34 -no-window -no-audio &

# Wait for boot
until [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '[:space:]')" == "1" ]]; do
    sleep 5
done

export ADB_SERIAL=emulator-5554

./experiments/my_experiment.sh

adb_cmd emu kill
```
