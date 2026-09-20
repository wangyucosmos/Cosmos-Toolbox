# 2026-09-19 Cosmos OS Development Log

## 1. Session goal

Implement the approved, bounded Campaign / Workspace Store persistence protection Phase 1 without migrating the persistence format or changing formal Workflow, Campaign, Workspace, Artifact, or local Workspace business data.

The phase covers safe startup loading, one last-known-good backup, process-local write serialization, stale-instance conflict rejection, write read-back verification, locked corruption states, and isolated UI acceptance for Campaign / Workspace create, edit, delete, and restart persistence.

## 2. Implementation

Added a shared `ZhuowangProtectedPersistence<Value>` boundary and applied it to `ZhuowangCampaignStore` and `ZhuowangWorkspaceStore`.

Implemented behavior:

- an existing valid primary loads without re-encoding and without creating a backup;
- a missing primary initializes once and verifies the read-back;
- an unreadable primary is preserved and locks the Store;
- a valid backup is detected but is not restored automatically;
- every accepted mutation rereads the primary while holding a shared process-local lock and compares it with the Store baseline;
- a stale Store instance rejects its mutation without changing primary, backup, or its public in-memory value;
- a successfully decoded current primary becomes the single last-known-good backup before the candidate primary is written;
- primary and backup writes are read back and compared in process;
- a failed write verification locks the Store and does not publish the candidate value;
- invalid or missing-item mutations do not write primary or backup;
- Campaign create, update, and delete return explicit mutation results;
- Workspace create, update, and delete use the same protected transaction boundary;
- DEBUG-only UUID suite injection is isolated from the production domain and fails closed;
- the suite injection code is absent from Release builds.

The lock is an `NSLock` registry keyed by UserDefaults domain and primary key. It is process-local and is not a cross-process lock. UserDefaults read-back verifies the value visible to this process; it is not a disk flush or strong durability guarantee.

## 3. Files changed

- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangProtectedPersistence.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignStore.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkspaceStore.swift`
- `Apps/CosmosOS/Cosmos Toolbox/Cosmos_ToolboxApp.swift`
- `Apps/CosmosOS/Cosmos Toolbox/DashboardView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignDetailView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkspaceView.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangCampaignStorePersistenceTests.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangWorkspaceStorePersistenceTests.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangStorePersistenceBoundaryTests.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangStorePersistenceTestSupport.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangProtectedPersistenceConcurrencyTests.swift` (added in §11)
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-09-19_Cosmos_OS_Development_Log.md`

## 4. Verification

### Automated verification

- Store-focused persistence tests: 29 passed.
- Full XCTest suite after the final root-level isolation banner change: 144 passed, 0 failed, 0 skipped.
- Result bundle: `/tmp/CosmosToolboxStorePhase1FullTests-Rerun/Logs/Test/Test-Cosmos Toolbox-2026.09.19_19-04-40-+0800.xcresult`.
- Universal macOS Debug build succeeded with `ONLY_ACTIVE_ARCH=NO`.
- Final executable architectures: `x86_64 arm64`.
- `git diff --check`: passed.

The first sandboxed test attempt failed because the Swift Preview macro service was unavailable under the sandbox. The same test command completed successfully outside that sandbox boundary; this was an execution-environment failure, not a code test failure.

### Isolated UI acceptance

UI acceptance used double isolation:

```text
Bundle ID: com.wangyucosmos.cosmostoolbox.persistenceui.run202609191902
suite: com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.9F2A6D1C-4E7B-4C3A-A8D9-1B6F5E2C7A40
DerivedData: /tmp/CosmosToolboxStorePhase1UIRun-20260919-1902
signing: ad hoc
```

Before destructive UI actions, PID, absolute executable path, Bundle ID, suite argument, and the root-level suite banner were rechecked. Only the `/tmp` App process was present.

Accepted scenarios (**note:** the Campaign and Workspace "acceptance areas" were DEBUG-only stand-in views, not the formal `ZhuowangCampaignView` / `ZhuowangCampaignDetailView` / Workspace Manager surfaces; see §11.3 — this acceptance therefore does **not** count as formal Campaign UI acceptance):

- Campaign `Phase1 UI Campaign` created, renamed to `Phase1 UI Campaign（已编辑）`, deleted, and remained deleted after restart;
- Workspace `Phase1 UI Workspace` created, renamed to `Phase1 UI Workspace（已编辑）`, deleted, and remained deleted after restart;
- the isolation suite banner remained visible from the Dashboard root through all pages;
- the Campaign and Workspace acceptance areas explicitly stated that they did not load Workflow Store;
- Dashboard and the normal Workspace surfaces showed no obvious regression after restart.

The first isolation-banner implementation existed only inside the Workspace surface. It was corrected before acceptance so the banner is attached at the Dashboard root and remains visible throughout the temporary App.

## 5. Workspace re-encoding incident

The first unsigned Universal App launch failed. A later CUA connection by the production Bundle ID attached to an already existing old App. Entering Workspace in that old build triggered its unconditional startup save.

The formal Workspace primary raw SHA-256 changed from:

```text
bc3657f54d3472a9bc3a24a556f701da24f5ce580e749255959d18b7b9335ce3
```

to:

```text
163b2189391e52019f31cb427b211d26fab85a888f13506591a89b0a54e9c4b0
```

