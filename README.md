# Habits

A habit tracker for iPod touch 4 in the Loop mould: yes/no, count and measure habits, weekday schedules, a strength score that forgives a miss, 12-week heatmaps, local reminders, a Pomodoro tomato that ripens, and Claude to turn a goal and recent progress into a practical plan and weekly review.

## Claude integration (2.0)

In **Settings → Habits → AI Coach**, choose Claude, enter an Anthropic API key in the masked field, and optionally set a model ID. The default is `claude-sonnet-5-5`. The older OpenRelay provider and its key remain separate. Nothing reads credentials from another app; keys are never bundled in a build. Legacy iOS requires TLSFix and trusted roots, with certificate verification enabled. Requests go directly to the selected provider over Wi-Fi.

**Habits → Generate** generates small actions from your goal, constraints and completion history. **Review → Coach** lets you inspect the progress summary, ask a question, or discuss it in Claude. Weekly notes use the same context.

Every generated plan opens a review screen. Keep the suggestions you want and tap **Add** to save them; existing plans stay. **Discuss in Claude** opens an editable draft in Claude 3.1 or newer. **Use Draft** puts it in a new chat; **Send** is a separate action. Neither handoff nor coaching changes logs.

Only an explicit Ask/Generate uploads the goal and bounded progress summary. Handoff stays on-device until Send in Claude. Keys live in device preferences, so protect device backups. Claude API billing is separate from a Claude subscription.

## Layout

`src/HBStore` holds habits, the log and every statistic. `HBViews` has the chart, heatmap, drum and check circles. `HBFocusViewController` is the tomato. `HBAI` does the goal-to-habits JSON and the weekly note.

## Building

Targets iOS 4.3 on armv7 from a modern Mac with only the Command Line Tools installed. No Xcode.

1. Get the iPhoneOS 4.3 SDK from [EachAndOther/Legacy-iOS-SDKs](https://github.com/EachAndOther/Legacy-iOS-SDKs) into `~/ios4sdk/iPhoneOS4.3.sdk`.
2. The modern linker refuses the old dylibs, so convert them to text stubs once: run `tapi stubify` from the Command Line Tools over the SDK's frameworks and retarget the `-darwin` platform strings to `-ios`.
3. `./build.sh` compiles with `clang -target armv7-apple-ios4.3 -fobjc-runtime=ios-4.3 -fno-objc-arc -marm`, pseudo-signs with `ldid -S`, and zips an IPA into `build/`. ARM mode matters: modern ld drops the Thumb bit on Objective-C method pointers for this target and the app crashes at launch without it.
4. Install on a jailbroken device with AppSync: `ideviceinstaller install build/<App>.ipa`.

Everything is hand-written Foundation and UIKit from 2011. The JSON parser is in `src/ORJSON.m` because iOS 4 has no NSJSONSerialization.

## Verification

`./tests/build.sh` runs host transport, cancellation, credential separation, URL handoff and plan-validation tests. `./tests/device-build.sh` builds an isolated audit app for native view loading/unloading and active-request teardown. It never uses a real key. `AUDIT_MAIN=tests/live.m ./tests/device-build.sh` instead builds an opt-in live test using synthetic goals; it requires an API key in the audit app’s own preferences and incurs API usage. See [the state and memory audit](docs/STATE_AND_MEMORY.md).

## License

MIT for the code. Third-party marks and data belong to their owners.
