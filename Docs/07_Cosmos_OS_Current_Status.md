# Cosmos OS Current Status

**Last updated:** 2026-09-19
**Project:** Cosmos OS / Cosmos-Toolbox  
**Current stage:** Campaign / Workspace Store persistence protection Phase 1 implemented, reviewed, tested and accepted through the formal Campaign UI in an isolated environment (2026-09-20); temporary acceptance data cleaned under explicit authorisation; not yet committed or pushed

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
06 客服文档       可开始
```

Important version state:

- 完整策划案 has multiple historical versions.
- Current adopted version is **V1**.
- 产品原型 current adopted version is **V3**.
- Artifact Detail currently manages prototype **V1 / V3 / V4**; the local V2 file remains intentionally unmanaged and must not be imported, deleted, or modified.
- Do not overwrite this choice unless the user explicitly changes it.

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

Renderer selection now starts from typed Preview Input rather than only `ZhuowangArtifactType`. Media classification considers payload kind first, then UTType identifier, MIME type, file extension, and the legacy type hint; conflicting evidence fails closed. Renderer capabilities drive whether Source, Full Preview, and 375px / 390px controls appear, so unrelated renderers are no longer forced to receive a mobile viewport. The Registry currently contains HTML, Image, and PDF Renderers plus the safe fallback; Figma, Pixso, external URL, and other external-document Renderers remain deferred.

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
- A minimal XCTest target now covers Step 05 high-value pure logic; broader persistence and UI regression coverage remains technical debt.
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

The current Step 05 milestone is complete:

```text
prototypeDesign Capability
+ Prototype Execution Profile
+ selected Provider / Connection / Tool / Route
→ immutable execution snapshot
→ DeepSeek Harness Runtime Compatibility Layer
→ HTML execution specification + normalization + validation
→ Artifact Draft
→ unified Artifact Review Workspace
→ human adoption
→ versioned .html Artifact
→ adopted Artifact Detail reopens the same Review Workspace
```

Completed milestone capabilities:

- Step 05 real HTML Prototype generation, validation, adoption, persistence, approval, and Step 06 unlock;
- tool-independent Low-fi / Mid-fi / High-fi fidelity and style controls frozen into execution provenance;
- type-independent Artifact Review Workspace with Phase 1 HTML Renderer, Source mode, Full Preview, and 375px / 390px real WebView mobile frames;
- unified Draft and adopted / historical Artifact Review Workspace entry;
- Renderer-owned HTML Preview CSP plus WebKit content rules, non-persistent storage, and navigation policy without modifying source Artifacts.
- independent managed-version Compare Workspace with stable logical-Artifact window identity, UUID-based left / right selection, shared Review Pane / Renderer Registry, independent Preview / Source and scrolling, and shared 375px / 390px viewport.
- typed Review Payload / Preview Input projection with controlled local-text resolution, safe binary / missing / conflicting fallback, and Renderer capability-driven controls without persistent schema changes;
- local static PNG / JPEG Image Renderer with ImageIO validation, bounded asynchronous decoding, file consistency checks, Renderer-local zoom, Full Preview, and mixed-type Version Compare.
- local PDF Renderer with exact media classification, bounded Data loading, fail-closed action inspection, secure PDFView delegation, continuous reading and navigation controls, explicit binding teardown, Full Preview, and independent PDF / mixed-type Compare panes.

Recommended next-session order:

1. Commit and push Phase 1 after explicit user authorisation (the working tree is the accepted state: 8 modified files + 7 new source / test / log files; no build by-products).
2. Keep Step 06 implementation paused until this persistence boundary is accepted and the next milestone scope is approved.
3. Treat cross-process transactions, automatic recovery, backup rotation, and persistence-format migration as separate future milestones.
4. Keep persistent Artifact payload descriptors, Image / PDF Adoption, Sidecar Manifest, Figma / Pixso execution, external-document adoption, and PDF process isolation deferred until their write paths receive separate review.

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
- `git diff --check` completed successfully.
- Runtime validation of V2 append behavior remains a future follow-up; pure-logic unit coverage already verifies that V2 append does not overwrite V1.
