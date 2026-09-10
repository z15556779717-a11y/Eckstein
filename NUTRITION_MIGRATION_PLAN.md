# Nutrition / Diet Data Architecture — Migration Plan (Phase 2)

Status: **Step 1 (audit) and Step 2 (this document) complete. No code changed yet.**
Branch: `develop/my-fitness-app`. Baseline: CI green (`a929fed`, 93 tests, 0 failures).

This document answers, in order, the ten audit questions, the four-entity field
comparison, the chosen official model, the Core Data migration design, and the
implementation order. It is the single source of truth for the Nutrition work.

---

## 1. Full Nutrition call-chain audit

### 1.1 Method

`grep -rl` for each of the six entity classes across the whole target, plus a
read of every file that references them, plus a reachability walk from the four
live tab roots (`ContentView.swift` → `WorkoutTabView`, `DietTabView`,
`WeightTabView`, `AICoachTabView`). Reachability was decided by finding the
external constructor of each Diet view; a view with no external constructor and
no `NavigationLink`/`sheet` destination pointing at it is unreachable.

### 1.2 File reference map

**`CDEcksteinFood`** (7 files)
`CDEcksteinFood+CoreDataClass.swift`, `CDEcksteinFood+CoreDataProperties.swift`,
`Core/Services/CustomFoodManager.swift`, `Core/Services/FatMealManager.swift`,
`Features/Diet/ViewModels/EcksteinDietViewModel.swift`

**`CDEcksteinMeal` / `CDEcksteinMealEntry`** (11 files)
their two `+CoreDataClass`/`+CoreDataProperties` pairs,
`CDUser+CoreDataProperties.swift`, `Core/Models/CoreData/SyncableExtensions.swift`,
`Core/Services/FatMealManager.swift`, `Core/Services/SyncManager.swift`,
`Features/Diet/ViewModels/EcksteinDietViewModel.swift`,
`Features/Diet/Views/DietCalendarView.swift`, `Features/Diet/Views/DietDayEditView.swift`,
`Features/Sync/Views/DataValidationView.swift`, `Features/Sync/Views/SyncDebugView.swift`

**`CDFood`** (18 files)
`Core/Data/FoodData.swift`, its two `+CoreData*` files,
`CDMealItem+CoreDataProperties.swift`, `Core/Models/CoreData/SyncableExtensions.swift`,
`Core/Services/DietRepository.swift`, `Core/Utilities/ServingSizeCalculator.swift`,
`Features/Diet/ViewModels/{BarcodeViewModel,DietViewModel,FoodSearchViewModel}.swift`,
`Features/Diet/Views/{AddFoodView,BarcodeScannerContainerView,FoodDetailView,FoodSearchView,MealDetailView,QuickAddView}.swift`,
`EcksteinTests/DietTests.swift`

**`CDMeal` / `CDMealItem`** (24 files)
the `+CoreData*` pairs for `CDFood`, `CDMeal`, `CDMealItem`,
`Core/Models/CoreData/SyncableExtensions.swift`,
`Core/Services/{AIContextBuilder,ConflictResolver,DietRepository,OpenAIService,SyncManager}.swift`,
`Core/Utilities/NutritionCalculator.swift`,
`Features/Diet/ViewModels/DietViewModel.swift`,
`Features/Diet/Views/{BarcodeScannerContainerView,DietDashboardView,MealDetailView,MealHistoryView,MealSection}.swift`,
`EcksteinTests/{DietTests,SyncTests}.swift`

### 1.3 Reachability result (the decisive finding)

`ContentView.swift` shows `DietTabView()` for the Diet tab. `DietTabView` renders
`EcksteinDietView()`. That is the entire live Diet UI.

Walking every Diet view for an external constructor:

| View | External caller | Reachable from the app? |
|---|---|---|
| `EcksteinDietView` | `DietTabView` | **yes** |
| `DietCalendarView` | `EcksteinDietView:66` (sheet) | **yes** |
| `DietDayEditView` | `DietCalendarView:137` | **yes** |
| `FoodPickerView` | `EcksteinDietView:54`, `DietDayEditView:1276` | **yes** |
| `AddCustomFoodView` | `FoodPickerView:189` | **yes** |
| `ManageCommonItemsView` | `CalorieBankCard:351`, `DietDayEditView:1036` | **yes** |
| `DietDashboardView` | — | **no** |
| `MealHistoryView` | only `DietDashboardView:48` | **no** |
| `BarcodeScannerContainerView` | only `DietDashboardView:121` | **no** |
| `DailyGoalsView` / `GoalSettingsView` | only `DietDashboardView:592` | **no** |
| `MacroBreakdownView` / `WeeklyAnalyticsView` | only `DietDashboardView:595,598` | **no** |
| `FoodSearchView` / `QuickAddView` | only each other | **no** |
| `AddFoodView` / `FoodDetailView` / `MealDetailView` | — | **no** |

`DietDashboardView` has **no external caller at all**. The whole macro-capable
UI suite hangs off it, so the entire `CDFood`/`CDMeal` view layer is dead code
as far as the shipping app is concerned.

One live entry point does touch `CDFood`, and it is a side effect, not a UI:
`App/EcksteinApp+Extensions.swift:35` and `Core/Services/ServiceContainer.swift:29`
both construct `DietRepository`, whose `init` calls `seedFoodsIfNeeded()`,
`fetchTodayMeals()`, `fetchFoods()` and `updateCalorieBankBalance()`. So the
legacy system **does write** at launch: `FoodData.seedFoodsIfNeeded` inserts ~30
`CDFood` rows the first time the store is empty.

