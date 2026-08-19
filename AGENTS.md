# AGENTS.md — Cosmos OS Codex Development Rules

## 0. Purpose

This file is the durable operating guide for Codex when developing Cosmos OS.

Cosmos OS is a long-lived native macOS personal work operating system.  
The project is not a throwaway demo. Changes must optimize for maintainability, recoverability, real daily use, and long-term evolution.

Working relationship:

- **User**: Product owner and final decision maker.
- **ChatGPT web**: Product architecture advisor / technical solution designer.
- **Codex on the Mac**: Local development engineer responsible for reading the repository, modifying code, building, testing, reviewing diffs, and preparing commits.

Codex should absorb implementation complexity so the user does not need to manually locate fields, copy code fragments, or repeatedly replace the same file.

---

# 1. Mandatory source-of-truth documents

Before any architecture-level task, read these repository documents:

1. `Docs/01_Cosmos_OS_PRD.md`
2. `Docs/02_Cosmos_OS_UI_Design.md`
3. `Docs/03_Cosmos_OS_Architecture.md`
4. `Docs/04_Cosmos_OS_Roadmap.md`
5. `Docs/05_Cosmos_OS_Philosophy.md`
6. `Docs/06_Cosmos_OS_Workspace_Vision.md`
7. `Docs/07_Cosmos_OS_Current_Status.md` if it exists

Also read the most recent relevant file under:

`Docs/Development Log/`

If implementation conflicts with these documents:

- Do not silently override the product direction.
- Identify the conflict.
- Prefer the latest explicit user decision.
- Update the relevant documentation intentionally when product direction legitimately changes.

---

# 2. Core product principles

Always preserve these principles.

## 2.1 Build once. Improve forever.

Prefer durable solutions over temporary demo code.

## 2.2 Software should remember.

Important user work must survive:

- app restart;
- Mac restart;
- model changes;
- schema changes;
- reasonable app upgrades.

Data loss is a P0 issue.

## 2.3 Workflows over features.

Do not build isolated buttons when the real need is an end-to-end workflow.

## 2.4 AI should disappear into the workflow.

AI is part of the business process, not a separate novelty chat box.

## 2.5 Local first.

Prefer:

- local files;
- user-owned workspace directories;
- user-owned GitHub;
- recoverable metadata.

Do not introduce cloud infrastructure without a concrete need.

## 2.6 Personal before universal.

Optimize first for the actual user's real workflow.

Do not prematurely generalize Cosmos OS into a universal multi-company platform.

## 2.7 Product before demo.

A feature is not complete merely because it compiles.

Ask:

- Can it be used?
- Can it be recovered?
- Can it be maintained?
- Can it be upgraded?
- Does it preserve existing user data?

---

# 3. Workspace architecture boundary

Cosmos OS belongs to the user, not to 卓望.

卓望 is the first real Company Workspace.

Long-term conceptual structure:

```text
Cosmos OS
└── Workspaces
    ├── Organization / Company
    ├── Projects
    ├── Workflows
    ├── Artifacts
    ├── Knowledge
    ├── Templates
    └── AI Connections
```

However:

**Do not refactor the current codebase into a universal multi-Workspace framework yet.**

First mature the real 卓望 workflow.  
Abstract common system-level concepts only after repeated real use proves they are generic.

---

# 4. Current Zhuowang workflow baseline

The standard activity workflow currently contains six steps:

```text
01 需求整理 / Brief
02 策划思路 / Campaign Idea
03 完整策划案 / Campaign Plan
04 页面结构 / Page Structure
05 产品原型设计 / Product Prototype
06 客服文档 / Customer Service FAQ
```

Important behavior:

- Every Workflow Step may independently choose an AI Provider.
- The next step may default to the previous provider, but the user must remain able to change it.
- AI outputs are reviewed by the user.
- Adopting a result creates / updates:
  - AI Run
  - Approval
  - Artifact
  - local file
  - step status
  - next-step availability
- Later steps should consume the **currently adopted upstream Artifact versions**, not every historical version.

---

# 5. AI Provider and Tool are separate concepts

This boundary is mandatory.

## AI Provider / Agent

Responsible for reasoning, generation, analysis, coding, or task execution logic.

Examples:

- OpenAI / ChatGPT
- Codex
- Claude
- DeepSeek Harness
- future AI providers

## Tool / External Tool / Adapter

Responsible for producing or manipulating external deliverables.

Examples:

- Figma
- Pixso
- HTML Prototype
- Browser
- GitHub
- future prototype or production tools

Never reintroduce Figma as an AI Provider.

Correct conceptual composition:

```text
Workflow Step
    ↓
AI Provider
    +
Tool / Adapter
    ↓
Artifact
```

Example:

```text
产品原型设计
AI: Codex
Tool: Figma
```

or:

```text
产品原型设计
AI: Claude
Tool: HTML Prototype
```

or:

```text
产品原型设计
AI: DeepSeek Harness
Tool: Pixso
```

---

# 6. Prototype design must not be bound to Figma

The Prototype step represents a capability:

