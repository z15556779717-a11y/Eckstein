# Eckstein Repository Audit

Phase-1 audit of the Eckstein iOS fitness app, performed before any secondary
development. Every finding below is based on the actual Swift sources, the Core
Data model file, the Xcode project file, and the bundled SQL schema — not on the
README.

- **Audited revision:** `beddcff` ("Initial commit - Clean repository for GitHub")
- **Branch:** `develop/my-fitness-app` → `origin` (fork) / `upstream` (`Zie619/Eckstein`)
- **Audit date:** 2026-09-10
- **Scope:** repository structure, features, data model, integrations, security, build/CI readiness

> **No secret values appear in this document.** Findings reference a type, file,
> and line only. Where a credential is discussed it is named, never reproduced.

---

## Architecture

SwiftUI app using MVVM with a coordinator-style tab router and a service container.

- **Entry point** — `Eckstein/Eckstein/App/EcksteinApp.swift`
  - Root view is `AuthenticationView`, not `ContentView`; `ContentView` is shown
    only once `AuthService.isAuthenticated` is true.
  - Injects `PersistenceController.shared.container.viewContext`, the theme,
    localization, and `ServiceContainer`.
- **Routing** — `App/AppCoordinator.swift` defines a 5-case `Tab` enum
  (`workout`, `diet`, `weight`, `ai`, `profile`), defaulting to `.workout`, plus a
  `handleDeepLink` path.
- **Tab bar** — `ContentView.swift:23-71` renders `WorkoutTabView`, `DietTabView`,
  `WeightTabView`, `AICoachTabView`, `ProfileView`, and always embeds `SyncStatusView`.
- **Feature layout** — `Features/<Feature>/{Views,ViewModels,Services}`; shared
  code in `Core/{Services,Models,Database,Utilities,Theme}`.
- **DI** — `Core/Services/ServiceContainer.swift` holds repository singletons
  built on `PersistenceController.shared`.

The layering is broadly consistent, but there is no module boundary: every feature
reaches into `Core` and into the shared Core Data context directly.

---

## Project Structure

```
Eckstein/
├── .github/workflows/ios.yml          # added in phase 1
├── .gitignore
├── .mcp.json                          # MCP config (see Security Findings)
├── FINAL_VERSION_APP_DB.sql           # Supabase schema, 593 lines
├── README.md
├── fix_xcode_clean.sh
├── supabase/config.toml
└── Eckstein/
    ├── Eckstein.xcodeproj/            # project only — NO .xcworkspace
    ├── Eckstein/                      # app target (file-system-synchronized group)
    │   ├── App/, Configuration/, ContentView.swift
    │   ├── Core/{Components,Data,Database,Extensions,Models,Services,Theme,Utilities,ViewModifiers,Views}
    │   ├── Features/{AI,Auth,Diet,Profile,Sync,Weight,Workout}
    │   ├── Resources/{en,he}.lproj/   # 7 .strings files each
    │   ├── Eckstein.xcdatamodeld/
    │   ├── Info.plist, Eckstein.entitlements
    │   └── Assets.xcassets/
    ├── EcksteinTests/                 # 7 unit test files
    └── EcksteinUITests/               # 2 template UI test files
```

**Scale:** 216 Swift files, 259 files total in the working tree, 266 tracked by git.

Key project facts (`Eckstein.xcodeproj/project.pbxproj`):

