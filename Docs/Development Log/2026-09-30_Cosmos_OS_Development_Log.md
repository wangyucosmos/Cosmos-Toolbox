# 2026-09-30 Cosmos OS Development Log

## Scope and finding

Pause real Campaign delivery-package UI acceptance and fix only Service source-path eligibility. The formal Campaign's historical Step 01–04 locations spell `Documents/cosmos os`; the computed root spells `Documents/Cosmos OS`. The read-only preflight established both spellings identify the same directory on the current disk. The initial case-sensitive string containment check incorrectly disabled those adopted files.

The user reports Claude's prior independent static review found no P0/P1 blockers and no P2 requiring repair. Its three P3 items are not addressed by this patch. No Harness, adoption, Artifact/Workflow mutation, Renderer change, or incident Evidence/Quarantine operation was performed. No commit or push was made.

## Implementation and files

- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangArtifactDeliveryPackageService.swift`: source containment walks the original source ancestry and matches the Workspace directory's device/inode identity. This follows the mounted filesystem's semantics without lowercasing path strings. Source and ancestor symlinks within the accepted chain are rejected; source `..` components, nonregular files, and external paths remain rejected. ZIP path validation and publication are unchanged.
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangArtifactDeliveryPackageTests.swift`: added a case-variant isolated fixture with real ZIP extraction and content/size/SHA-256 checks, plus prefix-similar sibling, source traversal, and directory-symlink coverage. Existing path-safety tests and assertions are preserved. The case-variant test branches according to actual filesystem behavior; no case-sensitive disk acceptance is claimed for this run.
- `Docs/07_Cosmos_OS_Current_Status.md`: current checkpoint updated; UI acceptance remains pending.
- `Docs/Development Log/2026-09-30_Cosmos_OS_Development_Log.md`: this session record. The 2026-09-29 historical log is unchanged.

## Verification

- Initial sandboxed Xcode invocation failed because the Swift Preview macro process could not run correctly. The same isolated test workflow was rerun outside the sandbox.
- The first executed pass exposed two diagnostic-reason mismatches: external paths were still rejected, but walking up to the `/var` system symlink reported `symbolicLink` instead of `outsideCampaignWorkspace`. The Service now establishes Workspace ancestry before reporting symlinks within that ancestry; original assertions were kept.
- Final focused delivery-package XCTest: **13 passed, 0 failed, 0 skipped**.
- Final related delivery-package / Step 05 / Step 06 / Artifact Review / Compare XCTest: **97 passed, 0 failed, 0 skipped**. Step 06 tests are isolated fixtures, not real Harness execution.
- Universal Debug: **BUILD SUCCEEDED**, `arm64 x86_64`, `CODE_SIGNING_ALLOWED=NO`.
- Tests use temporary Bundle ID `com.wangyucosmos.cosmostoolbox.deliverypathfix.tests20260930` and temporary fixture roots. Debug App uses the formal Bundle ID for subsequent user-operated UI acceptance but was not launched by this session.
- Evidence: `/private/tmp/CosmosDeliveryPathFixFocusedFinal20260930.xcresult`, `/private/tmp/CosmosDeliveryPathFixRegression20260930.xcresult`, corresponding `.log` files, and `/private/tmp/CosmosDeliveryPathFixDebug20260930.log`.
- UI App: `/private/tmp/CosmosDeliveryPathFixDebug20260930/Build/Products/Debug/Cosmos Toolbox.app`.
- `git diff --check`: passed. HEAD and `origin/main` remain `0f1c54e320423553ffb380b28f136aa56084fbef` on `main`; only the known Phase 1 files and this new daily log are dirty.
- Post-test read-only comparison against the 2026-09-29 preflight: all 11 formal business `Data` keys are byte-identical and JSON-decodable; all 9 explicitly managed source-file hashes are unchanged. Customer Service V1 remains `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`. Window-state keys are counted separately (71 before/after); whole-plist bytes are not the business-integrity gate. No Workspace enumeration or incident-file hashing occurred.

## Pending

Resume real UI acceptance using 浙江活动测试 and a destination outside its Workspace. Expected selection is default 0/6, with Step 01–04 V1, Prototype V3, and Customer Service V1 eligible. Verify actual ZIP, manifests, source hashes, non-overwrite behavior, temporary-directory cleanup, and per-key business persistence separately from macOS window state. Real UI acceptance has not passed yet. Keep all Phase 1 code uncommitted and unpushed.