`prototypeDesign`

It must remain tool-agnostic.

Possible implementations include:

- Figma;
- Pixso;
- HTML / Web prototype;
- React / web implementation;
- another future prototype tool.

Do not rename or redesign the workflow so that Figma becomes mandatory.

---

# 7. Artifact rules

Artifacts are first-class user work assets.

Current concepts include:

- Markdown
- Word
- PDF
- Excel
- Image
- Figma
- HTML
- Flowchart
- Prompt
- URL
- Other

Rules:

1. Preserve historical versions.
2. Do not delete old versions merely because a new result is generated.
3. Exactly one version may be considered the currently adopted version for a logical Artifact.
4. The user may switch the adopted version later.
5. A new AI or a new tool may generate a new version of the same logical Artifact.
6. Keep provenance when available:
   - workflow step;
   - AI run;
   - provider;
   - tool;
   - version;
   - file path / URL;
   - timestamps.
7. Prefer real local files for important work outputs.
8. Metadata should be reconstructable from local files where reasonably possible.

---

# 8. Data safety and persistence rules

This is a high-priority area.

Current code may still use UserDefaults for some business data, but long-term architecture calls for structured business data to move toward a more appropriate persistence layer such as SwiftData.

Until a planned migration occurs:

- Maintain backward-compatible decoding.
- Newly added Codable fields must not make old saved data undecodable.
- Never replace undecodable existing workflow data with a newly created empty workflow.
- Preserve backups before destructive metadata migrations.
- Local Artifact files are a recovery source.
- Recovery logic must be idempotent.
- Never delete user files during metadata recovery.
- Never reset UserDefaults, databases, or workspace directories as a shortcut to fix a bug.

Any change that can cause loss of:

- Campaigns;
- Workflow progress;
- AI Runs;
- Approvals;
- Artifacts;
- adopted-version choices;

must be treated as high risk.

---

# 9. Local workspace rules

Current real working files are stored under a user-owned workspace such as:

```text
~/Documents/Cosmos OS/Workspaces/卓望/<省份>/<活动>/
```

Current six-step directory concept:

```text
01_需求整理
02_策划思路
03_完整策划案
04_页面结构
05_产品原型 / 兼容历史原型目录
06_客服文档
Assets
```

Existing historical folder names must remain readable.

Do not rename or move the user's existing files automatically unless the user explicitly approves a migration.

---

# 10. Native macOS window rules

Cosmos OS is a native macOS application.

Meaningful business detail surfaces should use independent native macOS windows when appropriate.

Examples:

- Campaign Detail
- Artifact Detail
- Project Detail
- Knowledge Detail
- substantial document/detail views

These windows should generally support native:

- close;
- minimize;
- resize;
- drag/move.

Use Sheet / Dialog only for genuinely transient interactions such as:

- delete confirmation;
- small choices;
- short edits;
- lightweight forms.

Do not turn substantial business detail views back into modal sheets without a product reason.

---

# 11. UI design rules

The UI direction is:

- native;
- restrained;
- clear;
- durable;
- spacious;
- functional.

Prefer:

- SwiftUI;
- SF Symbols;
- semantic system colors;
- macOS materials;
- system typography;
- natural Light / Dark Mode support.

Avoid:

- cyberpunk styling;
- neon gradients;
- excessive cards;
- decorative visual noise;
- unnecessary animations;
- fake "AI futuristic" aesthetics.

Current development priority is functionality and architecture first.

Do not spend significant time on global visual polish until the core information architecture and workflow are stable.

---

# 12. Architecture rules

Primary stack:

- Swift
- SwiftUI
- macOS
- Apple frameworks first

Architecture direction:

**Feature-based Modular Architecture**

Do not introduce a heavyweight architecture merely for theoretical purity.

System operations should be encapsulated in services / adapters rather than scattered through Views.

Do not put shell execution directly inside large SwiftUI Views when it belongs in a Service / Adapter.

Avoid unnecessary third-party dependencies.

---

# 13. How Codex should approach implementation work

For any non-trivial task, do not modify the first obvious file immediately.

First inspect the full dependency chain.

At minimum consider:

```text
Model
↓
Persistence / Store
↓
Service / Adapter
↓
Workflow / Business logic
↓
View
↓
Artifact / Files
↓
Migration / Recovery
↓
Tests / Build
```

Think at least several steps ahead.

The user explicitly does **not** want this pattern:

```text
change one thing
↓
compile
↓
discover obvious next dependency
↓
change the same file again
↓
repeat
```

Prefer:

```text
understand the complete change
↓
identify affected files
↓
implement the coherent solution
↓
build
↓
fix all related compile/runtime issues
↓
review diff
↓
report once
```

Temporary UI or throwaway validation code should only be added if it has lasting diagnostic value.

---

# 14. User interaction rule

The user is the product owner, not the code operator.

Do not ask the user to:

- search for struct definitions;
- locate individual fields;
- manually insert code at several positions;
- copy multiple code fragments;
- fix braces;
- repeatedly replace the same file for predictable dependent changes.