| Setting | Value |
|---|---|
| Targets | `Eckstein` (app), `EcksteinTests` (unit), `EcksteinUITests` (UI) |
| `objectVersion` / `LastUpgradeCheck` | 77 / 1630 (Xcode 16.3+) |
| File organization | `PBXFileSystemSynchronizedRootGroup` (Xcode 16 folder sync) |
| `IPHONEOS_DEPLOYMENT_TARGET` | 18.4 (all targets) |
| `MACOSX_DEPLOYMENT_TARGET` / `XROS_DEPLOYMENT_TARGET` | 15.4 / 2.4 |
| `SUPPORTED_PLATFORMS` | `iphoneos iphonesimulator macosx xros xrsimulator` |
| `SDKROOT` | `auto` (multi-platform target) |
| `TARGETED_DEVICE_FAMILY` | `1,2,7` (iPhone, iPad, visionOS) |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.eliosdigital.Eckstein` |
| `DEVELOPMENT_TEAM` | `Z24WA5CL56` (original author's team — see Security Findings) |
| Swift language version | 5.0 (no strict-concurrency setting) |
| Shared schemes | **one checked in**: `xcshareddata/xcschemes/Eckstein.xcscheme` (added in phase 1) |

---

## Existing Features

### Dashboard

There is no single "Dashboard" screen; each tab carries its own summary surface.

- `WorkoutTabView` → `WorkoutListView` shows weekly count, current streak, total
  workouts, an active-workout card, quick actions, and a history link.
- `WeightTabView` → `WeightDashboardView` shows the current weight card,
  `StepsCounterCard`, goal progress, statistics, and insights.
- `DietTabView` → `EcksteinDietView` (see Nutrition).
- A leftover `syncBadgeForTab` in `ContentView.swift:81-87` always returns `nil`.

### Workout

**Functional and the most complete feature.**

- Model: `CDWorkout` (name, date, `durationMinutes`, notes, `completed`,
  `syncStatus`) → `CDWorkoutSet` (weight, reps, `targetReps`, `setNumber`,
  completed) with `CDExercise` as the shared exercise library.
- `CDWorkout+Extensions.swift:13-22` provides `setsArray` (sorted by set number)
  and `totalVolume` (`Σ reps × weightKg`), plus `completionPercentage` and
  `isCompleted` (≥90 % threshold).
- `Core/Services/WorkoutRepository.swift` — workout and exercise CRUD plus
  `fetchAllExercises()` / `fetchRecentExercises(limit:)`.
- `Core/Services/WorkoutTypeManager.swift` — workout *templates*
  (`CDWorkoutType` / `CDWorkoutTypeExercise`) with `createWorkoutFromType(_:)`
  pre-filling sets and carrying over the last used weight.
- `Features/Workout/Views/WorkoutDetailView.swift` — live session: add/remove
  exercise, add/update/delete set, drag-reorder, rest timer, finish.
- `Features/Workout/Views/AnalyticsView.swift:228` — progress charts including
  per-day max weight, total volume, and rep-achievement percentage.

### Nutrition

**Implemented, but the shipped tab uses a different subsystem than the one with macros.**

Two parallel, non-interoperating diet stacks exist:

- **System A — calorie/macro log (largely unreachable).** Entities `CDFood`
  (per-100 g calories/protein/carbs/fat/fiber, barcode, serving), `CDMeal`,
  `CDMealItem`. Driven by `DietRepository`, `DietViewModel`, `FoodSearchViewModel`,
  `BarcodeViewModel`, `ServingSizeCalculator`, `NutritionCalculator`, seeded from
  `Core/Data/FoodData.swift` (~34 hardcoded foods). Its views
  (`DietDashboardView`, `AddFoodView`, `FoodSearchView`, `MealHistoryView`,
  `WeeklyAnalyticsView`, `MacroBreakdownView`, `QuickAddView`, `DailyGoalsView`)
  are **not referenced from any active tab**.
- **System B — "Eckstein method" (what the UI actually renders).** Entities
  `CDEcksteinFood`, `CDEcksteinMeal`, `CDEcksteinMealEntry`. `CDEcksteinFood`
  stores only `name`, `category`, `dailyGrams`, `isFat` — **no calorie or macro
  fields at all**. The active `DietTabView` renders `EcksteinDietView`
  (`DietTabView.swift:24`), backed by `EcksteinDietViewModel` and `DietRule`.
  Tracking is therefore **gram-based against daily gram targets**, plus carb-load
  days and a weekly fat-meal cap — not calories/protein/carbs/fat.
- Supporting managers, all real: `CalorieBankManager` (150 kcal/day + 1500 kcal
  bank, persisted to `CDCalorieBank`), `CarbLoadManager`, `FatMealManager`,
  `MilkBankManager`, `CustomFoodManager`.
- Barcode scanning (`BarcodeScannerView` — real `AVCaptureSession` +
  `AVCaptureMetadataOutput`) and Open Food Facts lookup (`FoodAPIService`) are
  real implementations, but are only wired into the legacy System A views, so
  they are **unreachable from the shipped Diet tab**.

> **Implication for the roadmap:** the "Calories / Protein / Carbs / Fat" goal in
> phase 2 requires promoting System A (or adding macro fields to System B), not
> building from scratch. `CDEcksteinFood` currently cannot express macros.

### Weight Tracking

**Functional.** `Core/Services/WeightRepository.swift` implements entry CRUD,
goal weight/date, weekly/monthly averages and change, linear-regression trend,
progress-to-goal, BMI (`weightKg / (heightCm/100)²`, height from
`UserDefaults "userHeightCm"`), BMI category, best-weigh-in-time, and CSV/JSON
export. `WeightViewModel` drives manual entry (`WeightEntryViewModel`, validated
20–300 kg), charts, statistics, and HealthKit export.

**Xiaomi scale:** real BLE plumbing (`BluetoothManager` is a genuine
`CBCentralManager` wrapper with connect timeouts, service/characteristic
discovery, and delegate callbacks; `XiaomiScaleService` subscribes to
notifications across several candidate services). However, the **payload parsing
is speculative** — `XiaomiScaleData.parse` (`XiaomiScaleData.swift:83-201`) tries
several byte-layout guesses and accepts any value in 10–300 kg, and the
measurement trigger writes a rotating list of guessed command bytes
(`XiaomiScaleService.swift:743-762`). Treat this as unverified against real
hardware.

### Progress / Analytics

`AnalyticsView` (workout), `WeightAnalyticsView` / `WeightChartView` (weight) and
`EcksteinDietAnalyticsView` (diet) render Swift Charts over Core Data. There is no
unified cross-domain progress view.

### Settings / Profile

`Features/Profile/Views/ProfileView.swift` composed from section components
(account, appearance, diet progress, language, meeting, settings, user info,
weight goal). `Features/Weight/Views/WeightSettingsView.swift` holds units,
height, and the HealthKit toggle.

### Other

`AchievementManager` + achievement views, `NotificationService`,
`TipManager`, `ConfettiView`, `ThemeManager`, and `LocalizationManager`
(English + Hebrew `.lproj` resources).

---

## Core Data

Model: `Eckstein.xcdatamodeld/Eckstein.xcdatamodel/contents` — a **single model
version**, `usedWithCloudKit="YES"`, every entity `syncable="YES"`. No mapping
models, no `.xcmappingmodel`.

### Entities

| Entity | Purpose | Key attributes |
|---|---|---|
| `CDUser` | Root aggregate | `id`, `email`, `fullName`, `gender`, `syncStatus`, `lastSyncedAt` |
| `CDUserPreferences` | Goals / display | `dailyCalorieGoal`, `dailyProteinGoal`, `dailyCarbGoal`, `heightCm`, `startingWeight`, `weightUnit`, `preferredTheme`, `preferredAccentColor` |
| `CDWorkout` | **WorkoutSession** | `name`, `date`, `durationMinutes`, `completed`, `notes`, `syncStatus` |
| `CDWorkoutSet` | **Set** | `setNumber`, `weightKg`, `reps`, `targetReps`, `completed`, `notes` |
| `CDExercise` | **Exercise** | `name`, `category`, `muscleGroup`, `equipment`, `isCustom`, `youtubeLink`, `imageData`, `createdAt` |
| `CDWorkoutType` / `CDWorkoutTypeExercise` | Templates | `targetSets`, `targetReps`, `orderIndex` |
| `CDFood` | Food (macros) | `caloriesPer100g`, `proteinPer100g`, `carbsPer100g`, `fatPer100g`, `fiberPer100g`, `barcode`, `servingSize` |
| `CDMeal` / `CDMealItem` | Meal log (macros) | `mealType`, `date`, `quantityGrams` |
| `CDEcksteinFood` | Eckstein food | `name`, `category`, `dailyGrams`, `isFat`, `isCustom` — **no macros** |
| `CDEcksteinMeal` / `CDEcksteinMealEntry` | Eckstein meal | `mealNumber`, `isCarbLoad`, `foodName`, `gramsConsumed` |
| `CDWeightEntry` | **WeightEntry** | `weightKg`, `date`, `source`, `bodyFatPercentage`, `muscleMass`, `notes`, `photoPath`, `syncStatus` |
| `CDCalorieBank`, `CDFatMealTracker`, `CDCarbLoadTracker`, `CDMilkConsumption` | Diet rule trackers | `caloriesSaved`, `fatMealsConsumed`, `carbLoadDate`, `amount`, `weekStartDate`, `remoteId` |
| `CDChatMessage` | AI chat history | `content`, `isUser`, `timestamp` |

### Mapping to the roadmap vocabulary

The requested model names largely exist under different names — **no rename or
restructure is required**:

- `WorkoutSession` → **`CDWorkout`**
- `Exercises` → **`CDExercise`** (shared library, joined via `CDWorkoutSet.exercise`)
- `Sets` → **`CDWorkoutSet`**
- `FoodEntry` → **`CDEcksteinMealEntry`** (active) or `CDMealItem` (legacy, has macros)
- `WeightEntry` → **`CDWeightEntry`**
- `UserProfile` → **`CDUser`** + **`CDUserPreferences`**

The `CDWorkout → CDWorkoutSet → CDExercise` chain already supports the required
session → exercises → sets hierarchy.

### Relationships and delete rules

- `CDUser` → children (`workouts`, `workoutTypes`, `meals`, `ecksteinMeals`,
  `weightEntries`, `calorieBanks`, `milkConsumptions`, `fatMealTrackers`,
  `carbLoadTrackers`, `preferences`): all **Cascade** from the user side; the
  inverse `user` relationships are optional with **Nullify**.
- `CDWorkout.sets` → **Cascade**; `CDWorkoutSet.workout` → Nullify.
- `CDMeal.items` → **Cascade**; `CDEcksteinMeal.entries` → **Cascade**.
- `CDWorkoutType.exercises` → **Cascade**.
- `CDExercise.workoutSets` → **Nullify** (deleting an exercise does not delete
  history sets, which is correct for progress history).
- No relationship is marked "deny", so nothing prevents a delete; orphaned sets
  keep a `nil` exercise.

### UUID / optionality

- Every entity has an `id: UUID` attribute with a zero-UUID default. It is
  **required (non-optional)** — callers must set a real UUID, and the zero
  default is a silent footgun if a code path forgets.
- Because the model is CloudKit-enabled, most attributes are optional or carry
  defaults; client code compensates with `?? ""` / `?? Date()` patterns and
  hand-written `+CoreDataClass` / `+CoreDataProperties` files (no codegen — the
  project sets no `codeGenerationType`, so the checked-in classes are the source
  of truth).

### Migration risk

- Only one model version exists and there is no mapping model, so the app has
  never performed a real migration. `Persistence.swift:68-70` enables
  `NSMigratePersistentStoresAutomaticallyOption` and
  `NSInferMappingModelAutomaticallyOption`, which handles additive changes only.
- **`Persistence.swift:72-77` calls `fatalError` when `loadPersistentStores`
  fails.** Any future non-inferable model change (entity/attribute rename,
  type change, required attribute without default) will hard-crash on launch for
  existing users. Adding a second model version before the first schema change is
  the highest-value preventative step in phase 2.
- CloudKit is enabled (`usedWithCloudKit="YES"`, `NSPersistentCloudKitContainer`)
  **but `Eckstein.entitlements` declares an empty
  `com.apple.developer.icloud-container-identifiers` array and the pbxproj
  configures no iCloud container.** CloudKit sync cannot function as configured;
  the container currently runs in local-store mode. This also constrains future
  schema changes to CloudKit-compatible ones.

---

## HealthKit

`Core/Services/HealthKitService.swift` — **partially implemented and wired only
into the Weight feature.**

- **Types read:** `.bodyMass`, `.bodyFatPercentage`, `.leanBodyMass`, `.stepCount`.
- **Types written:** `.bodyMass`, `.bodyFatPercentage`, `.leanBodyMass`.
- **Not implemented:** active energy burned and HealthKit *workouts*. The variant
  Info.plist string promises workout sync ("save your workout … data to Apple
  Health"), but the Workout module contains zero HealthKit calls.
- **Entries:** `importWeightData(from:to:)`, `importBodyFatData(from:to:)`,
  `fetchStepsData(for:)`, `fetchAverageSteps(for:)`,
  `exportWeightToHealthKit`, `exportBodyCompositionToHealthKit`,
  `syncWithHealthKit(repository:)`.
- **Consumers:** `WeightDashboardView` (start-up sync plus a **30-second polling
  timer**), `StepsCounterCard`, `WeightSettingsView` (toggle + "Sync now"),
  `WeightViewModel` (scale export), `WeightEntryViewModel` (manual export).

**Permission handling — bug.** `requestAuthorization()` returns `true`
unconditionally on the success path (`HealthKitService.swift:57-60`), so the
caller cannot distinguish grant from denial.
`WeightSettingsView.requestHealthKitPermission()` turns the toggle off only on
`false`, so **a denied permission leaves "Auto-sync with HealthKit" showing as
ON**. Downstream calls are guarded by `isAuthorized`, so this degrades to a
silent no-op rather than a crash — but the UI lies about the state.
`checkAuthorizationStatus()` additionally inspects only body mass, so step-count
authorization is never reflected.

**Duplicate-import and conflict risk.** Import dedupes per *calendar day*: a new
sample is skipped if any entry already exists on that day
(`HealthKitService.swift:184-189`), so multiple samples in one day collapse to
one entry (first wins) and a manual entry always beats an import. There is **no
export-side dedupe** — `exportWeightToHealthKit` always writes a new
`HKQuantitySample`, so the 30-second poll plus manual entry can create duplicate
samples in Apple Health. `HealthKitService` does not use `ConflictResolver`; that
service is for cloud sync and is itself inert (see Supabase).

**Entitlements / Info.plist — present.** `NSHealthShareUsageDescription` and
`NSHealthUpdateUsageDescription` are in `Info.plist:14-17`;
`com.apple.developer.healthkit` and `…healthkit.background-delivery` are in
`Eckstein.entitlements:23-26`; `CODE_SIGN_ENTITLEMENTS` is set for the app target.

---

## Supabase

`Core/Services/SupabaseService.swift` — a `SupabaseService.shared` singleton
building one `SupabaseClient` in `private init()`, reading
`AppEnvironment.supabaseURL` / `.supabaseAnonKey`
(`Configuration/Environment.swift`), which read `EnvironmentLoader.shared`
(`Configuration/EnvironmentLoader.swift`).

- **Configuration sources (in order):** bundled `.env` → filesystem `.env`
  candidates → `ProcessInfo.processInfo.environment` keys prefixed `SUPABASE`/`OPENAI`.
- **Schema:** `FINAL_VERSION_APP_DB.sql` (593 lines) defines 19 tables with
  **RLS enabled on all of them** (lines 435-457) plus policies. This is good
  schema-level hygiene — and it is precisely what the phase-1 credential finding
  below bypassed.
- **Auth:** email/password sign-up and sign-in (`client.auth.signUp`/`signIn`),
  Sign in with Apple via `signInWithIdToken(provider: .apple, …)` with a nonce
  (`AuthService.swift:118-123`, `randomNonceString` / `sha256`), and sign-out.
  Session persistence relies on the Supabase SDK's own Keychain store;
  `AuthService.init` calls `checkAuthStatus()` on launch.
- **Crash safety:** `SupabaseClient` construction does not throw and does not
  contact the network, so an unreachable backend does not crash the app.
  `AuthService.checkAuthStatus` catches and sets `isAuthenticated = false`.
- **Fallback behavior:** when no authenticated user exists, sync attributes data
  to a hardcoded placeholder user UUID `00000000-…-0001`
  (`SyncManager.swift:383,390`, and in `encodeEntity`).

**Sync** (`SyncManager`, `SyncQueue`, `ConflictResolver`, `SimpleUserSync`):

- `SyncQueue` persists operations to `UserDefaults` and reloads on init, so the
  offline queue survives relaunch. `maxRetries = 3`.
- `SyncQueue.retryDelay = 2.0` is **declared but never used** — there is no
  backoff; retries only happen on the next trigger (5-minute timer, network
  restore, Core Data save, or manual).
- Operations that exhaust `maxRetries` stay in the queue forever:
  `removeCompletedOperations` only clears `.completed`, and nothing surfaces or
  expires the failures.
- **Conflict resolution is effectively absent.** `ConflictResolver.defaultStrategy`
  is `.lastWriteWins`, but `detectConflict` only flags timestamps within ±1 second
  (so it essentially never fires), `resolvePendingConflicts` operates on an
  always-empty array, `ConflictError` is never thrown, and the real sync path
  (`SyncManager.syncUpdate`, ~`:405-438`) fetches remote data and then discards it,
  always calling `supabaseService.update`. Net behavior: blind last-write-wins.

**Network layer.** No ATS exceptions in `Info.plist`, no `NSAllowsArbitraryLoads`,
no `didReceive challenge` / `serverTrust` override anywhere — **no TLS
weakening**. `CustomURLSession`/`CustomHTTPProtocol` is **dead code** (never
referenced; the Supabase SDK uses its own session). `FoodAPIService` uses
`URLSession.shared` over HTTPS.

---

## AI / OpenAI

- **Client-only architecture.** `OpenAIService.sendMessage` POSTs directly to
  `https://api.openai.com/v1/chat/completions` from the device with
  `Authorization: Bearer <key>`, model `gpt-4o-mini`
  (`OpenAIService.swift:85,145-160`). There is **no proxy**. All AI features
  (`AICoachViewModel`, `DietAdvisor`, `FormAnalyzer`, `WorkoutPlanGenerator`)
  call it the same way.