Evidence established that both byte sequences encode the same Workspace object:

- all 103,680 object-key-order combinations allowed by the model were enumerated;
- the same Workspace object reproduced both complete raw hashes exactly;
- all fields, UUIDs, and array order are equal;
- canonical semantic SHA-256 remained `711fd948e14f10e31f465731f84c25dd75c5360f2b18e2004942beacd4c0843b`;
- other formal Data keys, Workspace files, and Prototype V1–V4 did not change.

No recovery, overwrite, or new formal Workspace backup was performed. Coordinating review accepted the current raw hash as the new formal byte baseline. The implementation removes the Workspace Store's unconditional startup save.

## 6. Test-host plist window-state event

The complete XCTest host used the production Bundle ID and added SwiftUI window-state preferences to the global plist. These keys are exclusively `NSWindow Frame` and `NSSplitView Subview Frames` entries. No pre-existing key was removed, and every formal business Data key remained byte-for-byte unchanged.

The final global plist diagnostic state before temporary-suite cleanup was:

```text
SHA-256: 70061e04623fb3e7c18a22c7e27674f9a57af6469e58f25edd9b4be027225c5c
mtime: 2026-09-19 19:04:50.575705 +08
```

This global plist hash is diagnostic because it includes window layout state. Formal business integrity is gated by per-key Data hashes and decoded-model checks.

## 7. Final formal data evidence before cleanup

```text
Campaign primary: 82aa61a074df39bbc6cf14e16a10e75caa93c37d01d38ef1593a43407a0b2c24
Campaign backup: absent
Workspace primary raw: 163b2189391e52019f31cb427b211d26fab85a888f13506591a89b0a54e9c4b0
Workspace canonical: 711fd948e14f10e31f465731f84c25dd75c5360f2b18e2004942beacd4c0843b
Workspace backup: absent
Workflow primary: a7e3dd5f7e2dc1c62f62d0e7490b660df59b3947eb0f90e293d7ad617dd02b61
Workflow backup: 530c64b35e138654bf6d648426e07e089d656fb75e913da372385b08f7b17194
Workspace tree: 117 entries, eb9c25438720547fa42aac5c5b15dbc0ea11e4479603e65175d1a207dc4a0368
Historical Sandbox plist: 4b768aef90722e43fa63e4f5cd9cb21269029fd7e0cf6f8587a276810f994ecb
Prototype V1: 99aa1cf0db2f030a629e813d42744c60335a6175e619f798833c4dcd18c17823
Prototype V2: 4587af3ecda7e1823b50567619dbf40c559f1bba6b22d2bfb3a1ac9937036eb6
Prototype V3: d8150faf51bac2f1b8ec11a4a007c4e70c5dcd821619c5d34531eb4dae0264ed
Prototype V4: 6911e40666e459f6afa42fa08690d167503644de65565b45eedaba7f0d0bc489
```

All 11 business Data keys matched the accepted baseline. Workflow steps remained 01–05 `approved`, 06 `ready`; Prototype V3 remained the adopted version.

## 8. Temporary-data cleanup

After isolated acceptance, the following exact temporary targets were removed with explicit user authorization:

- `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.FB5F1C26-D219-4484-ACB5-69871D06E0DB`
- `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.E093EDAF-00CA-4E67-BDFB-FA6184E71716`
- `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.18C4A58D-8DFB-492C-BB22-FBA81F9DC430`
- `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.9F2A6D1C-4E7B-4C3A-A8D9-1B6F5E2C7A40`
- repository-root `default.profraw` generated by the tests;
- `/tmp/CosmosToolboxStorePhase1UIRun-20260919-1902`.

`defaults delete` first emptied each suite domain and left a 42-byte, zero-key plist. Those four exact empty plist paths were then removed. Post-cleanup checks confirmed all six targets were absent and no Cosmos Toolbox process was running.

Only the six targets listed above were removed. Other `/tmp` artefacts from the same day (for example `/tmp/CosmosToolbox-StorePhase1-UI.app`, `/tmp/CosmosToolbox-StorePhase1-UIRun`, `/tmp/CosmosToolboxStorePhase1FullTests*`, `/tmp/CosmosToolbox-c7491a36*`, `/tmp/cosmos_ws_*`) were **not** removed and still exist; the zero-key `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.Tests.*.plist` files left by every XCTest run were also not removed (see §11.7).

The post-cleanup snapshot again matched all 11 formal business Data key hashes, the 117-entry Workspace tree, Workspace raw and canonical hashes, historical Sandbox plist, and Prototype V1–V4. The production Bundle domain, historical Sandbox, user Workspace, and old incident-evidence DerivedData were not removed.

## 9. Remaining boundaries

- No cross-process transaction or file lock.
- No automatic recovery from backup.
- No backup rotation beyond one last-known-good payload.
- No disk-level strong durability guarantee.
- No persistence-format or database migration.
- Step 06, Image / PDF Adoption and Recovery, and Artifact payload migration remain outside this phase.

## 10. Git status (Codex phase)

No commit, push, branch, tag, or squash was performed. The implementation and isolated acceptance remain pending human and coordinating review.

## 11. Claude independent review and directed fixes

### 11.1 Independent read-only review

