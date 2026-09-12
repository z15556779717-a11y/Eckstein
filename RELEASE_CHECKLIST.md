# Eckstein — Release Checklist

Short by design. This covers the step from "the app builds and its tests pass in
CI" to "a signed build runs on a real iPhone and can be uploaded to TestFlight".
It is written for the state of `develop/my-fitness-app` at the Phase 6 change set.

Everything in section 1 is verified in the repository. Everything in section 2
needs an Apple account, a Mac, or both, and cannot be done from this Windows
machine.

## 1. Verified in the repository

| Item | State |
| --- | --- |
| App name | `Eckstein` (`PRODUCT_NAME = $(TARGET_NAME)`, target `Eckstein`) |
| Version / build | `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1` |
| Bundle ID | `com.z15556779717.eckstein` — no longer the upstream author's; see §2 |
| Signing team | `DEVELOPMENT_TEAM` is empty; see §2 |
| Deployment target | iOS 18.4 |
| Device families | `1,2,7` (iPhone, iPad, and the vision platform the project also declares) |
| App icon | All 11 slots present with real artwork, from the initial commit |
| Accent colour | `AccentColor.colorset` is empty (system default is used) |
| Privacy strings | Camera (added), Bluetooth, Health read, Health write — all specific about what the app does with the data |
| HealthKit entitlement | `com.apple.developer.healthkit` and `.background-delivery` present |
| App Transport Security | No `NSAllowsArbitraryLoads` and no other exception |
| Secrets in tracked tree | None; the AI provider key is not in the app bundle |
| AI path | App → Supabase Edge Function (`supabase/functions/ai-coach`) → provider |
| Debug tests | 299 executed, 2 skipped, 0 failures (CI run 34606797400) |
| Release compile check | `.github/workflows/ios-release-check.yml` builds Release with no signing |
| Working tree | Clean; no helper scripts or dumps |

## 2. Prerequisites only you can complete

Blocking, in order:

1. **Apple Developer Program membership.** Nothing below works without it.
2. **The bundle ID is now `com.z15556779717.eckstein`.** It used to be
   `com.eliosdigital.Eckstein`, the upstream author's reverse-DNS namespace.
   Keep it stable from here: the bundle ID is the App Store identity and cannot
   be changed after release. If you change it again, note that
   `EcksteinTests` and `EcksteinUITests` still carry the old prefix — they are
   separate targets and do not affect the app's identity.
3. **Set `DEVELOPMENT_TEAM`** to your Team ID. It is deliberately blank rather
   than set to the upstream author's team, which your account cannot sign with.
4. **Create the App ID** for the chosen bundle ID and enable the **HealthKit**
   capability on it. The entitlement file already asks for it, so a mismatch
   between the two fails provisioning rather than the build.
5. **Signing certificate and provisioning profile** (Xcode's automatic signing
   is enough for a device build and for TestFlight).
6. **App Store Connect app record** for the bundle ID.
7. **Rotate the leaked Supabase `service_role` key.** It was committed in the
   initial commit `beddcff` and therefore still lives in the git history even
   though the current tree is clean. Rotate it in the Supabase dashboard; do not
   restore it into the repository.
8. **Apply the migration** `supabase/migrations/20260910120000_nutrition_fields.sql`
   to the production database.
9. **Deploy the Edge Function** `supabase/functions/ai-coach`. The code is
   committed and the app calls it, but deployment is a server-side action that
   has not been performed or verified from here — the AI coach will fail until
   it is deployed.
10. **Fill in the App Store Connect privacy form** against the inventory in §3.
    That form is a legal declaration and only you can make it.

## 3. Data the app handles

Confirm each line against your actual backend before submitting:

- Health and fitness data, read from and written to Apple Health (weight, body
  fat, lean body mass, step count)
- Body weight and weigh-in history
- Nutrition: foods, meals, calories and macros
- Workout: sessions, exercises, sets, volume
- Account identifier (sign-in)
- AI coach chat content, which leaves the device and passes through the Edge
  Function to the AI provider

## 4. Building for a real device

There is no Xcode on the development machine (Windows), so a device or
TestFlight build **cannot** be produced locally. Two routes:

- **GitHub Actions macOS runner** — what this repository already uses for build
  and test verification. An Archive/upload job can be added here once the
  signing secrets in §6 exist.
- **A real Mac with Xcode** — open `Eckstein/Eckstein.xcodeproj`, select your
  team, and use Product → Archive.

## 5. Recommended TestFlight route

1. Join the Apple Developer Program.
2. Settle the bundle ID (§2.2) and set your team (§2.3).
3. Create the App ID with HealthKit enabled.
4. Create the App Store Connect app record.
5. Configure signing in Xcode.
6. Add the signing secrets to GitHub (§6).
7. Archive the app (locally, or in a new CI job).
8. Upload the build to TestFlight.
9. Install it from TestFlight on an iPhone and walk the main screens.
10. Only then consider App Store submission.

## 6. Secret names for a future TestFlight CI job

Names only. No values are stored in this repository, and none should be
committed.

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`

Do not enable an automatic upload until these exist; a pipeline that pretends to
sign is worse than no pipeline.
