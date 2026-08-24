# Cosmos OS Current Status

**Last updated:** 2026-08-24
**Project:** Cosmos OS / Cosmos-Toolbox  
**Current stage:** Step 05 prototype workflow milestone complete; Artifact Preview Abstraction Layer Phase 1 implemented

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

Renderer selection now starts from typed Preview Input rather than only `ZhuowangArtifactType`. Media classification considers payload kind first, then UTType identifier, MIME type, file extension, and the legacy type hint; conflicting evidence fails closed. Renderer capabilities drive whether Source, Full Preview, and 375px / 390px controls appear, so unrelated renderers are no longer forced to receive a mobile viewport. Phase 1 still registers only the HTML Renderer and the safe fallback; no Image, PDF, Figma, Pixso, or external-document Renderer has been added.

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
- Campaign Store and Workspace Store do not yet have the same backup / write-lock boundary.

### P1

- The first HTML Adapter Registry / execution orchestration path is complete; other Tool Adapters remain future work.
- Browser / desktop-width preview is not implemented; Phase 1 currently focuses on 375px / 390px mobile HTML review.
- Artifact Version Compare Phase 1 provides managed-version side-by-side review. Text / semantic Diff and difference highlighting are not implemented.
- Review annotations, anchored comments, approval notes, and markup are not implemented.
- Figma, Pixso, Image, and PDF Preview Renderers are not registered yet; the typed Review boundary is ready, but unsupported or unavailable inputs still use the safe fallback.
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
- typed Review Payload / Preview Input projection with controlled local-text resolution, safe binary / missing / conflicting fallback, and Renderer capability-driven controls without persistent schema changes.

Recommended next-session order:

1. Choose the first binary Renderer Phase; Image Renderer is the recommended smallest next step because it validates typed local-file input, decoding limits, fit/original-size behavior, and Source absence without adding PDF navigation or external authentication complexity.
2. If the HTML Preview compatibility allowlist changes, threat-model inline script and `data:` / `blob:` behavior before implementation.
3. Keep persistent Artifact payload descriptors, Sidecar Manifest, Figma / Pixso execution and external-document adoption deferred until a real write path requires them.

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
- `git diff --check` completed successfully.
- Runtime validation of V2 append behavior remains a future follow-up; pure-logic unit coverage already verifies that V2 append does not overwrite V1.