## Real successful export and partial acceptance

The user exported `/Users/rainiesmac-15/Documents/浙江活动测试_交付包.zip` and reported no export problem. This is outside the Campaign Workspace, though it is in Documents rather than the proposed independent acceptance directory. The actual running process (PID 46645) was identified as `/Users/rainiesmac-15/Library/Developer/Xcode/DerivedData/Cosmos_Toolbox-eevxfegadecaxfcbckpwprxfwzqa/Build/Products/Debug/Cosmos Toolbox.app`, rather than the previously suggested `/private/tmp` build. The actual ZIP still provides direct evidence for all six adopted files and the path-eligibility fix; running-App binary identity with the separately tested build is not claimed.

Read-only inspection and independent native extraction verified:

- export time: 2026-09-30 11:07:58.711 +08; archive 35,996 bytes; SHA-256 `c634c2aeac08d7b5a469e059402c5635ba15891fe7887e546443e17b47dd83b2`;
- exactly 8 regular files: six adopted outputs plus `交付清单.md` and `manifest.json`;
- selected versions: Step 01–04 V1, Prototype V3, Customer Service V1; no historical/unadopted outputs or incident files;
- payload byte counts: 4,416 / 6,340 / 5,700 / 2,790 / 42,589 / 28,360 respectively; every payload matches its source and manifest SHA-256;
- all item Artifact IDs, logical keys, steps, names, versions, package paths, sizes, and hashes match formal metadata; manifests have no absolute source path;
- Customer Service V1 hash remains `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`;
- all 11 business Data keys (including Workflow Run/Approval/Artifact/adoption data) and all 9 explicitly managed source hashes remain unchanged from preflight; AppKit window values were compared separately and also unchanged;
- no `.cosmos-delivery-*` directory remained in Documents or the independent acceptance directory. No source Workspace traversal or incident-file operation occurred.

Inspection evidence: `/private/tmp/Cosmos-Delivery-UI-Acceptance-20260930/zip-verification-after-export.json`. Independent extraction is retained under its recorded `zip-inspection-*` directory.

Actual compatibility observation: ditto wrote UTF-8 Chinese filename bytes without the ZIP UTF-8 flag. Python's default ZIP reader decodes them as CP437 and displays mojibake; explicit UTF-8 decoding and native macOS extraction both confirmed correct paths/content. Minimal follow-up would be to emit standard UTF-8 filename metadata and add a default-reader interoperability fixture, subject to a separate scoped decision. This session does not modify ZIP generation code or expand the earlier P3 fixes.

Existing-target refusal is still pending in real UI. An expendable byte-identical target was prepared at `/private/tmp/Cosmos-Delivery-UI-Acceptance-20260930/浙江活动测试_交付包.zip`; its pre-attempt hash is `c634c2aeac08d7b5a469e059402c5635ba15891fe7887e546443e17b47dd83b2`. The original Documents ZIP is untouched. Default-empty selection, Finder reveal, and Save Panel cancellation still require explicit user observation. The three original Claude P3 descriptions were not supplied in this conversation, so no individual P3 is claimed closed; the user reported no export problem and no residual transaction directory was found, while race scenarios were not exercised. Full UI acceptance remains incomplete; no commit or push.

## Final scoped UTF-8 repair and real UI acceptance (supersedes pending items above)

The user authorized only the real collision check, Chinese ZIP filename compatibility, independent interoperability tests, related tests/build and a final-code real export. This does not expand other P3 work or initiate another full Claude review.

### Existing-target refusal

The formal 浙江活动测试 delivery UI showed default 0/6, with 01–04 V1, Prototype V3 and Customer Service V1 eligible. After selecting all six, choosing the disposable existing target in the independent acceptance directory, and confirming the native Save Panel Replace dialog, the application refused with:

`目标 ZIP 已存在。为保护用户文件，Cosmos OS 不会覆盖它。`

The target retained SHA-256 `c634c2aeac08d7b5a469e059402c5635ba15891fe7887e546443e17b47dd83b2`; no `.cosmos-delivery-*` remained. The original Documents ZIP was untouched. This real check preceded the UTF-8-only change, which leaves destination validation/publication unchanged; final existing-target XCTest also passed, so the same UI operation was not unnecessarily repeated.

### Encoding finding and smallest repair

Raw ditto local and central filenames were strict UTF-8, with identical paired bytes and flags, but bit 11 was absent (files `0x8`, directories `0x0`). Entry comments were empty; observed extra fields held timestamps, not conflicting name encodings. Python default CP437 decoding therefore produced mojibake. Ditto has no applicable UTF-8 flag option.