- **Key resolution** (`OpenAIService.swift:69-83`): `AppEnvironment.openAIKey`
  (from `.env` / process env) → `UserDefaults["openai_api_key"]` → empty string.
  The `APIKeySettingsView` screen lets the user paste a key, stored in
  `UserDefaults`.
- **No hardcoded OpenAI key exists in the repository.** `.env` is gitignored and
  no `.env` is committed.
- **Risk (HIGH, architectural):** the design puts a long-lived OpenAI secret on
  the user's device. Whatever the source, the key is retrievable from the app
  container. The target architecture — iPhone → Supabase Edge Function → OpenAI —
  is the correct fix and is a phase-2 item; phase 1 only records it.
- **Grounding gap:** `OpenAIService.buildEcksteinDietContext()` returns a
  hardcoded placeholder string (`OpenAIService.swift:279-283`) while
  `AIContextBuilder` reads the *legacy* System A entities, so the coach is not
  actually grounded in the live Eckstein meal data.

---

## Dependencies

**One** external package (`project.pbxproj`, `XCRemoteSwiftPackageReference`):

| Package | Requirement | Used by |
|---|---|---|
| `https://github.com/supabase/supabase-swift` | `upToNextMajorVersion` from `2.0.0` | `Eckstein` target (`Supabase` product) |

