# Cosmos OS Current Status

**Last updated:** 2026-10-09
**Project:** Cosmos OS / Cosmos-Toolbox  
**Current stage:** Dashboard 真实数据整合 Phase 1 is **closed** on 2026-10-09: the product owner accepted the existing verification scope and authorized one `feat: 首页接入真实工作与学习数据` commit and normal push to origin/main (exact Git delivery is verified from repository refs after push; see §21). Implementation baseline `68f080fe72f69ba037b897a2a3962d9db9d87b1c`. The Home now summarizes real data from the finished modules and no longer shows fabricated tasks, projects or health numbers.

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

**Current:** Dashboard 真实数据整合 Phase 1 is closed (§21). The next module is to be determined by product coordination and must not start automatically. **Previous:** 全国月度会员促活 Phase 1 is closed (§20). The next stage is to be determined by product coordination and must not start automatically. **Previous:** 省份可维护配置 Phase 1 is closed (§19); it fulfils the previously recorded candidate (provinces maintainable, history preserved, every province reuses the standard Workflow, no hard-coded roster). The next candidate is a read-only **investigation of the national monthly member-activation (全国月度会员促活) integration**; it awaits a coordination instruction and must not start automatically. **Previous:** 学习中心 Phase 1 is closed (§18). The next module awaits product coordination and must not start automatically. Follow-up product requirement recorded as a later candidate task, not started: provinces must be maintainable, historical data must be preserved, and every province reuses the standard Workflow; no responsible-person roster is hard-coded. **Previous:** Prompt Vault Phase 1 is closed. The next major module awaits product coordination and must not start automatically. Non-blocking todos (parser warning position text, conservative save lock after pre-rename write failure, list refresh after re-entering the module with an editor open, new-draft favorite dirty check, and the declared UI / concurrency / filesystem-race coverage gaps) are recorded in §17 and are not being handled now. Word WIP stays local and paused.

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