The Service now validates ZIP/ZIP64 bounds, record structure, strict UTF-8 filenames/comments and corresponding local/central names/flags/methods before making any writes. It then sets bit 11 in both headers before the existing archive verification/publication. Invalid UTF-8 or mismatched records fail without modifying archive bytes and use existing transaction cleanup. No filename bytes, compressed content, CRC, sizes, offsets or manifests are changed. No production Python dependency was added.

Files changed in this follow-up:

- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangArtifactDeliveryPackageService.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangArtifactDeliveryPackageTests.swift`
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-09-30_Cosmos_OS_Development_Log.md`

The independent fixture uses Python default zipfile to assert exact Chinese names, extract and verify bytes/SHA-256. A separate raw-archive comparison asserts only paired flags change; malformed UTF-8 and mismatched names are rejected before writes. Existing integrity, collision, failure-cleanup, adoption-change and path-safety coverage remains.

### Final tests and build

- Focused delivery XCTest: **15 passed, 0 failed/skipped**.
- Related delivery / Step 05 / Step 06 / Artifact Review / Compare XCTest: **99 passed, 0 failed/skipped**, confirmed by xcresult summary (parallel log text alone undercounts by one).
- Universal Debug: **BUILD SUCCEEDED**, `x86_64 arm64`, `CODE_SIGNING_ALLOWED=NO`.
- Evidence: `/private/tmp/CosmosDeliveryUTF8Focused20260930.xcresult`, `/private/tmp/CosmosDeliveryUTF8Regression20260930.xcresult`, `/private/tmp/CosmosDeliveryUTF8Debug20260930.log`.
- No source edits followed passing tests/build; subsequent edits record these results only.

### Final-code real export

The previous App was closed after dismissing its sheet; its old PID exited. The final App was launched from `/private/tmp/CosmosDeliveryUTF8Debug20260930/Build/Products/Debug/Cosmos Toolbox.app`; PID 51814 and launch origin were verified. Formal 浙江活动测试 exported successfully; Finder reveal selected the exact final ZIP. No hang or export error was observed in this small six-item operation.

- Export time: **2026-09-30 13:49:47.842 +08**.
- Archive: `/private/tmp/Cosmos-Delivery-UI-Acceptance-20260930/浙江活动测试_交付包_UTF8最终验收.zip` (outside the Campaign Workspace).
- ZIP size: **35,996 bytes**; SHA-256 **`110c2231f702220ee72d4424dc9d965512da545a4f57f1bcbd30bb6460ba8512`**.
- Exact regular-file set: six current adopted outputs plus `交付清单.md` and `manifest.json`; versions 01–04 V1, Prototype V3, Customer Service V1. Exact Chinese names, paired UTF-8 headers, IDs, logical keys, steps, versions, package-relative paths, sizes and hashes match. No absolute source paths in manifests.
- Payload sizes: **4,416 / 6,340 / 5,700 / 2,790 / 42,589 / 28,360** bytes. Customer Service V1 SHA-256 remains **`ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`**.
- Actual independent tools: **Python 3.9.6 default zipfile/extractall** and **macOS `/usr/bin/ditto -x -k`**; exact filenames, content and SHA-256 pass both. Finder reveal is not an Archive Utility extraction test. **Windows and macOS Archive Utility were not tested**.
- All **11 business Data keys** remain byte-identical and JSON-decodable, all **9 managed source hashes** unchanged; Workflow/Run/Approval/Artifact/adoption unchanged. Only **`NSWindow Frame GoToSheet`** changed in separate window-state comparison, not business data.
- No `.cosmos-delivery-*` in Documents or acceptance directory. Original Documents ZIP and disposable collision target retain their previous hashes. Inspection extraction directories are intentionally retained evidence, not failed export transactions.
- Evidence: `/private/tmp/Cosmos-Delivery-UI-Acceptance-20260930/zip-verification-final-utf8.json`.

The requested final-code checks are complete. Unavailable-item presentation remains fixture-covered because all six real items are available; Save Panel cancellation was not separately exercised. No large-file responsiveness or race acceptance is claimed, and other P3 items remain deferred. No Harness, V1 adoption/regeneration, Artifact mutation, Evidence/Quarantine operation, knowledge-base write, commit or push occurred. HEAD/origin remain `0f1c54e320423553ffb380b28f136aa56084fbef`; all eight known Phase 1 files remain uncommitted for the user's closeout decision.

