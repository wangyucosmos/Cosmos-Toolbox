# Cosmos OS Current Status

**Last updated:** 2026-08-19  
**Project:** Cosmos OS / Cosmos-Toolbox  
**Current stage:** Zhuowang Workspace + AI Workflow stabilization

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
05 产品原型设计   可开始
06 客服文档       未开始
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

Implemented / compiling:

- `ZhuowangToolAdapter.swift`
- `ZhuowangHTMLPrototypeAdapter.swift`

The Tool Adapter abstraction exists to prevent Workflow logic from being tied to one concrete product.

The HTML Prototype Adapter is the first simple adapter used to validate the abstraction.

Current limitation:

- it is a compiling placeholder implementation;
- it is not connected to Workflow UI execution orchestration;
- it does not yet complete human review, adoption, local HTML persistence, or disaster recovery.

Do not assume HTML is the final prototype path.

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

- Adapter Registry / execution orchestration is not yet fully complete.
- Figma real automated execution is not yet implemented.
- Claude Desktop direct execution is not yet implemented.
- ChatGPT direct execution path is not yet implemented.
- Codex execution path from inside Cosmos OS is not yet fully implemented.
- The project still has no automated Test Target; persistence regression coverage remains technical debt.

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

The next engineering priority should be chosen after Codex reads the current codebase and verifies that the persistence / recovery fixes are present in the local repository.

The P0 persistence baseline for Workflow and AI/tool configuration is now healthy enough to continue, with the remaining risks recorded above.

### Next mainline

**Continue Workflow Step 05 — Product Prototype**

Target:

```text
AI Provider
+
Tool selection
+
Task Package
+
Adapter Registry / execution orchestration
+
Artifact version
+
human review
```

First prove the generic execution path without binding the architecture to Figma.

Then integrate real Figma automation as one Tool implementation.

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
- Full macOS Debug build completed with `BUILD SUCCEEDED` on 2026-08-19.
- No automated tests were added because the project has no Test Target; this remains explicit technical debt.
