# Cosmos OS Current Status

**Last updated:** 2026-08-21
**Project:** Cosmos OS / Cosmos-Toolbox  
**Current stage:** Step 05 prototype workflow milestone complete; Artifact Review foundation established

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
- Artifact Review Workspace opens AI Drafts and adopted V1 / V2 / V3 Artifacts in the same independent resizable macOS window
- type-agnostic Artifact Preview Renderer Registry with safe unsupported-type fallback
- Phase 1 HTML Renderer uses a real interactive WKWebView inside selectable 375px / 390px mobile device frames
- Artifact Review Preview / Source modes and focused Full Preview mode preserve the original Artifact content
- Review metadata is captured from Draft + immutable execution snapshot / Artifact provenance rather than current Workflow selections

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

HTML validation rejects empty, structurally incomplete, non-UTF-8, and Placeholder results. The review WebView uses a non-persistent data store, an injected restrictive CSP, and blocks external top-level navigation.

The Prototype step now keeps only the tool-agnostic business goal. The frozen capability + Tool + Route resolve the concrete execution specification. For the current DeepSeek Harness → HTML Prototype Route, both the final prompt and Preview Expected Outputs require a complete runnable single-file HTML result; the obsolete “prepare an execution brief and wait for confirmation” wording has been removed.

Prototype fidelity and style are represented by a tool-independent `ZhuowangPrototypeExecutionProfile`. Missing historical data defaults to High-fi + 高保真活动页 to preserve the previously accepted behavior. The Profile is persisted on capability-bearing Workflow Steps, frozen into each execution snapshot, shown in Task Package Preview, and translated by the selected Tool / Route specification. It does not alter the Artifact logical key, so Low-fi / Mid-fi / High-fi runs remain versions of the same logical prototype.

Do not assume HTML is the final prototype path.

Artifact review is now separated from execution and adoption:

```text
Artifact Draft / historical Artifact
→ ArtifactReviewDocument (immutable review provenance)
→ ArtifactPreviewRendererRegistry
→ registered Renderer or safe fallback
→ ArtifactReviewWorkspace
```

Phase 1 registers only the HTML Renderer. The Workspace shell does not switch on HTML and can accept future Figma, Pixso, Image, and PDF renderers without changing Workflow, Artifact versioning, or adoption logic. HTML is displayed unchanged in a non-persistent real WKWebView; 375px / 390px device widths are layout constraints, not screenshot scaling or HTML rewriting.

The adopted Artifact Detail entry now defaults to a Preview Workspace action instead of rendering HTML source as its primary body. Users can still explicitly select source view, and switching among V1 / V2 / V3 resets the entry to Preview. Both Draft and adopted Artifact entries construct an `ArtifactReviewDocument` and open the same `ArtifactReviewWindowManager`; unsupported types retain the Registry fallback, and historical Artifacts without provenance remain safe.

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
- Artifact version comparison is not implemented; V1 / V2 / V3 can be opened independently but cannot yet be compared side by side or diffed.
- Review annotations, anchored comments, approval notes, and markup are not implemented.
- Figma, Pixso, Image, and PDF Preview Renderers are not registered yet; unsupported types use the safe fallback.
- The current Artifact model and adoption / recovery paths remain partly HTML-first. A broader Artifact Abstraction Layer should be designed before real Figma / Pixso adoption is added, without disturbing the accepted HTML path prematurely.
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
- unified Draft and adopted V1 / V2 / V3 Review Workspace entry.

Recommended next-session order:

1. Perform the pending live UI acceptance for Fidelity controls and adopted Artifact Detail version switching.
2. Decide whether the next Review priority is Browser Preview, Version Compare, or Annotation.
3. Before implementing Figma / Pixso execution and adoption, define the required Artifact Abstraction Layer boundary and add the corresponding Renderer through the existing Registry.

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
- `git diff --check` completed successfully.
- Runtime validation of V2 append behavior remains a future follow-up; pure-logic unit coverage already verifies that V2 append does not overwrite V1.
