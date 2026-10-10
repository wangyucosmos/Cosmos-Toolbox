# Cosmos OS Current Status

**Last updated:** 2026-10-10
**Project:** Cosmos OS / Cosmos-Toolbox  
**Current stage:** 个人项目 Projects Phase 1 已完成实现、集中隔离验证及可回退日常部署（§30），用户已接受声明验收范围，阶段关闭，已授权本次正常提交推送；保留既有验证边界。独立个人项目列表/原生详情、原文进展与引用、归档恢复，核心备份导出扩展 V2 并兼容 V1。
**Previous stage (部署):** 日常使用部署已接受并正式关闭，提交 `f6a1e903914f4d5d37af14d3453180206ef336ad`、正常推送与同步核对完成（§29）。
**Previous stage (Mac 概览):** Mac 环境概览 Phase 1 已接受并正式关闭，提交 `7124c4f2c918fc39eb52ae05209898654fa24c4e`、正常推送与同步核对完成（§28）；既有验证边界保留。
**Previous stage (恢复):** 核心数据恢复 Phase 1 已接受并正式关闭，提交 `72f020b628d4ee7be3e720f1e67055686f4f55ea`，正常推送与同步核对完成（§27）；既有验证边界和待办保留。
**Previous stage (备份):** 核心数据备份 Phase 1 已接受并正式关闭，提交 `16dd38682e8c17ef15dc97cae2718a261db441dc`、正常推送与同步核对完成（§26）。导出与独立校验语义保持。
**Previous stage (任务资料):** 任务上下文资料选择 Phase 1 已接受并正式关闭，正式提交 `3024ceb6b9a501d19ef37002bdb108c3e63c27d8`（§25）；其历史验证及已声明限制沿用。
**Previous stage (交接记录):** AI 工作台 Phase 3 已正式关闭并正常推送，实际 Git 收尾见 §24；独立历史、手动记录及历史原文复制能力保留。
**Previous stage (任务准备):** Phase 2 已由用户接受验收并关闭，正式提交与正常推送已完成（见 §23）；有效收尾基线 main = origin/main = 远端 main、ahead/behind 0/0、工作区干净沿用，不重复 fetch 或历史验证。
**Previous stage (AI 工作台):** Phase 1 已由用户接受并关闭，正式提交 `6639e431fa9f1d6f8ba7664069ad18fed1b1f41b`，消息 `feat: 新增 AI 工作台本机工具检测`。正常推送、main = origin/main、ahead/behind 0/0、工作区干净为用户提供的有效收尾基线，本轮未重复 fetch。Phase 1 历史测试与验收证据沿用；工具检测能力保留，详见 §22。
**Previous stage:** Dashboard 真实数据整合 Phase 1 is **closed** on 2026-10-09: the product owner accepted the existing verification scope and authorized one `feat: 首页接入真实工作与学习数据` commit and normal push to origin/main (exact Git delivery is verified from repository refs after push; see §21). Implementation baseline `68f080fe72f69ba037b897a2a3962d9db9d87b1c`. The Home now summarizes real data from the finished modules and no longer shows fabricated tasks, projects or health numbers.

**Earlier stage (全国月度会员促活):** 全国月度会员促活 Phase 1 was **closed** on 2026-10-09: the product owner accepted the existing verification scope and authorized one `feat: 接入全国月度会员促活清单` commit and normal push to origin/main (exact Git delivery is verified from repository refs after push; see §20). Implementation baseline `863fc83690bd02543c0ca1570a88883a4b43831c`. National Campaigns can be created as the "月度会员促活" project type with a monthly checklist (7 outputs, 7 business inputs, registered final locations with an explicit finalization confirmation) layered on the existing Campaign and six-step Workflow.

**Earlier stage (省份可维护配置):** 省份可维护配置 Phase 1 was **closed** on 2026-10-09: the product owner accepted the existing verification scope and authorized one `feat: 支持省份配置维护与历史保留` commit and normal push to origin/main (exact Git delivery is verified from repository refs after push; see §19). Provinces can be added, renamed, reordered, stopped and restored; a fresh install starts with no provinces; existing data is never re-seeded. Implementation baseline `82cc7bab3d3772b296cb421fa85b8b5e43f42bf9`.

