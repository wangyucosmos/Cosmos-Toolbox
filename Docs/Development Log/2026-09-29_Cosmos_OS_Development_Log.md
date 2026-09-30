# 2026-09-29 Cosmos OS Development Log

## 1. Session goal and boundary

Implement **Campaign 工作产物交付包 Phase 1** as an independent feature after the six-step Workflow. It is not Step 07 and does not change Workflow, Run, Approval, Artifact, adoption state, persistence models, Renderer, or the Step 05/06 execution paths.

Phase 1 exports a user-selected set of the current Campaign's uniquely adopted, real local Workspace files into a local ZIP with `交付清单.md` and `manifest.json`. Cloud upload/sharing, AI regeneration, historical-version selection, unmanaged-file import, binary adoption/recovery, format conversion, HTML dependency collection, and persistent export history remain out of scope.

Start gate:

- repository: `/Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox`;
- branch: `main`;
- clean starting HEAD and `origin/main`: `0f1c54e320423553ffb380b28f136aa56084fbef`;
- `AGENTS.md` and the required repository context were read before implementation;
- no Step 06 Harness operation was run, no Artifact was generated or adopted, and the preserved incident Evidence/Quarantine files were not read, moved, cleaned, or included;
- no commit, push, branch, tag, stash, or PR was created.

## 2. Implementation

### 2.1 Selection and eligibility

- Campaign Detail's 工作产物 section now opens a dedicated export sheet.
- The sheet shows Workflow step, Artifact name, adopted version, file name, and eligibility status.
- No item is selected by default; the user may select individual eligible groups or all eligible groups.
- Eligibility uses the existing Artifact logical version-group key but does not reuse the list UI's latest-version fallback. Exactly one `isApprovedVersion == true` is required; zero or multiple adopted versions disables the group with a reason.
- Only current-Campaign, absolute-path, readable regular files inside the canonical Campaign Workspace are eligible. URL/Figma references, missing locations/files, relative paths, directories, symbolic links at any checked path component, and Workspace-external files are rejected.

### 2.2 Transactional ZIP service

- The export service is separated from SwiftUI and receives an injectable live-snapshot provider for testability.
- At export time it re-reads the Store snapshot and revalidates each selected logical group before any package publication.
- The request preserves both the selected logical-group key and the selected Artifact ID. If adoption moves to a different version before save, export is rejected instead of silently substituting the new version.
- Selected files are copied to safe package-relative paths under `Files/<step>/<Artifact UUID>/<file>`; unsafe `.`/`..`, absolute, backslash, and traversal paths are rejected.
- Source files are SHA-256 hashed before and after copy; staged copies must match. The generated ZIP is independently extracted and its complete regular-file entry set, safe canonical paths, file byte counts/hashes, and exact manifest/checklist bytes are verified.
- `manifest.json` and `交付清单.md` contain Campaign, export time, step, name, Artifact ID, logical key, version, package-relative path, byte count, and SHA-256. They contain no absolute source path.
- Packaging occurs in a hidden sibling transaction directory. An existing destination is rejected and never overwritten; the final ZIP appears only after full verification. Failure removes temporary package data and does not leave a final ZIP.
- Successful export is shown in the sheet and can be revealed in Finder.

### 2.3 Bug found during isolated verification

The first real-ZIP test exposed a macOS canonical-path mismatch: a temporary root created as `/var/...` was enumerated as `/private/var/...`, so raw string-length subtraction produced an invalid `ication/...` relative path. Verification now canonicalizes both root and extracted entries, checks containment, and only then derives and Unicode-normalizes the archive-relative path.

## 3. Files changed

Added:

- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangArtifactDeliveryPackageModels.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangArtifactDeliveryPackageService.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangArtifactDeliveryPackageView.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangArtifactDeliveryPackageTests.swift`
- `Docs/Development Log/2026-09-29_Cosmos_OS_Development_Log.md`

Modified:

- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignDetailView.swift`
- `Docs/07_Cosmos_OS_Current_Status.md`

The synchronized Xcode source/test groups discovered the new Swift files; `project.pbxproj` was not changed.

## 4. Automated verification

- Focused delivery-package XCTest: **11 passed, 0 failed, 0 skipped**.
- Related delivery-package, Step 05, Step 06, Artifact Review, and Artifact Version Compare suites: **95 passed, 0 failed, 0 skipped**.
- Tests used isolated temporary Workspace/data roots, temporary Bundle IDs, and `/tmp` DerivedData. The real-ZIP fixture created and independently extracted an archive and verified its selected files, manifests, package-relative paths, byte counts, and SHA-256 values.
- Universal macOS Debug build: **BUILD SUCCEEDED** for `arm64 x86_64` with `CODE_SIGNING_ALLOWED=NO`.
- `git diff --check`: passed after implementation.
- No formal App, real Harness execution, AI generation, adoption, or formal Workspace export was used for automated verification.

## 5. Pending review and manual UI acceptance

The implementation remains uncommitted and unpushed for independent Claude review. Review should focus on:

- source-path canonical containment and symbolic-link race assumptions;
- destination collision/TOCTOU handling around the final non-overwriting move;
- exact ZIP entry verification and Unicode-normalized relative paths;
- live Store revalidation after the user makes a selection;
- synchronous hashing/copying/ZIP verification on the sheet action for large delivery sets.

Real UI acceptance is still pending. It must verify default-empty selection, disabled reasons, individual/all-eligible selection, Save Panel cancellation, successful ZIP content/manifest inspection, Finder reveal, existing-target refusal, readable error feedback, and unchanged Workflow/Run/Approval/Artifact/adoption state. This document does not claim those UI checks have passed.
