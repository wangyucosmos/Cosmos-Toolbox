# 2026-10-09 Cosmos OS Development Log

## Goal and authority

Implement 知识与资产中心 Phase 1 from the approved read-only investigation. Authorized: implementation, necessary isolated verification and formal progress documentation. Not authorized: commit, push, merge. Opening preflight confirmed clean main, HEAD/origin `e2c615165fef4951d6dec99915949bddfbab2aa1`, parent `e15bf38f35509dbb453373b0474f92ce14a495d0`. Reused the already-read AGENTS / Docs / dependency investigation; no full redundant reread.

## Files

New App sources under `Apps/CosmosOS/Cosmos Toolbox/`:

- `ZhuowangAssetCatalogModels.swift`: entries, filters, matches and immutable body/request projections.
- `ZhuowangAssetCatalogReader.swift`: primary-data-only snapshot, bounded consistency retry, source association and adoption counts.
- `ZhuowangAssetTextReader.swift`: queue-confined safe file admission, bounded UTF-8 reads, fingerprints, cancellation and LRU.
- `ZhuowangAssetCatalogViewModel.swift`: debounce / generation, search, refresh, controlled Document and injected actions.
- `ZhuowangAssetCenterView.swift`: existing Knowledge Base entry's actual asset UI.
- `ZhuowangAssetDetailView.swift`: independent native read-only exact-version detail/window manager.

Modified App sources:

- `DashboardView.swift`: Knowledge Base route and DEBUG isolated-root / initial-sidebar support.
- `ArtifactReviewWorkspace.swift`: close a tracked document preview during asset-center refresh.

New tests: `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangAssetCenterTests.swift`.
Documentation: `Docs/07_Cosmos_OS_Current_Status.md` and this log. Actual repository AGENTS.md does not require PROJECT_BRIEF/PAGE_MAP/DATA_MAP/CHANGELOG; the latest user instruction excludes creating those extra files, so none were created.

## Decisions and boundaries

Reuse existing Codable types, versionGroupKey, typed Review projection, Renderer registry and native Review; do not construct mutating business Stores. Keep metadata content authoritative and unchanged; use an explicit local file only when no nonempty metadata body exists. 2 MiB text limit and 32 MiB cache; no truncated substitute, normalization, persistent index or external scan. Group Campaign UUID + logical identity; conflict visible, no automatic adoption/repair. No Campaign-detail route, Compare, AI operation or Word WIP restoration. Snapshot errors / missing keys / associations are explicit. Details invalidate vanished versions; actions re-resolve; refresh closes tracked stale previews.

## Concentrated verification and one repair round

Initial targeted batch: 40 tests, 36 passed / 4 failed, all involving file-backed text. Existing-path Foundation standardization rewrote `/private/tmp` as `/tmp`, which then hit the explicit symlink guard. Concentrated repair kept exact references without weakening symlink admission; added full-read-length verification and byte-exact Unicode comparison, refreshed Review invalidation and two related tests. No second fix round.

Final affected batch: **42/42**, no skips = **15 asset / 27 Review**. Result: `/private/tmp/CosmosAssetPhase1-Validation/Fixed.xcresult`. Named Pasteboard preserves complete raw text; injected Finder captures exact temporary URL. Read-only source records zero writes from initial load, absent keys do not seed defaults, corrupt primary does not read backup, changing snapshots fail within two attempts. Version conflicts, older current version, orphan associations, historical-only search, same-ID body refresh, removed UUID, fingerprint-based cache invalidation, cancellation, bounded cache, invalid paths / links / permissions / UTF-8 / size are covered.

Final Universal Debug / Release **BUILD SUCCEEDED**, both `x86_64 arm64`, signing disabled. Logs: `/private/tmp/CosmosAssetPhase1-debug-final.log`, `/private/tmp/CosmosAssetPhase1-release-final.log`. Release scan found zero instances of the three isolation launch strings. Existing Review SwiftUI State warning and AppIntents no-dependency extraction warning recorded; no new compile failure or actor warning.