- `Package.resolved` is **gitignored** (`.gitignore`: `Package.resolved`), so the
  resolved Supabase revision is not pinned in the repo. CI resolves fresh each
  run, which means an upstream minor release can change the build without a
  commit. Consider tracking `Package.resolved` once the baseline is green.
- Apple frameworks used: SwiftUI, Core Data, HealthKit, CoreBluetooth,
  AVFoundation (barcode), UserNotifications, Charts.
- `CoreBluetooth.framework` was previously linked via a **hardcoded absolute SDK
  path** (`DEVELOPER_DIR/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.4.sdk/…`)
  — see Build Risks.
- No CocoaPods, no Carthage, no `Package.swift`.

---

## Tests

| File | Subject | Status after phase 1 |
|---|---|---|
| `WorkoutTests.swift` | `CDWorkout`/`CDWorkoutSet`/`CDExercise`, `WorkoutRepository` | **Rewritten** — previously referenced ~10 nonexistent symbols |
| `AICoachTests.swift` | AI stack | **Rewritten** — was not actor-isolated and read `private` members |
| `CoreDataTests.swift` | Core Data model | Fixed |
| `DietTests.swift` | `DietRepository`, nutrition calculators | Fixed |
| `SyncTests.swift` | `NetworkMonitor`, `SyncQueue`, `ConflictResolver` | Fixed |
| `WeightTests.swift` | `WeightRepository` | Fixed |
| `EcksteinTests.swift` | Swift Testing placeholder | Unchanged (empty `@Test`) |
| `EcksteinUITests*.swift` | Launch smoke tests | Unchanged (Xcode templates) |