**Previous stage (学习中心):** 学习中心 Phase 1 was **closed** on 2026-10-09: the product owner accepted the existing verification scope and authorized one `feat: 新增学习中心与学习记录` commit and normal push to origin/main (exact Git delivery is verified from repository refs after push; see §18). Implementation baseline `693c4fc0d93544a69ff78bf03f02b02ccbbc52a6`; actual pre-commit HEAD `765b33b` (owner's docs-only rules commit). No percentage progress is shown anywhere: topic state is the manual three-state 计划中 / 学习中 / 已完成 and never changes automatically.

**Earlier stage (Prompt Vault):** Prompt Vault Phase 1 is **closed** on 2026-10-09: the product owner accepted the existing verification scope and authorized one `feat: 新增提示词库与变量模板` commit and normal push to origin/main (exact Git delivery is verified from repository refs after push). The known variable-name first-character issue (leading combining mark) received its minimal fix after Claude's takeover. Claude performed a concentrated review and took part in the fix, so this is not an independent third-party re-review of the repaired code. Post-fix evidence: Renderer + state tests 16/16 passed, 0 skipped. Pre-fix Codex evidence (36/36, Universal Debug/Release builds, Release launch-argument scan) is retained as historical for that phase; unchanged-file hash checks support reusing it but do not mean the final code passed a fresh full build, and Release was not rebuilt after the Renderer change (only the test-build compile covered it). Real-App UI, restart, quit-prompt and similar acceptance was not done; no complete end-to-end acceptance is claimed.

**Previous stage:** 知识与资产中心 Phase 1 closed on 2026-10-09 on existing verification evidence. Claude completed one concentrated read-only review with conclusion A and no discovered blockers; the owner authorized one `feat: 新增知识与资产中心` commit and normal push to origin/main. Exact Git delivery is checked after push; no complete end-to-end UI acceptance is claimed. Asset-focused 15/15 and affected Review 27/27 tests passed after one concentrated fix round; final Universal Debug/Release builds passed. Temporary real-App search, explicit historical-version selection, native detail, Text Review and temporary-file Finder reveal passed; no full end-to-end clipboard or all-media acceptance is claimed. Implementation baseline is `e2c615165fef4951d6dec99915949bddfbab2aa1`. Previous milestones: Campaign 项目推进工作台 Phase 1 is closed by the product owner (2026-09-30) and committed as `feat: 新增 Campaign 项目推进工作台` on top of `e15bf38`. Evidence: focused tests 8/8, Universal Debug build passed, isolated real-App run passed. Workbench navigation buttons were not actually clicked; no complete end-to-end UI acceptance is claimed (details in §13 / §15). 已采用 Markdown 导出 Word Phase 1 is paused and preserved only on local branch `wip/markdown-word-export-phase1-20260930` (commit `2d26b2a`; not merged, not pushed; partially UI-accepted, not accepted). The previous milestone follows. Campaign 工作产物交付包 Phase 1 is implemented and acceptance is explicitly confirmed by the product owner on 2026-09-30. The user reports Claude's independent static review found no P0/P1 blockers and no P2 requiring repair. The narrowly scoped filesystem-path and ZIP UTF-8 compatibility fixes passed isolated tests and a Universal Debug build. The final build completed the requested real 浙江活动测试 export, Finder reveal, independent ZIP/content/hash and business-integrity checks; real existing-target refusal also passed. Actual unpacking coverage is macOS ditto and Python 3.9.6 default zipfile, not Windows or macOS Archive Utility. The owner authorized a single `feat: 新增 Campaign 工作产物交付包` commit and normal push to origin/main; exact Git delivery state is verified from repository refs after push. Step 06 remains the accepted 2026-09-29 baseline; Evidence/Quarantine stays untouched.

---

## 1. Current product checkpoint

Cosmos OS is a native macOS SwiftUI personal work operating system.

The current real production-like testbed is the **卓望 Workspace**.

Current focus is not global UI polish.  
Priority is to make the real workflow reliable, recoverable, and extensible.

Core principle:

> 可运行 → 可使用 → 可稳定 → 再扩展

---

## 2. Current Zhuowang Campaign test state

Active test Campaign:

`浙江活动测试`

Current six-step Workflow state:

```text
01 需求整理       已确认
02 策划思路       已确认
03 完整策划案     已确认
04 页面结构       已确认
05 产品原型设计   已确认
06 客服文档       已确认
```

Important version state:

- 完整策划案 has multiple historical versions.
- Current adopted version is **V1**.
- 产品原型 current adopted version is **V3**.
- Artifact Detail currently manages prototype **V1 / V3 / V4**; the local V2 file remains intentionally unmanaged and must not be imported, deleted, or modified.
- Do not overwrite this choice unless the user explicitly changes it.
- On 2026-09-24, before the P1 fix, Step 06 was `ready` with zero Run, Approval and Artifact. Harness wrote an unadopted Markdown file in `06_客服文档` and a byte-identical knowledge-base mirror before adoption. The Workflow primary changed only in Workflow/Step 06 `updatedAt` because Provider selection was persisted. On 2026-09-29 both incident originals were moved to Quarantine only after byte-identical Evidence copies were verified; all four preserved files remain outside the formal Workspace and knowledge-base paths, at 31,878 bytes and SHA-256 `a198eb7d2336c4487683360bc3f008fd94f569601d3a1850d65a412e67aaa9ec`. Do not delete, overwrite, restore or automatically import them.
- On 2026-09-29, after the fixed real Harness run and human adoption, Step 06 is persisted as `approved` with exactly one succeeded AI Run, one approved Approval and one adopted Markdown Artifact V1 in logical group `workflow.customerService.primary`. The formal file is `~/Documents/Cosmos OS/Workspaces/卓望/浙江/浙江活动测试/06_客服文档/客服文档_V1.md`, 28,360 bytes, SHA-256 `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`; its bytes match the persisted Artifact content. Prototype V3 remains the unique adopted upstream prototype.

Post-P0 runtime acceptance was completed manually on 2026-08-19:

- 01-04 Workflow remain `已确认`;
- 05 产品原型设计 remains `可开始`;
- 完整策划案 currently adopted version remains **V1**;
- Figma does not appear in the `执行 AI` list;
- Figma remains available as a Tool;
- recovered Artifacts and all historical versions remain available.

The first real Step 05 HTML Prototype loop passed runtime acceptance on 2026-08-21:

- Cosmos OS launched DeepSeek Harness with `DSH_HOME=$HOME/.dsh-rc8-clean`;
- the current headless command used `@deepseek-ai/dsh@0.1.0-rc.6`;
- Harness resolved the existing credential through its local credentials service without exposing or copying the API Key into Cosmos OS;
- DeepSeek returned a complete runnable single-file HTML result;
- HTML validation, WebKit preview, source review, and a basic interaction check passed;
- human adoption created the versioned HTML Artifact V1 and durable `.html` file;
- Step 05 changed to `已确认` only after adoption, and Step 06 changed to `可开始`.

---

## 3. Verified Workflow capabilities

Verified:

- Campaign creation / detail flow
- Six-step standard Workflow
- Per-step AI Provider selection
- DeepSeek Harness local execution
- Task Package preview
- Task execution result return
- Human review
- Adopt result
- AI Run creation
- Approval creation
- Artifact creation
- Step approval
- Next-step unlock
- Artifact version history
- Switching currently adopted Artifact version
- Artifact automatic local Markdown persistence
- Finder reveal / open for local Artifacts
- Legacy Artifact local-file migration
- Later Workflow steps consuming currently adopted upstream Artifact content
- Step 06 Task Package explicitly identifies the customer-service step and consumes only currently adopted upstream Artifact versions, including the adopted Prototype V3 rather than unmanaged or historical versions
- Step 06 generated Markdown appeared as a Draft in the existing Artifact Review Workspace, including adopted Prototype V3 upstream context. The first live execution exposed a pre-adoption write defect; the narrow sandbox/integrity fix and the 2026-09-29 real Harness re-acceptance kept the formal `06_客服文档` and knowledge-base customer-service directories empty before adoption. The user then adopted the result; the UI displayed `已确认` and `已采用、已落盘`, and the separate persisted-data/file checks below confirmed that result.
- Markdown and plain-text Preview use a native selectable Text Renderer; source is displayed literally without HTML/script execution or network loading
- Step 06 formal adoption creates a versioned `.md` file, succeeded AI Run, approved Approval, provenance-complete Artifact with logical key `workflow.customerService.primary`, one current adopted version, and an approved final step
- Step 06 adoption is idempotent for an already adopted matching result, preserves older versions, and does not unlock a nonexistent next step
- Step 06 uses a narrow protected Workflow transaction with stale-baseline/decode-lock checks, backup and primary read-back verification, and memory publication only after metadata persistence succeeds
- Step 06 Recovery imports only exact `客服文档_V数字.md` names as unadopted Artifacts and never changes the step to approved or bypasses human adoption; the incident file `客服文档 _ AI 采用结果_V1.md` is not imported.
- Campaign Detail 工作产物区域 can open a separate delivery-package selection sheet without adding a Workflow step or changing Workflow/Run/Approval/Artifact/adoption state
- Delivery-package eligibility groups current Campaign Artifacts by their existing logical version key and requires exactly one `isApprovedVersion == true`; a group with zero or multiple adopted versions is disabled and never uses the work-artifact list's latest-version display fallback
- Delivery-package Phase 1 accepts only regular local files inside the current Campaign's canonical formal Workspace; URL/Figma references, relative paths, missing files, directories, symbolic links, unreadable files, and Workspace-external paths are disabled with an explicit reason
- Source containment follows directory device/inode identity on the mounted filesystem, rather than case-folding paths or requiring identical spelling. Historical `Documents/cosmos os` locations may qualify under `Documents/Cosmos OS` only when their actual ancestor is the same Campaign Workspace. Source ancestry rejects symbolic links; `..` source components and prefix-similar sibling directories are rejected. Artifact locations and adoption metadata are unchanged.
- Export defaults to no selection, supports selecting all eligible groups, lets the user choose a ZIP destination, refuses an existing target, and offers Finder reveal after success
- The ZIP contains only the selected files plus `交付清单.md` and `manifest.json`; both manifests record Campaign metadata, export time, step, Artifact name/ID/logical key/version, package-relative path, byte count, and SHA-256 without exposing absolute source paths
- Export re-reads a live Store snapshot before trusting the selection, hashes each source before and after copy, verifies each staged copy, extracts the generated ZIP into an isolated verification directory, and verifies the complete entry set, manifest/checklist bytes, byte counts, hashes, canonical containment, and path safety before publishing the final ZIP
- Delivery-package publication uses a sibling temporary transaction directory and never overwrites an existing target; failures clean temporary package data and do not leave a final ZIP
- Native macOS Campaign Detail window
- Native macOS Artifact Detail window
- Step 05 capability-based HTML Prototype Tool selection
- immutable Provider / Connection / Tool / Route / capability execution snapshot
- AI Execution Adapter Registry + Tool Adapter Registry orchestration
- DeepSeek Harness to validated HTML Artifact Draft execution path
- HTML preview and source review
- versioned `.html` Artifact persistence with overwrite protection
- HTML local-file disaster recovery across current and historical prototype folders
- Step 05 approval transition only after durable file + Artifact adoption
- Tool/Route-specific execution specification resolves the final instruction and Expected Outputs without binding the Prototype step to HTML
- Task Package Preview shows the frozen capability and a readable Route before execution
- tool-agnostic Prototype Execution Profile persists Fidelity / Style on the prototypeDesign step
- immutable execution snapshots and AI Run / Artifact provenance preserve the selected Prototype Fidelity / Style
- capability-driven Profile controls enforce supported Fidelity / Style combinations and map them into the selected Tool / Route specification
- Artifact Review Workspace opens AI Drafts and managed adopted / historical Artifacts in the same independent resizable macOS window
- type-agnostic Artifact Preview Renderer Registry with safe unsupported-type fallback
- Phase 1 HTML Renderer uses a real interactive WKWebView inside selectable 375px / 390px mobile device frames
- HTML Preview always derives an in-memory secured copy through the Renderer security policy; Source and the original Artifact remain byte-for-byte unchanged
- Preview CSP, WebKit content rules, a non-persistent data store, and a scheme allowlist form separate defense layers
- Artifact Review Preview / Source modes and focused Full Preview mode preserve the original Artifact content
- Review metadata is captured from Draft + immutable execution snapshot / Artifact provenance rather than current Workflow selections
- Artifact Detail can open a stable, independent Version Compare window for any logical Artifact with at least two managed versions
- Version Compare supports two UUID-selected managed versions, independent Preview / Source modes, shared 375px / 390px viewport, isolated scrolling / JavaScript state, and current-adopted marking without changing adoption
- Artifact Review projects legacy `content / location / type` into typed inline-text, local-file, or unavailable payloads without changing the persisted Artifact model
- Preview file I/O is isolated in a read-only Resolver; only explicitly referenced supported text files are decoded as UTF-8, while binary, missing, unreadable, unknown, or conflicting media safely fall back
- Renderer selection now uses typed Preview Input plus media classification, and Renderer capabilities independently declare Preview, Source, Full Preview, and Mobile Viewport support
- Image Renderer Phase 1 safely previews explicitly referenced local, single-frame PNG / JPEG files without decoding binary content as text or changing persistent Artifact data
- Image Preview uses ImageIO signature verification, bounded asynchronous decoding, pre/post file fingerprint checks, orientation-aware dimensions, controlled color-space handling, and Renderer-local Fit / 100% / 10%–400% zoom state
- single-version Review supports Image Full Preview; Version Compare supports Image | Image and HTML | Image combinations with independent image state while Mobile Viewport remains HTML-only
- PDF Renderer Phase 1 accepts typed local-file PDF input and is selected by the Registry only for exact PDF media classification; PDF binary content never enters the UTF-8 Reader
- PDF Preview is limited to local, unencrypted files that pass bounded loading and the PDF security policy; the Renderer keeps only a bounded in-memory Data snapshot, a PDFKit document, minimal metadata, and Renderer-local transient state
- PDFKit Preview supports continuous vertical scrolling, Fit Page, Fit Width, 10%–400% zoom, current / total page display, previous / next page, page-number navigation, page count, page size, file size, text selection, permission-dependent copy, and same-document internal GoTo
- single-version Review and Full Preview support PDF; Version Compare supports PDF | PDF, HTML | PDF, Image | PDF, and PDF | Unsupported
- each PDF Compare pane owns an independent PDFView, page state, zoom state, scroll state, binding session, delegate, and observers; actions on one side do not update the other
- PDF capabilities do not expose Source or the 375px / 390px Mobile Viewport controls
- PDF load, document, page, scale, delegate, observer, and security state remain Renderer-local and are not written to Store, Workflow, UserDefaults, or the Artifact model

---

## 4. Persistence and recovery status

A persistence regression was discovered after adding new Workflow model fields.

Observed failure:

- previous Workflow progress disappeared after app run/restart;
- Artifact UI showed 0 items;
- local Artifact Markdown files still existed.

Root cause:

- old persisted Workflow payload could become undecodable after non-optional Codable schema changes;
- decode failure could result in an empty Workflow state.

Fixes implemented:

- backward-compatible Workflow Step decoding;
- persistence protection against overwriting unreadable saved Workflow data;
- lightweight Workflow backup payload;
- backward-compatible decoding for AI Provider, AI Connection, Tool Integration, and Agent/Tool Route payloads;
- independent backup payloads and write locks for all four configuration boundaries;
- backup refresh only after the current payload is successfully decoded again;
- preservation of the last recoverable backup when the current payload is unreadable;
- default configuration seeding only when a storage key is genuinely missing, not when saved data is empty or unreadable;
- local-file disaster recovery;
- local Markdown Artifact discovery;
- reconstruction of missing Artifact metadata;
- reconstruction of completed Workflow steps;
- reconstruction of the next actionable step.

Campaign / Workspace Store persistence protection Phase 1 now adds:

- no-op startup loads preserve an existing valid primary payload byte-for-byte and do not create a backup;
- initialization writes defaults only when the primary key is genuinely missing;
- corrupt primary payloads lock the Store, preserve the original bytes, detect but do not automatically restore a valid backup, and reject mutations;
- successful mutations create one last-known-good backup from the currently decoded primary before writing the candidate;
- stale in-process Store instances reject writes after rereading the current primary under a shared process-local lock;
- write verification failures do not publish the candidate into the Store's public in-memory state;
- Campaign create / update / delete (Store API **and** formal UI: `ZhuowangCampaignView`, `ZhuowangCampaignDetailView`) use the protected transaction boundary;
- Workspace create (province / category / module) is exposed in the formal Workspace Manager UI; Workspace module **update / delete are Store API capabilities only** (`updateModule`, `deleteModule`) covered by XCTest — there is no formal UI for them and none is claimed;
- DEBUG-only suite injection is UUID-scoped, fails closed when invalid, and never falls back to the production UserDefaults domain; it is additionally accepted **only** when the running Bundle ID starts with the temporary UI prefix `com.wangyucosmos.cosmostoolbox.persistenceui.` — under the production Bundle ID, an empty / unreadable Bundle ID, or any other Bundle ID the App is blocked before any Store is created (the Workflow / AI Stores still read `UserDefaults.standard`, so a suite under the wrong Bundle would only be a partial, misleading isolation);
- Release builds do not compile the suite-injection bootstrap path, the isolation banner, the isolation metadata (`isIsolated` / `isolationSuiteName` / `isolatedSuite(named:)`), or any test-only string (verified by scanning the Universal Release binary);
- the main window's direct root is the stable, internal `CosmosRootView` in both Debug and Release, so AppKit window-state keys no longer embed a random `(unknown context at $ADDR)` type name;
- the DEBUG isolation banner is rendered only in the DEBUG isolated branch as `VStack(spacing: 0) { banner; navigationContent }`; the non-isolated Debug path and Release return the unchanged `NavigationSplitView` content directly (an earlier `.safeAreaInset(edge: .top)` variant overlapped the sidebar and was replaced).

Current formal Workspace persistence baselines after the recorded no-op re-encoding incident are:

```text
raw SHA-256       163b2189391e52019f31cb427b211d26fab85a888f13506591a89b0a54e9c4b0
canonical SHA-256 711fd948e14f10e31f465731f84c25dd75c5360f2b18e2004942beacd4c0843b
```

The incident changed JSON object key order only. Exhaustive reconstruction matched both raw encodings from the same semantic object; all fields, UUIDs, and array order remained equal. No recovery or overwrite was performed.

Phase 1 is intentionally limited to a process-local lock and UserDefaults read-back verification. It does not provide cross-process transactions, automatic recovery, backup rotation, or a disk-level durability guarantee. When any persistence verification fails (initial write, encoding, backup write / read-back, primary write / read-back) the Store locks and the UI does not publish the change; the persisted primary and/or backup may already have changed, so the user is told to stop and verify before restarting. The wording promises neither that the backup is valid nor that the primary is unchanged. No automatic rollback is performed.

Step 06 Phase 1 reuses this protected boundary only for the customer-service adoption operation. The transaction accepts the Store's last loaded Workflow bytes as its baseline, rereads and decodes the current primary under the process-local lock, builds the candidate in isolation, writes the versioned Markdown file, verifies backup and primary writes, and publishes the decoded candidate only after success. A file-write failure leaves Workflow memory and metadata unchanged. If metadata persistence or read-back fails after the file has been created, the file is deliberately retained as user-owned recovery material; Recovery may import it only as unadopted and must not approve Step 06. This is a narrow Step 06 hardening, not a migration of every historical `ZhuowangWorkflowStore` mutation to Store Phase 2.

Formal data gate: business integrity is gated by the per-key SHA-256 of the 11 business `Data` keys plus decode checks. The whole-plist SHA-256 of `com.wangyucosmos.Cosmos-Toolbox.plist` is a diagnostic indicator only, because it also contains AppKit window-state keys that any process using the production Bundle ID (including the XCTest host) legitimately updates.

Review status (2026-09-19): Claude's independent read-only review found P0 = 0, P1 = 0, P2 = 4, P3 = 10. All four P2 findings (unstable Debug root view type; DEBUG stand-in views replacing the formal Campaign UI during acceptance; self-referential "no re-encode" tests; Dashboard layout wrapped in a VStack) and P3-1 / P3-3 / P3-9 / P3-10 were fixed by Claude in a directed follow-up and re-verified (41 Store-focused tests, 156 total XCTest, Universal Debug and Release builds). A second independent re-review closed the four P2 items and raised **P2-A** (isolated suite accepted under the production Bundle ID), which is now fixed as described above. The P2-A resolver tests were actually executed on 2026-09-20 (Store-focused 43 / complete suite 158, all passed) with the 11 business `Data` keys byte-identical before and after; the empty `Tests`-prefixed suite plists left in `~/Library/Preferences` are a known test by-product awaiting separate cleanup authorisation. Formal Campaign UI acceptance was then completed on 2026-09-20 under a temporary Bundle ID + temporary suite (Round 6): create, edit, first restart with the edit retained, delete through the formal `ZhuowangCampaignDetailView`, second restart with the deletion retained (primary `[]`, backup = the pre-delete edited record), no lock, no error alert, and no obvious visual regression on Dashboard, Workspace overview, Campaign list or detail. The Workflow / AI Stores created by the formal Campaign UI wrote only into the temporary Bundle domain. All 11 business `Data` keys were byte-identical before and after every launch. The temporary Round 5 / Round 6 domains, the old temporary UI domain and the 346 empty test-suite plists were removed afterwards under explicit, path-exact authorisation; `/tmp` acceptance evidence is retained for now. Deferred P3 items: finer error enumeration, built-in module deletion rule, whole-Store `@MainActor` migration, stale-conflict reload, duplicate `allowsMutations` guards.

Recovery was manually verified.

Current recovered state is again:

```text
01-04 已确认
05 可开始
06 未开始
```

All known local work files were confirmed to still exist.

---

## 5. AI Provider / Tool boundary

This boundary is now mandatory.

### AI Providers

Examples:

- OpenAI / ChatGPT
- Codex
- DeepSeek Harness
- Claude
- future AI providers

### Tools / Adapters

Examples:

- Figma
- HTML Prototype
- Pixso
- future prototype / external tools

Figma was previously present in the AI Provider list.

That was corrected:

- Figma no longer appears in the "执行 AI" picker.
- Figma remains available as a prototype Tool.
- The legacy `.figma` provider enum case may remain temporarily for backward decode compatibility.

Do not reintroduce Figma as an AI Provider.

---

## 6. Prototype design architecture

Workflow step 05 is now conceptually:

`产品原型设计 / Product Prototype`

Capability:

`prototypeDesign`

It must not be hard-bound to Figma.

Target composition:

```text
Workflow Step
      ↓
Choose AI Provider
      +
Choose Tool
      ↓
Task Package
      ↓
Execution / Adapter
      ↓
Artifact
```

Examples:

```text
Codex + Figma
Claude + HTML Prototype
DeepSeek Harness + Pixso
ChatGPT + future web prototype tool
```

The user must be able to re-run the same Workflow Step with another AI and/or another tool, producing a new Artifact version while preserving old versions.

---

## 7. Current Tool Adapter work

Implemented and automatically verified:

- `ZhuowangToolAdapter.swift`
- `ZhuowangHTMLPrototypeAdapter.swift`
- `ZhuowangWorkflowExecutionCoordinator.swift`
- `ZhuowangWorkflowTransitionLogic.swift`
- `ZhuowangTaskExecutionSpecification.swift`

The Tool Adapter abstraction exists to prevent Workflow logic from being tied to one concrete product.

The first real Step 05 path is:

```text
DeepSeek Harness
→ AI Execution Adapter Registry
→ raw AI result
→ HTML Prototype Tool Adapter Registry
→ validated HTML Artifact Draft
→ preview / source review
→ human adoption
→ versioned .html file + Artifact provenance
→ Step 05 approved
→ Step 06 ready
```

HTML validation rejects empty, structurally incomplete, non-UTF-8, and Placeholder results. The HTML Adapter adds a generation-time CSP to newly produced Artifacts, but this is not the Preview trust boundary and historical files are not migrated or rewritten.

Every HTML entering Artifact Review now passes through a Renderer-owned Preview security chain:

```text
original ArtifactReviewDocument.content
→ ArtifactHTMLPreviewSecurityPolicy
→ in-memory secured Preview HTML with Renderer CSP
→ WKContentRuleList external-network blocking
→ non-persistent WKWebView
→ navigation scheme policy
```

The Renderer CSP is inserted at the start of the Preview document head even when the source already has its own CSP; missing-head and provenance-free historical HTML receive a safe in-memory fallback. It denies external/default sources, connections, form actions, base URLs, frames, objects, workers, and unsafe evaluation while retaining the current prototypes' required inline CSS, inline JavaScript / event handlers, and scoped `data:` / `blob:` image or media support. The WebKit content rules independently block HTTP, HTTPS, WS, WSS, and file requests across resource types and must compile before Artifact content is loaded; failure is closed. The website data store remains non-persistent, but is not treated as network isolation. Navigation permits only `about:` for `loadHTMLString` and same-document anchors; HTTP, HTTPS, file, mailto, data, blob, and all unrecognized navigation schemes are cancelled.

The Prototype step now keeps only the tool-agnostic business goal. The frozen capability + Tool + Route resolve the concrete execution specification. For the current DeepSeek Harness → HTML Prototype Route, both the final prompt and Preview Expected Outputs require a complete runnable single-file HTML result; the obsolete “prepare an execution brief and wait for confirmation” wording has been removed.

Prototype fidelity and style are represented by a tool-independent `ZhuowangPrototypeExecutionProfile`. Missing historical data defaults to High-fi + 高保真活动页 to preserve the previously accepted behavior. The Profile is persisted on capability-bearing Workflow Steps, frozen into each execution snapshot, shown in Task Package Preview, and translated by the selected Tool / Route specification. It does not alter the Artifact logical key, so Low-fi / Mid-fi / High-fi runs remain versions of the same logical prototype.

Do not assume HTML is the final prototype path.

Artifact review is now separated from execution and adoption:

```text
Artifact Draft / historical Artifact
→ ArtifactReviewDocumentProjector
→ ArtifactReviewPayload (inlineText / localFile / unavailable)
→ ArtifactPreviewInputResolver (read-only, controlled I/O)
→ ArtifactReviewDocument (immutable provenance + typed input)
→ ArtifactPreviewRendererRegistry
→ registered Renderer or safe fallback
→ ArtifactReviewWorkspace
```

The Artifact Preview Abstraction Layer Phase 1 is confined to Review projection and Renderer input. It does not modify `ZhuowangArtifact`, `ZhuowangArtifactType`, UserDefaults schema, Adoption, Recovery, Workspace File Manager, or Task Package construction. Legacy inline text is projected without normalization; a supported local HTML / Markdown / plain-text reference is read only while resolving Preview Input. Binary files are never decoded as `String`, arbitrary `location` values are not inferred as external URLs, and missing, unreadable, unknown, or conflicting media enter the safe fallback.

Renderer selection now starts from typed Preview Input rather than only `ZhuowangArtifactType`. Media classification considers payload kind first, then UTType identifier, MIME type, file extension, and the legacy type hint; conflicting evidence fails closed. Renderer capabilities drive whether Source, Full Preview, and 375px / 390px controls appear, so unrelated renderers are no longer forced to receive a mobile viewport. The Registry currently contains HTML, Text, Image, and PDF Renderers plus the safe fallback; Figma, Pixso, external URL, and other external-document Renderers remain deferred.

Image Renderer Phase 1 extends the Review-only typed boundary without changing persistence:

```text
ArtifactReviewPayload.localFile
→ ArtifactPreviewInputResolver (reference only; no UTF-8 decode)
→ typed local-file Preview Input
→ ArtifactPreviewRendererRegistry
→ ArtifactImagePreviewLoader
→ ImageIO validation + bounded decode
→ Renderer-local CGImage + minimal metadata
→ adaptive Image Preview canvas
```

Only local, single-frame PNG and JPEG are accepted. The Loader verifies the actual ImageIO type against declared UTType / MIME / extension evidence and rejects damaged, disguised, conflicting, multi-frame, or unsupported files rather than falling back to WebView or `NSImage`. Hard limits are 50 MiB file size, 16,384 px per side, 36 MP total pixels, and a 224 MiB estimated peak decompression budget; oversized files are rejected rather than downsampled. Decode work is asynchronous and globally serialized to one heavy operation, with cancellation and document-generation guards. File size, modification time, and resource identity are checked before and after decoding so changed results are discarded.

Image Preview supports Fit, backing-scale-aware 100%, zoom from 10% to 400%, reset, two-axis scrolling, transparent-image checkerboard, and minimal format / pixel / file-size information. It does not expose Source or Mobile Viewport. Image-specific state remains inside each Renderer instance, so Compare panes do not share zoom, load, error, or decoded-image state. Single-version Full Preview is supported; Compare intentionally continues without Full Preview.

PDF Renderer Phase 1 extends the same typed local-binary Review boundary:

```text
ArtifactReviewPayload.localFile
→ ArtifactPreviewInputResolver (reference only; no UTF-8 decode)
→ exact PDF media classification
→ ArtifactPreviewRendererRegistry
→ ArtifactPDFPreviewLoader
→ bounded Data snapshot + fingerprint checks
→ ArtifactPDFPreviewSecurityPolicy
→ PDFKit PDFDocument
→ ArtifactSecurePDFView + Renderer-local binding session
```

The Loader accepts only an explicitly referenced local PDF whose declared and detected media evidence agrees. It enforces file-size, page-count, page-dimension, and page-area limits; rejects encrypted documents; and discards results when cancellation, document generation, or the file fingerprint changes. Expensive PDF loading is serialized through one app-wide gate. The gate's verified maximum concurrent operation count is one and returns to zero after completion.

The security inspection rejects AcroForm / Widget content; JavaScript, OpenAction, Additional Actions, Launch, URI, RemoteGoTo, disallowed Named Actions, attachments, Sound, Movie, RichMedia, 3D, and unknown actions fail closed. Runtime PDFView delegation permits same-document internal GoTo while external HTTP / HTTPS, file, mailto, RemoteGoTo, Print, and other external actions do not launch another application. The UI does not provide Print, Save, Export, or Annotation editing. Error messages expose a sanitized reason rather than the full absolute file path.

PDF Preview uses continuous vertical PDFKit layout with Fit Page, Fit Width, 10%–400% zoom, page navigation, minimal page / size metadata, text selection, and copy only when the document permissions allow it. Review and Full Preview share the same Renderer. Compare creates one independent Renderer and PDFView per side for PDF | PDF and keeps mixed HTML | PDF, Image | PDF, and PDF | Unsupported capabilities isolated. Source and Mobile Viewport controls remain hidden for PDF.

`ArtifactPDFRendererBindingSession` makes cleanup explicit and idempotent. The View Model retains the active session; the session owns the safe delegate, observer tokens, and deferred publications while weakly referencing the View Model and PDFView; the Coordinator retains the session. Cancellation or dismantling invalidates the generation, cancels pending work, removes observers, clears both delegate references and the document, and disconnects the session. Teardown does not depend on object deinitialization or only on `dismantleNSView`, and late notifications or an old generation cannot write state back.

This is a bounded in-process preview boundary, not a claim that arbitrary hostile PDFs are safe. PDFKit and Core Graphics still parse inside the Cosmos OS process. Phase 1 cannot precisely cap PDF internal object counts, framework caches, or synchronous parse time, and a logical timeout cannot forcibly terminate work that has already entered synchronous PDFKit parsing. A materially stronger boundary requires a future XPC or separate-process Renderer.

Source displays the unchanged original HTML; Preview renders only the secured in-memory copy in a non-persistent real WKWebView. The existing HTML CSP, WKContentRuleList, Navigation Policy, and content-rule fail-closed behavior were not weakened or duplicated. The 375px / 390px device widths are layout constraints, not screenshot scaling or source-file rewriting.

The adopted Artifact Detail entry now defaults to a Preview Workspace action instead of rendering HTML source as its primary body. Users can still explicitly select source view, and switching among managed versions resets the entry to Preview. Both Draft and adopted Artifact entries construct an `ArtifactReviewDocument` and open the same `ArtifactReviewWindowManager`; unsupported types retain the Registry fallback, and historical Artifacts without provenance remain safe.

Artifact Version Compare Phase 1 adds a separate review surface without expanding the single-version Workspace into compare-specific branches:

```text
managed Artifact version collection
→ UUID-based compare selection state
→ ArtifactVersionCompareWorkspace
→ left / right ArtifactReviewPane
→ ArtifactPreviewRendererRegistry
→ secured Renderer Preview or unchanged Source
```

Compare state is window-local SwiftUI state only. It is not written to UserDefaults, SceneStorage, Workflow, Artifact models, or Codable persistence. The default pair is the current adopted version on the left and the selected historical version on the right; when the selected version is current, the highest other managed version is used. Choosing the opposite side's UUID swaps the pair so both sides can never reference the same Artifact. The Compare window identity is stable by `campaignID + versionGroupKey`, independent of the selected pair, and an existing window is brought forward instead of duplicated.

Both Compare sides reuse the same `ArtifactReviewPane` as the single-version Workspace. Each side resolves its Renderer from its own typed Preview Input, so HTML Preview continues through the established Renderer Security Boundary and unsupported / unavailable inputs continue through the safe fallback. Preview / Source are independent per side and Source is offered only when that Renderer declares support. The shared 375px / 390px control remains fully compatible for two HTML sides and is passed only to sides declaring Mobile Viewport support. A version change replaces that side's `ArtifactReviewDocument` and recreates only that Renderer subtree by the stable Artifact UUID, preventing prior DOM / JavaScript state from surviving or crossing between WebViews.

---

## 8. Current Artifact principles

Artifacts are versioned work assets.

Current behavior / requirements:

- preserve V1 / V2 / V3...
- one currently adopted version per logical Artifact
- allow rollback to an older version
- never delete old versions merely because a newer version exists
- preserve local file paths
- prefer real local files for important outputs
- recover metadata from local files where possible

Campaign 工作产物交付包 Phase 1 is a read-only projection of currently adopted, managed local files. It does not add an Artifact type or persistent export record, does not import unmanaged files, does not select historical versions, does not collect HTML dependencies, and does not convert, regenerate, upload, or share content.

Local workspace example:

```text
~/Documents/Cosmos OS/Workspaces/卓望/浙江/浙江活动测试/
```

Known step folders include:

```text
01_需求整理
02_策划思路
03_完整策划案
04_页面结构
05_...
06_客服文档
Assets
```

Historical folder naming must remain readable.

---

## 9. Current architecture boundary

Do not prematurely refactor into a universal multi-Workspace framework.

Long-term:

```text
Workspace
├── Organization / Company
├── Projects
├── Workflows
├── Artifacts
├── Knowledge
├── Templates
└── AI Connections
```

Current implementation focus:

**Make the real 卓望 workflow mature first.**

---

## 10. Known technical debt / risks

### P0 / High

- Business data still relies heavily on UserDefaults in current implementation.
- Long-term business persistence should move toward a more robust structured persistence strategy.
- Schema migration and recovery must remain safe.
- Workflow, AI Provider, AI Connection, Tool Integration, and Agent/Tool Route payloads now have decode protection and backup recovery.
- Campaign Store and Workspace Store now share the Phase 1 protected transaction boundary. Cross-process coordination, backup rotation, automatic recovery, and disk-level durability remain future work.

### P1

- The first HTML Adapter Registry / execution orchestration path is complete; other Tool Adapters remain future work.
- Browser / desktop-width preview is not implemented; Phase 1 currently focuses on 375px / 390px mobile HTML review.
- Artifact Version Compare Phase 1 provides managed-version side-by-side review. Text / semantic Diff and difference highlighting are not implemented.
- Review annotations, anchored comments, approval notes, and markup are not implemented.
- Figma, Pixso, external URL, and other external-document Preview Renderers are not registered yet; unsupported or unavailable inputs still use the safe fallback. Image and PDF Phase 1 remain local-file review only and do not add binary Artifact Adoption, persistent payload changes, recovery, search, thumbnails, Outline, form interaction, editing, OCR, annotation, printing, saving, export, password handling, or external URL documents.
- ImageIO decode calls cannot be interrupted once inside the framework. Cancellation prevents queued work and discards late results, but a currently executing decode may consume its bounded budget until ImageIO returns.
- PDFKit and Core Graphics parse PDF content inside the Cosmos OS application process. File, page, dimension, area, action, and concurrency limits reduce exposure but do not provide process isolation or guarantee safe handling of arbitrary malicious PDFs.
- PDF internal object counts, framework caches, and synchronous PDFKit parsing time cannot be precisely bounded at the current layer. Cancellation and logical timeout prevent stale publication but cannot forcibly terminate framework work already executing synchronously; a stronger trust boundary requires a future XPC or separate-process Renderer.
- Local Image Preview currently relies on the explicit URL already projected into the Review document. Durable security-scoped bookmark persistence and cross-Mac file relocation remain part of a future persistent payload / recovery phase.
- HTML Preview intentionally permits inline JavaScript / event handlers and scoped `data:` / `blob:` image or media resources for existing interactive prototypes. This is a compatibility boundary, not a general browser sandbox; any future relaxation or Browser Preview capability requires a separate threat review.
- The persisted Artifact model and adoption / recovery paths remain partly HTML-first. Phase 1 intentionally stops at the Review projection boundary; a future real binary or external-document adoption path still needs an optional, backward-compatible persistent payload descriptor without rewriting historical data.
- DeepSeek Harness now has a scoped Runtime Compatibility Layer. Swift no longer pins a concrete DSH release-candidate version; it discovers the installed `dsh` executable, reads its reported version, verifies `--profile headless` support, and resolves `DSH_HOME` from the launch environment or Harness LaunchAgent.
- Target runtime boundary:

```text
Cosmos OS
↓
Harness Runtime Adapter
↓
Current environment-available Harness Runtime
```

The discovered executable is used directly. If discovery fails, the previous npx-based launch shape remains available as a version-unpinned compatibility fallback. Runtime discovery logs the selected source, path, version, and `DSH_HOME`. This remains a DeepSeek-only compatibility layer, not a universal AI Runtime Adapter Layer.
- Figma real automated execution is not yet implemented.
- Claude Desktop direct execution is not yet implemented.
- ChatGPT direct execution path is not yet implemented.
- Codex execution path from inside Cosmos OS is not yet fully implemented.
- Step 06 Phase 1 supports only DeepSeek Harness → Markdown. Local import, external URL/cloud-document references, Word/PDF generation, other Provider adapters, persistent draft/revision history, comments, annotations, hard rejection, undo, and a general approval framework remain deferred.
- Step 06 pre-adoption running/result/revision state is session-only. The first live run violated this boundary by allowing Harness to write directly; after the child-process sandbox and before/after integrity check were added, the 2026-09-29 real Harness run left the formal customer-service Workspace and knowledge-base directories empty and the Workflow primary/backup bytes unchanged before adoption. This is one live acceptance, not a proof for all future Harness versions or external services.
- Step 06 Provider choice is now session-local until adoption, so selecting it for generation no longer saves Workflow/Step `updatedAt`. Step 01–05 provider behavior is unchanged.
- Step 06 has broad automated persistence, Review, Compare, Recovery, and regression coverage. The 2026-09-29 fixed-runtime Draft/Preview and human adoption passed real UI acceptance; persisted Workflow metadata and the formal Markdown V1 were independently checked afterward. Restart recovery and future-version compatibility were not part of this acceptance.
- Campaign 工作产物交付包 Phase 1 has automated ZIP-content, manifest/checklist, SHA-256, adoption-change, duplicate-adoption anomaly, missing/outside/symlink/directory, path-traversal, source-mutation, archive-corruption, destination-collision, cleanup, and default Python ZIP-reader coverage. The requested real export and existing-target refusal checks passed. ZIP creation, hashing, extraction, and verification still run synchronously from the selection sheet action; large delivery sets may temporarily block UI responsiveness. No hang was observed in this small Campaign export; that does not resolve the deferred responsiveness risk. Ditto's raw UTF-8 names initially lacked bit 11; the Service now validates strict UTF-8 bytes and paired local/central records before setting the flag in both headers. An independent whole-archive comparison proves only these flags change, not payloads, CRC, sizes, names or manifests. Other P3 items remain deferred.
- Artifact sidecar manifests are deferred, so disaster recovery can reconstruct the primary HTML prototype logical key only from the canonical artifact name.

### Deferred

- Permission optimization for DeepSeek subprocess / macOS file permissions.
- Artifact window opening performance optimization.
- global UI / motion polish.
- universal multi-Workspace refactor.

---

## 11. Current development workflow decision

Development responsibility is being split intentionally:

### User

- Product owner
- final business decisions
- final UX acceptance

### ChatGPT web

- Product architecture advisor
- technical solution design
- roadmap / tradeoff analysis
- cross-session project review

### Codex on Mac

- local repository engineer
- codebase analysis
- file modifications
- build / test
- bug fixing
- diff review
- documentation updates
- Git preparation

The goal is to remove manual code-copy / file-replacement work from the user.

---

## 12. Daily synchronization protocol

After meaningful Codex development:

1. Build / test.
2. Update this file.
3. Create/update today's file under:
   `Docs/Development Log/`
4. Review Git diff.
5. Commit with:
   `feat/fix/docs/refactor/chore/test: 中文描述`
6. Push when the user requests synchronization.

Then ChatGPT web can read GitHub and continue from the latest repository state.

---

## 13. Next priority

**Current:** Projects Phase 1 已完成开发、验证与可回退部署（§30），用户已接受声明验收范围并关闭阶段；本次仅完成已授权 Git 收尾，下一模块等待明确指令。Mac 概览、恢复与备份均已正式关闭（§28 / §27 / §26）；暂缓事项不动。

AI 工作台 Phase 1/2、Dashboard、月度会员促活、省份配置、学习中心、Prompt Vault、知识与资产中心均已关闭；不恢复其历史验收或旧调查候选项。Word WIP、Step06 Harness、客服文档 V1 重新采用、Evidence/Quarantine、旧 P3 保持暂缓。

**Previous milestone:** 知识与资产中心 Phase 1 is closed after Claude’s one concentrated read-only review (A; no discovered blockers). The owner authorized its single feat commit and normal origin/main push. The next major module awaits product coordination; do not automatically start it, repair deferred F1–F5, restore Word WIP, run Harness or expand deferred work. Previous checkpoint: Campaign 项目推进工作台 Phase 1 is closed. No further tests or manual click-through were requested for this phase. Do not open Campaign detail windows with sample / fixture Campaigns in the DEBUG isolated mode: detail windows can write into the formal Workspace path (todo 4). Development policy from 2026-09-30: advance whole features; per phase at most one focused test / review round and one focused fix round, then verify only affected parts; record non-blocking issues as todos until the whole project runs; no repeated full-suite runs and no step-by-step clicking requests. Data safety, content integrity and broken core functions are still fixed within the phase.

Campaign 项目推进工作台 Phase 1 (read-only summary):

- Entry: 卓望工作 sidebar → 总览 → **推进工作台** (selected by default when entering the Workspace). The previous province / module 概览 tab showed hard-coded placeholder metrics and recent-work rows; those two sections are replaced by the same workbench scoped to that province / module. 快捷创建 and 内容资产 placeholders remain unchanged.
- Content: metrics (activities, within activity dates, failed / needs revision, deliverable); filters (province / module, Campaign status, name search) with empty states; 推进列表 grouping each Campaign once by real Workflow state (failed / needs revision → generating / awaiting confirmation → next step → deliverable → six steps confirmed but no deliverable file → Workflow not created); 近期活动 by the Campaign's own start / end calendar days (ongoing, upcoming, ended within 30 days, with the date basis shown and no inferred deadlines); 活动总览 with name, province / module, dates, status, six-step progress and adopted-artifact count (multiple-adoption conflicts flagged).
- Deliverable means all enabled steps approved / completed and at least one adopted artifact accepted by the existing delivery-package eligibility rules (real local file inside the Campaign Workspace).
- Actions reuse the existing Campaign window manager: 打开 Workflow, 查看产物, 导出交付包 (opens the existing delivery sheet), 打开 (overview). A small route object lets an already-open Campaign window switch tab. No Step 07.
- Read-only: builds from persisted Campaign / Workspace / Workflow data; never creates a Workflow, changes status or adoption, or generates AI content. One Workflow Store instance is now shared by the Campaign list, the workbench and the Campaign windows they open (previously each Campaign list view created its own instance).

Todos (non-blocking, deferred until the whole project runs): (1) the large existing metric cards push lists below the fold on short windows; (2) summaries, including delivery-file checks, are recomputed on every render / filter keystroke — cache if Campaign count grows; (3) remaining placeholder sections in the province 概览 tab and the Dashboard home; (4) DEBUG isolated UI mode does not isolate Workspace files, and opening a Campaign window runs legacy-artifact migration that writes into the formal Workspace path — so real click-through of workbench actions was not exercised with fixture data; (5) the isolated App ignored a preset window frame, limiting captures; (6) a route request that arrives while a Campaign window is being edited is not re-applied after editing ends.

Previous milestone notes (delivery package / Word export) follow.

The product owner confirmed Phase 1 acceptance and authorized Git closeout on 2026-09-30. The requested final-code real export checks are complete, including default 0/6 selection, six current versions, all-eligible selection, successful save, ZIP inspection and Finder reveal. Existing-target refusal passed through the real Save Panel Replace confirmation and application refusal; UTF-8 normalization does not change destination validation/publication. Disabled-item scenarios are covered by fixtures (this real Campaign has six eligible items); Save Panel cancellation was not separately exercised. Claude's prior independent static review is complete per the user; no new full review is requested, and other P3 work remains deferred. After Git synchronization, await the owner's next explicitly selected milestone; do not automatically start P3, Step 07 or another project.

This feature is an independent post-Workflow capability, not Step 07. Phase 1 does not include cloud upload/sharing, AI regeneration, historical-version selection, unmanaged-file import, binary adoption/recovery, format conversion, dependency collection, or export-history persistence.

Step 06 Phase 1 is implemented and accepted for the observed 2026-09-29 real UI path:

```text
Step 06 ready
→ Task Package with currently adopted upstream Artifacts
→ DeepSeek Harness Markdown result
→ session-only Artifact Draft
→ safe Text Renderer in Artifact Review Workspace
→ human adoption
→ protected Workflow transaction
→ versioned .md + Run + Approval + provenance-complete Artifact
→ Step 06 approved
→ Artifact Detail / version history / Text Compare
```

Completed milestone capabilities:

- safe native Markdown/plain-text Preview with literal selectable content and no HTML/script/network execution;
- DeepSeek result conversion into the existing Review Workspace without formal writes before adoption;
- a stable `workflow.customerService.primary` logical Artifact group with version preservation and exactly one adopted version;
- a Step 06-specific protected adoption transaction with stale/decode checks, backup and primary verification, structured UI errors, and safe retry;
- unadopted-only Step 06 local-file Recovery that never approves the step;
- adopted Markdown reopening through Artifact Detail and using the existing managed-version Compare surface;
- isolated XCTest and Universal Debug/Release builds from the implementation, P1 and P2 verification rounds, plus the Release isolation-string scan. These automated checks preceded the final live adoption; they were not rerun as part of the 2026-09-29 closeout.

Next-session handoff:

1. Use this accepted Step 06 Phase 1 as the baseline; do not repeat adoption or import the quarantined accident file.
2. Keep the four Evidence/Quarantine files intact until the product owner separately authorizes their disposition. The knowledge-base customer-service directory remains empty; the adopted file lives only in the Cosmos Workspace.
3. Let the product owner choose the next milestone explicitly. Persistent drafts/revisions, comments/annotations, local import, external references, additional Providers, Word/PDF generation, Browser/Desktop Preview, Store Phase 2, and cross-process persistence remain separate future work.

A universal AI Runtime Adapter Layer remains deferred. Do not disturb the accepted DeepSeek Harness + HTML Step 05 path while adding Review capabilities.

---

## 14. Do not regress

Do not regress these verified decisions:

- 01-04 Workflow recovery
- 完整策划案 current version = V1
- Figma is Tool, not AI Provider
- prototype step is tool-agnostic
- Artifact versions are preserved
- local work files are not disposable
- native business detail windows remain native macOS windows
- core architecture before visual polish
- no premature universal Workspace refactor

---

## 15. Current verification checkpoint

- 2026-09-30 Campaign 项目推进工作台 Phase 1 (automated + isolated capture; **no manual UI acceptance**): `ZhuowangCampaignWorkbenchTests` **8/8** (progress / next step / attention / adoption / conflicts; category priority and disabled steps; calendar-day date phases incl. boundaries; province / module / status / name filters; deliverable counting through the delivery-package rules with real temporary files; read-only proof over real Stores backed by an in-memory data source — zero writes, storage unchanged, no Workflow created; route delivery; offscreen rendering of the real view for full, province-scoped and empty states). One review round found and fixed: overview header row stretching (flexible `Color.clear`), overview table overflowing and clipping the detail pane at common widths (compact dates / columns), and Swift 6 actor-isolation warnings; only affected tests were re-run. Universal Debug **BUILD SUCCEEDED** `x86_64 arm64`; `git diff --check` passed. The real App was launched in its existing DEBUG isolated mode (temporary Bundle ID `…persistenceui.C29DD703-…` + Store Phase 1 suite seeded with the test fixture) and opened directly on the workbench through a new DEBUG-only, isolated-only `--cosmos-initial-sidebar zhuowang` argument; the window was captured. Temporary domains created by this work were deleted afterwards. Screens: `/private/tmp/Cosmos-Workbench-Screens-20260930/`. Formal data check: all 11 business `Data` keys, five adopted source hashes, adoption / step states and the 浙江活动测试 Workspace file listing are unchanged versus the 15:39 baseline. `project.pbxproj` Xcode re-serialization (semantically identical) was restored to HEAD. Incident: an AppleScript resize meant for the isolated App resolved the product owner's running Xcode-run App by name and moved / resized its 客服文档 Artifact Detail window (window geometry only; no data). System Events automation was not used again.

- Post-P0 runtime state was manually verified by the user without regenerating 01-04 or changing the adopted V1 selection.
- P0 persistence changes do not reset or delete UserDefaults data.
- The user confirmed that Workflow progress, Tool separation, recovered Artifacts, and historical versions remained intact after running the updated app.
- Step 05 runtime adoption preserved the approved state of Steps 01-04 and the currently adopted Campaign Plan V1 while advancing only Step 05 to approved and Step 06 to ready.
- Full Universal macOS Debug build completed with `BUILD SUCCEEDED` on 2026-08-19.
- Minimal Step 05 Unit Test Target completed with 7/7 tests passing.
- Step 05 execution-semantics follow-up completed with full Universal Build success and 9/9 Unit Tests passing on 2026-08-20.
- Step 05 real runtime acceptance completed on 2026-08-21: credentials service resolution succeeded, DeepSeek returned real HTML, preview/source/interaction checks passed, HTML Artifact V1 was adopted and persisted, Step 05 became approved, and Step 06 became ready.
- The last manually accepted Harness run used `@deepseek-ai/dsh@0.1.0-rc.6` with `DSH_HOME=$HOME/.dsh-rc8-clean`. Swift no longer pins that package version; the compatibility layer currently discovers the installed local `dsh` runtime and the same LaunchAgent-managed `DSH_HOME`. A post-change live smoke run remains pending.
- Prototype Fidelity Control completed a macOS Debug Build and 30/30 Unit Tests on 2026-08-21. Live UI confirmation of profile selection, persistence, Preview display, and one Low-fi / High-fi Harness output remains pending.
- Artifact Review Workspace Phase 1 plus adopted Artifact Detail entry completed a macOS Debug Build and 39/39 Unit Tests on 2026-08-21. Automated coverage includes V1 / V2 / V3 HTML review documents, Preview as the Artifact Detail default, Renderer Registry selection, and legacy Artifacts without provenance. Live UI confirmation of version switching, selected-version window content, independent-window sizing, mobile interactions, full-preview ergonomics, and Light/Dark Mode remains pending.
- Artifact Review Renderer Security Boundary Phase 1 completed a Universal macOS Debug Build and 47/47 Unit Tests on 2026-08-21. Read-only UI smoke confirmed managed V1 / V3 / V4 Preview loading, V3 Preview / Source, 375px / 390px, scrolling, local button interaction, Full Preview, and V3 remaining adopted. V1-V4 file hashes and the Cosmos Toolbox UserDefaults domain hash were unchanged before and after the smoke test; unmanaged V2 remained untouched.
- Artifact Version Compare Phase 1 completed a Universal macOS Debug Build for arm64 + x86_64 and 59/59 Unit Tests on 2026-08-24. Read-only UI smoke confirmed default V3 | V4, Detail-selected V1 opening V3 | V1, UUID swap behavior, independent Preview / Source and scrolling, shared 375px / 390px viewport, isolated WebView interaction state, stable Compare window reuse, native full screen / close / reopen, and unchanged single-version V1 / V3 / V4 Review plus Full Preview. The adopted prototype remained V3; Workflow and UserDefaults were unchanged; V1-V4 hashes remained identical and unmanaged V2 stayed untouched.
- Artifact Preview Abstraction Layer Phase 1 completed a Universal macOS Debug Build for arm64 + x86_64 and 70/70 Unit Tests on 2026-08-24. Automated coverage verifies legacy inline/local text projection, exact Source preservation, binary files bypassing UTF-8 decoding, missing/unreadable/conflicting fallback, stable IDs and provenance, typed Registry selection, capability-driven UI normalization, unchanged HTML security, and mixed Compare compatibility. Read-only UI smoke reconfirmed V1 / V3 / V4 Review, V3 | V1 and default V3 | V4 Compare, independent Preview / Source and scrolling, shared 375px / 390px, isolated button state, Full Preview, native full screen / close / reopen, adopted V3, and Workflow 01–05 approved / 06 ready. Prototype file hashes remained unchanged, including unmanaged V2. The application preference plist was reserialized during the native-window smoke session because it contains `NSWindow Frame` / split-view state, so its whole-file hash changed; no business-data mutation was invoked, and the live Workflow/adoption state remained unchanged.
- Artifact PDF Renderer Phase 1 completed 115/115 Unit Tests with 0 failed and 0 skipped, plus a Universal macOS Debug Build for arm64 + x86_64 with `ONLY_ACTIVE_ARCH=NO` and `CODE_SIGNING_ALLOWED=NO`. `git diff --check` passed. The focused Fixture smoke passed five consecutive runs; the final post-acceptance Fixture smoke passed in 2.420 seconds. Security policy focused tests passed 5/5, lifecycle coverage passed, and the app-wide PDF load gate reached a maximum concurrency of one and returned to zero.
- PDF Fixture acceptance used only dynamically generated temporary files and did not read or import a real business PDF. Six business-shaped Fixture windows reached ready and contained seven real PDFViews. Human-observed and automated interaction coverage confirmed PDF display, continuous scrolling, page navigation and page entry, Fit Page, Fit Width, 100%, 10%–400% limits, independent PDF | PDF page / zoom state, Full Preview close / native close / reopen / resize / native full screen, HTML | PDF, Image | PDF, PDF | Unsupported, Light / Dark appearance, and the corrected temporary WindowContext close path. No PDF Publishing warning, crash, hang, or abnormal CPU use was observed.
- Manual acceptance did not completely cover the final system clipboard contents after text selection, a viewable-but-copy-prohibited PDF, or clicking every dangerous PDF action. Those boundaries have automated policy coverage and are explicit Phase 1 acceptance gaps rather than claims of complete manual security validation. A focused combined run also recorded two SwiftUI `@State` warnings caused by construction in other Compare tests; they were not PDF Publishing warnings and did not fail the tests. This was kept out of the PDF Phase 1 scope for separate follow-up.
- PDF verification did not run Harness, generate, import, or adopt an Artifact, or modify business UserDefaults. The canonical Workflow SHA-256 remained `a7e3dd5f7e2dc1c62f62d0e7490b660df59b3947eb0f90e293d7ad617dd02b61`; Workflow remained 01–05 approved and 06 ready; adopted prototype remained V3; managed versions remained V1 / V3 / V4 and V2 remained unmanaged; the established V1–V4 file hashes remained unchanged.
- Initial Step 06 implementation checkpoint: 170/170 XCTest passed with 0 failed/skipped under temporary Bundle ID `com.wangyucosmos.cosmostoolbox.step06tests.6F0B17A4-795F-4DA3-9DC7-BFC7A4C1D698`. The temporary preference domain contained only two window-state keys and no business `Data` key. The test build and independent macOS Debug/Release builds contained `x86_64 arm64`; the Release isolation-string scan found zero matches for 10 DEBUG-only identifiers and retained `CosmosRootView`. At that earlier checkpoint the formal plist and Workflow bytes were unchanged, and live UI acceptance had not yet run.
- 2026-09-24 P1 fix: targeted Step 06 XCTest 15/15 and full suite 175/175 passed with 0 failed/skipped under a temporary Bundle ID, suite and `/tmp` data/build roots. Universal Debug and Release builds succeeded for `x86_64 arm64`; 10 Release DEBUG-only identifiers were absent and `CosmosRootView` remained. No post-fix formal App or real Harness run occurred. The two incident files remain untouched.
- 2026-09-29 narrow P2 follow-up: the Step 06 sandbox profile and child environment use matching POSIX-canonical temporary run/DSH paths; only the exact `/dev/null` device is additionally writable. Real `sandbox-exec` probes cover permitted HOME, TMPDIR, cwd, PWD, npm cache, DSH_HOME and `/dev/null` writes, denied protected-root writes, and denied Git execution. Step 01–04 revisions use the original raw request, while Step 06 revisions retain the sandboxed task-package path. Focused and complete isolated XCTest and Universal Debug/Release builds passed; Release DEBUG-isolation scan had zero hits. Claude's narrow static re-review passed before the later live re-acceptance.
- 2026-09-29 live Step 06 re-acceptance: the user observed a real Harness Markdown Draft and readable Review Workspace. Before adoption, the two formal customer-service directories remained empty and the Workflow primary/backup bytes remained at the recorded pre-generation values. The user then clicked Adopt; the UI showed Step 06 `已确认` and the Markdown V1 `已采用、已落盘`. Independent read-only inspection found the 28,360-byte formal V1 file with SHA-256 `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`; persisted Step 06 is `approved` with exactly one succeeded Run, one approved Approval and one uniquely adopted Markdown Artifact. The Artifact's content bytes equal the file bytes. The Workflow backup equals the pre-adoption primary (`88ab71fe…`); the post-adoption primary is `b71226b1…`. The four incident Evidence/Quarantine files retain their original 31,878-byte size and `a198eb7d…` hash. This verifies this one adoption round trip, not restart recovery or universal future-runtime confinement.
- Campaign 工作产物交付包 Phase 1 focused XCTest passed 11/11. The isolated real-ZIP fixture creates and independently extracts a ZIP, then verifies the selected file bytes, manifest/checklist content, package-relative paths, byte counts, and SHA-256 values. Adoption-change coverage rejects both a group losing its adopted version and a selected Artifact being replaced by another adopted version before save. Related Artifact Review/Compare and Step 05/06 regression suites passed 95/95 in total with 0 failed and 0 skipped. These tests used temporary roots and a temporary Bundle ID; they did not launch the formal App or run a real Harness operation.
- Campaign 工作产物交付包 Phase 1 Universal macOS Debug build succeeded for `arm64 x86_64` with `CODE_SIGNING_ALLOWED=NO`. `git diff --check` passed. Full real UI acceptance remains pending.
- 2026-09-30 path eligibility fix: focused delivery-package XCTest **13/13**, related delivery-package / Step 05 / Step 06 / Artifact Review / Compare regression **97/97**, all passed. The case-variant fixture exported and independently extracted a real ZIP with matching bytes, size, and SHA-256 on the current case-insensitive volume; on a case-sensitive volume the test expects a nonexistent case variant to be disabled. Existing outside/missing/directory/symlink tests remain intact; new coverage rejects a prefix-similar sibling, source `..` traversal, and a directory symlink. Universal Debug build succeeded (`arm64 x86_64`); final App: `/private/tmp/CosmosDeliveryPathFixDebug20260930/Build/Products/Debug/Cosmos Toolbox.app`. The real successful export is recorded below; full acceptance remains pending.
- Real export on 2026-09-30 11:07:58 +08: `/Users/rainiesmac-15/Documents/浙江活动测试_交付包.zip` (35,996 bytes), outside the Campaign Workspace but saved in Documents rather than the proposed isolated directory. Native independent extraction and read-only ZIP checks confirmed exactly 6 adopted files (01–04 V1, Prototype V3, Customer Service V1), `交付清单.md`, and `manifest.json`; item IDs, logical keys, steps, versions, file bytes, sizes, hashes, and absence of absolute source paths all matched. Customer Service V1 SHA-256 is `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`. All 11 business Data keys and 9 managed source hashes were unchanged; window-state keys were compared separately and also unchanged. No `.cosmos-delivery-*` directory remained in Documents or the acceptance directory. Evidence: `/private/tmp/Cosmos-Delivery-UI-Acceptance-20260930/zip-verification-after-export.json`. Existing-target refusal is still awaiting a real UI operation; default-empty selection, Finder reveal, and Save Panel cancellation have not been explicitly reported by the user. No complete UI acceptance is claimed.
- 2026-09-30 final UTF-8 compatibility verification supersedes the earlier pending-acceptance checkpoints above: focused delivery-package XCTest **15/15**, related delivery / Step 05 / Step 06 / Review / Compare **99/99**, 0 failed/skipped; Universal Debug **BUILD SUCCEEDED**, `x86_64 arm64`. Evidence: `/private/tmp/CosmosDeliveryUTF8Focused20260930.xcresult`, `/private/tmp/CosmosDeliveryUTF8Regression20260930.xcresult`, `/private/tmp/CosmosDeliveryUTF8Debug20260930.log`. Tests/build correspond to the final Service and Tests; no subsequent source edit occurred.
- Real non-overwrite check: after native Replace confirmation, the App refused with `目标 ZIP 已存在。为保护用户文件，Cosmos OS 不会覆盖它。`. The disposable target SHA-256 remained `c634c2aeac08d7b5a469e059402c5635ba15891fe7887e546443e17b47dd83b2`; no transaction remnants. This preceded the UTF-8-only patch; destination handling is unchanged and the final existing-target XCTest passed.
- Final-code real export at **2026-09-30 13:49:47.842 +08** used `/private/tmp/CosmosDeliveryUTF8Debug20260930/Build/Products/Debug/Cosmos Toolbox.app` (running PID 51814 verified). Output: `/private/tmp/Cosmos-Delivery-UI-Acceptance-20260930/浙江活动测试_交付包_UTF8最终验收.zip`, 35,996 bytes, SHA-256 `110c2231f702220ee72d4424dc9d965512da545a4f57f1bcbd30bb6460ba8512`. Exactly six adopted files (01–04 V1, Prototype V3, Customer Service V1) and two manifests passed exact Chinese-name, metadata, byte-count and hash verification with **Python 3.9.6 default zipfile/extractall** and **macOS ditto extraction**. Finder reveal passed. Windows and macOS Archive Utility extraction were not tested.
- Final integrity comparison: all **11 business Data keys** are byte-identical and JSON-decodable; **9 managed source hashes** and Workflow/Run/Approval/Artifact/adoption state are unchanged. Customer Service V1 remains `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`. Only the separately compared window key `NSWindow Frame GoToSheet` changed; this is not business data. No `.cosmos-delivery-*` remained in Documents or the acceptance directory. Evidence: `/private/tmp/Cosmos-Delivery-UI-Acceptance-20260930/zip-verification-final-utf8.json`. No Harness, adoption, incident-file operation, commit or push occurred.
- `git diff --check` completed successfully.
- Runtime validation of V2 append behavior remains a future follow-up; pure-logic unit coverage already verifies that V2 append does not overwrite V1.


## 16. 知识与资产中心 Phase 1 — 2026-10-09

### Current behavior

Main sidebar 知识库 now opens 知识与资产中心, explicitly limited to Cosmos OS managed Zhuowang Artifacts. Search / province, Campaign and type filters → exact version / source → native read-only asset detail → existing safe Review or Finder → complete original text copy. No import, export, adoption, Campaign-detail navigation, Compare, AI, OCR, external knowledge synchronization or persistent index.

- Group identity is Campaign UUID + existing versionGroupKey. Current mode shows the unique adopted version even if a newer historical version exists; zero-adoption groups have a count / explicit All Versions entry; multiple-adoption groups remain visible with explicit conflicts and no automatic choice or repair. All Versions search identifies each concrete version and adoption state.
- A small raw-data snapshot reader decodes primary Campaign / Workspace / Workflow payloads without creating a business Store. Missing keys are explicitly reported without initialization; corrupt primary data produces a read error without backup recovery; orphan references remain visible. Two bounded attempts reject a changing snapshot. Optional Provider metadata supplies labels only. Duplicate Artifact UUIDs fail explicitly rather than selecting an ambiguous record. No cross-process transaction guarantee.
- Nonempty Artifact.content is authoritative; otherwise the explicitly referenced supported local text is used. Search / detail / copy / text Preview consume the same controlled result. Original whitespace, newlines and Unicode bytes are retained. File/metadata equality is marked only after successful UTF-8 read and byte comparison; missing, unreadable, oversized, conflicting or nonapplicable files remain explicit. No overwrite or synchronization.
- 2 MiB applies to metadata and local text; oversized content is not truncated and metadata results remain discoverable. A serial background service performs bounded FileHandle reads, pre/post device/inode/size/mtime/ctime checks, final-component no-follow open, cancellation and a 32 MiB accounted LRU cache. Refresh clears cache; metadata changes alter requests; each cached read rechecks the file fingerprint. Search has 250ms debounce and request-generation protection.
- Only explicit regular absolute local files are admitted; relative paths, URL strings, traversal, directories, symbolic links and unreadable files are rejected. Safe explicit references outside the Campaign directory are allowed. No directory enumeration. Existing local Image/PDF Renderer safety remains in force.
- Details are independent resizable native windows; no adoption controls. Vanished selected UUIDs do not silently switch version. Refresh clears detail results and closes this center's tracked Review previews; explicit actions re-resolve the selected body. Text Review receives an injected resolver containing the controlled result and cannot fall back to the unlimited default reader. Copy / Finder run only after explicit actions.
- DEBUG isolated asset launches require an explicit `/private/tmp/CosmosAssetPhase1-*` root; missing root fails closed. All sample references must be beneath that root. This does not repair the older Campaign-detail isolated-Workspace risk; do not open sample Campaign details.

### Actual verification

- First focused batch: 40 tests, 36 passed / 4 failed. All failures involved file-body admission: Foundation standardized existing `/private/tmp` paths into `/tmp`, then the strict symlink guard correctly rejected the alias. One concentrated fix preserved explicit paths, retained symlink / fingerprint checks, tightened byte equality and full read-length checks, and invalidated old Review previews on refresh. Unicode and historical / same-ID metadata-refresh tests were added in that round.
- Final affected batch: **42 passed, 0 failed, 0 skipped** = **15 asset tests + 27 ArtifactReviewWorkspace tests**. Evidence: `/private/tmp/CosmosAssetPhase1-Validation/Fixed.xcresult`. Coverage includes raw-data zero writes from startup, corrupt-primary / no-backup behavior, bounded snapshot retry, older adopted versions, conflicts / orphans, raw named-Pasteboard copy, injected Finder request, exact text Preview, changed-file / refresh cache invalidation, invalid / missing / unreadable / symlink / oversized / non-UTF8 files, cache budget, cancellation, latest search, historical hits and changed / removed metadata.
- Final **Universal Debug and Release BUILD SUCCEEDED**, `x86_64 arm64`, `ONLY_ACTIVE_ARCH=NO`, `CODE_SIGNING_ALLOWED=NO`. Logs: `/private/tmp/CosmosAssetPhase1-debug-final.log`, `/private/tmp/CosmosAssetPhase1-release-final.log`. Release binary contains zero instances of `--cosmos-asset-fixture-root`, `--cosmos-initial-sidebar`, `--cosmos-store-phase1-suite`.
- Offscreen real center/detail rendering generated PNGs; this is not real-App interaction acceptance. Fixtures / retained evidence: `/private/tmp/CosmosAssetPhase1-DB2B0E1E-B554-484A-8477-89B4D402B7F0/`.
- Real App: only the temporary Debug bundle `com.wangyucosmos.cosmostoolbox.persistenceui.assetphase1` with a UUID-scoped suite and temporary root. CUA verified current-mode historical-only query returns zero; explicit All Versions returns V3 with historical status/snippet; native detail opens and switches to V1; metadata/file equality and actual body are displayed; Text Review opens; Finder selects the exact temporary Markdown file. No sample Campaign detail was opened. CUA quit/re-query left a temporary bundle process without the isolation banner; the exact temporary executable was then terminated by path, without acting on a same-named formal App.
- Temporary suite's three business keys remained byte-identical to the imported fixture, no extra cosmos business keys appeared, and the temporary Markdown SHA-256 remained unchanged (`ui-integrity.json`). No formal Workspace or personal knowledge repository was used as a sample or scanned. Formal App was not intentionally launched or operated.

### Remaining limits / next action

Phase closed on existing evidence after Claude’s one concentrated read-only review: conclusion **A**, no discovered blockers. Claude independently read the final `Fixed.xcresult` and confirmed **42/42 passed, 0 skipped**, later than the last source modification. Build and real-App results above are Codex’s original verification records; Claude did not rerun them. Closeout also read the existing result and source modification times without running tests/builds. The owner authorized one `feat: 新增知识与资产中心` commit and normal origin/main push from baseline `e2c615165fef4951d6dec99915949bddfbab2aa1`; actual delivery refs are verified after push. This is not complete end-to-end UI acceptance. The next major module awaits product coordination.

Not covered by real UI: clipboard button / general clipboard round trip (named Pasteboard and action injection tested), refresh automatically closing a still-open Review, all filter combinations, all file Renderers, restart and large-catalog performance. Inherited Review XCTest reports an existing SwiftUI State-outside-installed-View warning; build reports AppIntents metadata extraction skipped without a dependency. Neither failed checks.

Deferred engineering: snapshot JSON decode stays on the UI actor and linear search has no persistent index; assess responsiveness with large metadata before optimizing. Invalid UTF-8 read failures can be reattempted on subsequent queries despite unchanged fingerprint (bounded reads, safe failure; optimize failure caching later). Native previews remain bounded in-process, not a stronger parsing sandbox. Existing Workbench / old P3 todos and Word WIP remain untouched.

### Concentrated review follow-ups (non-blocking; not repaired in this phase)

- **F1:** 离开资产中心后，已打开详情保留旧元数据快照，采用标签可能过期；复制仍对应窗口显示版本。后续优先考虑快照标识及重新核对采用状态。
- **F2:** 详情读取与搜索共用代次，搜索变化可能使详情读取失效并停留在重新核对状态。
- **F3:** 资产中心与 Campaign Review 共用窗口身份，后续打开可替换内容，资产中心刷新可能关闭共享窗口。
- **F4:** 无法读取正文的资产可能在正文搜索中缺席，缺少搜索覆盖提示；按名称仍可定位。
- **F5:** 隔离根过滤、Review close、并发测试覆盖及 sleep 稳定性待完善；相关边界与时序的自动化证据仍有限，后续增强，不扩大本轮验收声明。


## 17. Prompt Vault Phase 1 — 2026-10-09 (closed)

> **Historical note (added with 学习中心 Phase 1):** statements in this section such as "unstaged / uncommitted" and "Changes are intentionally unstaged/uncommitted on main baseline `db15f79…`" describe the implementation checkpoint *before* closure and are kept as history. Actual Git after closure: Prompt Vault is committed as `693c4fc` (`feat: 新增提示词库与变量模板`, parent `db15f79`) and pushed; `main` = `origin/main`. The Closure paragraph at the end of this section is the current state.

### Scope and current implementation

Existing Prompt Vault sidebar now routes to the personal module. User-created templates contain stable UUID / createdAt, name, exact body, optional single text category, favorite / archive flags, updatedAt and per-template revision. No predefined templates, imports, permanent deletion, version history, tags, AI, Provider, Workflow / Artifact integration, cloud or semantic search. Default list excludes archived records; explicit archive view offers restore. Search covers saved name/body and combines category/favorite/archive filters.

Category/list/use-detail uses native pure-text UI with a compact category selector fallback. Only saved templates feed use-detail; editor drafts do not update saved body. Variable values are transient and keyed by template UUID and UTF-8 variable identity, survive search/filter and template switching in the module, and clear on leaving the module/restart. Successful template changes preserve same-name values, remove deleted variables and leave new variables empty. Missing/whitespace-only values disable complete-result copy; raw-template copy remains separate. Named Pasteboard exact-copy tests passed. Text tokens preserve untouched UTF-8 spans, whitespace/newlines and replacement values; values are not recursively parsed. Invalid/nested/incomplete placeholders remain literal with warnings; slash parity implements literal escapes.

**Former blocker (fixed 2026-10-09, takeover):** `CharacterSet.letters` is defined as Unicode L*+M*, so it contains U+0301; `PromptTemplateRenderer.validName` therefore admitted a leading combining mark. Fix: first scalar must be `_` or general category Lu/Ll/Lt/Lm/Lo; later scalars `_`, `-`, letters, marks (Mn/Mc/Me) or Nd, judged per Unicode scalar (so `e`+U+0301 stays valid). Source text is never normalized; escape, invalid-placeholder and non-recursive rules untouched. Regression tests: leading mark (with/without leading space, alone, embedded) stays literal with a warning and creates no variable or missing blocker; letter+marks, `_`+mark, Chinese/underscore/hyphen/digit, repeated variables and escapes remain valid.

### Storage and protection

New independent UTF-8 JSON resolves FileManager Application Support + `Cosmos OS/PromptVault/templates.json`; sibling `templates.backup.json` and `.prompt-vault.lock` are the only durable support files. Opening a missing library does not create directories/files; first save does. No legacy Store or Workspace initialization. Default production storage was not used in verification.

Background serial storage uses a dedicated flock, rereads the latest disk document, checks only the target template revision, builds a candidate from that latest document, preserves unrelated templates, backs up exact valid primary bytes, atomically renames the candidate and verifies primary bytes/decode before publishing memory. Raw disk snapshots check for intervening external changes; no redundant document revision. The lock coordinates cooperating module writers, not arbitrary external editors; no claim of power-loss durability or race-proof hostile parent-directory replacement. Parent/file admission rejects symlinks and non-directory/non-regular objects; file reads use no-follow opens. JSON library limit is 16 MiB, rejected without truncation.

Corrupt/unreadable data, duplicate UUID, future schema, missing core fields, or missing primary with existing backup prevent empty initialization. Backup is not automatically restored. Failures preserve drafts and do not publish saved state; post-replacement verification failure marks disk status uncertain and locks saving. A conflict leaves draft intact and exposes copy draft / explicitly confirmed reload, without forced overwrite or automatic text merge. Reload is an explicit disk recheck; a still-corrupt file remains locked.

Native edit windows are keyed by storage root + template UUID, reused by bringing forward without replacing their content. New draft UUID remains its window identity after save. Close choices are save/discard/cancel; failure/cancel retain the window. A minimal `NSApplicationDelegateAdaptor` forwards application termination to the Prompt manager; pending termination freezes editor input and refuses additional editor opens, saves sequentially and replies only after decisions. No other module lifecycle was refactored. Actual native alerts/quit/reuse were not UI-accepted.

### Actual verification and limits

- Initial concentrated command failed during compile because Swift key-path backslashes were omitted in generated sources; zero tests executed. One concentrated repair corrected key paths and froze edit sessions during pending termination. (Codex's original phase: no second repair; the takeover fix below was separately authorized.)
- Codex-era final affected XCTest (before the takeover fix; Renderer 6 at that time): **36/36 passed, 0 failed, 0 skipped** = Renderer 6 + file persistence 8 + state/editor 8 + existing persistence-boundary regression 14. `/private/tmp/CosmosPromptVaultPhase1-Validation/Fixed.xcresult`; log `fixed.log`. Device arm64; this does not claim tests ran on x86_64.
- Tests cover real temporary-file create/update/reopen, exact Unicode/CRLF/whitespace, single prior backup, compatibility defaults, corrupt/future/duplicate/missing-identity cases, missing-primary/backup refusal, symlink/directory rejection, read/encode/backup/backup-readback/replace/readback failure hooks, nonpublication/draft preservation/uncertain lock, same-template stale refusal, unrelated-template preservation, concurrent different-template saves, search/category/favorite/archive/restore, transient values vs drafts, saved-variable reconciliation, named Pasteboard, close and termination decision logic.
- Test host Bundle `com.wangyucosmos.cosmostoolbox.persistenceui.promptphase1tests`, explicit UUID temporary file roots, temporary suites for existing regression, separate DerivedData. Existing-business Data keys in the temporary host stayed equal during Prompt operations; source dependency inspection found no old Store construction/write path in Prompt. No claim of instrumenting all formal business writes or rehashing formal Workspace files.
- Universal Debug and Release **BUILD SUCCEEDED**, both `x86_64 arm64`, signing disabled. Logs `debug.log`, `release.log` under the verification root. Release executable has zero occurrences of `--cosmos-prompt-fixture-root`, `--cosmos-initial-sidebar`, `--cosmos-store-phase1-suite`, `--cosmos-asset-fixture-root`; `release-scan.json` retained.
- Offscreen actual Prompt view rendered successfully in XCTest; its PNG was temporary and removed by test teardown, so no retained visual-layout screenshot or real UI acceptance is claimed. XCTest records a FocusState-outside-installed-View warning in this rendering test; builds also record the existing AppIntents no-dependency warning / existing PDF weak-variable warnings.
- Native CUA initialization timed out twice (30s / 20s). No standalone App launch or real UI operations were performed. Real restart, editor reuse/close/quit alerts, narrow/wide layout, archive visibility after mutation, module-exit value clearing and general clipboard button are unverified at UI level. No user click-through requested or replacement automation framework created.
- Takeover re-run after the Unicode fix: Renderer 8 + PromptVaultState 8 = **16/16 passed** (`/private/tmp/CosmosPromptVaultPhase1-TakeoverValidation/Takeover.xcresult`). Remaining validation limitations: concurrent test uses two async tasks and the real flock but no explicit overlap barrier; real unreadable-file permission and parent replacement races are not exercised; error hooks simulate stages but do not prove every filesystem failure mode. These are review/coverage follow-ups, not passing claims.

### Git and next action

Changes are intentionally unstaged/uncommitted on main baseline `db15f790450da5f1a5107ee78e6076c0e3ff2ed1`; no push/merge/WIP restore. Only Dashboard and App entry plus new Prompt sources/tests and these two progress documents changed. `project.pbxproj` unchanged; synchronized groups found new Swift files automatically.

Takeover review (2026-10-09) of transaction/lock ordering, target-revision and unrelated-template preservation, byte integrity, parser, close/quit handling, App delegate, DEBUG fail-closed root and business-Store isolation found no data-loss, overwrite, body-loss, isolation or core-function blocker beyond the fixed Unicode issue. Non-blocking todos: (1) parser warnings print the literal text `位置 (start + 1)` (string not interpolated; byte offsets would also be misleading for CJK) — fix wording/position in a later polish; (2) any failure inside the replace/read-back block, including a pre-rename write failure such as disk full, is reported as `uncertainWrite` and locks saving until an explicit reload — safe but conservative; (3) an open editor window keeps the Store of the module instance that opened it; after leaving and re-entering the module the new Store reloads from disk, and saves from either side stay protected by revision checks, but the list can be stale until refresh; (4) a new unsaved draft's dirty check ignores the favorite flag; (5) Release was not rebuilt after the pure-Renderer change (Debug test build compiled the same file; earlier Release evidence covers all other files). Real UI items (restart, editor reuse/close/quit alerts, narrow layout, module-exit value clearing, copy button), real permission failures and parent-replacement races remain unverified.

Closure (2026-10-09): product owner accepted the current verification scope; Phase 1 closed with one feat commit and normal push. No further fixes, tests, builds or real-UI acceptance were run for closure. The next major module is to be chosen by product coordination; do not start it automatically. Word WIP (`wip/markdown-word-export-phase1-20260930`, `2d26b2a`), Step 06 Harness, Evidence/Quarantine, F1–F5 and old P3 remain untouched.

---

## 18. 学习中心 Phase 1 — 2026-10-09 (closed)

> **Closure (2026-10-09):** the product owner accepted the existing verification scope and closed Phase 1, authorizing one `feat: 新增学习中心与学习记录` commit and a normal push to origin/main. No further fix, review, test, build or real-UI acceptance was run for closure. The section below was written at the implementation checkpoint; wording such as "implemented, unstaged / uncommitted" is history and is superseded by this closure and by the actual repository refs.

> **Evidence boundaries:** first concentrated batch 57/58, the single failure being a wrong test expectation, corrected and re-run to pass; the offscreen-render test re-run after the routing fix passed (the full 58 were not re-run after those follow-ups); Universal Debug and Release succeeded on the final code; the isolated real page confirmed routing and the topic / status / last-study-day / next-step display with an unchanged fixture hash. Editors, native close / quit alerts, filters, archive, copy button, restart and narrow layout were **not** UI-accepted; no complete end-to-end pass is claimed. The non-blocking todos below are retained and not handled.

### Scope and behavior

The existing **学习 → 学习中心** sidebar entry now opens a personal learning module (previously a bare placeholder; no model, store or tests existed). Path: create topic → write goal and next step → record one study session → read history → continue with the next step.

- **Topic:** name (required, trimmed, no newline, ≤ 200 chars), goal (≤ 4000), status 计划中 / 学习中 / 已完成 (manual only; recording a session never changes it), next step (≤ 1000; the user's own action text, no inferred deadline), optional resource link (http/https text only; shown selectable with a copy button; never fetched, never opened automatically), archive flag, revision. Goal, next step and notes are stored **exactly as typed** (whitespace, CRLF, Unicode, pure-whitespace values included); only name and link are trimmed. "Has a next step" is judged on non-whitespace content without rewriting stored text.
- **Entry:** study day, note body (must contain non-whitespace; ≤ 1 MiB UTF-8; rejected, never truncated), optional whole-minute duration 1–1440 (blank = not recorded). Same-day entries are allowed. No totals, averages or statistics.
- **Progress decision:** no percentage or progress bar. 3 states only. The PRD/UI sketches' "28%" / "Today 45 min" are illustrative and intentionally **not** adopted; the other Docs are not rewritten for this.
- **Combined save:** saving an entry can update the topic's next step in the same transaction (only when the next-step text was edited); either side stale → nothing is written.
- **Archive:** topics are archived/restored, never deleted; entries are kept. Archived topics are read-only (no edit, status change, or new/edited entries) until restored; enforced inside the storage transaction, not only by disabled buttons. Entries have no delete/archive in Phase 1 (edit only).
- **List/detail:** search (name, goal, next step, link, note bodies), status filter, 仅有下一步, 查看归档. Topics sort by most recent study day (ties: entry creation, then stable id), topics without entries last. Detail shows goal, next step, link, history newest first (long notes collapse to 6 lines, full text selectable).
- **Native windows:** topic and entry editors are independent native windows keyed by storage root + kind + UUID (re-opening brings forward). Close asks save / discard / cancel; failed save keeps the window and draft; "copy draft" and confirmed "reload saved version" are available; ⌘S saves.
- **Dashboard home:** the fabricated "Python 28%" learning card was replaced by a neutral text card without numbers (no real summary wired in).

### Dates

`LearningDay` stores a calendar-day label `yyyy-MM-dd` (strict: 10 ASCII chars, real proleptic-Gregorian date, years 1900–9999; `2026-02-30` etc. are rejected, never normalized). Saved days are never reinterpreted by time-zone changes. New or changed days later than the current local day are rejected; an unchanged historical date on an existing entry is accepted even if a time-zone change makes it "future" (checked against the latest on-disk entry under the lock).

### Storage and protection

Independent JSON at Application Support `Cosmos OS/Learning/learning.json` (+ `learning.backup.json`, `.learning.lock`), topics and entries in one document so combined saves are atomic. Opening creates nothing; first save creates. Safety primitives are **copied and adapted** from Prompt Vault storage (not shared, Prompt storage untouched, no general storage platform): lstat parent walk / symlink and file-type refusal, no-follow read, 16 MiB limit (reject, never truncate), flock, atomic sibling-temp rename, single previous backup with read-back. ISO-8601 (fractional seconds) dates, sorted keys, pretty-printed for hand recovery.

Under the lock the latest disk document is re-read and the mutation validated against it: target record revision; entry's topic still exists and is not archived; combined saves check both baselines; unrelated topics/entries from other writers are preserved; state is published only after verified read-back. Failure classes: any failure **before** the primary rename (including temp-file write errors) → retryable `writeFailed`, disk untouched, saving not locked; a failure after the rename or an unconfirmable read-back → `uncertainWrite`, saving locked until an explicit successful reload; corrupt / non-UTF-8 / future schema / duplicate id / orphan entry / invalid on-disk content / missing primary with backup → saving locked, nothing overwritten, no automatic backup restore or empty-library initialization. Conflicts keep drafts and never auto-merge or force-overwrite.

### Shared quit protection

`CosmosTerminationCoordinator` (in `LearningEditors.swift`) serializes one quit request over Prompt and Learning participants: cancel if a save/close is in flight or a quit is already pending; terminate immediately when neither module has unsaved drafts (original behavior); otherwise freeze **both** modules (editors disabled, new editor windows refused), ask each dirty module in turn, unfreeze both and reply to AppKit **exactly once**. A cancel or failed save by either module cancels the quit and restores both. `CosmosPromptTerminationDelegate` now calls the coordinator; `PromptTemplateWindowManager` gained a `CosmosTerminationParticipant` extension and its old `requestTermination` method (replaced by that extension; Prompt editing/close behavior otherwise unchanged) was removed. Prompt storage was not touched. No other application-lifecycle refactoring.

### Files

New: `LearningModels.swift`, `LearningFileStorage.swift`, `LearningStore.swift` (+ `LearningLocation`), `LearningViewModel.swift`, `LearningCenterView.swift`, `LearningEditors.swift`; tests `LearningPersistenceTests.swift`, `LearningStateTests.swift`. Modified: `DashboardView.swift` (route, DEBUG isolated learning root + initial-sidebar entry, neutral home card), `PromptTemplateEditor.swift` (termination wiring only). `project.pbxproj` unchanged (synchronized groups).

### Actual verification and limits

- Concentrated batch (Learning persistence + Learning state + existing PromptVaultState as Prompt exit/state regression, 58 tests): **57 passed, 1 failed** — the failure was a wrong test expectation (an editor stale after the topic was archived is refused as `conflict` first; the archived-with-matching-revision case is covered at the storage boundary). One concentrated repair: expectation corrected, that test re-run **passed**. After a later production fix (below) only the offscreen-render test was re-run (**passed**). The full 58 were not re-run after those two follow-ups. Results: `/private/tmp/CosmosLearningPhase1-Validation/Test1.xcresult`, `Test2.xcresult`, `Test3.xcresult`.
- Covered: strict dates and zone-independence, validation limits and exact text, round trip/reopen/backup, stale topic/entry refusal, unrelated-record preservation, concurrent writers, archive/restore with entries kept, archived topic refusal for every mutation, topic-missing, combined-save atomicity and non-writing on either stale baseline, future-date and zone-shift rules, pre-replace vs post-replace failures (hooks and a real read-only-directory write failure), uncertain write lock and reload, corrupt/unsupported/duplicate/orphan/impossible-date/unknown-status/blank-body files, missing primary with backup, symlinks and wrong types, oversize file and over-limit save, DEBUG location fail-closed, search/filters/ordering/history, exact clipboard copy, edit-session dirty/draft behavior, close choices, coordinator scenarios (no drafts, blocked, both modules, Learning approves then Prompt cancels in both orders, first-cancel, second request while pending, single reply, reuse) and real window managers (freeze refuses new editors, cancel keeps draft, save writes once, failed save blocks quit), offscreen rendering of the real center/detail/editor views.
- Builds: Universal Debug and Release **BUILD SUCCEEDED**, `x86_64 arm64`, signing disabled, on the final code. Release executable contains none of the five DEBUG launch strings (`--cosmos-learning-fixture-root`, `--cosmos-prompt-fixture-root`, `--cosmos-initial-sidebar`, `--cosmos-store-phase1-suite`, `--cosmos-asset-fixture-root`) nor `CosmosLearningPhase1-`. Test execution was arm64 only.
- Isolation: temporary Bundle `com.wangyucosmos.cosmostoolbox.persistenceui.learningphase1tests`, UUID roots under `/private/tmp/CosmosLearningPhase1-*`, injected locations/clocks/pasteboards, separate DerivedData; a sentinel `cosmos.zhuowang.*` defaults key stayed equal; Learning code references no Campaign/Workflow/Artifact/Workspace/Prompt store. No formal Learning directory or formal Zhuowang data was read or hashed.
- Real UI (one limited attempt with window-scoped capture): the first launch showed the old placeholder, which exposed a **real defect** — the Dashboard route for `.learningCenter` had not actually been applied (the unit tests do not cover Dashboard routing). Fixed, rebuilt with the temporary Bundle, relaunched against a temporary fixture: the Learning Center page loaded from the isolated root and showed both fixture topics with status, last study day and next step; the fixture file SHA-256 was unchanged after the run; the exact temporary process was terminated by PID. A top-alignment layout tweak followed. A first capture attempt grabbed the full screen instead of the app window and showed unrelated content from the user's own browser; that image was deleted immediately and not used. No click tool was available, so **editor windows, native close/quit alerts, filters, archive, copy button and restart in the real UI are not UI-accepted.**
- Existing warnings unchanged; test code only: Swift-6-mode capture / isolation warnings in the two new test files.

### Non-blocking todos

1. Real-UI acceptance of editors, close/quit alerts, archive/filters, copy, narrow layout, restart.
2. Safety primitives are duplicated between Prompt and Learning storage; extract only when a third module needs them.
3. Editor windows keep the Store of the module instance that opened them; after leaving and re-entering the module the list may be stale until refresh (same as Prompt todo 3); revision checks keep saves safe.
4. Entries cannot be deleted or archived; link is copy-only (no "open in browser").
5. Window title does not follow a renamed topic; search matches note bodies without highlighting; list recomputes on every render (cache if data grows).
6. Sidebar label still reads the pre-existing "AI 学习中心" naming; other Dashboard home cards remain placeholders (existing todo).
7. Test-code Swift 6 warnings; DatePicker has no range, so a future day is rejected on save with a message.

### Git and next action

At the implementation checkpoint all changes were unstaged and uncommitted on `main` (implementation baseline `693c4fc0d93544a69ff78bf03f02b02ccbbc52a6`; during the session the owner added the docs-only commit `765b33b` — AGENTS.md §23 coordination rules plus a one-line CLAUDE.md — so the actual HEAD is `765b33b`, `main` = `origin/main`, and no phase file overlaps it); nothing of this phase is committed, pushed or merged. Word WIP, Harness, Evidence/Quarantine, F1–F5, old P3, formal Workspace and personal knowledge repositories were not touched. Next: closed; the next module is chosen by product coordination (candidate: read-only survey of existing province management, see §13). Do not start it automatically.

---

## 19. 省份可维护配置 — 2026-10-09 (closed)

> **Closure (2026-10-09):** the product owner accepted the existing verification scope and closed Phase 1, authorizing one `feat: 支持省份配置维护与历史保留` commit and a normal push to origin/main. No further test, build, review, UI acceptance or todo fix was run for closure. The section below was written at the implementation checkpoint; "implemented, unstaged / uncommitted" there is history and is superseded by this closure and the actual repository refs.

> **Evidence boundaries:** the concentrated batch was 68/68 passed, 0 skipped (new suite 18 + existing Workspace persistence, store boundary, workbench and asset-center suites); Universal Debug / Release succeeded on the final code. The isolated real-UI run confirmed only the sidebar display (enabled order, collapsed stopped group, stopped province absent from the main list) and that the workspace payload **length** was unchanged; this is not recorded as business data being byte-for-byte unchanged. Manager operations (rename, move, stop, restore), the stopped-province page and the create-form refusal were not UI-accepted; the refusal is covered at the rule level only. The non-blocking todos below are retained and not handled.

### Behavior

Provinces are now maintainable inside the existing **管理工作区** sheet (no new window): add, rename, move up/down, stop and restore. Province identity is the UUID; the array order is the display order (no `sortOrder` field); provinces are never deleted. All changes use the existing protected workspace transaction.

- **Stop / restore:** stopping only forbids creating **new** Campaigns. Historical and in-progress Campaigns stay editable; Workflow, Artifacts, files and delivery are unchanged. Confirmation shows the province's Campaign count. Restoring returns the province to its old position.
- **Sidebar:** enabled provinces in order; stopped ones under a collapsible **已停用省份（历史）** group (opened automatically when one is selected). A stopped province page keeps its history but has no "新建活动" and explains why. With no provinces, the sidebar shows a "还没有省份，点击添加" entry to the manager.
- **Filters:** the progress-workbench and asset-center province pickers still list every province and label stopped ones "（已停用）", so history stays filterable and searchable.
- **New Campaign form:** opening the form is not the only gate. Saving re-reads the live configuration (`ZhuowangProvinceRules.creationRefusalMessage`); if the province was stopped after the form was opened, saving is refused and the input stays in the form. Saving an existing Campaign has no province check.
- **National / other:** Campaigns with `scopeType` national/other keep `provinceID == nil` and the "全国及其他" folder; "全国", "全国及其他" and the national module's name are reserved and can never become provinces.
- **Fresh install decision:** a fresh install **no longer seeds the six fixed provinces**. The default snapshot still seeds modules and categories; provinces start empty and are added by the user. Existing saved provinces, UUIDs, order, Campaigns and files are untouched, and an existing library is never re-seeded (no write on load). Existing tests that assumed six default provinces were updated for this.

### Compatibility and folders

`ZhuowangProvince` gained `isEnabled` (missing → `true`) and `directoryName` (optional) with custom `decodeIfPresent` decoding, so old saved data keeps decoding and loading it triggers **no migration write**. `pathName = directoryName ?? name` is the only name used for path construction; `name` is display only.

- New provinces fix `directoryName` at creation. For a province saved before this field existed, the **first rename that changes the name pins the old name as `directoryName` in the same transaction**; later renames never change it. An English-name-only edit does not pin.
- Path construction sites switched to `pathName`: Campaign detail (delivery-package workspace URL, local-artifact discovery/recovery, workspace creation, legacy migration calls), the Workflow view's AI-execution calls and the progress workbench's deliverable count. Display-only uses (delivery manifest `province`, asset scope names, task-package text, sidebar) intentionally keep `name`. Workflow Store functions only forward the path name they are given. Artifact absolute `location` values are preserved; no directory is moved or renamed.
- Existing risk, unchanged and **not** handled: the Campaign **name** is also part of the folder path, so renaming a Campaign still changes its derived folder (todo).

### Validation (business layer, `ZhuowangProvinceRules`)

Display names must be unique among all provinces, stopped ones included (compared trimmed, Unicode-canonical, case- and width-insensitive). A new province's folder name must not collide with any existing province's *effective* folder (pinned or legacy), compared after the file manager's actual path sanitization plus the same folding — a conservative check, not a claim of file-system identity. Rename checks only display names and excludes the province itself; it never needs or changes a folder. Existing duplicate data is kept and shown as a warning in the manager (never merged, deleted or locked). Violations return the generic invalid-input result at the store; the manager pre-validates and shows the precise reason, so the persistence error vocabulary was not extended.

### Files

New: `ZhuowangProvinceRules.swift`, `ZhuowangProvinceManagementView.swift`; test `ZhuowangProvinceConfigurationTests.swift`. Modified: `ZhuowangModels.swift`, `ZhuowangWorkspaceStore.swift`, `ZhuowangWorkspaceFileManager.swift` (sanitizer made internal), `ZhuowangWorkspaceView.swift`, `ZhuowangCampaignView.swift`, `ZhuowangCampaignDetailView.swift`, `ZhuowangWorkflowView.swift`, `ZhuowangCampaignProgress.swift`, `ZhuowangCampaignWorkbenchView.swift`, `ZhuowangAssetCenterView.swift`; tests `ZhuowangWorkspaceStorePersistenceTests.swift` and `ZhuowangStorePersistenceBoundaryTests.swift` (default-province expectations). `project.pbxproj` unchanged.

### Actual verification and limits

- One concentrated batch (new province suite 18 + existing Workspace persistence, store boundary, Campaign workbench and asset-center suites): **68/68 passed, 0 skipped**, no repair round needed (`/private/tmp/CosmosProvinceConfig-Validation/Test1.xcresult`). Covered: fresh install without provinces and no reseed; old data unchanged with zero writes and decode compatibility; add / duplicate / case / width / Unicode / stopped-province duplicates; folder conflict against pinned folders; reserved names; first and repeated renames keep the folder URL stable; English-only rename; rename excluding itself; existing duplicates kept and reported; stop/restore keep order and write nothing on no-ops; reorder and restart; unrelated workspace fields and other stores' bytes untouched; stale and locked states; creation gate and save-time refusal rule; historical Campaigns of a stopped province still in the progress workbench, still editable and still in the asset catalog; renamed province keeps ownership by UUID. Tests use in-memory data sources and URL assertions under an injected root; no UserDefaults suite for the unit tests, no file system writes, no formal Workspace data read.
- Builds: Universal Debug and Release **BUILD SUCCEEDED** (`x86_64 arm64`, signing disabled) on the final code; Release has none of the DEBUG launch strings. Test execution was arm64.
- Real UI (one limited attempt, temporary Bundle `com.wangyucosmos.cosmostoolbox.persistenceui.provinceconfigtests`, isolated suite, window-only capture, no Campaign detail opened): an old-format workspace payload with a pinned-folder renamed province and a stopped province loaded healthily; the sidebar showed the enabled provinces in the saved order (with the renamed display name) and a collapsed **已停用省份（历史）** group; the stopped province was not in the main list; the saved workspace payload length was unchanged after the run; the exact temporary process was stopped by PID. The suite plist left by the isolated run remains (as in earlier phases).
- **Not UI-accepted** (no click tool): the manager sheet itself, inline rename, up/down, stop confirmation, restore, expanding the stopped group, a stopped province page, the create sheet's save-time refusal, picker labels. The create-form refusal is covered at the rule level, not by driving the form.

### Non-blocking todos

1. Real-UI acceptance of the manager and stopped-province pages (above).
2. Campaign rename still changes the derived Campaign folder (existing; untouched).
3. Existing: when the workspace primary key is missing but a backup exists, load re-initializes defaults instead of consulting the backup. Not introduced or worsened by this change (a fresh default now simply has no provinces, so nothing fake is re-created); history stays on disk and in other stores.
4. `ZhuowangProvinceRules.isReserved` passes `displayKey`/`pathKey` as method references and produces two Swift-6-mode actor-isolation warnings (behaviour correct); trivially fixable with closures.
5. The workbench Campaign list rows do not mark a stopped province (only the pickers do).
6. Province display names in the manager use a plain list; large lists are not paginated.

### Git and next action

At the implementation checkpoint all changes were unstaged and uncommitted on `main` (baseline `82cc7bab3d3772b296cb421fa85b8b5e43f42bf9`). Word WIP, Harness, Evidence/Quarantine, F1–F5, old P3, the formal Workspace and personal knowledge repositories were not touched. Next: closed; the next candidate is the national monthly member-activation integration investigation (see §13), not started automatically.

---

## 20. 全国月度会员促活 Phase 1 — 2026-10-09 (closed)

> **Closure (2026-10-09):** the product owner accepted the existing verification scope and closed Phase 1, authorizing one `feat: 接入全国月度会员促活清单` commit and a normal push to origin/main. No further fix, review, test, build or real-UI acceptance was run for closure. The section below was written at the implementation checkpoint; "implemented, unstaged / uncommitted" there is history and is superseded by this closure and the actual repository refs.

> **Delivered:** the national monthly project type, the month label, the 7 outputs and 7 inputs with stable keys, registration history with explicit finalization confirmation, and the live previous-period reference. **A registration is not Artifact adoption and does not enter the existing ZIP delivery; no real material has been imported.**

> **Evidence boundaries:** the concentrated batch was 78/78 passed, 0 skipped; Universal Debug / Release succeeded on the final code. The isolated real run confirmed only that the synthetic data loaded and the progress workbench displayed it; its comparison was of payload **length** only and is not recorded as business data being byte-for-byte unchanged. The create form's monthly section and the checklist actions were not UI-accepted. The non-blocking todos below are retained and not handled.

### Business basis

The checklist definition follows the monthly process document in the separate `zhuowang-workspace` repository (`流程/月度会员促活.md`, plus the referenced "掌厅引导页" / fixed-skeleton sections and `流程/Word交付.md` 3.4 / 3.6 / 3.7), read once and read-only for this phase. That repository was not modified or synchronized; nothing from it is imported. The process document marks its schedule as an initial convention, so the suggested days below are references only.

### Scope and behavior

- **Project type:** in the national module's "新建活动" form a Campaign can be created as **月度会员促活** (plain Campaign remains the default; province Campaigns cannot be monthly). Stored as an optional `monthly` plan on the Campaign: old saved data decodes with `nil`, loading writes nothing, and ordinary Campaigns never gain the field. No Step 07, no copied Workflow, step 03 is **not** disabled by default (existing step enable rules apply).
- **Month and dates:** `YYYY-MM` label (strictly validated, 1900–9999) kept separate from the real start / end times. The form prefills "previous month-end 17:00 → this month-end 17:00" in Asia/Shanghai, both editable; changing the month never overwrites dates the user edited by hand. A duplicate month only produces a warning.
- **Previous-period reference (optional):** only the reference Campaign's identity is stored, never its content. Default candidate: the latest monthly Campaign of an *earlier* month (never itself, never the same or a later month); a manual choice is limited to the same rule. The reference is live: the checklist shows the previous period's current registration per output ("上期当前定稿（实时参考）" when confirmed there, otherwise "上期当前登记（未确认定稿）"); it follows later edits of the previous period and is never counted toward this period. A missing or non-monthly reference is reported explicitly and never replaced automatically.
- **Monthly checklist** (new "月度清单" tab in the Campaign detail window, shown only for monthly Campaigns):
  - **7 outputs** (stable keys, never associated by Chinese title): 思路与文案方案, 主活动页原型, 掌厅引导页文案, 动效稿, 客服文档, 掌厅活动规则, 主活动页活动规则. Each shows a *source hint* (the mapped existing step and its adopted-artifact count), the process document's reference day relative to T (= the activity start), and the registered final.
  - **7 business inputs**: 奖品表, 0 元流量包方案编号与排除口径, 活动时间书面确认与活动链接, 掌厅奖池是否共用, 抽奖数值, 券类奖品权益条款原文, 业务联系人. Ordinary inputs are 待要 / 已到 / 不适用 with an exact-text note; the prize-pool relation is 待确认 / 共用 / 独立 and is **reset to 待确认 for every new Campaign**. The contact input only records whether it was obtained; no contact-detail field exists.
  - **Suggested days** are labelled "流程参考日 … 初版约定，非截止日期": no reminder, no overdue state, never treated as a real deadline.
- **Creating a new month copies nothing:** no files, no text, no registered locations, no confirmations, no input states, and no prize-pool relation; only the optional reference identity.

### Registration is not Artifact adoption and not ZIP delivery

A **registration** is metadata on the monthly plan: a location string (an explicit absolute local path starting with `/`, or an http/https link), an optional free-text version label, an exact-text note and a stable UUID. Registering **does not open the link, read, copy, scan or verify the file**, does not create an Artifact, does not adopt anything, does not write into any Campaign workspace folder, and does not make a file eligible for the existing delivery package. The UI states "已登记，未核验文件／链接可用性" and never shows a landed-file or deliverable state. By contrast an **Artifact adoption** is the Workflow's protected transaction that makes one version of a real managed file the adopted version of a step, and **ZIP delivery** packages adopted local files inside the Campaign workspace; both stay exactly as before and neither is touched. The existing adopted artifacts of the mapped step are shown only as a source hint; "step has an adopted artifact" never means the checklist item is done (a Markdown customer-service document is not the external Word final).

Registration rules: an output may have no registration; new registrations are appended and history is kept (no edit, no delete; a mistake is corrected by registering a new one); the newest registration becomes the single current one; a new registration is never auto-confirmed; changing the current registration clears that output's confirmation; the confirmation stores the specific registration ID and only counts while it equals the current one; confirming needs a current registration; blank locations cannot be saved; relative paths, `~`, `file:`, other schemes, `..` components and control characters are refused; notes are kept exactly as typed; version labels are labels, not identities.

### Four separate statements (never substituting for one another)

"月度成品已确认 x/7" (only your explicit confirmations of registered finals), "业务输入已齐备 y/7", the existing Workflow step progress, and the existing delivery-package eligibility. None modifies the others, none changes adoption or step status, and the general workbench's "可以交付" judgement is unchanged. Opening the checklist never creates a Workflow, never triggers recovery and never adopts anything.

### Data protection

Plan changes use the existing protected Campaign transaction (`updateMonthlyPlan`), applied to the **latest persisted** plan with a per-plan revision check: a stale revision is refused (`stale`), the user's input stays in the UI, other Campaigns are untouched, plan edits do not change `updatedAt` or reorder the list, and a stale cross-instance baseline is refused by the existing persistence layer. `updateCampaign` now preserves the persisted `monthly` plan, so an ordinary edit with a stale Campaign copy can never overwrite it. Creation reuses the existing `addCampaign` path (single transaction) with a blank plan; no multi-store "atomic" creation is simulated and no Workflow is created at creation. Unknown future item keys inside a stored plan are preserved on decode.

### Files

New: `ZhuowangMonthlyPromotion.swift` (month type, fixed definition, plan models, rules and pure helpers), `ZhuowangMonthlyChecklistView.swift`; test `ZhuowangMonthlyPromotionTests.swift`. Modified: `ZhuowangCampaignModels.swift`, `ZhuowangCampaignStore.swift`, `ZhuowangCampaignView.swift` (create form), `ZhuowangCampaignDetailView.swift` (new tab). `project.pbxproj` unchanged.

### Actual verification and limits

- One concentrated batch (new monthly suite plus existing Campaign store persistence, Campaign workbench, asset-center and the province-configuration suites as affected regression): **78/78 passed, 0 skipped**, no repair round (`/private/tmp/CosmosMonthlyPhase1-Validation/Test1.xcresult`). Covered: fixed definition identities and mapping; strict month and Shanghai default periods (leap year, January, year boundary); hand-edited dates preserved; reference-day arithmetic; old data decodes with zero writes; ordinary Campaigns unchanged; creation refusals (bad month, non-national scope, reversed dates, missing / non-monthly / same-month / future reference); new month copies nothing and resets the prize-pool relation; default-reference candidate rules and duplicate-month reporting; reference validation and live states (including a deleted reference); location validation; append-only history, current / confirmation semantics; input states, exact notes and the separate prize-pool relation; the separate progress concepts; read-only Workflow hints and zero Workflow writes; stale revision and stale baseline refusal with other Campaigns kept; a stale Campaign copy cannot overwrite the plan; list order unchanged; offscreen rendering of the checklist (with history, reference and prize-pool states), a non-monthly fallback and the create form (national module). Only synthetic metadata and virtual locations, in-memory data sources; no formal Workspace, no file system and no real material was used.
- Builds: Universal Debug and Release **BUILD SUCCEEDED** (`x86_64 arm64`, signing disabled) on the final code; Release has none of the DEBUG launch strings. Tests ran on arm64.
- Real UI (one limited attempt, temporary Bundle `…persistenceui.monthlyphase1tests`, isolated suite, window-only capture, **no Campaign detail opened**): a synthetic workspace plus campaigns payload (two monthly Campaigns in the new format and one old-format Campaign) loaded without locking; the progress workbench counted all three; the empty-province state from the previous phase was visible; the payload length was unchanged after the run (not claimed as byte-for-byte business-data identity); the exact temporary process was stopped by PID. The suite plist left by the run remains.
- **Not UI-accepted** (no click tool; opening a Campaign window can write into the formal Workspace path in isolated mode, todo 4): the create form's monthly section, the "月度清单" tab, registration / confirmation / input actions and the stale-save message in the real window. These are covered by data-level tests and offscreen rendering only. Note that opening *any* Campaign detail window already runs the existing recovery / legacy-migration calls in its `onAppear` (existing behavior, tab-independent); the monthly tab adds none.

### Non-blocking todos

1. Real-UI acceptance of the create form's monthly section and the checklist tab (blocked by todo 4's missing workspace-file isolation).
2. No monthly marker on Campaign list rows / workbench rows and no "月度成品已确认 x/7" summary there (the general workbench is unchanged by design).
3. An existing ordinary Campaign cannot be converted to monthly, and a monthly Campaign cannot be converted back.
4. Registrations are append-only: no hide or delete; location text cannot be edited after the fact.
5. Registering real Word / Figma / link finals as managed Artifacts (adoption, version history in the Workflow, ZIP delivery) is a separate future phase; the 10-slot 掌厅 copy table has no structured editor yet.
6. The default month text is the next calendar month; the month in an existing plan can be edited but never moves the dates.
7. Carried over: Campaign rename still changes the derived folder; "primary missing but backup exists" re-initialization; the two isolation warnings in `ZhuowangProvinceRules.swift`; real-UI acceptance of earlier modules.

### Git and next action

At the implementation checkpoint all changes were unstaged and uncommitted on `main` (baseline `863fc83690bd02543c0ca1570a88883a4b43831c`). Word WIP, Harness, Evidence/Quarantine, F1–F5, old P3, the formal Workspace and personal knowledge repositories were not touched. Next: closed; the next stage is determined by product coordination and is not started automatically.

---

## 21. Dashboard 真实数据整合 Phase 1 — 2026-10-09 (closed)

> **Closure (2026-10-09):** the product owner accepted the existing verification scope and closed Phase 1, authorizing one `feat: 首页接入真实工作与学习数据` commit and a normal push to origin/main. No further fix, review, test, build or UI acceptance was run for closure. The section below was written at the implementation checkpoint; "implemented, unstaged / uncommitted" there is history and is superseded by this closure and the actual repository refs.

> **Delivered:** the Home now shows real campaign / Workflow state, the monthly checklist, favorite prompts and the learning summary. Reading is strictly read-only: no restore, no migration, no delivery-file check. **Evidence boundaries:** 56/56 tests passed, 0 skipped; Universal Debug / Release succeeded on the final code. The real isolated run covered the activities and monthly cards only; the refresh and navigation buttons, the lower (Prompt / Learning) cards and the calendar-day event were not verified in the real App.

> **Known display limitation (not changed):** a campaign whose status is 已结束 never appears in the Home list even if its Workflow steps are unfinished (it is only counted in the summary); it remains visible in the progress workbench.

### Behavior

The Home (仪表盘) is rebuilt as a read-only summary of what the finished modules actually hold. The fabricated "今日工作 3 项待处理任务", the fake "最近项目" list (with its inert "查看全部") and the fake "AI 工作台 8/9 / 系统状态 正常" health numbers were removed, as was the hard-coded "下午好". Now:

- **Header:** greeting from the real local clock, the real date, a refresh button and "读取于 HH:mm". "读取于" is the time of *this read* (the snapshot time), not a data update time.
- **活动 · Workflow 状态:** real campaigns with Workflow step state. Progress is computed over the **actually enabled** steps (never a fixed six). A campaign whose enabled steps are all confirmed / completed / skipped is only counted ("启用步骤均已确认", explicitly *not* meaning files usable, exported or deliverable); a campaign with zero enabled steps (or an empty workflow) is shown as "没有启用的 Workflow 步骤" and never as done. Campaign status 已结束 is counted only. List: at most 5, grouped by Workflow state (failed / needs revision → generating or waiting → next step ready → not created → no enabled steps), same group ordered by campaign update time, with stable id tie-breaks; the rest is summarized ("还有 N 个"). "活动期" is only the campaign's own start / end dates, not a task deadline. No today-todo, priority, overdue or "recently visited" wording anywhere.
- **月度会员促活:** the two most recent periods by month (same month: newer creation first, then a stable id order; invalid month labels last). Per period three independent statements: "月度成品已确认 x/7", business inputs counted as 已到 / 不适用 / 待要 (the six ordinary inputs; **不适用 is never folded into "complete"**) and the prize-pool relation shown separately (待确认 stays visible, in orange), plus the Workflow step progress line. None of them is presented as, or replaces, ZIP-deliverable status.
- **提示词 · 收藏:** favorite, non-archived templates, at most 5, ordered by template update time ("按模板更新时间", not "最近使用"); it only opens the Prompt Vault, never copies.
- **学习:** non-archived, non-completed topics, at most 3, in the learning module's most-recent-study order, with the user's own next step exactly as saved (whitespace-only counts as none).
- **未接入:** a single line stating AI 工作台 / Mac 优化 are not yet connected to the Home.
- **Navigation:** every card only opens an existing module through the sidebar selection (`DashboardCard.target`): campaigns and monthly → 卓望工作 (its progress workbench), prompts → 提示词库, learning → 学习中心. No shortcut into a Campaign detail window (opening one runs recovery / migration code). Selections inside modules are not preserved.

### Read-only reading

`DashboardReader` reads the persisted campaign, workspace and workflow data directly from the configuration's data source and decodes it; it **never creates a business Store**, so nothing is initialized, defaulted, restored or migrated. Prompt Vault and the learning center are read with their own read-only `load()` and existing isolated-location resolution (a blocked location is shown as blocked and never falls back to production). No directory is created or scanned, no asset body is read, and no delivery-file check runs: the existing progress projection is reused with an explicitly injected zero-returning delivery counter, and its delivery-dependent `category` / `nextActionText` are never used. Two back-to-back reads of the data keys must agree, otherwise the section reports "data changed during the read". Heavy decoding (campaigns, workflows) runs in the background; unchanged bytes reuse the previous decode (cache shared across Home visits), but every date-dependent projection is recomputed from `now` on each read and on a calendar-day change (`NSCalendarDayChanged`, no polling), without re-reading.

### Section states

Each section carries its own state: **尚未建立** (key / file does not exist, nothing is created), **真实为空** (built, no qualifying items), **无法读取** (decode / storage failure, with reason, "首页没有修改任何数据" and an entry to the module) and **被阻止** (isolation). A missing Workflow dataset means "尚未创建"; an *unreadable* Workflow dataset is shown as unreadable and is never counted as not created (campaigns are still listed without progress; the monthly section does not depend on it). When a refresh fails, the previous value is kept only with its own successful read time and the current error ("以下是 … 上次成功读取的内容，不是本次读取的结果"); a failed read is never presented as freshly loaded; a vanished or blocked source drops the old value. A newer refresh or leaving the Home discards older results (generation guard).

### Files

New: `DashboardSnapshot.swift` (source and display states, projection, reader, greeting), `DashboardHomeViewModel.swift`, `DashboardHomeView.swift`; test `DashboardSnapshotTests.swift`. Modified: `DashboardView.swift` (old fake Home and the unused `ProjectRow` removed; new Home wired with the persistence configuration, the isolated Prompt / Learning locations, a shared read cache and the module-opening callback). No existing module logic was modified.

### Actual verification and limits

- One concentrated batch (new Dashboard suite plus the Campaign workbench and monthly suites it depends on): **56/56 passed, 0 skipped**, no repair round (`/private/tmp/CosmosDashboardPhase1-Validation/Test1.xcresult`). Covered: all four data states and zero writes (in-memory source write count 0, missing roots not created, no lock / backup / temporary files, existing files byte-identical); per-section failures; blocked locations; inconsistent reads; byte-reuse vs re-decode; Workflow read failure vs missing; enabled-step progress, zero / all-disabled steps, completed and ended campaigns counted but not listed; stable shuffle-independent ordering and the 5 / 2 / 5 / 3 limits; independent monthly states and the 不适用 / pending prize-pool semantics; same-month stable ordering; favorites-only prompts; learning exclusions and exact next-step text; cross-day re-projection without a re-read; failed-refresh stale handling (time, repeated failures, recovery, independent sections); stale-generation and cancel discarding; greeting / date; navigation target mapping; offscreen rendering of the loaded, not-built, blocked and stale states. Synthetic data only.
- Builds: Universal Debug and Release **BUILD SUCCEEDED** (`x86_64 arm64`, signing disabled) on the final code; Release has none of the DEBUG launch strings. Tests ran on arm64.
- Real UI (one limited attempt, temporary Bundle `…persistenceui.dashboardphase1tests`, isolated suite and temporary Prompt / Learning roots with synthetic data, window-only capture): the Home loaded from the isolated sources; the activities card showed the two campaigns with "Workflow 尚未创建" (the Workflow key was absent) and the activity phase; the monthly card showed 0/7 confirmed, 已到 1 / 不适用 1 / 待要 4 and the prize pool 待确认 in orange; the greeting, date and "读取于" were real. After the run no lock, backup or other file existed in the Prompt / Learning roots and the suite held only the two seeded keys (the Home created nothing); the temporary process was stopped by PID.
- **Not verified in the real window:** the refresh button and every navigation button were not clicked (no click tool); the Prompt and Learning cards were below the visible area in the captured window (covered by offscreen rendering and data tests only); the day-change event and the stale / failure states were not triggered in the real App.

### Non-blocking todos

1. Real-UI acceptance of refresh, navigation and the lower cards.
2. Navigation opens modules only; no preserved selection or deeper links (would need module changes).
3. The step-confirmed wording follows the existing progress rule (approved / completed / skipped count as done), hence "含跳过".
4. Decoding cost for very large Workflow datasets is unmeasured (background decode and byte reuse are in place).
5. In isolated runs all keys come from the injected suite while the Workflow Store itself still uses the standard domain (existing); the Home follows the asset center's convention.
6. AI 工作台 and Mac 优化 remain unconnected; the activity card keeps the shared card's minimum height (some empty space).
7. Carried over: earlier modules' real-UI acceptance, Campaign rename folder risk, "primary missing but backup exists" re-initialization.

### Git and next action

At the implementation checkpoint all changes were unstaged and uncommitted on `main` (baseline `68f080fe72f69ba037b897a2a3962d9db9d87b1c`). Word WIP, Harness, Evidence/Quarantine, F1–F5, old P3, the formal Workspace, formal module data and personal knowledge repositories were not touched. Next: closed; the next module is determined by product coordination and is not started automatically.

---

## 22. AI 工作台 Phase 1 — 本机工具与运行环境检测 — 2026-10-09 (closed)

Implementation baseline `4c45dbbdd33ba3226a0a3b880a081eb9bbb9752e` (clean, main = origin/main at start). Phase 1 is closed; the accepted formal commit is `6639e431fa9f1d6f8ba7664069ad18fed1b1f41b` (owner-provided push/clean baseline reused in Phase 2).

### Behavior

- The sidebar item **AI 工作台** opens a page listing five tools: Claude Code, Codex CLI, Git, Node.js, Python. Each row shows status (可运行 / 无法运行 / 未找到 / 未检测), the version number and the first line of the real output, the executed path (plus the symlink-resolved location when different), the **actual discovery source**, and a short failure explanation with a hint.
- Detection is **manual**: first entry shows "尚未检测"; the button reads 开始检测 / 重新检测 and is disabled while running. The last completed result and its time are kept **in memory only** (a cache owned by `DashboardView`), so switching sidebar items and coming back still shows it. Nothing is persisted; the result is not written anywhere and is not shown on the Home.
- A fixed notice states the boundary: detection only proves the tool exists and `--version` runs; it says nothing about login, quota, network or model availability. Nothing is installed, updated, logged into, read for keys, or run beyond `--version`; no AI service is called.
- Existing `ZhuowangAIConnectionStore` records (Codex `.available`, Claude Code `.needsLogin`, …) are **not read or modified**.

### Discovery and execution rules

- Candidates per tool, in order, de-duplicated by path (first discovery wins the label): current process `PATH` entries (**当前进程 PATH**) → `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `/usr/bin` (**常见安装位置**; Claude also `~/.claude/local`, Node also `~/.volta/bin`, `~/.asdf/shims` and the numerically newest `~/.nvm/versions/node/*`) → Claude Desktop's bundled CLI under `~/Library/Application Support/Claude/claude-code/<version>/<id>/claude.app/Contents/MacOS/claude`, highest numeric version first, at most three versions (**Claude 桌面版内置**) → Codex in `/Applications` and `~/Applications` `ChatGPT.app/Contents/Resources/codex-cli/bin/codex` (**ChatGPT 桌面版内置**). No login or interactive shell is used and no unrelated directory is scanned. The first candidate that runs successfully wins; an earlier failure never blocks a later good candidate.
- Execution goes through `AIWorkspaceProcessRunner`: absolute path, fixed `--version`, stdin `/dev/null`, **allow-listed environment** (`PATH` = executable's own directory + system dirs, `HOME`, `LANG`, `NO_COLOR`; nothing inherited, so no `CLAUDE_*` / `ANTHROPIC_*` values), stdout+stderr read concurrently through `poll` with a 64 KiB cap (excess is drained and dropped so the child never blocks), 5 s timeout per command and 8 s budget per tool. Timeout and task cancellation send SIGTERM, SIGKILL after 1 s, and a last-resort deadline always resumes the caller. Five tools are probed concurrently.
- **System shims:** `/usr/bin/git` and `/usr/bin/python3` are only run after `/usr/bin/xcode-select -p` reports an existing developer directory. Otherwise they are skipped and the row reads 未找到 with the explanation that developer tools are missing and nothing is installed (the user may run `xcode-select --install` themselves).
- **Repeated refresh / leaving the page:** a refresh while one is running is ignored; leaving the page cancels the task (children are terminated); a generation token guarantees a superseded or cancelled run can never overwrite a newer result or the cache. A finished result survives leaving the page.

### Files

New: `AIWorkspaceModels.swift`, `AIWorkspaceProcessRunner.swift`, `AIWorkspaceToolProbe.swift`, `AIWorkspaceViewModel.swift`, `AIWorkspaceView.swift`; test `AIWorkspaceToolProbeTests.swift`. Modified: `DashboardView.swift` (route `.aiWorkspace`, the in-memory cache, and DEBUG-only, isolated-only launch arguments `--cosmos-initial-sidebar aiWorkspace` and `--cosmos-ai-workspace-autodetect`). `project.pbxproj` needs no change (synchronized folders); a running Xcode re-serialized it during the session and it was restored to HEAD. No model, Store, UserDefaults schema or data file was changed.

### Actual verification and limits

- **Focused tests: 24/24 passed, 0 failed** on the final code (`AIWorkspaceToolProbeTests`; temporary fake executables only). Covered: version/exit-code capture; timeout kills the child (including a shell with a sleeping grandchild) and returns promptly; a child ignoring SIGTERM is SIGKILLed; cancellation terminates the child; an already-cancelled task never launches; output cap without blocking; controlled environment (no leaked secrets, stdin closed); launch failure; discovery source for every tool incl. highest bundled Claude version and newest nvm version; first-discovery label on duplicate paths; symlink resolution; not-executable / non-zero / timeout explanations; a later good candidate beating an earlier failure; version-less output still runnable; shim not launched without developer tools and run with them; version parsing and numeric sorting; view-model single-run, cancel-then-refresh with a late stale finisher, result surviving leave/return, cancelled run keeping the old result; probe cancellation stops children; a live probe smoke (five tools in order); offscreen rendering of the real view (idle and mixed states).
- **One repair round** (test-only): the first full run exposed test problems — real `/usr/bin` leaking into discovery tests (common directories made injectable) and cold first-exec latency of freshly written scripts exceeding 1 s (test timeouts raised, pid-based tests wait for the child to start). No product code failure.
- **Universal Debug build SUCCEEDED** (`x86_64 arm64`, signing disabled, temporary isolated Bundle ID); no warnings from the new files. `git diff --check` passed. Release was not rebuilt.
- **Real App (one launch, via LaunchServices `open`, isolated Bundle + suite, DEBUG auto-detect argument, window-only capture):** the App opened directly on AI 工作台 and detected on its own. Visible in the capture: Claude Code 2.1.293 from Claude 桌面版内置; Codex CLI 0.162.0-alpha.17.2 from ChatGPT 桌面版内置; Git 2.54.0 at `/usr/bin/git` via 当前进程 PATH, marked 系统自带入口; "最近检测" time shown. These match the independent `--version` probes made during the investigation. The App process's own PATH (read with `ps eww`, PATH only) contained `~/.local/bin` on this Mac, so Node resolves as 当前进程 PATH here. Temporary preference domain deleted afterwards; the formal App and data were not touched.
- **Not verified:** the Node.js and Python rows were below the visible area in the real window (covered by the live probe test and offscreen rendering only); the detect button was not clicked and the cancel-on-leave path was not exercised in the real App (no click tool; DEBUG auto-detect used instead; covered by tests); behavior on a machine without developer tools was tested only with fake `xcode-select` scripts (no real shim dialog scenario); a Finder launch with a bare launchd PATH was not reproduced (this Mac's launchd PATH already includes `~/.local/bin`); TCC / Gatekeeper behavior for running binaries inside other apps' bundles was not observed beyond this one successful launch; Release build, full suite and historical tests were not run.

### Non-blocking todos

1. The Codex and Claude bundle paths are app-internal layouts and may change with app updates; a miss shows 未找到 rather than an error.
2. Multiple installs are not compared: the first working candidate is shown, not necessarily the one the user's Terminal uses.
3. `Process.terminate()` signals only the direct child (no process group); `--version` children rarely spawn grandchildren, and the test with a sleeping grandchild confirms the call still returns.
4. Deferred: login / quota / network checks, update hints, Homebrew / npm / uv / VS Code / DeepSeek Harness, Home summary, mapping detection onto `ZhuowangAIConnection` status, persistence.
5. The existing `DeepSeekHarnessAdapter` still hard-codes a user-specific `npx` path (not touched).
6. Carried over: earlier modules' real-UI acceptance and the other non-blocking items above.

### Git and next action

Phase 1 closed at formal commit `6639e431fa9f1d6f8ba7664069ad18fed1b1f41b`. Historical verification above remains bounded to its stated scope. Phase 2 was explicitly authorized and is recorded below. Word WIP, Step 06 Harness, Evidence/Quarantine, F1–F5, old P3, other repositories, the knowledge base and formal App data remain outside this work.


## 23. AI 工作台 Phase 2 — 任务准备与提示词交接 — 2026-10-10

### 当前行为与边界

- 从现有主元数据只读读取全部 Campaign、已有 Workflow 与 Workspace 名称配置，不初始化业务 Store、不创建默认活动/流程、不恢复备份。支持省份、全国、其他范围，不硬编码负责省份。
- 用户选择活动与步骤、Claude / Codex，填写本次目标与补充要求；完整提示词实时预览，一键复制。CLI 未检测或不可运行不阻止交接。切换活动/步骤清空输入，无确认弹窗；草稿仅当前页面内存，离开页面可能丢弃，不建立历史或持久化。
- 提示词标明来源，包含活动名称/范围/时间/状态/notes、流程与步骤 ID/状态/启用/说明/能力及工具要求、用户输入和关联产物元数据。按既有 versionGroupKey 与 isApprovedVersion 判定当前采用；其他版本为参考，零采用明确未确定，多采用明确冲突；排除所属活动不匹配的产物。不读取文件正文、不验证登记路径可读性、不以最新版本兜底。
- 月度活动补充既有参考活动关联、业务输入状态/说明、奖池关系、登记版本/位置/定稿状态，以及现有清单定义中与步骤关联的交付形式。
- 步骤模型没有独立目标/详细完成标准字段，因此目标由用户填写，步骤 notes 保留为说明；不把说明冒充完成标准。提示词明确已有 requiresApproval 语义和详细标准缺失。新产物输出目录未确定，登记路径只作为来源，不推导或编造输出目录，不把源码仓库作为活动输出目录。
- 缺少活动、Workflow、步骤、目标及读取异常均阻止生成/复制。刷新发现关联失效会清空对应选择与输入。复制前重新读取主元数据；若文本变化，更新预览并要求核对后再次复制；若失效或读取失败则拒绝复制。成功/失败均有反馈，输入变化清除旧反馈。
- 不自动执行 CLI/AI、发送或导出，不创建 Run/Approval、不改 Workflow、不采用/覆盖/移动/删除产物、不改业务 Store。不授权提交、推送或其他知识库回写。Phase 1 检测入口及执行逻辑保留。

### 本轮验证

- 新增 `AIWorkspaceTaskPreparationTests` **10/10 通过**：真实关联及动态省份名称；旧 V1 当前采用而 V3 为参考；采用冲突/未采用/跨活动产物；活动/步骤切换与清空；缺活动/流程/步骤/目标；失效关联与复制前更新；输入/工具变化后预览和复制一致；失败反馈；只读主数据且不读备份/不写 Store；重复身份拒绝；实际 SwiftUI 视图离屏布局与私有剪贴板全文一致。
- **Universal Debug BUILD SUCCEEDED**，`lipo` 确认 `x86_64 arm64`；临时 DerivedData / 隔离 Bundle，签名关闭。新增文件无编译警告；旧省份规则两条 actor 警告及 AppIntents 提示不修复。`git diff --check` 通过。未跑历史/全量测试、Release 或独立复审。
- 首次沙箱内 xcodebuild 被 Swift 宏插件 sandbox_apply 拒绝，测试未执行；改用同一隔离配置在沙箱外验证成功，无产品阻塞或修复轮次。
- **真实 App 一次隔离启动**：LaunchServices 后台 `open -g -n`，随机 suite + 临时 Bundle、合成活动/步骤/产物，仅窗口截图，未移动用户窗口。任务准备页面呈现，Phase 1 DEBUG 自动检测完成，显示重新检测及时间。Campaign / Workflow / Workspace 三份 payload 前后逐字节一致，无新增 cosmos 业务键；临时进程已结束、随机 suite 已删除。证据：`/private/tmp/CosmosAIPhase2-UI/`；测试 `/private/tmp/CosmosAIPhase2-Focused.xcresult`；构建日志 `/private/tmp/CosmosAIPhase2-build.log`。

### 未覆盖与下一步

- 原生 UI 操作工具初始化超时，未重复尝试；真实 App 未点击活动/步骤选择、输入、复制/失败反馈、刷新及检测按钮，未滚动检查所有检测行。功能逻辑、离屏视图及私有剪贴板证据不等于完整端到端 UI 验收。月度提示词扩展本轮只做编译与静态检查，没有专项运行测试；真实文件路径存在性不在本期实现范围。
- 非阻塞：大规模 Workflow 元数据读取当前同步进行，后续真实规模出现卡顿时再考虑优化；离开工作台不保证保留草稿。本期无任务历史、导出、自动发送或 CLI 启动。
- **结论：用户已接受上述验收范围，本阶段关闭，无已知阻塞。** 用户授权的 `feat: 新增 AI 工作台任务准备与提示词交接` 已正常推送 main，正式提交 `e66dd21fe228828ba05753ff78cebf97efdd6806`，parent `6639e431fa9f1d6f8ba7664069ad18fed1b1f41b`，仅包含报告的 7 个文件；收尾实际远端 SHA 与 main/origin/main 一致、ahead/behind 0/0、工作区干净。收尾 fetch 曾遇到瞬时 SSL 错误，随后 ls-remote 成功核对实际远端；不重复测试、构建或复审。后续 Phase 3 由用户明确授权实施，记录见 §24。Word WIP、Step06 Harness、客服文档 V1 重新采用、Evidence/Quarantine、旧 P3 和其他仓库/知识库均未处理。


## 24. AI 工作台 Phase 3 — 任务交接记录 — 2026-10-10

### 当前流程与语义

- 准备任务 → 复制提示词 → 手动“记录本次交接” → 交接记录入口 → 按活动筛选 / 时间倒序查看 → 原生详情窗口 → 再次复制保存原文。复制与记录为两个动作，不自动检测发送，不代表 AI 已执行或任务完成。
- 新的不可变值类型保存 UUID、首次记录点击时间、Campaign/Workflow/Step 稳定 ID 与当时名称、工具标识与显示名、完整目标/补充要求以及完整提示词。历史不引用当前资料重新生成、不改写旧名称、不提供编辑、删除或完成标记。
- 保存前重新读取 Phase 2 只读上下文，核对原有活动/流程/步骤身份并逐 UTF-8 字节比较当前预览；上下文变化时不保存，先更新预览提示核对。关联失效时拒绝记录且保留草稿。最近复制后文字变化时，明确告知记录的是当前预览而非之前复制版本。
- 保存过程中停用按钮；成功后相同预览不能连续记录，需明确“准备再次交接相同任务”重新开启下一次登记。允许有意重复交接相同任务。失败保留草稿与预览；重试未确认写入时复用记录 ID / 时间，磁盘已有同 ID 且内容逐字一致则返回已有记录，不重复追加。
- 历史按记录快照中的活动 ID 筛选，显示保存时名称、步骤、工具、时间和目标。读失败显示错误，不能伪装为空；详情在打开及用户点击“核对当前关联”时只读核对当前关联。关联已删除或无法读取不影响查看/复制历史；历史复制逐字使用保存文本，并有成功/失败反馈。
- Phase 1 检测与 Phase 2 准备能力保留；本期不启动任务、不改 Campaign/Workflow/Run/Approval/Artifact、不调用服务、不改 Prompt Vault / Home、不同步其他知识库，暂缓事项仍不处理。

### 独立存储与数据保护

- 正式位置遵循现有 Application Support 约定：`~/Library/Application Support/Cosmos OS/AIWorkspace/handoffs.json`，备份 `handoffs.backup.json`，协作写锁 `.handoffs.lock`；当前工程关闭 App Sandbox。文件内 schemaVersion = 1；库大小超过 16 MiB 时拒绝而非截断。仅手动记录时创建目录/主文件，首次读取不存在目录不写入默认数据。
- 使用模块独立的串行 I/O 队列与 flock；安全读路径/拒绝符号链接、读取最新已验证文件、保留既有记录、原子写备份并读回、同目录临时文件 fsync + rename 原子替换主文件、逐字读回确认后发布。沿用 LearningFileStorage 已有安全原语但不修改 Learning 模块，不引入通用框架。
- 写前失败保留已有主文件；写后校验失败明确标为结果不确定，不冒充未保存或自动回滚，重试同 ID 幂等。解析错误、未知 schema、危险路径及主文件缺失但备份存在时拒绝保存，不自动恢复、清空或重建。历史加载错误保留内存记录但显示错误并阻止记录，用户可刷新核对。
- DEBUG 隔离必须同时有隔离 Bundle、隔离 suite 和获准 UUID 临时根（`--cosmos-ai-handoff-fixture-root /private/tmp/CosmosAIHandoffPhase3-<UUID>`）；缺根或错误配置不会回退正式目录。隔离可用 `--cosmos-ai-workspace-history` 打开历史页。测试宿主不传根时历史失败关闭，不创建正式历史数据。

### 本轮实测

- 新增 `AIWorkspaceHandoffTests` 15 项：首轮 **14 通过 / 1 失败**；唯一失败为测试比较 directory URL 尾部斜杠而非路径，不是产品缺陷。一次集中修复仅改该断言，随后只重跑受影响项并通过；最终 **15 项通过（14 项首轮有效结果 + 1 项修复后通过）**，未重跑全套或 Phase 1/2 历史测试。
- 覆盖保存/重载全文及 Unicode/CRLF/空白字节一致；改名历史不变；关联删除仍可读/复制；复制不记录；复制后改要求提示当前版；当前可见预览与保存一致；上下文变更/失效阻断；连续点击及有意再次登记；写失败保留已有文件与草稿；读错误不覆盖、不恢复备份；各写前阶段失败；写后不确定重试同 ID；两个存储实例并发追加不丢记录；符号链接与未知 schema 拒绝；私有剪贴板全文/失败反馈；业务数据源零写入；隔离失败关闭；缺目录读取不创建；实际历史/详情 SwiftUI 视图离屏布局。
- **Universal Debug BUILD SUCCEEDED**，`lipo` 确认 `x86_64 arm64`；新增文件无编译警告。既有省份规则两条 actor 警告与 AppIntents 提示不扩大修复。`git diff --check` 通过。Xcode 自动重排 project.pbxproj 已在解析内容相等后恢复，不纳入变更。
- 一次隔离真实 App 后台 LaunchServices 启动，只截该 App 窗口，不移动用户窗口。历史页显示入口、筛选、合成记录、保存时活动/步骤/工具/目标/时间和明确临时存储路径；Phase 1 自动检测完成（截图可见 Claude 可运行）。交接主文件 SHA-256 和一条记录数量均未变化，无备份/锁/写入临时文件被创建；Campaign/Workflow/Workspace 三份 payload 逐字节不变，无新增业务键。进程结束，UUID suite 删除，正式历史及正式数据未读写。
- 证据：首轮 `/private/tmp/CosmosAIPhase3-Focused.xcresult`；修复项 `/private/tmp/CosmosAIPhase3-IsolationFixed.xcresult`；构建 `/private/tmp/CosmosAIPhase3-build.log`；窗口及完整性 `/private/tmp/CosmosAIHandoffPhase3-51da0eeb-ee32-4553-a936-ed76e0ca074f/`。

### 覆盖缺口、待办与收尾

- 本会话原生 UI 操作工具先前已超时，不重复尝试。真实 App 未点击记录、筛选、详情、再次复制、再次交接或准备/历史切换；这些由状态/存储测试或离屏视图覆盖，不宣称完整端到端 UI 验收。未测真实正式目录写入（按要求隔离验证）、Release、全量/历史测试或独立复审。
- 非阻塞：历史本期全部加载，无分页；超过 16 MiB 明确拒绝追加；关联提示不是持续实时监听，可手动核对；跨进程只承诺遵守协作锁的追加及现有文件变化检查，不宣称覆盖全部非协作文件系统竞争；无自动备份恢复 UI。首次创建记录目录也会创建协作锁文件，失败时可能保留空目录/锁，但不破坏旧主文件。
- **结论：用户已接受上述验收范围，Phase 3 关闭，无已知阻塞。** 用户授权以 `feat: 新增 AI 工作台任务交接记录` 提交并正常推送 main。提交前实际 origin 为 `https://github.com/wangyucosmos/Cosmos-Toolbox.git`，本地 HEAD 与远端 main 均为预期 parent `e66dd21fe228828ba05753ff78cebf97efdd6806`；逐项核对范围为 10 个文件，不纳入个人记录、锁、备份或临时数据。沿用已通过验证，不追加测试/构建。实际提交 `bc9cb33bdf66b85e8645180b8ea8602d1c25f0af`，parent `e66dd21fe228828ba05753ff78cebf97efdd6806`；正常推送后 ls-remote 核对远端 main，main / origin/main / 远端 main 一致、ahead/behind 0/0、工作区干净。Word WIP、Step06 Harness、客服文档 V1 重新采用、Evidence/Quarantine、旧 P3 及其他知识库不动。后续资料选择 Phase 1 的实施见 §25。


## 25. 任务上下文资料选择 Phase 1 — 2026-10-10

### 当前流程与读取边界

- 选择活动/步骤 → 明确选择参考产物 → 读取并预览原文 → 完整提示词 → 复制 / 手动记录交接。默认不选、不读正文，仅提供当前 Campaign 已管理的 Workflow.artifacts，不扫描目录、导入产物或读取其他知识库。
- 复用知识与资产中心的 ZhuowangAssetTextReader 与 request(for:)：元数据正文优先，UTF-8 文本文件后备，限量读取、符号链接/路径拒绝、读取前后文件检查、缓存及原文保留。图片、PDF、HTML、Figma、Word、Excel、URL 等只显示元数据，不新增提取/转换。
- 唯一当前采用版本优先展示；历史、未采用及采用冲突置于需明确展开选择的区域。按既有 versionGroupKey / isApprovedVersion 判断，不以最新版本代替采用版本。重复 Artifact ID 显示错误，拒绝可靠选择。
- 所选正文可查看、移除、重新读取。提示词标记名称、版本、稳定身份、来源步骤、逻辑组、采用状态、正文来源、登记位置及文件核对状态；使用不会出现在正文中的分隔符，逐 UTF-8 字节保留空白、CRLF、Unicode 和尾部。正文中的指令只作参考，不提升为当前任务授权。
- 单份正文最多 **2 MiB**（沿用安全读取器）；**最终完整提示词最多 4 MiB UTF-8**（包括基础说明与全部正文），超限拒绝，不静默截断。读取失败且无有效正文则阻止交接；若有效元数据正文存在而文件不可读、不一致或文件超限，沿用资产中心优先级，明确显示使用元数据正文和文件核对失败/超限，不冒充已加入文件正文。元数据自身超限或读取期间文件变化仍拒绝。
- 切换活动清空资料并使晚到异步结果失效；切换步骤保留同活动明确选择项，显示保留数量及核对用途提示，本次目标/要求仍清空。移除、切换或正在读取时不会交接旧正文。
- 复制与记录前只重新校验所选资料及主元数据；文件修订、正文、元数据或采用状态变化先更新预览并拒绝当前操作，用户核对后再次点击。即使元数据仍是优先正文、显示文本未变化，文件修订变化也要求再次操作。最终逐字比较可见预览，不能静默复制或保存另一文本。
- Phase 3 保存最终完整提示词快照；历史查看与复制始终使用保存原文，不随资料变化重新生成。资料选择及正文仅页面内存，无新持久化结构；历史存储位置仍为 §24 独立目录。不写业务 Store、不修改源文件、Workflow、Run、Approval 或采用状态。
- DEBUG 资料读取复用既有隔离 asset root；隔离缺根失败关闭，不回退正式文件。Phase 1 检测、Phase 2 准备及 Phase 3 历史入口保留。

### 本轮实测与保护证据

- 新增 AIWorkspaceTaskReferencesTests **14/14 通过，0 失败**，无集中修复：默认零磁盘读取、当前活动限定/采用优先、明确历史/未采用/冲突；原文字节与完整预览/私有剪贴板/保存重载历史一致；活动清空、步骤明确保留、晚到读取失效；元数据优先及 Unicode 原字节缓存校验；文件修订/正文或采用变化首次交接拒绝、再次明确操作成功；缺失/非 UTF-8/符号链接失败；单份及总上限拒绝且不截断；非支持类型仅元数据、隔离缺根零读取；删除产物/重复身份；实际选择视图离屏布局。测试使用 UUID 临时目录，业务数据源零写入、源文件逐字节不变。
- **Universal Debug BUILD SUCCEEDED**，lipo 确认 `x86_64 arm64`，签名关闭、临时 DerivedData/隔离 Bundle。新增代码无编译警告；既有省份规则 actor 警告和 AppIntents 提示不扩大修复。git diff --check 通过。工程自动重排经 plutil 解析内容相等后恢复，不纳入变更。未跑全量或历史测试、Release 或独立复审。
- 一次真实 App 后台 LaunchServices 隔离启动，使用随机 suite、临时 asset root 和历史 root，仅截目标窗口、不移动用户窗口：任务准备/交接记录入口呈现，Phase 1 自动检测完成时间可见。Campaign / Workflow / Workspace 三份载荷逐字节不变、无新增业务键，样本源文件 SHA-256 不变，临时历史目录无记录/锁/备份文件。结束隔离进程并删除随机 suite，正式数据未读写。
- 证据：`/private/tmp/CosmosTaskReferences-Focused.xcresult`、`/private/tmp/CosmosTaskReferences-focused.log`、`/private/tmp/CosmosTaskReferences-build.log`；窗口、载荷及完整性报告 `/private/tmp/CosmosAssetPhase1-a2441e3b-4ccb-43a2-b071-7bf4d183930b/`。

### 限制、待办与结论

- 原生 UI 工具本会话先前已超时，不重试。真实 App 未选择活动/资料、滚动正文、点击复制/记录或体验变化后二次确认；新选择区域位于截图可见区域以下。逻辑、离屏视图与私有剪贴板测试不等于完整端到端 UI 验收。未触碰正式文件、未跑历史读取器完整测试；本轮新增路径的实际读取风险由新测试覆盖。
- 非阻塞：大段正文/完整预览目前直接 Text 呈现，接近上限时可能有排版成本；选中资料仅页面内存，离开页面不保证保留。校验为操作前检查及既有 stat 修订检查，不承诺防止外部进程在检查结束后修改文件。无全文搜索、编辑、转换、任意目录资料或跨知识库同步。
- 修改范围：新增 AIWorkspaceTaskReferences.swift、AIWorkspaceTaskReferencesView.swift、AIWorkspaceTaskReferencesTests.swift；修改 AIWorkspaceTaskPreparation.swift、AIWorkspaceTaskPreparationView.swift、AIWorkspaceHandoffStore.swift、AIWorkspaceView.swift、DashboardView.swift、ZhuowangAssetCatalogModels.swift、ZhuowangAssetTextReader.swift，以及本文件和当日日志，共 12 个文件。
- **结论：用户已接受上述声明验收范围，阶段关闭，无已知阻塞。** 用户授权按 `feat: 支持 AI 任务选择产物正文作为上下文` 提交并正常推送 main，仅包含报告中的 12 个文件。提交前实际 origin 为 `https://github.com/wangyucosmos/Cosmos-Toolbox.git`，本地 HEAD 与远端 main 均为预期 parent `bc9cb33bdf66b85e8645180b8ea8602d1c25f0af`。沿用 14/14 测试、Universal Debug 构建及隔离数据保护证据，不追加测试/构建/复审；真实按钮交互未覆盖及大段正文排版成本继续作为验收限制。实际正式提交 `3024ceb6b9a501d19ef37002bdb108c3e63c27d8`，parent `bc9cb33bdf66b85e8645180b8ea8602d1c25f0af`；正常推送后 main / origin/main / 实际远端 main 一致、ahead/behind 0/0、工作区干净。下一模块仅依用户明确授权开展（本轮 §26）。Word WIP、Step06 Harness、客服文档 V1 重新采用、Evidence/Quarantine、旧 P3 和其他知识库保持不动。


## 26. 核心数据备份 Phase 1 — 导出与完整性校验 — 2026-10-10

以下保留已关闭 V1 阶段的历史验收；当前 Projects 第 11 源与 V2/V1 兼容扩展见 §30。

### 用户流程与实际数据边界

- Settings → 查看包含/不包含与安全排除 → 保存面板选择新 ZIP → 后台导出并校验 → 显示结果及逐源状态 → Finder 查看；也可选择已有 ZIP 独立校验。正在操作时停用按钮，失败明确反馈，不自动重试、不导入或恢复。
- 开工只查 status / HEAD，实际干净基线为 `3024ceb6b9a501d19ef37002bdb108c3e63c27d8`。沿用用户提供的有效远端收尾证据，不 fetch、不重跑历史验证、不设调查或独立复审。
- 只读 10 个明确主数据源；不初始化 Store、不扫描目录/偏好域、不读产物实体、不刷新业务备份、不创建缺失默认数据。配置读取经现有 dataSource；UserDefaults 已有非 Data 值明确报错，不能伪装缺失。缺失主数据但已有对应备份时拒绝，不自动恢复或重建。

| 包内源 ID | 实际持久化来源 | 包内路径（存在时） |
| --- | --- | --- |
| campaigns | `cosmos.zhuowang.campaigns.v1` | `data/campaigns.json` |
| workspace | `cosmos.zhuowang.workspace.v1`（包含省份配置） | `data/workspace.json` |
| workflows | `cosmos.zhuowang.workflows.v1`（内嵌 Artifact、Run、Approval） | `data/workflows.json` |
| providers | `cosmos.zhuowang.ai.providers.v1` | `data/providers.json` |
| connections | `cosmos.zhuowang.ai.connections.v1` | `data/connections.json` |
| tools | `cosmos.zhuowang.ai.toolIntegrations.v1` | `data/tools.json` |
| routes | `cosmos.zhuowang.ai.agentToolRoutes.v1` | `data/routes.json` |
| prompts | Application Support / Cosmos OS / PromptVault / templates.json | `data/prompts.json` |
| learning | Application Support / Cosmos OS / Learning / learning.json（主题+记录） | `data/learning.json` |
| handoffs | Application Support / Cosmos OS / AIWorkspace / handoffs.json | `data/handoffs.json` |

- 普通业务 JSON 原字节保留（包括正文、空白、CRLF、Unicode、登记路径引用）；配置先解析验证，再按固定白名单输出已知非敏感字段。Provider 排除 configurationIdentifier 和未知字段；Connection / Tool / Route 排除整份自由 configuration 字典、endpointOrPath、adapterIdentifier、notes 及未知字段。清单逐源记录转换，exclusions 明确排除项；宁可明确排除不能判定安全的自由配置，不猜测其中是否含 token。已知名称、模型、身份、状态、能力、执行选项和时间保留，不恢复这些被排除字段。
- 不读取 Keychain、API Key/token/认证文件或整个 Application Support。用户既有 Prompt / Artifact / 学习 / 交接正文原样备份，不实施正文敏感词改写；不是加密备份。源码、正式产物、外部知识库、工具环境、Evidence/Quarantine、Word WIP 与临时数据均不包含；现有文件路径仍依赖原文件，不宣称完整换机恢复。

### 格式、校验与一致性

- ZIP 内 `manifest.json`：format = CosmosCoreMetadata、version = 1、ISO8601 exportedAt、exclusions、10 个固定 source 条目。每条含 ID、present / missing、包内路径、字节数、SHA-256 及 transformation；missing 无数据条目，真实空数组/空库仍 present。清单不额外记录绝对来源路径；业务内容本身原有路径引用仍保留。
- 只支持本格式的未压缩标准 ZIP，不支持任意 ZIP、压缩方法、ZIP64、额外字段或注释。校验直接解析有界 ZIP 内存字节，不解压到磁盘；固定路径白名单、中央/本地头严格配对、CRC32、唯一条目及清单精确匹配拒绝路径穿越、符号链接、重复项、未知项、缺项及损坏。清单格式/版本、大小/SHA-256、各源 Codable/身份及已有文件文档 validate 同时检查；配置中未获准字段也拒绝。
- 容量：每源 **16 MiB**、包 **128 MiB**（含 ZIP 结构与清单）、清单 **256 KiB**，最多 11 个条目。不截断。源读取/ZIP 操作在后台，UI 状态在主线程。
- 复用既有安全文件模式：lstat 普通文件与父路径/符号链接拒绝、O_NOFOLLOW、限量读取、读取前后 device/inode/大小/mtime/ctime 纳秒修订比较。发布前逐源复读原字节和文件修订；不同则中止。UserDefaults 只比较当前进程可见的原始业务值，不调用 synchronize 或写入源，也不宣称持有全域/跨进程事务。
- 一致性是检查点校验，不是全业务原子快照或跨进程事务；无法保证外部进程在最终检查后不再写入，或捕获检查点之间发生且完全回退的变化。文件检测复用现有修订语义，不创建/修改源锁或恢复主文件。
- 同目标目录的专属临时文件，以 0600 权限、O_EXCL 写入并 fsync；先验证临时包再核对源，用 renamex_np / RENAME_EXCL 发布。即使其他进程中途建立同名目标，也拒绝覆盖。失败只清理本次临时包，不改已有目标或源数据。活动交付包服务语义未改；没有采用其 ditto 解包路径来校验未知输入，新增的 ZIP 逻辑仅限本备份格式。
- SHA-256 / CRC32 用于意外损坏及条目完整性，不是签名、认证或加密；同时篡改内容并重算清单无法证明来源真实性。校验不引用正式源数据、不判断当前业务关联是否存在。

### 本轮实测

- 首轮集中检查在编译阶段停止，测试未执行：Settings 缺少 Combine 导入，另有配置初始化 actor 边界 warning。一次集中修复加入导入、主线程捕获 dataSource 后交给后台闭包；随后只运行尚未执行的新 CoreBackupTests，**12/12 通过**。未跑历史/全量测试，没有第二轮修复。
- 覆盖 10 源和普通载荷/正文逐字节保留、敏感配置与未知字段排除、清单无额外来源绝对路径；未建立 vs 真实空库、读取不创建默认目录/数据；不可读、坏数据、错类型、缺主有备份；偏好值变化与同字节文件修订变化中止且清临时包；已有目标及发布前抢先创建目标不覆盖；篡改/缺项/多余项、重算哈希但结构损坏、重复清单、ZIP 重复/穿越/符号链接/压缩方法/条目数、未知版本及未获准配置字段；单源/包超限、源和包/父路径符号链接拒绝、隔离缺根失败关闭，以及 Settings 离屏渲染。
- 合成数据使用 UUID 临时根。导出及独立校验前后业务源字节与主文件字节一致；操作只获指定源读取能力，无业务写接口。错类型测试用随机 UserDefaults suite，测试前后域值一致并清理；无正式业务源读取、写入或恢复。
- **Universal Debug BUILD SUCCEEDED**，lipo 确认 `x86_64 arm64`；签名关闭、临时 DerivedData 和隔离 Bundle。git diff --check 通过。工程自动重排经 plutil 解析内容相等后恢复，无工程语义修改。新模块有一条 `ZhuowangWorkspaceSnapshot.Decodable` nonisolated 使用 warning（当前 Swift 5 可编译通过，未来 Swift 6 迁移待统一处理）；既有省份 actor / AppIntents / 历史测试编译 warnings 不扩大修复。
- 一次后台 LaunchServices 隔离 App 启动：随机 suite + 三个明确 UUID 临时文件根，仅截目标窗口，不移动用户窗口。Settings 范围、排除、容量、一致性说明、导出/校验入口清楚呈现。三份 Campaign/Workflow/Workspace 偏好载荷逐字节不变，无新增业务键；Prompt/Learning/Handoff 三个主文件哈希不变，目录只保留原主文件、无新备份或锁。进程已结束、随机 suite 已删除，正式数据未触碰。
- 证据：首次编译 `/private/tmp/CosmosCoreBackup-Focused.xcresult`；修复后 `/private/tmp/CosmosCoreBackup-Fixed.xcresult`、`/private/tmp/CosmosCoreBackup-fixed.log`；构建 `/private/tmp/CosmosCoreBackup-build.log`；窗口/载荷/完整性 `/private/tmp/CosmosCoreBackupUI-19db1199-0d33-4567-bf5c-bd63171c418d/`。

### 缺口、待办与结论

- 原生 UI 工具此前受限，本会话不重试。真实 App 未点击保存/打开面板、导出/校验反馈、重复操作或 Finder 按钮，不宣称完整端到端验收；服务风险由本轮测试覆盖。未验证真实正式数据导出、Release、任意第三方 ZIP 改写兼容、接近 128 MiB 的性能/内存峰值；不跑全量或历史测试、不安排独立复审。
- 非阻塞：V1 未压缩 ZIP 与源载荷在内存操作，接近上限可能有内存成本；只有特定版本格式可校验，没有来源签名、加密、恢复或自动备份。配置自由字典全部排除，未来需要保留特定安全字段时应明确扩展白名单，不能放宽为全量导出。Swift 6 actor 迁移 warning 待未来统一处理。
- 修改文件：新增 CoreBackupModels.swift、CoreBackupSource.swift、CoreBackupArchive.swift、CoreBackupService.swift、CoreBackupSettingsView.swift、CoreBackupTests.swift；修改 DashboardView.swift、ZhuowangProtectedPersistence.swift、本文件和当日开发日志，共 10 个文件。
- **结论：用户已接受上述声明验收范围，阶段关闭，无已知阻塞。** 授权以 `feat: 新增核心数据备份与完整性校验` 正常提交推送 main，仅包含报告中的 10 个文件，沿用 12/12 测试、Universal Debug 和隔离数据保护证据，不追加测试/构建/复审。提交前实际 origin 为 `https://github.com/wangyucosmos/Cosmos-Toolbox.git`，HEAD 与远端 main 均为预期 parent `3024ceb6b9a501d19ef37002bdb108c3e63c27d8`；实际提交 `16dd38682e8c17ef15dc97cae2718a261db441dc`，parent `3024ceb6b9a501d19ef37002bdb108c3e63c27d8`，消息 `feat: 新增核心数据备份与完整性校验`。正常推送后实测 main = origin/main = 远端 main，ahead/behind 0/0，备份收尾时工作区干净；恰好提交上述 10 个文件。随后按授权实施空环境恢复，不操作正式数据。Word WIP、Step06 Harness、客服文档 V1 重新采用、Evidence/Quarantine、旧 P3、其他仓库和知识库保持不动。


## 27. 核心数据恢复 Phase 1 — 空环境恢复 — 2026-10-10

以下保留已关闭 10 源阶段的历史验收；当前 Projects 目标/空环境检查扩展见 §30，其余事务与启动保护保持。

### 流程与范围

- Settings → 选择备份 → 完整校验与关联检查 → 展示导出时间/格式版本/各源状态与摘要/实际恢复项及限制 → 明确确认 → 再校验包和空目标 → 后台恢复 → 提示退出并重启。确认前、取消和校验失败均不创建恢复数据。不提供覆盖、合并、强制恢复或选择性恢复。
- 复用 §26 的固定 10 源、V1 格式与安全 ZIP 校验；单源 16 MiB、整包 128 MiB、清单 256 KiB。不从包内路径推导外部目的地。实际目标为当前安装原有 7 个业务 UserDefaults 主键及 PromptVault/templates.json、Learning/learning.json、AIWorkspace/handoffs.json；逐源位置以 §26 表为准。
- Campaign、Workspace、Workflow、Prompt、Learning、Handoff 原字节保留，包括正文、CRLF、Unicode、UUID、历史版本、Run/Approval、采用选择与历史交接文本。Workflow→Campaign、Run/Approval→Step、Artifact 所属 Campaign 结构关联错误拒绝；历史产物 Step/Run、历史 Provider 或配置关联缺失提示限制，不补造身份。关联已删除的交接历史仍保留快照。
- 原文件路径仅是历史引用。不读取、产生、移动或修复实体文件；不恢复认证、端点、自由配置字典或被排除字段，不执行 CLI/联网验证。
- AI 配置恢复使用固定白名单：Provider 禁用；Connection/Tool 禁用且 needsSetup；Connection 关闭自动选择；Connection/Route 自动执行及自动返回选项关闭，Route needsSetup。历史 available 不表示当前可用，UI 提示重新设置。恢复安装跳过既有 Provider 规范化与默认连接补建，避免脱敏身份被改写或缺失配置被伪造；missing 配置源仍不存在。

### 空环境与启动门控

- 空不是“列表为空”：固定主键及其 .backup 必须不存在，三个业务模块不得有主文件、备份或相关写锁。有效空载荷、错类型、损坏、不可读取、状态不明均拒绝；不恢复缺失主文件、不删除默认数据来绕过检查。未知恢复控制数据也拒绝。
- 根视图先进入数据启动保护，再决定是否构造 Dashboard/业务 Store。新安装可在初始化任何业务数据前选择恢复；“创建新环境”先持久化 started 标记，再进入工作台，之后不能再当作空环境恢复。
- 恢复成功的当前进程保持重启提示，不构造仍持有旧状态的业务 Store；下一启动核对 complete 收据与实际数据，清暂存并转 started/restored 后才加载。inProgress/failed 或损坏标记阻止业务加载，提供明确的本次事务安全回退入口；不自动清空修复。

### 发布、失败与中断保护

- 独立控制目录：`~/Library/Application Support/Cosmos OS/CoreRestore/`。`state.json` 保存版本、事务 UUID、状态、恢复安装标志及逐源 planned/pending/written 收据；`.restore.lock` 为非阻塞 flock 协作锁；`payload-<sourceID>.json` 为已验证暂存。journal 临时文件 fsync 后原子 rename，目录也 fsync；不把业务旧备份或写锁恢复为正式状态。
- 解析、结构和关联检查全部先完成。确认时重新读取有界备份，核对包 hash 与文件修订；写前复查目标、已写收据和备份/锁。UserDefaults 使用现有同进程每键锁、存在性检查、set/remove + synchronize + 读回；文件用完整暂存的 exclusive hardlink 原子发布，拒绝覆盖，核对 inode/device/字节并 fsync 目录。
- 同卷 hardlink 是文件发布前提，当前生产位置同属 Application Support；跨卷 EXDEV 安全失败，不用非原子 copy 降级。文件收据记录修订身份；只有可确认属于本次创建且未变化的数据才能回退。并发变化、归属不明 pending 数据不删除，保留失败/未完成标记并阻止成功加载。
- 这是带持久化收据、启动门控及协作锁的恢复协议，不是文件与 UserDefaults 的跨进程原子事务。UserDefaults 无跨进程 CAS；非协作程序在检查后写入的竞态不能完全排除。中断后新 service 可显式安全回退，无法确认时保留并阻断，不把半套数据视作成功。
- 备份导出语义未变；仅抽出既有有界字节校验以供恢复复用。未恢复任何暂缓事项，不写其他仓库或知识库。

### 本轮验证与证据边界

- 一轮集中 CoreRestoreTests **14/14 通过**。随后一次集中补齐文件原子发布，仅重跑受影响的 **7/7 通过**；最终 14 项覆盖由未变化 7 项沿用首轮、文件相关 7 项修复后证据组成，未重新跑整套或历史测试，无第二轮修复。
- 覆盖备份→恢复→新 service/新偏好 wrapper 重新加载原文、UUID、Run/Approval、V1 采用及 V3 历史；实际 WorkflowStore 重载不补建 Provider、偏好字节不变；禁用配置不补造秘密；missing 源不创建；确认前/取消零写；已有空库、损坏/错类型/不可读目标、备份/锁拒绝；坏包/结构关联错误/预览后包修订变化拒绝。
- 覆盖写失败回退已确认前缀；目标变化保留并阻断启动；注入中断、重新创建 service 后显式回退；不确定偏好写入不删除；变化文件/符号链接保护；complete 后目标变化或损坏 marker 阻断；创建新环境后拒绝恢复。源资料与备份未修改，缺失实体不生成，恢复视图离屏渲染通过。所有目标为完整隔离临时目录及随机 suite，未操作正式 App 数据。
- 一次 **Universal Debug BUILD SUCCEEDED**，lipo 确认 `x86_64 arm64`，隔离 Bundle ID、关闭签名、临时 DerivedData。工程自动重排经 plutil 内容相等核对后恢复，不纳入修改；git diff --check 通过。
- 一次后台隔离真实 App 显示“数据启动保护”、选择备份及创建新环境入口；仅截图目标窗口，不激活或移动用户窗口。随机偏好域无 cosmos 业务键，Prompt/Learning/Handoff/CoreRestore 四个临时根均未创建，证明初始化门控未写业务数据。隔离进程已结束；清理随机 suite 时域已不存在，defaults 未改其他域。
- 证据：首轮 `/private/tmp/CosmosCoreRestore-Focused.xcresult` 与 focused.log；受影响项 `/private/tmp/CosmosCoreRestore-FilePublish.xcresult` 与 file-publish.log；构建 `/private/tmp/CosmosCoreRestore-build.log`；真实窗口及 integrity.json 位于 `/private/tmp/CosmosCoreRestoreUI-d41ae7fd-6eb9-499a-90d8-b5b3e220b892/`。
- 未覆盖：真实打开面板、确认/恢复/回退按钮及真实重启恢复完整交互；实际断电/kill 中断仅由注入模拟覆盖；未验证正式数据、Release、容量上限性能或非协作跨进程竞态，不宣称完整端到端 UI 验收。原生点击工具此前受限，本轮不重试。
- 非阻塞待办：新模块 4 条非 Sendable 后台闭包捕获 warning（CoreRestoreStartupView 三处、CoreRestoreView 一处），当前 Swift 5 构建通过，未来 Swift 6 迁移需明确契约；既有 WorkspaceSnapshot.Decodable、省份 actor 和 AppIntents warning 沿用，不扩大修复。

### 修改与结论

- 新增：CoreRestoreModels.swift、CoreRestoreTarget.swift、CoreRestoreService.swift、CoreRestoreView.swift、CoreRestoreStartupView.swift、CoreRestoreTests.swift。
- 修改：CoreBackupService.swift、CoreBackupSettingsView.swift、Cosmos_ToolboxApp.swift、DashboardView.swift、ZhuowangAIConnectionStore.swift、ZhuowangProtectedPersistence.swift、ZhuowangWorkflowStore.swift、本文件、当日开发日志。共 **15 个文件**，无工程语义修改或业务数据纳入。
- **结论：用户已接受上述声明验证范围，阶段关闭，无已知阻塞。** 授权按 `feat: 新增核心数据空环境恢复` 正常提交推送，仅逐项纳入上述 15 个文件，沿用已有验证，不追加测试、构建或复审。提交前 origin 为 `https://github.com/wangyucosmos/Cosmos-Toolbox.git`，实际远端 main 与预期 parent 一致。当前基线 `16dd38682e8c17ef15dc97cae2718a261db441dc`；实际提交 `72f020b628d4ee7be3e720f1e67055686f4f55ea`，parent `16dd38682e8c17ef15dc97cae2718a261db441dc`，消息 `feat: 新增核心数据空环境恢复`，恰好逐项提交上述 15 个文件。正常推送后 main = origin/main = 实际远端 main，ahead/behind 0/0，恢复收尾时工作区干净。随后实施已授权 Mac 概览，不操作正式数据。Word WIP、Step06 Harness、客服文档 V1 重新采用、Evidence/Quarantine、旧 P3 均保持暂缓。不自动开发下一模块。


## 28. Mac 环境概览 Phase 1 — 2026-10-10

### 用户流程与来源口径

- 原有“Mac 优化 / macOptimizer”导航身份保留，占位页替换为原生只读概览。首次进入后台读取一次，显示完成读取时间，可手动刷新；不持续轮询。当前进程再次进入沿用内存快照，未完成读取离开时取消，再进入可重新读取；重启无历史。
- 系统版本使用 ProcessInfo.operatingSystemVersion；硬件型号 sysctl `hw.model`、芯片/处理器名称 `machdep.cpu.brand_string`；硬件架构先读取 `hw.optional.arm64`，支持 ARM 时显示 arm64，否则用 `hw.machine`。不读取序列号、设备 UUID、网络地址或认证信息。
- 物理内存使用 ProcessInfo.physicalMemory，二进制格式并显示原始字节（1 GiB = 2³⁰ 字节；系统 ByteCountFormatter 可能仍将单位显示为 GB，页面明确说明口径）。没有“总量减空闲”或应用内存估计。当前系统压力没有采用可靠的同步读数，明确显示未知/本期未读取，不推算健康评分。
- 磁盘使用用户主目录 URL 的 volumeTotalCapacity / volumeAvailableCapacity。展示该卷总量与可用容量，十进制单位（1 GB = 10⁹ 字节）；不是主目录大小，不包含可清除空间估算、不扫描目录或垃圾。
- 电池使用 IOPSCopyPowerSourcesInfo/List 与 IOPSGetPowerSourceDescription，只处理 InternalBattery，不把 UPS 当内置电池。电量是 IOPS 当前容量 / 满充容量百分比（两者同单位）；供电用 Power Source State，充电用 Is Charging。容量字段不是电池健康最大容量，不展示循环次数/健康容量。无内置电池或系统明确未安装时为不适用；电源描述/类型/存在状态读取失败与不适用区分。电量、供电、充电各自保留未知或错误。
- 每项独立读取或表达未知/失败，不用未知代替正常，一项失败不隐藏其他结果。没有业务 Store、设备历史、外部命令、网络、上传、系统修改或额外权限申请；不接入首页、不重复 CLI 检测。

### 内存状态与验证

- 服务是 nonisolated Sendable，只读调用在 detached 后台任务执行；模型主线程发布、重复刷新忽略、代次核对并检查取消，迟到结果不能覆盖较新快照。取消停止接收结果，不宣称可中断正在执行的系统同步 API；这些固定查询不执行子进程或遍历文件。
- 首轮集中检查在编译阶段停止，测试未执行：项目默认 MainActor 令后台模型 Equatable/Sendable 隔离不兼容，沙箱另阻止既有宏工具。一次集中修复补齐新模型/服务 nonisolated 声明；在沙箱外仅执行尚未运行的新 MacEnvironmentTests，**11/11 通过**，无第二轮修复，无历史/全量测试或独立复审。
- 覆盖容量与二进制/十进制单位、无电池/UPS、不明类型和非法容量、独立供电/充电未知、单项失败不影响其他字段、无效内存；首次读取/重入不自动刷新、重复刷新、取消保留既有快照、迟到结果不覆盖；页面离屏渲染及 UserDefaults 前后不变。
- 本机一次对照：macOS 26.6.2、MacBookPro18,2、Apple M1 Max、arm64、34359738368 字节（32 GiB）；sysctl / sw_vers 返回相同。IOKit 与 pmset 同为 80%、外接供电、未充电。卷总量 994662584320 字节、采样可用 535377547264 字节，与同口径 URL 卷 API 一致；可用容量实时变化，自动对照允许 64 MiB 短时变化，不当作固定值。
- 一次 **Universal Debug BUILD SUCCEEDED**，lipo 确认 x86_64 arm64，临时 DerivedData/隔离 Bundle/关闭签名；git diff --check 通过。工程自动重排经 plutil 解析内容相等后恢复，无工程语义改动。新模块无编译 warning；既有恢复 Sendable、WorkspaceSnapshot/省份 actor 等 warning 保留，不扩大修复。
- 一次后台隔离 App 直接打开原有 macOptimizer：窗口显示系统/内存/磁盘口径、时间和刷新入口；只截目标窗口，不激活或移动窗口。随机偏好域 Campaign 空载荷原字节不变，无新增业务键，Prompt/Learning/Handoff/CoreRestore 四个临时根均未创建；进程及随机 suite 已清理，正式数据未触碰。
- 证据：首轮 `/private/tmp/CosmosMacEnvironment-Focused.xcresult`（编译停止）；修复后 `/private/tmp/CosmosMacEnvironment-Fixed.xcresult`、fixed.log；构建 `/private/tmp/CosmosMacEnvironment-build.log`；同口径读数 `/private/tmp/CosmosMacEnvironment-live.json`；窗口和完整性 `/private/tmp/CosmosMacEnvironmentUI-ad34ab22-15d0-4e1e-bad5-eab67d7400b8/`。

### 限制、修改与结论

- 真实 UI 未点击刷新或操作滚动后的电池区域，取消/迟到由自动化覆盖，不宣称完整端到端 UI 验收。无电池通过合成电源数据覆盖，未在台式 Mac 实测；未在 Intel/Rosetta 实机或 Release 验证。本期内存压力、循环次数与健康最大容量未读取；不为此增加命令或私有字段。部分 SDK/API 在受限进程中可能失败，页面按字段报告原因。
- 新增：MacEnvironmentModels.swift、MacEnvironmentService.swift、MacEnvironmentViewModel.swift、MacEnvironmentView.swift、MacEnvironmentTests.swift。修改：DashboardView.swift、本文件、当日开发日志，共 **8 个文件**；未纳入正式数据、截图或临时证据。
- **结论：用户已接受上述声明验收范围，阶段关闭，无已知阻塞。** 授权按 `feat: 新增 Mac 环境只读概览` 正常提交推送 main，仅逐项纳入上述 8 个文件；沿用 11/11 测试、Universal Debug 及本机对照证据，不追加测试、构建或复审。提交前 HEAD 与实际远端 main 均为预期 parent `72f020b628d4ee7be3e720f1e67055686f4f55ea`，origin 为 `https://github.com/wangyucosmos/Cosmos-Toolbox.git`；实际 commit `7124c4f2c918fc39eb52ae05209898654fa24c4e`，parent `72f020b628d4ee7be3e720f1e67055686f4f55ea`，恰好提交 8 个文件；正常推送后 main/origin/main/远端一致、ahead/behind 0/0、工作区干净。随后复用双架构构建产物，以正式 Bundle ID 从临时独立副本正常启动（未重新编译、未传测试参数）；该临时副本现由 §29 的稳定 Release 部署替代。所有暂缓事项不动，不写其他知识库、不自动开发下一模块。


## 29. 日常使用部署 — Universal Release — 2026-10-10

- 用户授权本机构建、可回退部署与正常启动，未授权提交推送。开工仅查 status/HEAD，干净基线 `7124c4f2c918fc39eb52ae05209898654fa24c4e`；不调查/复审已关闭阶段，不跑历史或全量测试。
- 稳定安装：`~/Applications/Cosmos Toolbox.app`，正式 Bundle ID `com.wangyucosmos.Cosmos-Toolbox`。本次为首次安装，该目标没有旧 App；先前 `/private/tmp/CosmosOS-Daily-7124c4f/` 的临时 App 通过 NSRunningApplication.terminate 正常退出，新 App 已从稳定路径启动，确认 PID 94945，不传任何测试/隔离/样例参数。
- 版本 `1.0`、构建 `1`、配置 Release；部署元数据记录完整 commit `7124c4f2c918fc39eb52ae05209898654fa24c4e`，`CosmosBuildDirty=true`，如实表示基于该提交并包含本次未提交代码。沿用系统“关于”菜单和原生 About 面板，显示版本/构建/commit/源码状态；普通非部署构建没有元数据时标记未记录，不编造 commit。未递增产品版本或宣称本次源码已提交。
- 可复用命令（仓库根目录）：`/usr/bin/python3 scripts/deploy-macos.py`。脚本按自身位置定位仓库，使用 Path.home() 定位 Applications，不硬编码用户路径。固定现有 Xcode project/scheme、正式 Bundle，构建 Universal Release（arm64 x86_64），临时 DerivedData 与日志；检查两架构、正式身份及构建期间 HEAD/源码状态，注入元数据后本地 ad-hoc 签名并验证。
- 部署有独立 flock；先准备并校验安装暂存副本，再正常请求旧 App 退出。仅关闭安装目标或已知 CosmosOS-Daily 临时位置的正式 Bundle；其他位置同身份 App、身份未知、符号链接、并发部署或拒绝/超时退出均停止，不强杀。未保存内容可通过现有退出处理保留，脚本不绕过确认。
- 若目标已有同身份 App，移至 `~/Applications/Cosmos OS Rollbacks/Cosmos Toolbox-<时间>-<唯一标识>.app` 后，以 renamex_np/RENAME_EXCL 发布新 App，不覆盖中途出现的目标。发布失败且目标仍缺失时保留旧版本回退；目标出现时保留回退副本并停止。只清理本次唯一暂存 App，不删除旧回退版本。启动失败报告并保留安装/备份，不强杀或自动迁移数据。该位置只放 App 副本，不迁移业务文件。
- 本轮只完成必需的 **一次 Universal Release BUILD SUCCEEDED**、lipo 双架构确认、签名/身份/元数据及稳定路径进程确认；没有新增测试、历史验收或独立复审。工程文件自动序列化变化由脚本在 plutil 内容完全一致时还原，没有工程语义改动。diff check 通过。
- 构建/部署证据：`/private/tmp/CosmosOS-daily-deploy.log`；构建日志与 DerivedData 位于 `/var/folders/fh/13jx00z13ln1d46vx35pgljc0000gn/T/CosmosOS-ReleaseDeploy-62motejj/`。脚本未读写正式业务 Store、创建活动/样例、调用 AI 或恢复备份；正常启动沿用既有 App 行为，可能写入自身窗口偏好，不宣称全域 UserDefaults 零写入。
- 验收限制：未点击关于面板做排版验收；本次首次安装，已有旧版本更新/回退及真实未保存内容阻止退出分支未实机触发。未做签名公证或第三方分发，本机 ad-hoc 签名供当前用户日常使用；没有添加自动更新、安装器或后台常驻。既有阶段待办不扩大处理。
- 修改文件仅 **4 个**：Cosmos_ToolboxApp.swift、scripts/deploy-macos.py、本文件、当日 Development Log。安装 App、构建日志及临时证据不纳入仓库。
- **结论：用户接受本次声明验收范围，日常部署阶段关闭，无已知阻塞。** 授权按 `feat: 支持 Cosmos OS 本机日常部署` 正常提交推送，逐项仅纳入上述 4 文件，沿用已完成构建与启动证据、不追加验证。提交前 origin 为 `https://github.com/wangyucosmos/Cosmos-Toolbox.git`，HEAD 与实际远端 main 为预期 parent `7124c4f2c918fc39eb52ae05209898654fa24c4e`。实际 commit `f6a1e903914f4d5d37af14d3453180206ef336ad`，parent `7124c4f2c918fc39eb52ae05209898654fa24c4e`，恰好提交上述 4 文件；正常推送后 main/origin/main/实际远端一致、ahead/behind 0/0、工作区干净。随后直接实施已授权 Projects；全部暂缓事项及其他知识库保持不动。


## 30. 个人项目 Projects Phase 1 — 2026-10-10

### 流程与模型

- 依 PRD §5.8 / Philosophy / Workspace Vision，Projects 是非卓望个人长期项目，不复制 Campaign Workflow、不做多 Workspace 重构。原侧栏 projects 从占位页接到真实列表：新建、名称/说明搜索、手动三状态筛选、当前/归档切换、真实下一步及更新时间。默认无样例，不扫描或登记源码仓库，不接入 Dashboard/知识库/AI 工作台。
- UUID、名称、目标/说明、计划中/进行中/已完成、下一步、创建/更新时间、归档标记及内部修订号。进展按时间/原文追加；引用保留 UUID、名称、类型、路径/URL与登记时间。状态由用户设置，没有百分比、截止时间或推断完成。
- 查看/编辑为原生独立可关闭/缩放/最小化窗口。编辑目标/下一步/状态与归档标记，新增进展、用户选取文件或 http/https 链接，在保存中一并提交。未加入的链接输入阻止误保存；保存失败保留草稿。取消/关闭及 App 退出复用既有保存/放弃/取消保护，保存失败或进行中阻止关闭；同库/同 ID 窗口复用，旧修订不能覆盖较新数据。
- 文件只保存用户选取的路径，不复制/移动/删除实体。明确点击打开才交给 NSWorkspace，不扫描正文/抓取网页；失效/不可访问保留原引用并显示原因，链接打开失败也保留。已保存进展与引用只追加、不改写或删除，归档/恢复保留全部历史。本期没有永久删除或自动 AI 执行。

### 存储与保护

- 正式位置：`~/Library/Application Support/Cosmos OS/Projects/projects.json`；必要备份 `projects.backup.json`，协作锁 `.projects.lock`。独立 schemaVersion 1 项目文档，不写任何卓望或其他模块业务 Store。
- 模块内沿用 Learning 的受控读取/串行队列/flock/原子临时 rename/写前备份及读回模式，不抽象通用框架；读取缺库不创建目录/默认数据，snapshot 区分未建立与已建立空库。损坏/未知格式/缺主有备份/符号链接锁定写入，错误不伪装空列表、不清空恢复。
- 在最新磁盘载荷上核对项目 expectedRevision，再保存字段和追加历史；库字节变化也中止。保存失败不更新发布状态、保留输入；结果不确定时锁写，用户显式重新加载确认。每次备份保存原主文件字节；同一文档其他项目不会被旧窗口替换。协作锁不宣称排除非协作程序的最终检查后竞态。
- 原文含 CRLF、空白及 Unicode 按字节保留，不 trim/truncate；名称必填最多 200 字符，单段目标/下一步/进展正文最多 1 MiB，整库 16 MiB，超限拒绝。引用名称 200 字符、位置 16 KiB，仅 http/https（拒绝内嵌认证）；未知 schema 拒绝。
- DEBUG 隔离必须提供专属 UUID 根 `--cosmos-projects-fixture-root /private/tmp/CosmosProjectsPhase1-<UUID>`，同时满足现有隔离 Bundle/suite 约束；缺失即失败关闭，不回退正式位置。Release 只用正式位置。

### 备份与恢复兼容

- 当前导出 `CosmosCoreMetadata` **V2**：原 10 源加 `projects`，包内 `data/projects.json`，读取原文且校验 Projects 身份/结构/历史/引用字段。固定 11 源、最多 12 ZIP 条目；容量与防穿越/重复/符号链接/校验限制不变。Settings 说明项目文件引用实体不包含。
- 校验/恢复继续接受原 V1 的精确 10 源及原 exclusions；V2 必须精确包含 11 源清单，缺项不伪造。旧 V1 在结果/恢复预览明确说明“未包含 Projects”；Projects 不建立、不恢复空库。V2 主库不存在则 missing，真实空库仍 present。
- 恢复目标只用当前安装的 Projects 位置，与原三个 JSON 根一起受空环境检查；已存在项目主文件、备份或锁均拒绝恢复，坏/不可读状态不能绕过。事务允许第 11 源收据；原收据版本及旧 10 源事务仍可读取，配置禁用、原子防覆盖、持久化门控/中断保护不弱化。不搬迁或重写文件引用实体。

### 本轮证据与边界

- 一轮集中测试：新 Projects **12/12 通过**；因新增固定源，备份/恢复旧夹具计数及三文件数组尚未完整更新，首轮共有 15 项失败（含夹具越界）。一次集中修复仅补齐夹具/期望后，受影响 **15/15 通过**。最终有效覆盖 **38 项** = Projects 12 + 备份 12 + 恢复 14；未变化 23 项沿用首轮，未重跑整套。产品代码不因本次夹具修复变化，无第二次修复。
- 覆盖创建/编辑/新实例重载、原文字节与追加历史、筛选/三状态/归档恢复、失效引用与禁止非 http(s)、追加历史不可改写、两编辑 session/两个 storage wrapper 的旧修订保护、失败保留已有原字节及草稿、损坏/缺主有备份/符号链接锁写、关闭取消/保存失败及退出冻结、缺库/真实空库/只读零初始化、超限/重复身份/隔离失败关闭、详情离屏渲染。
- 覆盖 V2 项目备份→隔离空恢复→重载原文/历史/引用；V1 包校验、预览未包含警告与 Projects 目标不创建；已有空项目库/项目备份拒绝覆盖；既有防篡改/坏结构/源变化/事务中断/配置禁用等受影响保护通过。不创建/移动缺失实体，源主项目字节不变。
- 一次 **Universal Debug BUILD SUCCEEDED**，lipo 确认 x86_64 arm64，关闭签名、临时 DerivedData、隔离 Bundle。工程自动重排经 plutil 解析相等后恢复，无工程语义改动；diff check 通过。新 Projects 模块无编译 warning，既有 actor/Sendable 等 warning 不扩大修复。
- 一次后台隔离真实 App 的列表展示合成项目、状态、下一步、时间、筛选及新建/详情入口；仅截目标窗口，不激活/移动用户窗口。随机业务域原字节未变，projects.json 哈希未变，项目目录仅原主文件、无备份/锁；其他业务根和控制根未创建。已请求隔离窗口及残留测试宿主正常退出，随机 suite 已清理。
- 证据：`/private/tmp/CosmosProjects-Focused.xcresult` / focused.log；受影响修复 `/private/tmp/CosmosProjects-Fixed.xcresult` / fixed.log；Debug `/private/tmp/CosmosProjects-build.log`；窗口与 integrity.json `/private/tmp/CosmosProjectsUI-77bfa7b9-a498-4b8b-bf79-9b4e5a6d963c/`。
- 未覆盖真实新建/保存按钮、独立详情窗口关闭/退出提醒、文件选择/外部打开、完整重启交互；服务及 session 重载/保护由自动化覆盖，不宣称完整端到端 UI 验收。旧 V1 兼容用合成的严格 V1 包覆盖，未读取用户备份；未测容量上限性能或真实跨进程非协作写入。引用为路径而非安全书签，文件移动后需用户另行登记，不自动修复。
- 修改 **19 文件**：新增 ProjectsModels.swift、ProjectsFileStorage.swift、ProjectsStore.swift、ProjectsView.swift、ProjectsEditor.swift、ProjectsTests.swift；修改 DashboardView.swift、PromptTemplateEditor.swift、CoreBackupModels.swift、CoreBackupSource.swift、CoreBackupService.swift、CoreBackupArchive.swift、CoreBackupSettingsView.swift、CoreRestoreTarget.swift、CoreRestoreService.swift、CoreBackupTests.swift、CoreRestoreTests.swift、本文件及当日日志。部署脚本保持既有成果，不纳入新阶段修改。
- 按授权复用既有部署脚本完成一次必要 **Universal Release BUILD SUCCEEDED**、双架构/签名/正式 Bundle 校验；旧日常 App 正常退出，新版本从 `~/Applications/Cosmos Toolbox.app` 启动（PID 98251），无测试参数或样例。版本 1.0（构建 1），commit `f6a1e903914f4d5d37af14d3453180206ef336ad`、dirty=true，如实显示本次未提交的 Projects 改动。
- 实际旧版回退副本：`~/Applications/Cosmos OS Rollbacks/Cosmos Toolbox-20261010-154702-5e6f9985.app`。未执行回退，没有强杀或业务操作；正式启动沿用既有行为，可能写窗口偏好，不宣称正式数据全域写入审计。部署日志 `/private/tmp/CosmosProjects-deploy.log`，Release 构建证据 `/var/folders/fh/13jx00z13ln1d46vx35pgljc0000gn/T/CosmosOS-ReleaseDeploy-5qsm4yu0/`；部署脚本未修改。
- **结论：用户已接受上述声明验收范围，阶段正式关闭，无已知阻塞。** 本次授权逐项提交 19 文件并正常推送，提交消息为 `feat: 新增个人项目 Projects Phase 1`。沿用已接受证据，不追加修复、测试、构建、UI 验收或部署；提交前 HEAD 与实际远端 main 均为 `f6a1e903914f4d5d37af14d3453180206ef336ad`，实际 Git 结果以收尾报告为准。所有暂缓事项保持不动，不写其他知识库，不自动开发下一模块。
