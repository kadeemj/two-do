# Privacy manifests

Each shipping target includes its own `PrivacyInfo.xcprivacy` in Copy Bundle Resources:

| Target | Source | Required-reason declarations |
| --- | --- | --- |
| TwoDo | `TwoDo/Resources/PrivacyInfo.xcprivacy` | UserDefaults: `CA92.1`, `1C8F.1` |
| TwoDoWidgets | `TwoDoWidgets/PrivacyInfo.xcprivacy` | UserDefaults: `1C8F.1` |

## Rationale

- `CA92.1`: app-only preferences in `DeviceCalendarService` and the sample-data seeding flag in `SampleData`.
- `1C8F.1`: `WidgetSnapshotStore` reads/writes task snapshots through `UserDefaults(suiteName:)` for `group.com.kadeem.twodo`. Both targets have that App Group entitlement. The widget does not directly use app-only defaults.
- Both targets declare tracking false, no tracking domains, and no collected data types. Task storage uses SwiftData and private CloudKit; calendar display uses on-device EventKit; widget snapshots stay in the App Group. No third-party SDK dependencies or direct advertising/analytics integrations were found in this source audit.
- No direct file-timestamp, disk-space, system-boot-time, or active-keyboard required-reason API usage was found in the shipping source. Task dates and the widget snapshot's `generatedAt` are model timestamps, not filesystem metadata APIs.
- Calendar and notification permissions are separate from required-reason APIs; they do not get invented categories in the manifest.

Reason definitions: [Apple's required-reason API reference](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Release verification

1. Run `plutil -lint` on both manifests and the Xcode project.
2. Archive the Release scheme and inspect the actual products, not only the source files:
   - `Products/Applications/TwoDo.app/PrivacyInfo.xcprivacy`
   - `Products/Applications/TwoDo.app/PlugIns/TwoDoWidgets.appex/PrivacyInfo.xcprivacy`
3. Compare each packaged plist with its source; confirm the app-only reason does not accidentally replace the widget's App Group reason.
4. For distribution, generate/review the signed archive's privacy report and complete App Store Connect validation. An unsigned local archive verifies packaging but is not a distributable build or an Apple acceptance result.

Re-audit when adding SDKs, networking, tracking, or required-reason API calls. These files do not populate App Store Connect's App Privacy answers; review those separately, including applicable optional-disclosure rules for support and Apple's beta services.