**Why they were broken.** The unit tests had been written against a *planned or
older* API and had never been compiled — the app was developed in Xcode with the
test target never built. Concrete examples of the drift:

- `exercise.muscleGroups = [...]` (array) vs the real
  `CDExercise.muscleGroup: String?` (singular).
- `repository.createExercise(name:category:muscleGroups:)` vs the real
  `createExercise(name:muscleGroup:category:equipment:isCustom:notes:)`.
- `workout.duration` / `totalWeightKg` / `isTemplate` / `uniqueExercisesCount` —
  none exist (`durationMinutes` and the computed `totalVolume` do).
- `repository.searchExercises`, `.filterExercises`, `.getWorkoutStats`,
  `.getExerciseProgression`, `.getWorkoutTemplates` — none exist.
- `DietRepository.createFood(name:brand:calories:…)` — the real signature takes
  per-100 g values and no brand; `addFoodToMeal` takes `quantityGrams` and
  returns `Void`; `createMeal(mealType: String, date: Date)`.
- `CalorieBankManager` has a **private** initializer, so it cannot be constructed
  in isolation.
- `AICoachTests` touched `@MainActor` types from a non-isolated `setUp`, read
  `private let model` / `minRequestInterval` / `exerciseDatabase`, and used
  `AIContext.activitySummary` (real name: `recentActivitySummary`).

No test asserts on the network. Live OpenAI tests are skipped unless a key is
configured, and the `private` members needed for assertion were narrowed to
internal (not public) with an explanatory comment.

---

## Security Findings

Severity: **CRITICAL** > HIGH > MEDIUM > LOW. No secret values are reproduced.

### S1 — CRITICAL — Supabase `service_role` key hardcoded in client source

- **Type:** Supabase `service_role` JWT (decoded `role` claim: `service_role`)
  for project ref `zyuqxuuosmiiezjsrasb`.
- **Locations:** `Eckstein/Eckstein/Features/Sync/Views/DirectSyncTestView.swift:55`
  and `Eckstein/Eckstein/Features/Sync/Views/WorkaroundTestView.swift:73`.