Offscreen rendering: actual asset center and detail views produced PNG evidence. Real App automation: only temporary Bundle ID + UUID suite + explicit temporary root; current mode excludes historical-only body hit, All Versions finds exact V3, native detail switches to adopted V1, Text Review displays the controlled body, Finder selects temporary Markdown. General clipboard button was not clicked. Temporary suite business hashes and source SHA-256 match the fixture; no unexpected cosmos keys. Fixture evidence `/private/tmp/CosmosAssetPhase1-DB2B0E1E-B554-484A-8477-89B4D402B7F0/`, integrity `ui-integrity.json`.

CUA quit / subsequent state observation left a temporary App process on an unbannered Dashboard. The exact executable under the temporary build root was terminated; no process was targeted by the shared display name. Temporary suites/evidence are retained for review, no broad preference cleanup. Formal App / Workspace / personal knowledge repositories were not used as test samples; no sample Campaign detail or Harness run.

## Remaining and handoff to Claude

No blocking test/build failure known. Review the read-only snapshot initialization boundary, orphan/group identity, zero/one/multiple adoption selection, authoritative text and equality states, size/cache accounting, queued cancellation/generation, file-admission race checks, controlled Review resolution, detail refresh/UUID disappearance and DEBUG fail-closed root gate. Verify preview-window UUID reuse / refresh interactions with other existing entry points. Do not expand to old P3 or Word WIP.

Unverified UI: general clipboard round trip, still-open preview closure on refresh, all filters/file Renderers, restart and large metadata responsiveness. Named Pasteboard and interface assertions are not end-to-end UI acceptance. Snapshot decode is UI-actor work; invalid-UTF8 failures may be re-read on later queries; both are follow-up performance work, not justification for persistence refactoring.

Next: one concentrated independent review if requested, then await explicit owner closeout instruction. No commit/push/merge; all changes remain unstaged on main. Final diff and Git state are reported from actual commands after documentation writes.

## Formal closeout after concentrated review

The owner reported Claude’s one concentrated read-only review conclusion **A: 可收尾**, with no discovered blockers, and authorized formal documentation closeout, one `feat: 新增知识与资产中心` commit and normal push to origin/main. This supersedes the earlier awaiting-review / uncommitted handoff checkpoint; no source change or follow-up repair is included in closeout.

Claude independently read the final `/private/tmp/CosmosAssetPhase1-Validation/Fixed.xcresult`: **42/42 passed, 0 skipped**, later than the last source modification. Builds and real-App operations are Codex’s original records above; Claude did not rerun them. Closeout read the existing xcresult and checked source modification times; it did not rerun tests/builds or launch any App. The phase closes on existing evidence, without claiming complete end-to-end UI acceptance.

Git preflight: main and post-fetch origin/main both `e2c615165fef4951d6dec99915949bddfbab2aa1`, parent `e15bf38f35509dbb453373b0474f92ce14a495d0`; staging empty, exactly 11 phase files. Full tracked diff and all new-file contents inspected. Closeout changes only Current Status and this log; explicit-path staging, staged-diff review, whitespace checks and post-push fetch/ref/clean/ahead-behind verification are the delivery procedure. Actual commit and synchronization outcome are reported from final Git commands.

Word WIP remains local at `wip/markdown-word-export-phase1-20260930`, commit `2d26b2a2d4c0f719c9562ec0303dac3bdc2dfa51`, unmerged and unpushed. No Harness, adoption, Evidence/Quarantine, old P3, formal Workspace or other knowledge-repository operations. No extra root documents.

### Concentrated review follow-ups (non-blocking; not repaired in this phase)

- **F1:** 离开资产中心后，已打开详情保留旧元数据快照，采用标签可能过期；复制仍对应窗口显示版本。后续优先考虑快照标识及重新核对采用状态。
- **F2:** 详情读取与搜索共用代次，搜索变化可能使详情读取失效并停留在重新核对状态。
- **F3:** 资产中心与 Campaign Review 共用窗口身份，后续打开可替换内容，资产中心刷新可能关闭共享窗口。
- **F4:** 无法读取正文的资产可能在正文搜索中缺席，缺少搜索覆盖提示；按名称仍可定位。
- **F5:** 隔离根过滤、Review close、并发测试覆盖及 sleep 稳定性待完善；相关边界与时序的自动化证据仍有限，后续增强，不扩大本轮验收声明。