## Product-owner acceptance and authorized Git closeout

On 2026-09-30 the product owner explicitly confirmed Campaign 工作产物交付包 Phase 1 acceptance and authorized one formal commit, `feat: 新增 Campaign 工作产物交付包`, followed by a normal push to `origin/main`. Preflight in `/Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox` found only the eight known Phase 1 files; successful `git fetch origin` confirmed the remote baseline remains `0f1c54e320423553ffb380b28f136aa56084fbef`. No source code changed after the passing 15/15 focused tests, 99/99 related tests and Universal Debug build; this closeout updates documentation only and does not rerun the suite.

Only Campaign Detail, the three delivery-package source files, delivery-package Tests, Current Status and the 2026-09-29/30 Development Logs are authorized for individual staging. Workspace files, ZIP/JSON acceptance evidence, temporary files, personal knowledge repositories and incident preservation files are excluded. Post-push HEAD, parent, remote ref, clean-tree and ahead/behind results are reported from Git rather than predicted here. Actual compatibility coverage remains Python default zipfile and macOS ditto; Windows and Archive Utility were not tested. Other P3 items stay deferred. No new development or full Claude review is initiated.

## Word export paused; Campaign 项目推进工作台 Phase 1 (uncommitted)

### Word export preserved

The product owner paused 已采用 Markdown 导出 Word Phase 1 before full UI acceptance. The nine files were committed as local checkpoint `2d26b2a` on `wip/markdown-word-export-phase1-20260930` (not pushed, not merged); that branch carries its own status / log record (UI acceptance steps 1–2 passed, 3–5 not performed). `main` returned clean to `e15bf38`.

### Goal

One screen in 卓望工作 that shows every Campaign's Workflow progress, next action, dates and adopted work, reusing existing detail / Workflow / 工作产物 / 交付包 entries. Read-only; no Step 07, no new persistence, no AI generation.

### Files

- New `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignProgress.swift` — pure projection (progress, next step, attention, adoption / conflicts, deliverable count via delivery-package eligibility, calendar-day date phase) and filter.
- New `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignWorkbenchView.swift` — workbench UI (metrics, filters, empty states, 推进列表, 近期活动, 活动总览).
- `ZhuowangWorkspaceView.swift` — 总览 / 推进工作台 sidebar entry selected by default; full-page workbench; province / module 概览 placeholder metrics and recent rows replaced by the scoped workbench; one shared `ZhuowangWorkflowStore`.
- `ZhuowangCampaignView.swift` — Workflow Store injected instead of per-view instance; Campaign window manager reusable with an optional destination; `ZhuowangCampaignDetailRoute`.
- `ZhuowangCampaignDetailView.swift` — applies route requests (overview / workflow / artifacts / delivery sheet).
- `ZhuowangModels.swift` — `ZhuowangNavigationItem.workbench`.
- `DashboardView.swift` — DEBUG-only, isolated-mode-only `--cosmos-initial-sidebar zhuowang` launch argument for fixture captures.
- New `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangCampaignWorkbenchTests.swift` — 8 tests incl. offscreen renders and fixture plist export for isolated launches.

### Verification

- Focused `ZhuowangCampaignWorkbenchTests` 8/8 after the single fix round; Universal Debug build succeeded (`x86_64 arm64`); `git diff --check` passed. Full suite not rerun (policy; no shared persistence code changed).
- Isolated real-App capture as recorded in Current Status §15; temporary domains removed afterwards; formal business data, sources, adoption, steps and Workspace listing unchanged.
- Not verified: real click-through of workbench actions opening Campaign windows (see todo 4), manual UI acceptance, performance with many Campaigns.
- Incident: one AppleScript window resize hit the product owner's running App window (geometry only).

### Next

Product-owner evaluation of the workbench; todos listed in Current Status §13.

### Closeout

The product owner closed Campaign 项目推进工作台 Phase 1 without further testing or manual click-through, based on: focused tests 8/8, Universal Debug build passed, isolated real-App run passed. Navigation buttons were not actually clicked; no complete end-to-end UI acceptance is claimed. Todos and the existing isolated-mode Workspace-write risk remain open; fixture Campaigns must not be used to open detail windows. Authorized as one commit, `feat: 新增 Campaign 项目推进工作台`, with a normal push; the Word export WIP branch stays local and unmerged.