- **Why critical:** a `service_role` key **bypasses RLS entirely** — every table
  in `FINAL_VERSION_APP_DB.sql` becomes fully readable and writable. It was
  compiled into the app bundle. `DirectSyncTestView` is reachable in **DEBUG**
  builds via `SyncStatusView.swift:292`; `WorkaroundTestView` is currently dead
  code but still compiled into the binary. It was also committed to git history.
- **Status:** literals removed in phase 1; both call sites now use
  `AppEnvironment.supabaseAnonKey`.
- **REQUIRED FOLLOW-UP (blocking, cannot be done from the repository):** the key
  must be **rotated in the Supabase dashboard**. Removing it from the working
  tree does not invalidate the copy in git history
  (`git log -p -- '*DirectSyncTestView.swift'`), nor any fork/clone already made.
  Until rotation, treat this credential as public.

### S2 — HIGH — Weak hardcoded sign-up gate password

- **Type:** hardcoded password literal.
- **Location:** `Eckstein/Eckstein/Features/Auth/ViewModels/AuthViewModel.swift:25`
  — `ProcessInfo.processInfo.environment["ADMIN_PASSWORD"] ?? "adminpass"`,
  enforced in `canSubmit` (`:45`) and surfaced by a visible "Admin Password"
  field (`LoginView.swift:176`).
- **Why high:** it is a client-side check compiled into the binary, so it provides
  no real protection while implying that it does.
- **Status:** default literal removed in phase 1 (empty when
  `ADMIN_PASSWORD` is unset). Real authorization belongs in Supabase RLS /
  an Edge Function — phase 2.

### S3 — HIGH — OpenAI secret lives on the device by design

- **Type:** architectural exposure of a long-lived API credential.
- **Location:** `Core/Services/OpenAIService.swift:69-83,145-160`.
- **Why high:** any key entered via `APIKeySettingsView` or shipped in `.env` is
  extractable from the app container and is billed to the owner.
- **Status:** recorded, not fixed. Phase 2 target: iPhone → Supabase Edge
  Function → OpenAI, with the key held server-side.

### S4 — MEDIUM — Hardcoded Supabase project URL and anon key in source

- **Type:** Supabase project URL + `anon` JWT.
- **Locations (before phase 1):** `Configuration/Environment.swift:13,18` and
  `Configuration/EnvironmentLoader.swift:23-24`; the URL was additionally
  repeated across `Features/Sync/Views/*` and `Features/Auth/Views/*`.
- **Why medium:** an `anon` key is a *public* credential by design and RLS is
  enabled, so this is not equivalent to S1 — but hardcoding it removes the
  ability to point builds at another project and makes rotation painful.
- **Status:** literals removed from `Environment.swift` and
  `EnvironmentLoader.swift`; config now comes from `.env` / process env only. The
  URL is still repeated as a literal in several DEBUG-only test views (see D3).

### S5 — MEDIUM — Credentials and PII written to the device console

- **Type:** information disclosure via `print`.
- **Locations:** `SupabaseService.swift:18-19` (URL + key prefix),
  `EnvironmentLoader.swift:75-82,108-109`, `SyncManager.swift:222-231`,
  `SyncDebugView.swift:284-291`, `SupabaseTestView.swift:60-61`,
  `OpenAIService.swift:125`, plus user email/ID logging in `AuthService` and
  `SupabaseService`.
- **Why medium:** partial key material and PII land in device logs and
  sysdiagnose archives.
- **Status:** key-prefix and URL logging removed at the main sites in phase 1.
  `print`-based logging remains in DEBUG paths; a proper `os.Logger` migration
  with redaction is a phase-2 cleanup.

### S6 — MEDIUM — Original author's `DEVELOPMENT_TEAM` committed

- **Type:** build-configuration identifier (not a secret).
- **Location:** `project.pbxproj` — `DEVELOPMENT_TEAM = Z24WA5CL56` at project and
  all three target levels; `CODE_SIGN_STYLE = Automatic`;
  `CODE_SIGN_ENTITLEMENTS = Eckstein/Eckstein.entitlements`.
- **Why medium:** CI cannot sign with a team it does not own, and the fork cannot
  ship under that team. It will need to become the new owner's team before
  TestFlight.
- **Status:** not changed in phase 1 (CI disables signing instead). Must be
  changed before any device/TestFlight work in phase 2.

### S7 — LOW/MEDIUM — Debug/test-only views shipped in the binary

- **Type:** attack surface / dead code.
- **Locations:** `Features/Auth/Views/{SupabaseDebugView,RawSupabaseTest,DirectSupabaseTest,SupabaseTestView}.swift`
  (unreferenced, kept alive only by their `#Preview`),
  `Features/Sync/Views/{SyncDebugView,SyncTestView,NetworkDiagnosticsView,DirectSyncTestView,DataValidationView,WorkaroundTestView}.swift`
  (DEBUG-gated via `SyncStatusView.swift:163-269`), and
  `Features/Weight/Views/WeightTrackingTests.swift`.
- **Why:** several perform unauthenticated raw HTTP against the project and print
  responses; they enlarge the binary and the review surface.
- **Status:** recorded. Removing them (they are provably unreferenced or
  DEBUG-gated) is a cheap phase-2 win.

### S8 — LOW — Repository / tooling hygiene

- `.mcp.json` is committed and contains a Python-oriented template
  (`npx @modelcontextprotocol/server-filesystem .`, puppeteer, magic, context7)
  that has no relation to this iOS project; it grants a filesystem MCP server
  access to the repo root. Not a credential leak, but it is unrelated surface
  area — recommend deleting or replacing with an iOS-appropriate config.