Next: wait for product coordination to select the next major module. F1–F5 remain deferred; do not automatically begin implementation or another repair round.


## Prompt Vault Phase 1 — implementation and blocked handoff

### Authority / preflight

Owner approved the prior read-only proposal and authorized source implementation, necessary isolated verification and these two formal progress documents; no commit/push/merge/WIP restoration. Preflight clean main, HEAD `db15f790450da5f1a5107ee78e6076c0e3ff2ed1`, parent `e2c615165fef4951d6dec99915949bddfbab2aa1`, empty staging, no changed investigation files. Reused prior source/document investigation. This appended section does not replace the asset-center history above.

### Files / decisions

New App sources: `PromptVaultModels.swift`, `PromptVaultFileStorage.swift`, `PromptVaultStore.swift`, `PromptTemplateRenderer.swift`, `PromptVaultViewModel.swift`, `PromptVaultView.swift`, `PromptTemplateEditor.swift`. New tests: `PromptTemplateRendererTests.swift`, `PromptVaultPersistenceTests.swift`, `PromptVaultStateTests.swift`. Modified `DashboardView.swift` for existing route/DEBUG launch root; `Cosmos_ToolboxApp.swift` adds only the announced minimal native termination delegate adaptor. Current Status §17 and this append are the only documentation updates. No extra root documents or project.pbxproj edit.

Independent FileManager Application Support JSON; single validated previous backup, dedicated flock, latest-disk per-template transaction, byte readback before state publication, conflict/uncertain/corrupt states. No document revision duplicating template revision/raw transaction baseline. 16 MiB document limit rejects rather than truncates. Symlink and file-type admission, no-follow read, atomic sibling temporary-write/rename. No automatic backup recovery or old Store dependency. Native editor owns draft; use-detail consumes saved templates. Values are transient per UUID. Native close/quit save/discard/cancel; pending quit freezes editor input and blocks opening more editors.

### Concentrated verification / one repair

Initial targeted xcodebuild test failed in compile: omitted key-path backslashes in new files; zero tests executed (`Initial.xcresult`, `initial.log`). One concentrated repair corrected key paths and added pending-termination editor freezing. Final affected batch `Fixed.xcresult`: **36/36 passed, 0 skipped** (22 Prompt / 14 existing persistence-boundary). No full-suite repetition. Test host `com.wangyucosmos.cosmostoolbox.persistenceui.promptphase1tests`, UUID roots beneath `/private/tmp/CosmosPromptVaultPhase1-*`, isolated suites and DerivedData.

Universal Debug / Release **BUILD SUCCEEDED**, `x86_64 arm64`, signing disabled. Four DEBUG launch markers absent from Release. Logs and `release-scan.json`: `/private/tmp/CosmosPromptVaultPhase1-Validation/`. Test execution was arm64, not both architectures. Named Pasteboard exact-copy passed; actual Prompt view offscreen rendering passed but generated PNG was cleaned at test teardown. FocusState offscreen warning recorded; existing AppIntents/PDF warnings did not fail checks.

Two CUA initialization attempts timed out (30s / 20s), so no standalone App was launched and no real UI/restart/clipboard/close/quit acceptance is claimed. No framework workaround or user click-through. Temporary-host business Data keys remained equal during Prompt operations; Prompt dependency audit found no Campaign/Workflow/Artifact Store construction/write. Formal business file hashes were not read/revalidated; no formal App/Workspace or other knowledge repository operations.

### Final semantic blocker / stopping gate

A targeted final Foundation semantic check found `CharacterSet.letters.contains(U+0301) == true` (generalCategory nonspacingMark). Current renderer uses this set for first-character admission, so leading combining marks are incorrectly parsed as variables; approved grammar requires a Unicode letter or underscore. Existing passing cases do not cover leading marks. Evidence: `semantic-boundary.txt` under the verification root. This is a parser-contract acceptance blocker. The one-repair budget is exhausted; **no second source repair** was performed. Recommended narrow next fix: explicitly allow only Unicode letter general categories or underscore as first scalar and add a leading-mark regression, then verify Renderer affected tests only plus required affected compile checks under fresh authority.