### 1.4 The ten questions

**Q1 — Which official UI uses `CDEcksteinFood`?**
`EcksteinDietView` → `FoodPickerView` (`getAllFoodsForCategory`), `AddCustomFoodView`,
`ManageCommonItemsView`, via `EcksteinDietViewModel` + `CustomFoodManager`.
These are the food pickers of the live Diet tab. Reachable and shipping.

**Q2 — Which official UI uses `CDEcksteinMeal`?**
`EcksteinDietView` (today's meals + `EcksteinDailySummaryCard`), `DietCalendarView`
(per-day history), `DietDayEditView` (editing a historical day). All reachable and
shipping. This is where every real log entry the user makes is written.

**Q3 — Which modules use `CDFood`?**
`DietRepository` (constructed at launch, seeds the catalog), `FoodData`,
`ServingSizeCalculator`, `DietViewModel`, `FoodSearchViewModel`, `BarcodeViewModel`,
`NutritionCalculator`, and the unreachable view suite. `DietTests` covers it.

**Q4 — Which modules use `CDMeal`?**
`DietRepository`, `DietViewModel`, `NutritionCalculator.calculateNutritionForMeals`,
`AIContextBuilder.fetchRecentMeals`, `OpenAIService`, `ConflictResolver.mergeMeal`,
`SyncManager` (encode + `meals` table mapping), and the unreachable view suite.

**Q5 — Which set actually saves to the user's daily database?**
**`CDEckstein*`.** Every interactive write goes through `EcksteinDietViewModel`
(`saveFoodEntry`, `saveFoodEntryForDate`, `addSnack`, …) into `CDEcksteinMealEntry`.
`CDMeal`/`CDMealItem` receive no user writes: the only `CDMeal` writer is
`DietRepository.createMeal`, called solely from `DietViewModel.createMeal`, which
is only reached from `DietDashboardView`/`BarcodeScannerContainerView` — both
unreachable. The single exception is the `CDFood` **catalog seed** at launch
(§1.3), which writes reference data, not user data.

**Q6 — Which set exists only in legacy/orphaned code?**
`CDMeal` and `CDMealItem` purely. `CDFood` is half-orphaned: its *UI* is dead but
its *catalog seed* still runs at every launch.

**Q7 — Do the two sets sync/bridge each other?**
**No.** There is no code path that moves data between them, no shared food key,
and no relationship. `CDEcksteinMealEntry` stores a `foodName` **string** and does
not reference `CDEcksteinFood` either — the Eckstein side is denormalised end to
end. The only place the two meet is `SyncManager`, which uploads both to different
remote tables. A user's logged meal is therefore invisible to every `CDFood`-based
reader, including the AI Coach (`AIContextBuilder.fetchRecentMeals()` reads `CDMeal`,
which is always empty → the coach sees **zero meals** for real users).

**Q8 — Do duplicate model fields exist?**

| Semantics | System A (live) | System B (orphaned) | Compatible? |
|---|---|---|---|
| identity | `id: UUID` | `id: UUID` | identical |
| food name | `CDEcksteinMealEntry.foodName: String` | `CDFood.name: String` | one is a snapshot string, one a catalog key |
| quantity | `gramsConsumed: Int32` | `CDMealItem.quantityGrams: Double` | **type mismatch** (Int32 vs Double) |
| date | `CDEcksteinMeal.date: Date` | `CDMeal.date: Date` | identical |
| meal grouping | `mealNumber: Int32` (1/2) | `mealType: String` | **incompatible semantics** |
| category | `category: String` (a `DietCategory.rawValue`) | `category: String?` (free-form food group) | **same name, different domain** |
| isCustom | `isCustom: Bool` | `isCustom: Bool` | identical |
| createdAt | `createdAt: Date` (food only) | — | A only |
| daily budget | `dailyGrams: Int32` | — | A only |
| macros | — | `*Per100g` ×5 | B only |
| barcode / brand / serving | — | `barcode`, `brand`, `servingSize`, `servingUnit` | B only |
| favorite / recent | — | `isFavorite`, `lastUsed` | B only |

**Q9 — Do field semantics conflict?**
Yes, in three places:
1. `category` — `CDEcksteinFood.category` holds a `DietCategory` raw value
   (`"Protein (Fat)"`, `"Carbs"`, `"Carb Load"`, …) and is *required*, and is used
   as an exact-match predicate by `CustomFoodManager.fetchFoodsByCategory` /
   `EcksteinDietViewModel.getAllFoodsForCategory`. `CDFood.category` is a free-form
   food group (`"Protein"`, `"Dairy"`, `"Grains"`). These are the same *name* for
   different concepts and must not be merged into one attribute.
2. Meal grouping — `mealNumber ∈ {1, 2}` (the Eckstein two-meal method) is not a
   relabelling of `mealType ∈ {breakfast, lunch, dinner, snack}`; it is a different
   partition. `mealNumber` cannot be derived from `mealType` or vice versa.
3. Quantity — `gramsConsumed` is `Int32`, `quantityGrams` is `Double`. Any bridge
   loses sub-gram precision in one direction.

**Q10 — Is there existing-user-data migration risk?**
Yes, and it is structural rather than volume-related:
- The store has exactly **one** model version directory (`Eckstein.xcdatamodel`)
  and **no `.xccurrentversion` file**. Adding attributes to the existing
  `contents` in place would leave existing stores with no version to migrate
  *from* and the container would fail to open. A new version directory plus an
  `.xccurrentversion` marker is mandatory.
- `PersistenceController` calls `fatalError` when a store fails to load
  (`B7` in AUDIT.md), so a migration failure is a crash on launch, not a
  degraded state. The migration must be lightweight-inferrable, and every new
  attribute must be optional so nothing has to be invented for old rows.
- Real data at risk is only in `CDEcksteinMeal`/`CDEcksteinMealEntry` (dates,
  food names, gram amounts, meal grouping, UUIDs). `CDFood`/`CDMeal`/`CDMealItem`
  hold seeded catalog rows and no user logs, so they carry no migration risk.

### 1.5 Additional facts established by the audit

- **The live Diet tab computes no macronutrients at all.** `EcksteinDietViewModel`
  (1190 lines) tracks grams against a per-food `dailyGrams` budget and a
  protein/carb percentage carry-over between meal 1 and meal 2. `EcksteinDailySummaryCard`
  shows percentage budgets, not calories. Grepping the file for
  `calorie|protein|carb|fat|fiber` returns only `calorieBankBalance` and the
  `carbLoad*` meal flags. Calories exist only as the separate `CalorieBankManager`
  ledger (a 150 kcal/day deposit/withdraw concept), not as food energy.
- **The barcode layer is already mostly decoupled.** `FoodAPIService` talks to
  Open Food Facts and returns `FoodAPIResponse.Product`; it converts to a
  model-independent `FoodTemplate` struct (`Core/Data/FoodData.swift:11`).
  `BarcodeScannerView` is raw AVFoundation and knows nothing about Core Data.
  Only the last mile — `BarcodeViewModel.foundFood: CDFood?` and
  `DietViewModel.createFoodFromAPI`/`findFoodByBarcode` — is bound to `CDFood`.
- **`SyncManager` already maps both sets to Supabase** via the generic `default:`
  branch of `encodeEntity`, which walks `entity.entity.attributesByName`. This
  matters: any attribute added to a syncable entity is automatically sent to the
  server, so a local-only field would break its upload with a PostgREST
  "column does not exist" error.
- **The remote schema is already partly prepared for this migration** (§12).

---

## 2. Four-entity field comparison

Types are verbatim from `Eckstein.xcdatamodel/contents`.

### 2.1 Food entities

| Field | `CDEcksteinFood` | `CDFood` | Note |
|---|---|---|---|
| `id` | `UUID` required | `UUID` required | same |
| `name` | `String` required | `String` required | same |
| `brand` | — | `String?` | B only |
| `barcode` | — | `String?` | B only |
| `category` | `String` required — `DietCategory` raw value | `String?` — free-form group | **semantic conflict** |
| `caloriesPer100g` | — | `Int32` required | B only |
| `proteinPer100g` | — | `Double` required | B only |
| `carbsPer100g` | — | `Double` required | B only |
| `fatPer100g` | — | `Double` required | B only |
| `fiberPer100g` | — | `Double` required | B only |
| `servingSize` | — | `Double` required | B only |
| `servingUnit` | — | `String?` | B only |
| `dailyGrams` | `Int32` required | — | A only (Eckstein budget) |
| `isFat` | `Bool` required | — | A only (protein class) |
| `isCustom` | `Bool` required | `Bool` required | same name, same meaning |
| `isFavorite` | — | `Bool` required | B only |
| `isVerified` | — | `Bool` required | B only |
| `lastUsed` | — | `Date?` | B only |
| `createdAt` | `Date` required | — | A only |
| `updatedAt` | — | — | **neither has one** |
| `source` | — | — | **neither has one** |
| relationships | none | `mealItems → CDMealItem`, to-many, Nullify | B only |

**Only in A:** `dailyGrams`, `isFat`, `createdAt`, and the `DietCategory` meaning of `category`.
**Only in B:** all five macros, `barcode`, `brand`, `servingSize`, `servingUnit`, `isFavorite`, `isVerified`, `lastUsed`, `mealItems`.
**Same name, different meaning:** `category`.
**Same name, same meaning:** `id`, `name`, `isCustom`.
**Cannot map directly:** `CDFood.category` → `CDEcksteinFood.category` (different domains — must land in a separate attribute).
**Needs a default in migration:** every B-only field, for the A rows that lack it (`0`, `nil`, `false`).
**Missing in both, needed by the target design:** `updatedAt`, `source`.

### 2.2 Meal entities

| Field | `CDEcksteinMeal` | `CDMeal` | Note |
|---|---|---|---|
| `id` | `UUID` required | `UUID` required | same |
| `date` | `Date` required | `Date` required | same |
| meal grouping | `mealNumber: Int32` required | `mealType: String` required | **incompatible** |
| `isCarbLoad` | `Bool` required | — | A only |
| `syncStatus` | — | `String` required | B has a stored copy; A gets it from `SyncableEntity` |
| totals | — | — | **neither denormalises totals** |
| `user` | `→ CDUser`, to-one, Nullify | `→ CDUser`, to-one, Nullify | same |
| children | `entries → CDEcksteinMealEntry`, to-many, **Cascade** | `items → CDMealItem`, to-many, **Cascade** | structurally same |

### 2.3 Entry entities

| Field | `CDEcksteinMealEntry` | `CDMealItem` | Note |
|---|---|---|---|
| `id` | `UUID` required | `UUID` required | same |
| food reference | — (`foodName: String` required, denormalised) | `food → CDFood`, to-one, Nullify | different model |
| `foodName` | `String` required | — (read through `food.name`) | A snapshots, B joins |
| quantity | `gramsConsumed: Int32` required | `quantityGrams: Double` required | **type mismatch** |
| `category` | `String` required | — | A only |
| `meal` | `→ CDEcksteinMeal`, to-one, Nullify | `→ CDMeal`, to-one, Nullify | same |
| nutrition snapshot | — | — | **neither snapshots** |

### 2.4 Goals

`CDUserPreferences` already carries `dailyCalorieGoal`, `dailyCarbGoal`,
`dailyProteinGoal` (all `Int32`, required) — **no `dailyFatGoal`, no
`dailyFiberGoal`**. The remote `user_preferences` table mirrors this exactly
(`daily_calorie_goal`, `daily_protein_goal`, `daily_carb_goal`; no fat/fiber).

---

## 3. Decision: which model becomes official

### 3.1 Chosen strategy: **A — `CDEckstein*` becomes the official Nutrition path**

`CDEcksteinFood`, `CDEcksteinMeal` and `CDEcksteinMealEntry` are the single
official Nutrition data path. They gain the nutrition fields that today exist
only on `CDFood`. `CDFood`/`CDMeal`/`CDMealItem` are **frozen**: no official
business path writes them, they are not deleted, and their entities remain in
the model for compatibility.

### 3.2 Why A and not B

B means promoting the macro-capable set and moving the app onto it. It is
rejected on four independent grounds, in the order the brief weights them:

1. **Existing user data does not live there.** Every log entry a user has ever
   made is in `CDEcksteinMealEntry`. B requires a custom (non-inferrable) entity
   mapping that reconstructs `CDFood` rows from `foodName` strings, resolves or
   invents a `CDMeal.mealType` for rows that only have `mealNumber`, and
   downcasts `Int32` grams to `Double`. That is lossy, unverifiable without real
   device data, and directly contradicts "不丢已有用户数据".
2. **It requires the large UI rewrite Phase 2 forbids.** All five reachable Diet
   views plus `EcksteinDietViewModel` (1190 lines), `CustomFoodManager`,
   `FatMealManager`, `CarbLoadManager`, `CalorieBankManager` and
   `AchievementManager` are written against the Eckstein types. Retargeting them
   is a Diet-tab rewrite, which the brief excludes ("不做大规模 UI 重设计").
3. **`mealNumber` does not generalise to `mealType`.** The Eckstein method is a
   two-meal protein/carb percentage system. Mapping meal 1/2 onto
   breakfast/lunch/dinner/snack is not a bijection and would silently change
   what the user's history means.
4. **More fields is not a reason.** The brief says so explicitly. The macro
   fields are *data*, not *architecture*, and they port to A with a purely
   additive, lightweight-migratable schema change.

A is chosen on the positive grounds too: it is purely additive (no attribute is
removed, renamed, or made non-optional), so `NSInferMappingModelAutomaticallyOption`
can infer it; it leaves the shipping UI untouched; and it is the only option that
keeps existing rows byte-identical.

### 3.3 What "official" means concretely

- `NutritionService` is the **single** write façade. It writes only
  `CDEcksteinMeal` / `CDEcksteinMealEntry` / `CDEcksteinFood`.
- It is also the **single** read façade for aggregates, so the Dashboard and the
  AI Coach never issue their own fetch requests against Nutrition entities.
- `DietRepository`, `DietViewModel`, `FoodSearchViewModel`, `BarcodeViewModel`,
  `FoodSearchView`, `QuickAddView`, `DietDashboardView` and the rest of the
  unreachable `CDFood` view suite are marked `@available(*, deprecated)`-style in
  comments and stop being constructed by the live app. `DietRepository` is
  removed from `ServiceContainer` and `EcksteinApp+Extensions` (its only live
  callers) — that also removes the startup seed of ~30 `CDFood` rows.
- `FoodData`'s templates are **reused** as the seed source for `CDEcksteinFood`
  catalog rows, so the seeded catalog is not lost, only relocated.

---

## 4. Core Data migration design

### 4.1 Current state

- `Eckstein.xcdatamodeld/` contains exactly one version: `Eckstein.xcdatamodel`.
- There is **no `.xccurrentversion`**. Adding attributes in place is not
  acceptable: a store already written with the old schema would have no source
  version to migrate from.
- `PersistenceController` already sets `NSMigratePersistentStoresAutomaticallyOption`
  and `NSInferMappingModelAutomaticallyOption` on every store description (added
  in Phase 1), and shares one `NSManagedObjectModel` across containers. Store
  load failure is still a `fatalError` (`B7`).

### 4.2 Plan

1. Copy `Eckstein.xcdatamodel` → **`Eckstein 2.xcdatamodel`** and add the new
   attributes there. The old version directory is **kept unchanged** so the
   source model remains resolvable.
2. Write `Eckstein.xcdatamodeld/.xccurrentversion` as a plist pointing at
   `Eckstein 2.xcdatamodel`. This is the file that makes the new version current;
   without it Xcode and Core Data fall back to the alphabetically first version.
3. **Every new attribute is optional.** This is required twice over: an optional
   attribute needs no default to infer a mapping for existing rows, and
   `NSPersistentCloudKitContainer` requires attributes to be optional or to carry
   a default. No existing attribute changes its optionality, type, or name.
4. **Missing-value policy, chosen explicitly** (the brief asks for a decision, not
   a default): existing entries have no macro data, and inventing a number would
   corrupt history. Old rows get **`nil`** on every new nutrition attribute,
   meaning *unknown*. The aggregation layer coerces `nil → 0` when summing, and
   the domain model exposes `hasNutritionData` so a caller can distinguish
   "logged before nutrition tracking existed" from "logged 0 kcal". `Bool` flags
   default to `false`. Nothing is written back to old rows.
5. No custom mapping model is required, so none is written. If CI ever reports a
   migration failure, the fallback is a custom `NSMappingModel` plus a staged
   migration — but nothing in this change set needs one, and the brief says not
   to force or pre-emptively build one.
6. Tests cover the migration path by opening the store, asserting old-shaped
   rows still read, and asserting new fields default to `nil`.

### 4.3 Fields preserved by the migration

Untouched by definition — no attribute is modified — so all of: `name`,
`date`, `gramsConsumed`, `mealNumber`, `category`, `isCarbLoad`, `id`,
`dailyGrams`, `isFat`, `isCustom`, `createdAt`, and both relationships
(`entries`, `user`).

---

## 5. Official Nutrition fields

### 5.1 `CDEcksteinFood` — the official food catalog

Existing (unchanged): `id`, `name`, `category`, `dailyGrams`, `isFat`,
`isCustom`, `createdAt`.

| New attribute | Type | Optional | Why |
|---|---|---|---|
| `caloriesPer100g` | `Double` | yes | energy, per 100 g |
| `proteinPer100g` | `Double` | yes | |
| `carbsPer100g` | `Double` | yes | |
| `fatPer100g` | `Double` | yes | |
| `fiberPer100g` | `Double` | yes | |
| `barcode` | `String` | yes | barcode lookup key |
| `brand` | `String` | yes | |
| `servingSize` | `Double` | yes | default serving, grams |
| `servingUnit` | `String` | yes | |
| `foodCategory` | `String` | yes | the free-form food group; **separate from `category`**, which keeps its `DietCategory` meaning |
| `isFavorite` | `Bool` | yes | favourite foods |
| `isVerified` | `Bool` | yes | matches `CDFood` |
| `lastUsed` | `Date` | yes | recent foods |
| `updatedAt` | `Date` | yes | |
| `source` | `String` | yes | provenance, e.g. `"openfoodfacts"`, `"seed"`, `"user"` |

`Double` rather than `Int32` for calories, unlike `CDFood.caloriesPer100g`:
`Int32` truncation is what makes a 0.4 kcal/100 g entry read as 0, and the
aggregation layer needs the precision to round once at the end. Both the remote
column and `CDFood` keep their existing shape — this is a local type choice, and
`ServingSizeCalculator` already rounds to `Int` at the presentation boundary.

### 5.2 `CDEcksteinMealEntry` — the official log entry, with a snapshot

Existing (unchanged): `id`, `foodName`, `category`, `gramsConsumed`, `meal`.

| New attribute | Type | Optional | Why |
|---|---|---|---|
| `calories` | `Double` | yes | nutrition snapshot |
| `protein` | `Double` | yes | |
| `carbs` | `Double` | yes | |
| `fat` | `Double` | yes | |
| `fiber` | `Double` | yes | |
| `food` | `→ CDEcksteinFood`, to-one, Nullify | yes | optional catalog link |
| `updatedAt` | `Date` | yes | |

**On snapshots — decided as the brief's recommended principle.** A historical
diet record must not change when the food catalog is later edited, so the entry
stores its own nutrition values. The audit makes this cheap rather than a
refactor: the entry **already** denormalises `foodName` and `category`, so
storing five more numbers matches the existing design instead of fighting it —
`CDFood`/`CDMealItem` are the ones that normalise, and they are the ones being
retired. Snapshots are also what the remote table already expects (§12).

**On the `food` relationship.** It is added as optional and is *not* the source
of truth for nutrition; it is a convenience link for "cook this again" and for
recent/favourite roll-ups. Old rows keep `food == nil` and remain fully readable
through `foodName` + snapshot. Because `CDEcksteinMealEntry.food` uses Nullify,
deleting a catalog food never deletes history.

`gramsConsumed` stays `Int32`. Widening it to `Double` would be a destructive
type change on a populated attribute; the gram amounts the live UI collects are
whole numbers, and the double-precision quantity the target design needs lives in
the snapshot + per-100 g fields instead.

### 5.3 `CDEcksteinMeal`

| New attribute | Type | Optional | Why |
|---|---|---|---|
| `mealType` | `String` | yes | breakfast/lunch/dinner/snack — see §6 |
| `totalFiber` | `Double` | yes | meal-level roll-up, mirrors `eckstein_meals.total_*` |
| `totalCalories` | `Double` | yes | |
| `totalProtein` | `Double` | yes | |
| `totalCarbs` | `Double` | yes | |
| `totalFat` | `Double` | yes | |
| `updatedAt` | `Date` | yes | |

The totals are **denormalised caches**, written by `NutritionService` whenever an
entry changes, so a day's list view does not have to walk every entry. They are
never the source of truth: `NutritionAggregator` recomputes from entries, and the
totals exist only for cheap display and for matching the remote `eckstein_meals`
columns. `mealNumber` and `isCarbLoad` are untouched.

---

## 6. Meal type

Officially supported values: **`breakfast`, `lunch`, `dinner`, `snack`** — matching
the remote `meals.meal_type` CHECK constraint, which already enumerates exactly
these four.

- Stored as an optional `String`, not an `Int16` enum. An enum with raw values
  would make persistence depend on declaration order, and the brief forbids
  invalidating old data through raw-value changes.
- The canonical values live in a Swift enum `MealType: String, CaseIterable` in
  the domain layer, and `CDEcksteinMeal.mealType` stores its `rawValue`. An
  unrecognised or `nil` stored value decodes to `nil` rather than trapping, so a
  future value added on the server cannot crash an older client.
- **`mealNumber` is not replaced.** It keeps its Eckstein-method meaning. New
  writes set *both*: `mealNumber` for the live two-meal UI, `mealType` for the
  nutrition layer. A row written before this phase has `mealType == nil`; the
  aggregator groups those under "other" rather than guessing a slot. No backfill
  is performed, because a guess is not recoverable and `mealNumber` alone does
  not determine a `mealType`.

---

## 7. Daily nutrition aggregation

A separate, pure, testable layer with no `View` and no `NSManagedObject` in its
signature.

```
struct NutritionSnapshot { calories, protein, carbs, fat, fiber: Double }
struct DailyNutritionSummary { date, totals: NutritionSnapshot,
                               goals: NutritionGoals,
                               byMealType: [MealType: NutritionSnapshot] }
struct NutritionGoals { calories, protein, carbs, fat, fiber: Double }
```

- `NutritionAggregator.summary(for entries: [CDEcksteinMealEntry], on date: Date,
  calendar: Calendar = .current, goals: NutritionGoals) -> DailyNutritionSummary`
  — the load-bearing function. It takes plain values, so it is unit-testable
  without a store, and takes an injectable `Calendar` so tests are not
  timezone-dependent.
- `NutritionService.summary(on date:)` fetches and delegates. Views and the AI
  layer call *this*, never the aggregator's inputs directly.
- **Day boundaries.** No `Date == Date` anywhere. The range is half-open:
  `calendar.startOfDay(for: date)` inclusive to
  `calendar.date(byAdding: .day, value: 1, to: startOfDay)` exclusive, matching
  the predicate style `DietRepository.fetchTodayMeals` already uses. The
  `Calendar` is injected; nothing calls `Calendar.current` inside the aggregator.
  An entry whose `date` is exactly midnight belongs to the day that starts at it,
  and the exclusive upper bound prevents a meal logged at 00:00 tomorrow from
  being counted today — the bug a closed `<= endOfDay` range produces.
- Minimum outputs: `dailyCalories`, `dailyProtein`, `dailyCarbohydrates`,
  `dailyFat`, `dailyFiber`.
- `nil` snapshot values coerce to `0`. Calories are rounded once, at the
  presentation boundary, not per-entry.
- Entries are grouped by `mealType` for `byMealType`, with `nil` under an
  explicit `.unspecified` case.

No aggregation logic is added to any `body` — `EcksteinDailySummaryCard` and any
future dashboard read `NutritionSummary` values that were computed outside the
view.

---

## 8. Nutrition goals

`CDUserPreferences` already has `dailyCalorieGoal`, `dailyCarbGoal`,
`dailyProteinGoal` (`Int32`, required). It has **no fat or fiber goal**.

Add two optional `Double` attributes: **`dailyFatGoal`**, **`dailyFiberGoal`**.
Optional for the same migration and CloudKit reasons as §4.2; a `nil` goal means
"not set", and the aggregator reports `goals.fat == 0` so a dashboard can render
an empty ring instead of a full one.

A `NutritionGoals` value is produced by `NutritionService.goals()` reading
`CDUserPreferences` for the current user, with a documented fallback when no
preferences row exists yet. This phase adds **no** Profile UI — the brief
excludes it — so these two fields are readable through the service but not yet
editable in the app. No new `CDUser` relationship is introduced.

---

## 9. Barcode scanning

**No second scanner is written.** `BarcodeScannerView` (AVFoundation
`UIViewControllerRepresentable`) and `FoodAPIService` (Open Food Facts
`…/product/{barcode}.json`) are entity-agnostic already; `FoodAPIService` returns
`FoodAPIResponse.Product` and converts to the model-independent `FoodTemplate`.
Only the last mile is bound to `CDFood`.

- `NutritionService.food(matchingBarcode:)` / `upsertFood(from: FoodTemplate)` is
  the new seam. It maps `FoodTemplate` → `CDEcksteinFood` (macros into
  `*Per100g`, `brand`, `barcode`, `servingSize`, `servingUnit`, `source =
  "openfoodfacts"`). This *is* the "minimal adapter" the brief allows.
- `BarcodeViewModel`'s `foundFood: CDFood?` becomes a `FoodTemplate?` /
  `CDEcksteinFood?` result from the service. The scanner view type is unchanged.
- Because `CDFood` and `CDEcksteinFood` are different entities with no shared
  superclass, the two barcode lookup paths (`NutritionService.food(matchingBarcode:)`
  for the canonical store, `DietRepository`'s for the frozen one) stay separate
  functions rather than one polymorphic API — duplicating an entity binding is
  acceptable; duplicating a scanner is not.
- `BarcodeScannerContainerView` (unreachable) is left in place, marked
  deprecated, and not retargeted, so no live behaviour changes.

---

## 10. Recent foods / favourite foods

`CDFood` already models this with `isFavorite` and `lastUsed`; both concepts are
carried onto `CDEcksteinFood` (§5.1) rather than invented anew.

- **Favourite** — `isFavorite: Bool?`, toggled by
  `NutritionService.setFavorite(_:isFavorite:)`.
- **Recent** — `lastUsed: Date?`, stamped by `NutritionService` on every log
  write. Recency is a query, not a second table:
  `recentFoods(limit:)` fetches with `lastUsed != nil`, sorted descending.
  A `usageCount` counter is deliberately **not** added: nothing in the target
  requirements needs frequency ranking, and a counter would be a field to migrate
  and keep consistent for no user-visible gain. If frequency ranking is wanted
  later it can be derived from the entries that already exist.

No new entity, no new relationship, no UI.

---

## 11. Principles for retiring the old system

This phase **does not delete** any entity, attribute, or relationship.
`CDFood`, `CDMeal`, `CDMealItem` remain in `Eckstein.xcdatamodel` (and in the new
version) with their schemas untouched, and `CDMealItem`'s relationships stay as
declared.

What this phase does do:

- Stop constructing `DietRepository` from the live app, which stops the `CDFood`
  catalog seeding and the `updateCalorieBankBalance` side effect at launch.
- Stop every official write into the three old entities. After this change the
  only `CDFood` rows in a store are ones seeded by an older build; no new ones
  appear.
- Mark the old files deprecated in comments (`DietRepository`, `DietViewModel`,
  `FoodSearchViewModel`, `BarcodeViewModel`, `NutritionCalculator`, `FoodData`,
  `ServingSizeCalculator`, and the unreachable view suite) with a pointer to this
  document.
- Keep read compatibility: the old entities are still in the model, so old rows
  still load, still sync, and are still readable by the code that references them.
- Cover aggregation and migration with tests (§14).

Deletion is explicitly deferred. It becomes eligible only when: the migration is
confirmed on real data, CI has stayed green, `git grep` shows no official caller,
and no compatibility dependency remains. That is a later phase, not this one.

---

## 12. Supabase compatibility

The remote schema is `FINAL_VERSION_APP_DB.sql` (v1.1) plus `supabase/config.toml`.
**Both** nutrition schemas already exist remotely, and the Eckstein side is
already better prepared than the local model:

- `eckstein_foods (id, name, category, daily_grams, is_fat, is_custom, created_at, sync_status, remote_id)` — **no macro, barcode, brand or serving columns.**
- `eckstein_meals (…, meal_number, is_carb_load, total_calories, total_protein, total_carbs, total_fat, …)` — already carries the four total columns, `meal_type` is **absent**.
- `eckstein_meal_entries (…, food_name, category, grams_consumed, calories, protein, carbs, fat, …)` — **already carries the per-entry nutrition snapshot**, `NOT NULL DEFAULT 0`.
- `user_preferences` — has `daily_calorie_goal`, `daily_protein_goal`, `daily_carb_goal`; **no fat or fiber goal**, same as local.
- `meals.meal_type` already has `CHECK (meal_type IN ('breakfast','lunch','dinner','snack'))`.
- RLS is enabled on all three Eckstein tables with owner-scoped policies.

**Why this matters:** `SyncManager.encodeEntity`'s generic branch sends *every*
attribute of a syncable entity, so a locally-added field with no remote column
would make the upload fail with a PostgREST "column does not exist" error. The
schema change is therefore not optional for sync to keep working — but it is
small, additive, and confined to columns the remote schema already anticipates on
the entries table.

**Plan.** Add `supabase/migrations/<timestamp>_nutrition_fields.sql`, written to
be **idempotent** (`ADD COLUMN IF NOT EXISTS`) and **non-destructive** — no
`DROP`, no `DELETE`, no `UPDATE` of existing rows, no `ALTER TYPE`, no tightening
of an existing constraint that could reject existing data:

- `eckstein_foods`: `+ calories_per_100g, protein_per_100g, carbs_per_100g,
  fat_per_100g, fiber_per_100g, barcode, brand, serving_size, serving_unit,
  food_category, is_favorite, is_verified, last_used, updated_at, source`.
- `eckstein_meals`: `+ meal_type TEXT`, `+ total_fiber`, `+ updated_at`.
- `eckstein_meal_entries`: `+ fiber`, `+ updated_at` (calories/protein/carbs/fat
  already exist).
- `user_preferences`: `+ daily_fat_goal`, `+ daily_fiber_goal`.

`FINAL_VERSION_APP_DB.sql` is **not** edited: it opens with `DROP TABLE … CASCADE`
for every table and is a destructive reset script, which is exactly what the
brief forbids running against production. The migration file is the only
sanctioned path. It is not executed from this machine; it is committed for the
user to apply, and it contains no key of any kind — not the anon key, and
certainly not `service_role`.

If the sync path turns out to be non-functional for unrelated reasons, the
migration is still correct on its own and no local behaviour depends on it having
been applied.

---

## 13. AI Coach compatibility

The AI Coach is **not** rewritten. One real defect is fixed and one seam is added.

**Defect.** `AIContextBuilder.fetchRecentMeals()` reads `CDMeal` — the orphaned
entity that receives no user writes — so the coach currently sees zero meals for
every real user. The fix is to point it at the official path:
`NutritionService.recentMeals(limit:)`.

**Seam.** The AI layer must not fetch Core Data entities all over the place. It
gets one explicit, value-typed API and no entity access:

```
NutritionService.summary(on: Date)     -> DailyNutritionSummary
NutritionService.recentMeals(limit:)   -> [NutritionMealSummary]
NutritionService.goals()               -> NutritionGoals
```

`NutritionMealSummary` is a plain value: date, meal type, food names, total grams,
and the nutrition totals — no `NSManagedObject` escapes the service. A future AI
prompt is built from these values only. `AICoachViewModel`, `DietAdvisor` and
`WorkoutPlanGenerator` keep their current structure; only the meal-data source
inside `AIContextBuilder` changes, plus whatever string formatting reads the new
values.

---

## 14. Tests

Added to the existing `EcksteinTests` target. **No existing test is deleted,
skipped, or weakened** — the 93-test baseline stays and the new cases are added
beside it. `DietTests` (which exercises the frozen `CDFood`/`CDMeal` path) is
left intact and must keep passing; if any test there depends on `DietRepository`
being constructed by the app, only the construction is removed, not the test.

New file `EcksteinTests/NutritionTests.swift`, covering the 13 required items:

| # | Required coverage | Test |
|---|---|---|
| 1 | daily calories aggregation | `testDailyCaloriesAggregation` |
| 2 | daily protein aggregation | `testDailyProteinAggregation` |
| 3 | daily carbs aggregation | `testDailyCarbsAggregation` |
| 4 | daily fat aggregation | `testDailyFatAggregation` |
| 5 | daily fiber aggregation | `testDailyFiberAggregation` |
| 6 | meal type filtering | `testMealTypeFiltering` |
| 7 | multiple meals same day | `testMultipleMealsSameDay` |
| 8 | different day isolation | `testDifferentDaysAreIsolated` |
| 9 | empty day returns zero | `testEmptyDayReturnsZero` |
| 10 | historical snapshot behaviour | `testHistoricalSnapshotSurvivesFoodEdit` |
| 11 | Core Data migration compatibility | `testLightweightMigrationPreservesExistingData` |
| 12 | old food records still readable | `testLegacyFoodRecordsRemainReadable` |
| 13 | new nutrition fields default correctly | `testNewNutritionFieldsDefaultToNil` |

Notes on the harder three:

- **#8 / day boundaries** uses an injected `Calendar` and entries at `23:59:59`
  and `00:00:00` to pin the half-open interval, not just two far-apart dates.
- **#10** edits a `CDEcksteinFood`'s macros after an entry was logged and asserts
  the entry's snapshot is unchanged. This is the test that makes the snapshot
  decision load-bearing rather than decorative.
- **#11 / #12** are the migration tests. They construct a store from the **old**
  model version, insert an old-shaped `CDEcksteinMealEntry` (no nutrition fields),
  then reopen it through `PersistenceController` so the real inferred migration
  runs, and assert: the row still loads, `foodName`/`gramsConsumed`/`mealNumber`
  are intact, the new fields are `nil`, and the `entries` cascade still works.
  `NSManagedObjectModel` instances are built from the bundled `.momd`, so this
  exercises the real model rather than a hand-built one.

Test style follows the existing suite: `PersistenceController(inMemory: true)`
for logic, a temp-directory SQLite store where persistence across a reopen is
required, `@MainActor` only where the type under test needs it.

---

## 15. Implementation order

Executed in this order, committing at each milestone. No step is skipped.

| Step | Work | Commit |
|---|---|---|
| 1 | Full Nutrition audit | — |
| 2 | This document | `docs: add nutrition migration plan` |
| 3 | Model decision + migration strategy (§3, §4) | *(in this document)* |
| 4 | `Eckstein 2.xcdatamodel` + `.xccurrentversion` + migration SQL | `feat: add nutrition core data migration` |
| 5 | `NutritionService` + domain values (`NutritionSnapshot`, `DailyNutritionSummary`, `NutritionGoals`, `MealType`) | `feat: unify nutrition data model` |
| 6 | Move the official business path onto the service; remove `DietRepository` from the live container; retarget `AIContextBuilder` | `feat: unify nutrition data model` |
| 7 | Barcode adapter onto `CDEcksteinFood` (§9) | `feat: unify nutrition data model` |
| 8 | `NutritionAggregator` (§7) | `feat: add nutrition aggregation` |
| 9 | `NutritionTests` (§14) | `test: add nutrition data tests` |
| 10 | GitHub Actions verification | — |

CI loop per the brief: `git status` + `git diff` at each milestone, `git push`,
`gh run list`, and on failure `gh run view --log-failed` — fixed from the real
Xcode log, never guessed. Done when `** BUILD SUCCEEDED **` and
`** TEST SUCCEEDED **` with zero failures, the tree is clean, everything is on
`develop/my-fitness-app`, `main` is untouched, and no secret is committed.

---

## 16. Out of scope for this phase

Chinese localisation, Dashboard redesign, Workout UI, HealthKit rewrite, AI Coach
rewrite, Authentication, SwiftData, deleting the old Core Data entities, a
whole-app refactor, Flutter, React Native, any change to `main`, `git push
--force`, `git reset --hard`, committing secrets, and putting either an OpenAI key
or a Supabase `service_role` key in the client.

The leaked `service_role` key recorded as `S1` in `AUDIT.md` remains in git
history at `beddcff` and **still requires rotation in the Supabase dashboard**.
That is a user action, not a code change, and it blocks nothing in this plan
because the migration SQL contains no key.