- `.gitignore` ignores `*.md` except `README.md` and `*.sql` except
  `FINAL_VERSION_APP_DB.sql`. **`AUDIT.md` therefore needs `git add -f`.** This
  rule will silently swallow future documentation — worth revisiting.

### Verified clean

- **No secrets currently tracked by git.** `git ls-files` matches nothing for
  `.env*`, `Secrets.swift`, `secrets.plist`, `*.key`, `*.pem`, `*.p12`,
  `*.mobileprovision`, or `*.xcconfig`; no `.env` file exists on disk.
- **No hardcoded OpenAI key** anywhere in the repository.
- **No TLS weakening** — no ATS exceptions, no trust-evaluation override.
- `Package.resolved` is untracked and no package cache is committed.
- The only tracked binary assets are the `AppIcon.appiconset` PNGs and
  `1024.png` (expected).

---

## Build Risks

| # | Risk | Detail | Status |
|---|---|---|---|
| B1 | **Hardcoded SDK path for CoreBluetooth** | `project.pbxproj` referenced `CoreBluetooth.framework` via `sourceTree = DEVELOPER_DIR` with the literal path `Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.4.sdk/…`. `DEVELOPER_DIR` resolves to `xcode-select`'s Xcode, so the file only exists if that exact Xcode 16.4 SDK is installed. On any CI runner (different Xcode) the reference dangles. | **Fixed** — the explicit file reference, build-file entry, Frameworks-group child, and build-phase entry were removed; Swift autolinks CoreBluetooth from `import CoreBluetooth`. |
| B2 | **Test target did not compile** | ~10 nonexistent symbols in `WorkoutTests`, plus stale APIs in `DietTests`, `WeightTests`, `SyncTests`, `CoreDataTests`, and actor/visibility errors in `AICoachTests`. Because Xcode builds the whole scheme, this also blocked `xcodebuild test` for the app. | **Fixed** in phase 1. |
| B3 | **No shared schemes** | There was no `xcshareddata/xcschemes/`, so CI depended on Xcode auto-generating a scheme on first open. | **Fixed** — an `Eckstein` shared scheme (app target build + `EcksteinTests` testable) is now checked in. |
| B4 | **iOS 18.4 simulator runtime removed from CI images** | GitHub removed the iOS 18.4 runtime in Jan 2026. Pinning a destination to OS 18.4 would fail. The deployment target stays 18.4 (enforced by the build setting); CI picks the newest available runtime. | **Handled** in `ios.yml`. |
| B5 | **Multi-platform target needs an explicit destination** | `SDKROOT = auto` with `iphoneos/xros/macosx` supported — an invocation without `-destination` can build the wrong platform. | **Handled** in `ios.yml`. |
| B6 | **CloudKit container configured but not entitled** | `NSPersistentCloudKitContainer` + `usedWithCloudKit="YES"` with an **empty** `icloud-container-identifiers` array and no pbxproj iCloud container. Sync silently does nothing; the container runs locally. | Open — decide in phase 2 (configure properly, or switch to `NSPersistentContainer`). |
| B7 | **`fatalError` on store load failure** | `Persistence.swift:72-77` crashes the app if the store cannot load; `save()` also `fatalError`s. The first non-inferable model change will brick existing installs. | Open — high priority before any model change. |
| B8 | **Package versions unpinned** | `Package.resolved` is gitignored, so CI resolves `supabase-swift` fresh each run. | Open — re-enable tracking once green. |
| B9 | **No strict-concurrency setting** | No `SWIFT_STRICT_CONCURRENCY`/`SWIFT_UPCOMING_FEATURE_*` is set, so the code compiles under minimal checking despite heavy `@MainActor` usage and `Task`/`async` code. It will not survive Swift 6 language mode as-is. | Open — phase 2 hardening. |
| B10 | **Dead navigation notification** | `CreateWorkoutView.swift:57-62` posts `Notification.Name("NavigateToWorkout")`; **no observer exists anywhere**. The created workout is saved but never opened or made active. | Open — functional bug, not a build failure. |
| B11 | **Deprecated `NavigationView`** | 64 occurrences across `Features/**`. Compiles today with deprecation warnings; should migrate to `NavigationStack`. | Open — phase 2 UI work. |

---

## Technical Debt

- **Two parallel diet systems.** System A (`CDFood`/`CDMeal`/`CDMealItem`, macros,
  barcode, Open Food Facts) is implemented but orphaned; System B
  (`CDEcksteinFood`/`CDEcksteinMeal`, grams, no macros) is what ships. Every food,
  meal, and analytics concept exists twice. The macro roadmap item requires
  resolving this — either promote System A into the Diet tab or add macro fields
  to System B.
- **`CDEcksteinFood` cannot express macros** — so "Calories / Protein / Carbs /
  Fat" is a data-model change, not just UI.
- **Dead code in the Workout feature:** `RestTimerView.swift`,
  `ExerciseProgressionView.swift` (a full progression/PR implementation that
  nothing links to), `CreateExerciseView.swift`, `WorkoutRowView.swift`,
  `RecentWorkoutCard`, plus unused `WorkoutRepository.addSet` and
  `WorkoutRepository.createWorkout`.
- **`WorkoutRepository.seedExercisesIfNeeded()` is a no-op stub**
  (`WorkoutRepository.swift:83-87`) that only calls `removeBuiltInExercises()`,
  and `Core/Data/ExerciseData.swift` exports an empty array — so the exercise
  library starts empty. `createExercise` also accepts `notes` and silently drops
  it (there is no `notes` attribute on `CDExercise`).