Non-blocking/coverage review items: no explicit concurrency overlap barrier (real flock + async writers tested); real unreadable-file permission failure and parent replacement races not tested; file-error hooks cover stage failure/nonpublication without proving every filesystem mode. UI window identity reuse/quit alerts/input freeze, module-exit cleanup and layout remain unaccepted. Lock only coordinates cooperating writers; no hostile-directory-race or power-loss durability guarantee.

### Concentrated read-only review handoff / Git

Review only Prompt transaction ordering, flock and target revision, unrelated-template preservation, UTF-8 exactness, parser grammar/invalid spans/slash parity/nonrecursion, saved-vs-draft/temporary-state separation, native close and deferred quit cancellation, and DEBUG Bundle/suite/root failure. Include the known leading-mark blocker; do not infer acceptance from 36 passing tests. Do not repair F1–F5, old P3 or restore Word WIP. Owner must authorize any next repair round.

Main remains at the authorized baseline with all phase changes unstaged, no commit/push/merge. Final diff/whitespace/Git inspection follows documentation writes; report actual results in chat. Word WIP, Harness, Step 06 adoption, Evidence/Quarantine and other knowledge repositories were not touched. No production Prompt library was created. Current phase is **implemented but blocked before acceptance**, awaiting review / next instruction.


## Prompt Vault Phase 1 — Claude takeover, concentrated review and unicode fix

### Authority / baseline

Codex paused on quota; Claude took over as lead engineer with a single bounded repair authorized. Verified: `main` = `origin/main` = `db15f790450da5f1a5107ee78e6076c0e3ff2ed1`, empty index, 4 modified + 10 untracked files exactly as handed over (all kept); `project.pbxproj` unchanged. Source hashes of the unchanged Prompt/App files match Codex's `source-sha256.json`.

### Review (read all sources, not just the diff)

Read Models, FileStorage, Store, Renderer, ViewModel, View, Editor, App delegate and Dashboard diff. Storage transaction order (lock → latest disk → target revision → candidate from disk → backup + read-back → atomic rename → read-back before publish), unrelated-template preservation, byte exactness, draft retention, quit deferral, DEBUG root fail-closed (isolated without valid flag/bundle/UUID path → blocked, never production) and no Campaign/Workflow/Artifact Store reference in Prompt code: no blocker. Todos recorded in Current Status §17.

### Fix (one round)

Reproduced with a standalone compile of the renderer: `CharacterSet.letters.contains(U+0301)` true, `{{U+0301 a}}` yielded a variable. `validName` now judges per Unicode scalar by general category (first: `_` or L*; rest: `_`, `-`, L*, M*, Nd). Added `testLeadingCombiningMarkIsInvalidAndPreserved` and `testLetterFollowedByMarksAndMixedNamesStayValid`.

### Verification

`xcodebuild test` on Renderer + PromptVaultState suites (isolated bundle `...promptphase1tests`, DerivedData and xcresult under `/private/tmp/CosmosPromptVaultPhase1-TakeoverValidation/`): **16/16 passed, 0 failed, 0 skipped**. Persistence suite and storage were not re-run (files unchanged, hashes identical); earlier 36/36 and Universal Debug/Release evidence reused. No production Application Support directory created. No real-App launch.

### State

Blocker resolved; Phase 1 awaits product-owner wrap-up. Nothing committed, staged, pushed or merged. Word WIP, Harness, Evidence/Quarantine untouched.


## Prompt Vault Phase 1 — closure

The product owner accepted the existing verification scope and formally closed Phase 1, authorizing one `feat: 新增提示词库与变量模板` commit and a normal push to origin/main. Only the two progress documents were edited for closure; no source change, test, build or UI run.