Claude reviewed the uncommitted Phase 1 working tree (8 modified + 6 untracked files, HEAD `c7491a3`) against the HEAD baseline. Result: **P0 = 0, P1 = 0, P2 = 4, P3 = 10.** The 28-item persistence transaction checklist was proven item by item; no false-success, overwrite, or lock-bypass path was found. Release/Debug Universal builds passed. XCTest was not run during the review because the test host launches the App with the production Bundle ID (user decision).

P2 findings:

- **P2-1** The Debug `WindowGroup` root was `_ConditionalContent<DashboardView, (unknown context at $ADDR).CosmosStoreBootstrapBlockedView>`; the `private` type name embeds a memory address, so every Debug / test-host launch minted new `NSWindow Frame` / `NSSplitView Subview Frames` keys in the production plist (38 keys added between `c814b85c…` and `70061e04…`, all of this form).
- **P2-2** Isolated UI acceptance ran DEBUG stand-in views instead of the formal Campaign views, so the new formal-UI code (lock banner, disabled state, mutation-failure alerts) was compiled but never exercised.
- **P2-3** The "loads without re-encoding" / "legacy payload" tests built fixtures with the production `JSONEncoder()`, so a decode → re-encode round trip would have produced identical bytes and passed (self-referential). "Initializes only once" could not distinguish "no write" from "rewrote identical bytes".
- **P2-4** `DashboardView` wrapped `NavigationSplitView` in a `VStack` for the banner; never visually verified in the production configuration, and it re-indented ~143 lines.

### 11.2 Fixes applied (Claude, directed scope only)