Codex should inspect the repository itself.

If user action is genuinely necessary:

- ask for the smallest possible action;
- explain exactly why;
- prefer one concise step.

---

# 15. Build and verification requirements

After meaningful Swift changes:

1. Identify the correct Xcode project / workspace and scheme from the repository.
2. Build using the existing project configuration.
3. Prefer `xcodebuild` or the project's established build workflow.
4. If tests exist for affected behavior, run them.
5. Fix compilation errors before reporting completion.
6. Review `git diff` before reporting completion.

Do not claim success merely because code was written.

Expected final engineering report:

```text
Build: SUCCEEDED / FAILED
Tests: ...
Files changed: ...
Behavior verified: ...
Remaining risk: ...
```

For user-facing workflow changes, mention what still needs manual UI validation.

---

# 16. Git safety rules

Before work:

1. Inspect `git status`.
2. Do not discard user changes.
3. Do not run destructive reset commands unless explicitly authorized.
4. If the working tree is clean and remote sync is appropriate, `git pull --ff-only` may be used.
5. If the working tree is dirty, do not silently pull/reset over it.

Never use destructive commands such as:

```text
git reset --hard
git clean -fd
rm -rf
```

as routine problem-solving shortcuts.

---

# 17. Commit convention

Use:

```text
feat: 中文描述
fix: 中文描述
docs: 中文描述
refactor: 中文描述
chore: 中文描述
test: 中文描述
```

Examples:

```text
feat: 新增 Workflow Tool Adapter 执行链路
fix: 修复旧 Workflow 数据升级后无法恢复
docs: 更新 Cosmos OS 当前开发状态
refactor: 解耦 AI Provider 与原型工具
```

Do not use vague messages such as:

```text
update
fix bug
changes
```

Do not automatically push unless the user explicitly requests push or says to complete GitHub synchronization.

---

# 18. Daily progress synchronization protocol

The repository is the shared bridge between Codex and ChatGPT web.

Maintain two documentation layers.

## 18.1 Current state — single mutable file

File:

`Docs/07_Cosmos_OS_Current_Status.md`

This is the **current project checkpoint**.

Update it after every meaningful completed development task.

It should answer:

- What is working now?
- What has been verified?
- What is the current architecture?
- What is the current Workflow progress?
- What known issues remain?
- What is the single next priority?
- What product decisions are still pending?

Do not turn it into a chronological diary.

Keep it current.

## 18.2 Development logs — append-only history

Directory:

`Docs/Development Log/`

At the end of a meaningful development session, create or update:

```text
YYYY-MM-DD_Cosmos_OS_Development_Log.md
```

It should record:

- goals for the session;
- files changed;
- architecture decisions;
- bugs found;
- fixes;
- build/test result;
- Git commit(s);
- unresolved issues;
- next recommended task.

Development logs are historical records.

Do not rewrite older logs to match the latest state.

---

# 19. End-of-session procedure

When the user says things like:

- "今天先到这里"
- "收尾"
- "同步进度"
- "准备推送"
- "结束今天开发"

Codex should:

1. Run final build / relevant tests.
2. Review `git diff`.
3. Update `Docs/07_Cosmos_OS_Current_Status.md`.
4. Update or create today's Development Log.
5. Show a concise summary to the user.
6. Propose a commit message using the repository convention.
7. Commit only if the user requested it or the task explicitly includes committing.
8. Push only if the user explicitly requested GitHub synchronization.

---

# 20. ChatGPT web handoff

The intended cross-product workflow is:

```text
ChatGPT web
Product architecture / technical solution
        ↓
GitHub repository docs
        ↓
Codex
Local engineering / build / testing
        ↓
Update Current Status + Development Log
        ↓
Commit / Push
        ↓
ChatGPT web reads GitHub
        ↓
Next architecture decision
```

Therefore documentation updates are part of engineering completion, not optional cleanup.

When preparing a handoff to ChatGPT web, make sure `Docs/07_Cosmos_OS_Current_Status.md` is accurate enough that another session can understand the project without reading the entire chat history.

---

# 21. Current development focus

Read `Docs/07_Cosmos_OS_Current_Status.md` for the latest checkpoint.

At the time this collaboration model was established, the active direction was:

- stabilize Zhuowang Workspace;
- preserve Workflow / Artifact data;
- maintain local-file disaster recovery;
- keep AI Providers separate from Tools;
- continue Product Prototype workflow;
- build Adapter Registry / execution orchestration only after the persistence boundary is stable;
- avoid premature global UI polish.

If Current Status contains a newer priority, follow Current Status.

---

# 22. Definition of done

A meaningful task is done only when:

- implementation is coherent across affected layers;
- project builds;
- relevant behavior is verified as far as available tooling permits;
- existing user data is protected;
- no known obvious dependency is left intentionally broken;
- documentation is updated when architecture or project state changed;
- user receives a concise report;
- Git state is understandable.

Cosmos OS is a long-term product.

Optimize for fewer regressions, fewer manual steps, and stronger continuity between sessions.