- **`WorkoutHistoryView.CalendarView` is a stub** — `Text("calendar_implementation")`
  with a "Calendar grid would go here" comment (`WorkoutHistoryView.swift:209-210`).
- **`ContentView.syncBadgeForTab` always returns `nil`** — dead stub.
- **`ConflictResolver` is inert** — detection never fires, merge functions fall
  back to last-write-wins, the error type is never thrown, and the sync path does
  not call it. Either wire it up or delete it.
- **`SyncQueue.retryDelay` is unused** — no backoff; exhausted operations never
  expire.
- **`CustomURLSession` / `CustomHTTPProtocol` is entirely dead code.**
- **`AppEnvironment.isConfigured` conflated two integrations.** It required
  Supabase *and* OpenAI, so a missing OpenAI key silently disabled Supabase sync
  (`SyncManager` gated on it). Split into `isSupabaseConfigured` /
  `isOpenAIConfiguration` in phase 1.
- **`EnvironmentLoader` hardcoded a developer's absolute home path**
  (`/Users/eliadshahar/Desktop/Eckstein/.env`) in its search list — removed in
  phase 1.
- **Pervasive `print` logging** with emoji prefixes is the only observability;
  there is no `os.Logger` usage.
- **`ExerciseSetCard.swift:128`** — `.if(index == 0 && exercise == exercise)`;
  the second clause is always true.
- **Repositories are instantiated ad hoc** (`WorkoutDetailView.swift:232`,
  `WorkoutTypesView.swift:241`, `WorkoutListView.swift:136`,
  `ExerciseDetailView.swift:130`) even though `ServiceContainer` exists, so each
  instance keeps its own unsynchronized `@Published` array.
- **`.gitignore` over-broad** — `*.md` (except README) and `*.sql` (except one)
  are ignored; documentation will be silently dropped.
- **`.taskmaster/`, `.cursor/`, `.mcp.json`, `.metadata.json`, `fix_xcode_clean.sh`**
  are scaffolding from another workflow and are unrelated to the iOS app.

---

## Recommended Development Order

**Phase 1 — baseline (this change set)**
1. Secret removal (S1, S2, S4) and console-log cleanup (S5).
2. CoreBluetooth SDK-path fix (B1).
3. Repair the unit-test target so it compiles (B2).
4. Add `.github/workflows/ios.yml` and get a green simulator build + unit tests on
   `develop/my-fitness-app`.
5. Commit `AUDIT.md` (forced past the `*.md` ignore rule).

**Phase 2 — before any schema or feature work**
6. **Rotate the leaked `service_role` key in Supabase (S1) — blocking.**
7. Decide the CloudKit question (B6) and add a second Core Data model version +
   replace `fatalError` with a recoverable error path (B7).
8. Set `DEVELOPMENT_TEAM` to the new owner (S6) before device builds.
9. Track `Package.resolved` (B8).

**Phase 3 — product work**
10. Simplified-Chinese localization (the `he.lproj` pattern generalizes directly).
11. Resolve the dual diet system and land macros (Calories/Protein/Carbs/Fat).
12. Workout set/rep/weight/volume polish, and fix the dead
    `NavigateToWorkout` navigation (B10).
13. Weight/BMI/trend.
14. HealthKit completion: fix the authorization-truth bug, add active energy and
    HK workout write, add export dedupe.
15. AI coach: move OpenAI behind a Supabase Edge Function (S3) and ground the
    context in live meal data.
16. Delete debug/test views (S7) and dead Workout code; migrate `NavigationView`
    → `NavigationStack` (B11).

**Phase 4 — distribution**
17. Signing, TestFlight, device install.

---

## Known Issues

Tracked but deliberately **not** fixed in phase 1 (they are behaviour bugs, not
build blockers, and the brief restricts phase 1 to build/CI/security):

1. **HealthKit denial is not reflected in the UI** — `requestAuthorization()`
   returns `true` on denial (`HealthKitService.swift:57-60`), so the auto-sync
   toggle stays ON and the user sees a silent no-op.
2. **HealthKit export has no dedupe** — `exportWeightToHealthKit` can create
   duplicate weight samples in Apple Health, especially with the 30-second poll
   in `WeightDashboardView`.
3. **HealthKit work is weight-only** — no active-energy read, no HK workout
   write, despite the Info.plist claim.
4. **Workout creation does not navigate** — `NavigateToWorkout` has no observer
   (`CreateWorkoutView.swift:57-62`).
5. **The exercise library starts empty** — `seedExercisesIfNeeded()` is a no-op
   and `ExerciseData.exercises` is empty.
6. **CloudKit sync does not function** — container configured, entitlement empty.
7. **Cloud conflict resolution is last-write-wins** with no real detection or merge.
8. **Failed sync operations never expire** — they remain queued indefinitely.
9. **Barcode scanning and food search are unreachable** from the shipped Diet tab.
10. **The AI coach's "Eckstein diet" context is a hardcoded placeholder**
    (`OpenAIService.swift:279-283`).
11. **The AI coach is not grounded in live meal data** — `AIContextBuilder` reads
    the orphaned System A entities.
12. **Xiaomi scale parsing is speculative** and unverified against real hardware.
13. **`WeightTrackingTests.swift`** lives inside `Features/Weight/Views/` rather
    than a test target.
14. **The calendar grid in workout history is a stub.**
15. **`.gitignore` swallows non-README markdown**, including this document, which
    requires `git add -f`.