Evidence boundaries: post-fix Renderer + state tests 16/16 passed, 0 skipped (the Renderer change compiled in that test build; Release not rebuilt). Codex-era 36/36, Universal Debug/Release builds and the Release launch-argument scan are historical evidence for the pre-fix code; unchanged-file hashes support reuse but are not a fresh full build of the final code. Claude's review was a concentrated check by an engineer who also took part in the fix, not an independent post-fix third-party review. Real UI, restart and quit-prompt acceptance were not done; no end-to-end acceptance is claimed.

Open non-blocking todos (not handled): parser warning position text; conservative save lock after a pre-rename write failure; list refresh after re-entering the module with an editor window open; new-draft favorite dirty check; declared UI / concurrency / filesystem-race coverage gaps. Next major module awaits product coordination. Word WIP stays local and paused; Harness, Evidence/Quarantine, formal Workspace and production Prompt data untouched. Exact commit/push state is verified from repository refs.


## 学习中心 Phase 1 — implementation

### Authority / preflight

Owner approved the read-only plan and authorized implementation, isolated verification and the two progress documents; no commit/push. Quick preflight: clean `main` = `origin/main`, HEAD `693c4fc0d93544a69ff78bf03f02b02ccbbc52a6`; no full re-read of Docs or re-check of earlier phases (owner instruction).

### Files / decisions

New: `LearningModels.swift`, `LearningFileStorage.swift`, `LearningStore.swift`, `LearningViewModel.swift`, `LearningCenterView.swift`, `LearningEditors.swift`, tests `LearningPersistenceTests.swift`, `LearningStateTests.swift`. Modified `DashboardView.swift` (route, DEBUG learning root, neutral home card replacing the fabricated "Python 28%") and `PromptTemplateEditor.swift` (termination wiring only: participant extension replaces `requestTermination`; delegate calls the shared coordinator). Independent storage with adapted (copied) Prompt safety primitives; one JSON document for topics + entries so the entry + next-step save is atomic; storage-boundary checks for revision, topic existence and archive state under the lock; pre-rename failures retryable, post-rename unconfirmable failures lock saving. Strict `yyyy-MM-dd` calendar-day labels; future days rejected unless an existing entry's date is unchanged. No percentage anywhere; state is manual. Details in Current Status §18.

### Verification and one repair round

Concentrated batch of 58 (Learning persistence + state + existing PromptVaultState): 57 passed / 1 failed; the failure was a wrong test expectation (stale editor → `conflict` precedes `topicArchived`), corrected and re-run: passed. The one-attempt real-UI run then found that the Dashboard route for the learning item had not been applied (tests do not cover Dashboard routing); fixed, rebuilt with the temporary Bundle, relaunched on a temporary fixture: list, status, last study day and next step displayed from the isolated root; fixture SHA unchanged; process stopped by PID. Added a top-alignment layout tweak; re-ran the offscreen render test (passed). Universal Debug / Release **BUILD SUCCEEDED** (x86_64 arm64) on the final code; Release contains none of the five DEBUG launch strings. xcresults and logs under `/private/tmp/CosmosLearningPhase1-Validation/`. A first full-screen capture accidentally showed the user's browser; it was deleted unused and later captures were window-scoped.

### Not covered

Real-UI editors, native close/quit alerts, filters, archive, copy button, restart and narrow layout (no click tool available; not requested of the user). Full 58 not re-run after the two follow-ups; tests ran on arm64 only.

### State

Implemented, unstaged, uncommitted on `main`. Awaiting the owner's closeout instruction. Word WIP, Harness, Evidence/Quarantine, F1–F5, old P3, formal Workspace and knowledge repositories untouched; no extra root documents.


## 学习中心 Phase 1 — closure

The product owner accepted the existing verification scope and formally closed Phase 1, authorizing one `feat: 新增学习中心与学习记录` commit and a normal push to origin/main. Only the two progress documents were edited for closure; no source change, test, build or real UI run.

Evidence boundaries: first batch 57/58 with the single failure a wrong test expectation, corrected and re-run to pass; offscreen-render test re-run after the routing fix passed (the full 58 not re-run after the follow-ups); Universal Debug / Release succeeded on the final code; isolated real page confirmed routing and topic / status / last-study-day / next-step display, fixture hash unchanged. Editors, close / quit alerts and other interactions are not real-UI accepted; no end-to-end acceptance is claimed. Non-blocking todos retained, unhandled.