- **P2-1 → fixed.** `WindowGroup { CosmosRootView() }` in every configuration; `CosmosRootView` is an internal, non-conditional struct. The DEBUG suite resolver and the production / isolated / blocked choice live inside it. `CosmosStoreBootstrapBlockedView` is no longer `private` and is never the window root. Verified: two further test-host launches added exactly the two stable keys `NSWindow Frame Cosmos_Toolbox.CosmosRootView-1-AppWindow-1` and `NSSplitView Subview Frames Cosmos_Toolbox.CosmosRootView-1-AppWindow-1, …` and **zero** new `(unknown context …)` keys. Existing window-state keys were not modified or cleaned. (Side effect: Release users' saved window frame moves from the `DashboardView` key to the `CosmosRootView` key once.)
- **P2-4 → fixed (revised in §13).** `DashboardView.body` was restored to `NavigationSplitView { … }` with the banner attached via `.safeAreaInset(edge: .top)` inside `#if DEBUG`. Round 5 UI acceptance showed that inset overlapping the sidebar; Codex then extracted the split view into a private `navigationContent` and renders the banner only in the DEBUG isolated branch as `VStack(spacing: 0) { banner; navigationContent }`, with the non-isolated Debug path and Release returning `navigationContent` directly.
- **P2-2 → fixed.** Removed `ZhuowangStorePhase1CampaignValidationView`, the DEBUG branch that substituted it for `ZhuowangCampaignView`, and the DEBUG "Workspace Store 隔离验收" section of the Workspace Manager. The Campaign category always renders the formal `ZhuowangCampaignView`. Workspace module update / delete remain Store API capabilities covered by XCTest; no formal UI is claimed for them.
- **P2-3 → fixed.** See §11.4.
- **P3-1 → fixed.** `isIsolated`, `isolationSuiteName`, `isolatedSuite(named:)`, the banner and its strings are inside `#if DEBUG`. Release binary scan: `CosmosDebugStorePersistenceBootstrap`, `ZhuowangStorePhase1CampaignValidationView`, `cosmos-store-phase1-suite`, `StorePhase1.UI`, `Store Phase 1 隔离测试数据`, `CosmosStoreBootstrapBlockedView`, `isolatedSuite`, `isolationSuiteName` all occur **0** times.
- **P3-3 → fixed, wording corrected in §12.** `writeVerificationFailed` is reached from several paths (initial write, encoding failure, backup write / read-back, primary write / read-back), so the user message must not promise a valid backup or an unchanged primary. Final wording: 「持久化校验失败，当前界面未发布本次变更。主数据或备份状态可能已经变化，Store 已锁定，请停止继续操作，并在重启前核对数据。」 No automatic rollback.
- **P3-9 / P3-10 → fixed** in `Docs/07` and this log (Store API vs formal UI; DEBUG stand-in ≠ formal acceptance; cleanup claims limited to what was actually removed).
- `productionDomainIdentifier` was **not** changed (P3-2 rejected by coordination); a comment now explains why it must stay a fixed literal.
- The persistence helper layer (`ZhuowangPersistenceDataSource`, `ZhuowangUserDefaultsDataSource`, `ZhuowangPersistenceLockRegistry`, `ZhuowangProtectedPersistence` and its result enums) is now explicitly `nonisolated`. The module's default actor isolation is `MainActor`, which had implicitly made the lock-owning helper main-actor-isolated; `nonisolated` matches its design and lets the concurrency tests race it honestly. Both Stores stay main-actor-isolated (module default). Correction to the review: the earlier P3-6 note that the Stores lack `@MainActor` was inaccurate — they are main-actor-isolated by the module default.

### 11.3 Formal Campaign UI acceptance — pending

Claude's environment has no reliable macOS native GUI driver, so **no UI acceptance was performed and none is claimed**. Required manual procedure (do not use the production Bundle ID):

1. Build Debug to a `/tmp` DerivedData with `PRODUCT_BUNDLE_IDENTIFIER=com.wangyucosmos.cosmostoolbox.persistenceui.<fresh-run-id>` and ad-hoc signing.
2. Launch the App by absolute path with `--cosmos-store-phase1-suite com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.<fresh UUID>`.
3. Before any write, record PID, executable path, Bundle ID (`lsappinfo` / `codesign -d`), the suite argument and that the orange banner is visible at the Dashboard root.
4. Campaign (formal `ZhuowangCampaignView` / `ZhuowangCampaignDetailView`): list → create → open detail → edit → save → delete → relaunch → deletion persists.
5. Failure paths: with the suite's `cosmos.zhuowang.campaigns.v1` replaced by non-JSON bytes, relaunch and confirm the orange lock banner, the disabled "新建活动" / "编辑" / "删除" controls, and that the create sheet's "创建" button is disabled; confirm no alert claims success.
6. Confirm the Workflow Store created by `ZhuowangCampaignView` wrote only into `~/Library/Preferences/<temporary Bundle ID>.plist` and that the production plist's 11 business `Data` keys are unchanged.
7. Workspace: formal page renders; with `cosmos.zhuowang.workspace.v1` corrupted, the locked page appears and "管理工作区" is disabled. No DEBUG manager exists any more.

### 11.4 Test reinforcement

Test support (`ZhuowangStorePersistenceTestSupport.swift`, test target only):

- `ZhuowangRecordingPersistenceDataSource` wraps any data source and records every write (count, per-key count, key, exact bytes); `makeRecordedSuite` wraps a real temporary `UserDefaults` suite in it.
- `ZhuowangInMemoryPersistenceDataSource` gained the same write log.
- `ZhuowangConcurrentInMemoryDataSource` is thread-safe, records writes and the maximum number of overlapping accesses, and adds an artificial delay to widen race windows.
- `ZhuowangHandWrittenPayload` holds raw JSON fixtures written by hand with non-canonical key order and legal whitespace; each test asserts the fixture differs from the production encoding before using it.

Rewritten tests: `testValidPayloadLoadsWithoutReencodingOrBackup` (Campaign, Workspace) and `testExistingPayloadNeedsNoMigration` now load hand-written bytes and assert primary bytes unchanged, primary writes = 0, backup writes = 0. `testMissingPrimaryInitializesOnlyOnce` / `…DefaultsOnlyOnce` assert exactly one primary write with the expected bytes on first load and a write delta of 0 on the second load. `testRestartPreservesProvinceUUIDs` now adds a custom province so the fixed default UUIDs alone cannot satisfy it.

New tests (12):

- Campaign: `testLegacyHandWrittenPayloadLoadsWithoutMigration`, `testCorruptPrimaryAndCorruptBackupLockWithoutValidBackup`, `testSuccessfulUpdatePersistsAndSurvivesRestart`, `testBackupWriteFailureLeavesPrimaryAndMemoryUntouched`.
- Workspace: `testCorruptPrimaryAndCorruptBackupLockWithoutValidBackup`, `testBackupWriteFailureLeavesPrimaryAndMemoryUntouched`.
- Boundary (DEBUG resolver): `testDebugBootstrapMissingSuiteValueFailsClosed`, `testDebugBootstrapPrefixedButInvalidUUIDFailsClosed`, `testDebugBootstrapProductionDomainAsSuiteFailsClosed` (also proves the factory is never called and `isolatedSuite(named: production)` returns nil).
- Concurrency (`ZhuowangProtectedPersistenceConcurrencyTests`, `nonisolated`, real threads via `DispatchQueue.concurrentPerform`): `testConcurrentInitializationWritesExactlyOnePrimary` (16 threads, distinct defaults → 1 primary write, 0 backup writes, identical value and baseline for all, max overlapping accesses = 1); `testConcurrentMutationsAreSerialisedWithoutLostUpdates` (8 threads × 25 increments with stale-retry → final value 200, primary writes 201, backup writes 200, backup = 199, stale rejections > 0, max overlapping accesses = 1); `testDifferentDomainsDoNotShareTheLock` (control: unlocked probe observes overlap > 1).

Existing `testWriteVerificationFailureDoesNotPublishCandidate` (both Stores) now also asserts that a further mutation stays rejected, that the primary write was attempted exactly once, and that a fresh Store on the same data locks with `hasValidBackup: true` without writing.

### 11.5 Verification after fixes

- Store-focused XCTest (4 classes): **41 passed, 0 failed, 0 skipped.**
- Complete XCTest: **156 passed, 0 failed, 0 skipped** (was 144 + 12 new).
- Universal macOS Debug build: succeeded, `x86_64 arm64`.
- Universal macOS Release build: succeeded, `x86_64 arm64`; string scan above all 0; `CosmosRootView` present.
- Compiler warnings in Phase 1 files: 0 (pre-existing warnings in `ArtifactPDFRendererTests.swift` unchanged).
- `git diff --check`: passed.
- DerivedData: `/tmp/Claude-CosmosStorePhase1-Tests`, `/tmp/Claude-CosmosStorePhase1-Debug`, `/tmp/Claude-CosmosStorePhase1-Release`; `LLVM_PROFILE_FILE` → `/tmp/Claude-CosmosStorePhase1-*.profraw`; no `default.profraw` in the repository.

### 11.6 Formal data gate before / after

All 11 business `Data` keys were read directly from `~/Library/Preferences/com.wangyucosmos.Cosmos-Toolbox.plist` with `plistlib` before the first and after the last test-host launch and are byte-for-byte identical (Workflow primary `a7e3dd5f…`, backup `530c64b3…`; Campaign primary `82aa61a0…`, backup absent; Workspace primary raw `163b2189…`, canonical `711fd948…`, backup absent; the seven AI keys unchanged). Workspace tree 117 entries `eb9c2543…`, historical Sandbox plist `4b768aef…`, Prototype V1–V4 hashes, Workflow steps 01–05 `approved` / 06 `ready` and adopted prototype V3 unchanged. The whole-plist SHA-256 changed only because the XCTest host wrote the two stable `CosmosRootView` window-state keys (diagnostic indicator only). `(unknown context …)` key count: 64 before, 64 after.

### 11.7 Temporary targets created by this phase (not cleaned; awaiting authorisation)

- `/tmp/Claude-CosmosStorePhase1-Tests`, `/tmp/Claude-CosmosStorePhase1-Debug`, `/tmp/Claude-CosmosStorePhase1-Release` (DerivedData), `/tmp/Claude-CosmosStorePhase1-*.log`, `/tmp/Claude-CosmosStorePhase1-*.xcresult`, `/tmp/Claude-CosmosStorePhase1-*.json`, `/tmp/Claude-CosmosStorePhase1-snapshot.py`, `/tmp/Claude-CosmosStorePhase1-prefsprobe*`.
- Zero-key `~/Library/Preferences/com.wangyucosmos.Cosmos-Toolbox.StorePhase1.Tests.*.plist` files (cfprefsd re-creates them at process exit even after `removePersistentDomain`; unlinking in `tearDown` was tried and reverted because it is ineffective). They contain no data. Counts: 169 before this phase (from Codex's runs); this phase added **116** XCTest suite plists (`…Tests.<label>.<UUID>.plist`) and **2** `…Tests.ClaudeProbe.<UUID>.plist` from the cfprefsd probe, i.e. **287** `Tests`-prefixed empty plists in total (exact list of the 118 new ones in `/tmp/Claude-CosmosStorePhase1-new-test-suite-plists.txt`). **None of these have been cleaned.**
- `~/Library/Preferences/com.wangyucosmos.cosmostoolbox.persistenceui.run202609191902.plist` — the temporary-Bundle-ID preference domain of Codex's isolated UI run; still present, **not cleaned**.
- LaunchServices registrations of the `/tmp` Debug / Release / test-host apps (registered by xcodebuild; none launched interactively).

### 11.8 Deferred

Finer mutation-failure enumeration; built-in module deletion rule; whole-Store `@MainActor` migration (moot — module default isolation already applies); stale-conflict reload affordance; duplicate `allowsMutations` guards; automatic backup rotation / recovery; cross-process locking.

### 11.9 Status

Claude findings fixed and re-verified. Formal Campaign UI acceptance pending. Not committed; awaiting independent re-review and coordinating acceptance.

## 12. Second independent re-review and P2-A

### 12.1 Re-review outcome

P0 = 0, P1 = 0; the four P2 items were confirmed closed; the `nonisolated` boundary and the concurrency tests were accepted. One new finding, **P2-A**: with the production Bundle ID and a valid `--cosmos-store-phase1-suite` argument, Campaign / Workspace would use the temporary suite and show the isolation banner while the Workflow and AI Stores kept using the production `UserDefaults.standard` — a misleading, partial isolation.

### 12.2 P2-A fix

`CosmosDebugStorePersistenceBootstrap.resolve(arguments:bundleIdentifier:defaultsFactory:)` (DEBUG only) now accepts an isolated suite only when **all** of the following hold: the suite name has the temporary suite prefix, ends in a valid UUID and is not the production domain; **and** the running Bundle ID is non-nil, non-empty, not the production domain and starts with `com.wangyucosmos.cosmostoolbox.persistenceui.`. Any suite argument under the production Bundle ID, an empty / unreadable Bundle ID or any other Bundle ID yields `.blocked("检测到隔离suite参数，但当前App不是获准的临时UI验收Bundle，已阻止启动。")` before the suite name is examined and before the `UserDefaults` factory is called. `bundleIdentifier` is injectable for tests and defaults to `Bundle.main.bundleIdentifier`. `productionDomainIdentifier` remains the fixed literal. The isolation banner now shows both the temporary Bundle ID and the temporary suite. Launches **without** the suite argument still enter production for every Bundle ID (unchanged design; Debug development builds read `UserDefaults.standard`).

Static proof for "blocked ⇒ no Store": `CosmosRootView.body` switches on the resolver result; `.ready(configuration)` is the only branch that constructs `DashboardView` (and, through it, `ZhuowangWorkspaceView` → Campaign / Workspace Stores and, via `ZhuowangCampaignView`, the Workflow Store); `.blocked(message)` constructs only `CosmosStoreBootstrapBlockedView(message:)`, which holds a `String` and no Store. `.blocked` carries no configuration by type.

### 12.3 New / rewritten tests (DEBUG resolver)

`testDebugBootstrapWithoutArgumentUsesProductionConfiguration` (production, isolated, unrelated, empty and nil Bundle IDs all enter production without the argument), `testDebugBootstrapAcceptsIsolatedBundleWithUUIDSuite`, `testDebugBootstrapProductionBundleWithValidSuiteIsBlocked` (exact message; factory calls = 0), `testDebugBootstrapNonIsolatedBundlesWithValidSuiteAreBlocked` (unrelated / test-bundle / near-miss prefix / empty / nil; factory calls = 0), `testDebugBootstrapIsolatedBundleWithInvalidSuiteIsBlocked` (no prefix / bad UUID / production domain), `testDebugBootstrapMissingSuiteValueFailsClosed`, `testDebugBootstrapProductionDomainAsSuiteFailsClosedAtEveryLayer`, `testDebugBootstrapFactoryFailureDoesNotFallBackToStandard`, `testBlockedBootstrapCarriesNoConfiguration`. Boundary class: 14 tests (was 12).

Low-risk follow-ups in the same pass: Dashboard comment no longer claims "byte-identical to Release"; both legacy hand-written payload tests assert the fixture differs from the production encoding before use; the concurrency control test is renamed `testOverlapCounterDetectsParallelAccessWithoutSharedLock` with a comment stating exactly what it proves; `ZhuowangPersistenceLockRegistry` documents that `locks` is guarded exclusively by `registryLock`.

### 12.4 Verification of the P2-A change

- Universal Release build: succeeded, `x86_64 arm64`; Release string scan (`CosmosDebugStorePersistenceBootstrap`, `cosmos-store-phase1-suite`, `StorePhase1.UI`, `Store Phase 1 隔离测试数据`, `com.wangyucosmos.cosmostoolbox.persistenceui.`, `com.wangyucosmos.Cosmos-Toolbox.StorePhase1`, `检测到隔离suite参数`, `CosmosStoreBootstrapBlockedView`, `isolationBundleIdentifier`, `isolatedSuite`) all **0**; `CosmosRootView` present.
- Universal Debug build: succeeded, `x86_64 arm64`; 0 warnings in Phase 1 files; `git diff --check` clean.
- Preferences isolation: a standalone probe with `CFFIXED_USER_HOME=/tmp/CosmosStorePhase1-TestHome-<UUID>` redirected `NSHomeDirectory()` but **not** cfprefsd writes (the suite plist still landed in the real `~/Library/Preferences`; one empty `…Tests.HomeProbe.<UUID>.plist` resulted). Coordination therefore decided (2026-09-20) to run the tests with the existing UUID temporary suites, to accept new empty `Tests`-prefixed plists as a known test by-product, and to gate formal data safety on the 11 business `Data` keys only. Path-based suites and a command-line override of the test host's `PRODUCT_BUNDLE_IDENTIFIER` were explicitly not adopted for this milestone.
- **XCTest actually run on 2026-09-20 with the final P2-A sources:** Store-focused (4 classes) **43 passed, 0 failed, 0 skipped**; complete suite **158 passed, 0 failed, 0 skipped**. The nine DEBUG-resolver tests listed in §12.3 all executed and passed, i.e. production Bundle + valid suite → blocked with factory calls = 0; unrelated / empty / nil Bundle + valid suite → blocked; isolated Bundle + valid suite → isolated; isolated Bundle + invalid suite → blocked; no suite argument → production; production domain rejected as suite at every layer; factory failure does not fall back to standard; `.blocked` carries no configuration.
- Formal data gate before / after the two test-host launches: all 11 business `Data` keys byte-identical (Workflow primary `a7e3dd5f…`, backup `530c64b3…`; Campaign primary `82aa61a0…`, backup absent; Workspace primary `163b2189…`, canonical `711fd948…`, backup absent; seven AI keys unchanged); Workspace tree 117 entries `eb9c2543…`, historical Sandbox plist `4b768aef…`, Prototype V1–V4, Workflow 01–05 `approved` / 06 `ready`, adopted V3 all unchanged. The global plist SHA-256 `ebf06c9b…` and its mtime (2026-09-19 21:15:40) did **not** change: the host re-wrote identical values for the two stable `CosmosRootView` keys, no key was added or removed, and the `(unknown context …)` count stayed at 64. The whole-plist hash remains a diagnostic indicator only.
- Test by-product: 58 new empty `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.Tests.<label>.<UUID>.plist` files (29 per host launch), bringing the total to **346**. An inventory of every such file (absolute path, 42 bytes, SHA-256 `9261ecce…`, `plutil` empty dictionary, pattern match) is saved at `/tmp/Claude-CosmosStorePhase1-empty-test-plists-inventory.json` / `.tsv`. All 346 are empty dictionaries; none contains a business key. **Nothing has been deleted; cleanup awaits separate authorisation.**

### 12.5 Temporary targets from this pass (not cleaned)

- `/tmp/CosmosStorePhase1-TestHome-1019AA96-95F6-4F77-8612-1094ADA4A33F` (empty probe home), `/tmp/Claude-CosmosStorePhase1-homeprobe`, `/tmp/Claude-CosmosStorePhase1-homeprobe.swift`, `/tmp/Claude-CosmosStorePhase1-testhome.txt`, `/tmp/Claude-CosmosStorePhase1-r3-*.log`, `/tmp/Claude-CosmosStorePhase1-r4-*.log`, `/tmp/Claude-CosmosStorePhase1-r4-*.xcresult`, `/tmp/Claude-CosmosStorePhase1-r4-FullTests-tests.json`, `/tmp/Claude-CosmosStorePhase1-snapshot-r3-*.json`, `/tmp/Claude-CosmosStorePhase1-snapshot-r4-*.json`, `/tmp/Claude-CosmosStorePhase1-snapshot-r4.py`, `/tmp/Claude-CosmosStorePhase1-empty-test-plists-inventory.{json,tsv}`.
- `~/Library/Preferences/com.wangyucosmos.Cosmos-Toolbox.StorePhase1.Tests.*.plist` — 346 empty files (inventory above).
- `~/Library/Preferences/com.wangyucosmos.cosmostoolbox.persistenceui.run202609191902.plist` — Codex's temporary UI Bundle domain: 1,655 bytes, 6 window-state keys, **no** `Data` keys; not cleaned.

### 12.6 Status (superseded by §13)

P2-A tests executed and passed; formal business data unchanged; awaiting temporary-data cleanup authorisation and real Campaign UI acceptance; not committed.

## 13. Formal Campaign UI acceptance, cleanup and pre-commit state (2026-09-20)

### 13.1 Round 5 (stopped) and the banner layout fix

Round 5 built an isolated Debug App (`PRODUCT_BUNDLE_IDENTIFIER=com.wangyucosmos.cosmostoolbox.persistenceui.r5202609200936-af8d8d3a`, ad-hoc signed, `/tmp/Claude-CosmosStorePhase1-UI-R5`, launched by absolute path with suite `…StorePhase1.UI.261489DB-…`). The root banner showed the correct Bundle ID and suite, but the `.safeAreaInset(edge: .top)` banner visibly overlapped the sidebar navigation and the top of the content area and appeared to intercept clicks. The run was stopped before any Campaign was created; the App was terminated normally; the healthy suite held only default-initialised data (0 campaigns, no backup); formal data was unchanged; no code was modified in that round.

Codex then applied the single-point layout fix in `DashboardView.swift` only: `.safeAreaInset` removed; the `NavigationSplitView` extracted unchanged into `private var navigationContent`; `body` returns `VStack(spacing: 0) { isolatedSuiteBanner; navigationContent }` only under `#if DEBUG` when `isIsolated`, otherwise (Debug non-isolated and Release) `navigationContent`. `CosmosRootView`, the resolver and the banner text were untouched (Claude verified the diff against HEAD: +84 / −1 in that file, no other source change).

### 13.2 Round 6 — formal Campaign UI acceptance (passed)

Identity: Bundle `com.wangyucosmos.cosmostoolbox.persistenceui.r620260920100655-1327c0a9`, suite `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.7587286B-6AB6-4762-B3C3-FD50D0BB72CC`, App `/tmp/CosmosToolboxStorePhase1UIRound6-20260920100655-1327c0a9/Build/Products/Debug/Cosmos Toolbox.app`, launched by absolute path; before every restart the PID, executable path, Bundle ID and suite argument were re-checked and the process was the only Cosmos Toolbox process.

Through the formal `ZhuowangCampaignView` / `ZhuowangCampaignDetailView` (no DEBUG stand-in exists any more):

1. created `Phase1 Real UI Campaign R6`; edited to `Phase1 Real UI Campaign R6（已编辑）` — suite then held 1 primary record and a backup holding the pre-edit record (same id, older `updatedAt`);
2. normal TERM, first restart with the identical identity by Claude (CWD `/tmp`, `LLVM_PROFILE_FILE` in `/tmp`): primary and backup bytes identical before and after; UI showed the edited record;
3. deleted the only record through the detail window; list showed `0 个活动`, no error alert, Store not locked, banner layout normal;
4. normal TERM, second restart with the identical identity: suite read three times (running / after exit / after restart) byte-identical — primary `[]` (0 records, SHA `4f53cda1…`), backup = the pre-delete edited record (SHA `6ba929a4…`), Workspace primary unchanged and decodable, no Workspace backup; UI showed the empty list.

Dashboard, Workspace overview, Campaign list and detail showed no obvious visual regression. Workflow isolation proof: the temporary Bundle domain gained `cosmos.zhuowang.ai.providers.v1` (temporary defaults written by the Workflow / AI Stores through `UserDefaults.standard` of the temporary Bundle) while the formal `ai.providers` key and every other formal `Data` key stayed byte-identical; the suite contained no workflow / AI keys; the formal plist never contained the temporary Bundle ID, the suite UUID or the test campaign name.

Formal data gate at every checkpoint (Round 5 start, Round 5 stop, Round 6 running, after each restart, after final termination, before and after cleanup): all 11 business `Data` keys byte-identical to the accepted baseline (Workflow primary `a7e3dd5f…`, backup `530c64b3…`; Campaign primary `82aa61a0…`, backup absent; Workspace primary raw `163b2189…`, canonical `711fd948…`, backup absent; seven AI keys unchanged); Workflow steps 01–05 `approved` / 06 `ready`, adopted prototype V3; Workspace tree 117 entries `eb9c2543…`; Prototype V1–V4; historical Sandbox plist `4b768aef…`; global plist SHA-256 `ebf06c9b…` and mtime unchanged since 2026-09-19 21:15:40 (71 window-state keys, 64 `(unknown context …)`, 2 stable `CosmosRootView`).

Summary of verification for this milestone: Store-focused XCTest 43 / 43; complete XCTest 158 / 158; Universal Debug and Release builds succeeded (`x86_64 arm64`); Release binary scan for `CosmosDebugStorePersistenceBootstrap`, `cosmos-store-phase1-suite`, `StorePhase1.UI`, `Store Phase 1 隔离测试数据`, the temporary Bundle prefix, the suite prefix, the blocked-bundle message, `CosmosStoreBootstrapBlockedView`, `isolationBundleIdentifier`, `isolatedSuite` all 0; P2-A double isolation (temporary Bundle ID prefix **and** UUID suite) enforced by the DEBUG resolver; stable `CosmosRootView` root; banner rendered only in the DEBUG isolated branch.

Boundaries that remain true after acceptance: the lock is process-local, not cross-process; UserDefaults read-back is in-process consistency, not a disk flush or strong transaction; no automatic recovery, backup rotation or format migration; the whole-plist hash is a diagnostic indicator only — the 11 business `Data` keys are the formal gate; the formal Workspace UI offers create only (province / category / module); module update / delete are Store API capabilities covered by XCTest, not formal UI features.

### 13.3 Authorised cleanup (executed 2026-09-20)

After terminating the last Round 6 process (PID 43404, identity re-checked, exited normally, no other Cosmos Toolbox process), the following exact targets were removed under explicit authorisation, each verified immediately before deletion:

- `~/Library/Preferences/com.wangyucosmos.cosmostoolbox.persistenceui.r5202609200936-af8d8d3a.plist` (2 window-state keys, 0 Data keys) — deleted;
- `~/Library/Preferences/com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.261489DB-F586-4E96-9D40-F70DB282AA14.plist` (default-initialised campaigns `[]` + workspace, no backup) — deleted;
- `~/Library/Preferences/com.wangyucosmos.cosmostoolbox.persistenceui.r620260920100655-1327c0a9.plist` (2 window-state keys + temporary `ai.providers`; no payload byte-identical to any formal key) — deleted;
- `~/Library/Preferences/com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI.7587286B-6AB6-4762-B3C3-FD50D0BB72CC.plist` (campaigns `[]`, backup = edited record, workspace) — deleted;
- `~/Library/Preferences/com.wangyucosmos.cosmostoolbox.persistenceui.run202609191902.plist` (6 window-state keys, 0 Data keys, no formal data) — deleted;
- the 346 empty `com.wangyucosmos.Cosmos-Toolbox.StorePhase1.Tests.<label>.<UUID>.plist` files listed in `/tmp/Claude-CosmosStorePhase1-empty-test-plists-inventory.json`, deleted one by one from the inventory's resolved absolute paths after re-checking each (in `~/Library/Preferences`, pattern match, regular file, 42 bytes, SHA-256 `9261ecce…`, `plutil -p` = `{}`, 0 keys): **346 deleted, 0 skipped**;
- `<repo>/default.profraw` (regular file, untracked, 0 bytes, SHA-256 `e3b0c442…`, created by the Round 6 App launch with the repository as CWD) — deleted.

Domains were emptied with `defaults delete` before their files were removed; no wildcard or recursive deletion was used. Post-cleanup: none of the above paths exist; `~/Library/Preferences` contains no `StorePhase1` or `persistenceui` file; the formal `com.wangyucosmos.Cosmos-Toolbox.plist` still exists with all 11 business `Data` keys byte-identical, no Campaign / Workspace backup, and unchanged Workspace, Workflow, V1–V4, file tree and historical Sandbox. Cleanup report: `/tmp/Claude-CosmosStorePhase1-r7-cleanup-report.json`.

Not removed (retained as evidence for now): every `/tmp/Claude-CosmosStorePhase1-*` DerivedData, xcresult, log, snapshot, script and inventory; `/tmp/CosmosToolboxStorePhase1UIRound6-*`; Codex's earlier `/tmp/CosmosToolbox*` and `/tmp/cosmos_ws_*` artefacts; LaunchServices registrations of the `/tmp` apps.

### 13.4 Pre-commit state

`git diff --check` clean; no `.profraw` in the repository; working tree = 8 modified files (`Cosmos_ToolboxApp.swift`, `DashboardView.swift`, `ZhuowangCampaignDetailView.swift`, `ZhuowangCampaignStore.swift`, `ZhuowangCampaignView.swift`, `ZhuowangWorkspaceStore.swift`, `ZhuowangWorkspaceView.swift`, `Docs/07_Cosmos_OS_Current_Status.md`) + 7 untracked files (`ZhuowangProtectedPersistence.swift`, the four Store persistence test files, `ZhuowangProtectedPersistenceConcurrencyTests.swift`, this log). HEAD is still `c7491a3`; nothing has been committed or pushed. Commit / push require explicit user authorisation.