Product requirement recorded as a later candidate (not started): provinces maintainable, historical data preserved, every province reusing the standard Workflow, no hard-coded responsible-person roster. Next candidate: read-only survey of existing province management and its gaps, awaiting coordination. Pre-commit HEAD was `765b33b` (owner's docs-only rules commit on top of `693c4fc`); exact commit / push state is verified from repository refs.


## 省份可维护配置 — implementation

### Authority / preflight

Owner approved the read-only plan with revisions and authorized implementation, isolated verification and the two progress documents; no commit/push. Quick preflight: clean `main` = `origin/main`, HEAD `82cc7bab3d3772b296cb421fa85b8b5e43f42bf9`. No fetch, no full re-read of Docs or earlier evidence.

### Files / decisions

New `ZhuowangProvinceRules.swift` (pure validation, reserved names, conflict reporting, creation gate), `ZhuowangProvinceManagementView.swift` (manager section), test `ZhuowangProvinceConfigurationTests.swift`. Modified province model (`isEnabled`, `directoryName`, `pathName`, compatible decoding), `ZhuowangWorkspaceStore` (add with validation, rename with first-rename folder pin, stop/restore, reorder; no fixed default provinces on a fresh install), file-manager sanitizer visibility, Workspace sidebar / manager wiring, Campaign view + create-form save-time gate, ten path-construction call sites switched to `pathName` (display-only uses audited and left alone), stopped-province labels in the workbench / asset pickers, and two existing tests' default-province expectations. Array order is the display order; no `sortOrder`. Stopping only blocks new Campaigns. Violations stay in the business layer. Details in Current Status §19.

### Verification

One concentrated batch: new suite (18) plus existing Workspace persistence, store boundary, Campaign workbench and asset-center suites, **68/68 passed**, no repair round. Universal Debug / Release **BUILD SUCCEEDED** on the final code; Release has none of the DEBUG launch strings. One limited real-UI attempt on a temporary Bundle and isolated suite (window-only capture, no Campaign detail): old-format payload loaded; sidebar showed enabled provinces in order and a collapsed stopped group; payload unchanged after the run; process stopped by PID. Evidence under `/private/tmp/CosmosProvinceConfig-Validation/`.

### Not covered / todos

Manager sheet interactions, stop confirmation, restore, stopped-province page, create-form refusal as a UI flow (covered at rule level) are not UI-accepted. Todos: Campaign-name folder risk (existing), "primary missing but backup exists" re-initialization (existing, not worsened), two isolation warnings in the rules file, stopped-province marker on workbench rows.

### State

Implemented, unstaged, uncommitted on `main`. Awaiting the owner's closeout instruction. Word WIP, Harness, Evidence/Quarantine, F1–F5, old P3, formal Workspace and knowledge repositories untouched; no extra root documents.


## 省份可维护配置 — closure

The product owner accepted the existing verification scope and formally closed Phase 1, authorizing one `feat: 支持省份配置维护与历史保留` commit and a normal push to origin/main. Only the two progress documents were edited for closure; no source change, test, build, review or UI run.

Result: provinces can be added, renamed, reordered, stopped and restored; a fresh install has no fixed provinces and existing data is never re-seeded; the stable UUID plus the pinned folder name (`pathName`) protect history and file locations; stopping only forbids creating new Campaigns.

Evidence boundaries: 68/68 tests passed, 0 skipped (new suite 18 + affected existing suites); Universal Debug / Release succeeded on the final code. The isolated real-UI run confirmed only the sidebar display and an unchanged workspace payload **length** (not claimed as byte-for-byte business-data identity); manager operations and the create-form refusal were not UI-accepted (the refusal is covered at the rule level). Non-blocking todos retained, unhandled: real-UI acceptance, Campaign-name folder risk, "primary missing but backup exists" re-initialization, two isolation warnings, stopped-province marker on workbench rows.

Next candidate: investigation of the national monthly member-activation (全国月度会员促活) integration; not started. Exact commit / push state is verified from repository refs.
