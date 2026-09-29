# 2026-09-24 Cosmos OS Development Log

## Goal and incident

The first formal Step 06 live UI pass reached DeepSeek generation, Draft display, adopted Prototype V3 upstream context and readable Artifact Review Workspace. The user had not adopted the result, yet Harness wrote two byte-identical Markdown files: one in the formal Campaign `06_客服文档` directory and one in the ignored knowledge-base mirror. Both remain preserved as evidence. Step 06 stayed `ready` with no Run, Approval or Artifact. The formal Workflow primary differed from its prior backup only in Workflow and Step 06 `updatedAt` after Provider selection.

Root causes:

1. The Step 06 raw-task execution path exposed a suggested save location and upstream absolute file paths. DeepSeek Harness inherited the real home environment and had no child-process file-write restriction.
2. Revision/regeneration used the same unrestricted Harness path.
3. The Step 06 Provider picker called `selectProvider`, which saved Workflow timestamps before adoption.
4. Recovery grouped any Step 06 `_V数字.md` file into `workflow.customerService.primary`.

## Narrow fix

- Step 06 task text now contains only supplied upstream content, no upstream local paths or suggested delivery location, and requests Markdown on stdout without file/Git operations. Other steps retain their existing task behavior.
- Only Step 06 Harness execution is wrapped with macOS `sandbox-exec`. It runs in a fresh temporary cwd/HOME; filesystem writes are denied by default except the temporary run directory, the existing DSH runtime home needed for its own profile/credential state, and the exact `/dev/null` device. Formal `~/Documents/Cosmos OS` and `~/Documents/我的知识库` are unreadable to that child process, and common Git executables are denied. Missing/unusable sandbox fails closed.
- SHA-256-based snapshots of the formal Cosmos OS and knowledge-base trees are taken before and after Step 06 execution. Any change rejects the result instead of producing an adoptable Draft; no file is deleted. This is a last-line detector, not the primary write restriction.
- Step 06 Provider selection remains in the SwiftUI session until adoption. The existing adoption transaction still performs the only formal versioned Markdown/Run/Approval/Artifact write and persists selected Provider then.
- Step 06 local-file Recovery now accepts only `客服文档_V数字.md`. The incident filename and other user Markdown files remain untouched and ungrouped.

The sandbox confines the launched local process tree. Automated tests do not prove that the installed real Harness and any independently running external service obey this boundary; no post-fix real Harness/UI run was performed. Review this limitation before live re-acceptance.

## Verification

- Targeted Step 06 XCTest: 15 passed, 0 failed, 0 skipped.
- Complete XCTest: 175 passed, 0 failed, 0 skipped.
- Both test runs used temporary Bundle ID `com.wangyucosmos.cosmostoolbox.step06tests.39112EDB-1E6D-48A4-8655-E270E68784E5`, independent UserDefaults suites and `/tmp` test data/DerivedData; no formal App was launched by tests.
- Universal Debug and Release builds: succeeded, both `x86_64 arm64`, with `CODE_SIGNING_ALLOWED=NO` and `ONLY_ACTIVE_ARCH=NO`.
- Release binary: zero matches for the 10 established DEBUG isolation identifiers; `CosmosRootView` retained.
- `git diff --check`: passed.
- The existing formal App was normally terminated before development; no UI click or second formal Harness generation was performed.

## Git and next action

All Step 06 implementation and P1 fix changes remain uncommitted on `main` at `6b52af54089c221b814e04a0ac971d35b429326e`. No branch, commit, push, tag, stash or PR. Request an independent review of this P1 fix, then separately decide how to handle the two preserved incident files before a new formal live UI acceptance. Do not adopt the old Draft or automatically recover the incident file.

## 2026-09-29 narrow P2 follow-up

- The Step 06 Seatbelt profile now uses POSIX `realpath` for the existing temporary run directory and DSH home, and the child receives those same canonical paths for HOME, TMPDIR, PWD, npm cache and DSH_HOME. This closes the observed `/var` versus `/private/var` mismatch. The only device write exception is the exact `/dev/null` literal; formal Workspace and knowledge-base roots remain outside the write allowlist.
- Real `sandbox-exec` tests now reach each permitted write target and attempt protected Workspace/knowledge-base writes and `/usr/bin/git` without stderr redirection. Step 06 revisions keep task-package execution; Step 01–04 revisions pass the original revision string to `execute(task:)`, without a destination hint or repeated package context.
- Focused XCTest and the complete XCTest suite passed under a temporary Bundle ID and temporary data/build roots. Universal Debug and Release builds passed for `x86_64 arm64`; the Release binary had zero hits for the 10 established DEBUG-isolation markers and retained `CosmosRootView`. No formal App or real Harness was run. Independent review and live acceptance remain pending.

## 2026-09-29 formal live re-acceptance and adoption

- Claude's narrow static re-review of the two directly related P2 fixes passed before the formal UI re-acceptance. This is a review of those changes, not evidence that a real Harness run would succeed.
- After the two incident originals were copied to Evidence and moved to Quarantine with four matching 31,878-byte SHA-256 checks (`a198eb7d2336c4487683360bc3f008fd94f569601d3a1850d65a412e67aaa9ec`), the fixed Debug App ran under the formal Bundle ID. The original customer-service Workspace and knowledge-base directories were empty before the new generation. No accident file was deleted, overwritten, restored or imported.
- The user observed a real DeepSeek Harness Markdown Draft, its readable Artifact Review Workspace and adopted Prototype V3 upstream context. Before adoption, read-only inspection confirmed both formal customer-service directories stayed empty, Workflow primary/backup bytes matched the pre-generation checkpoint, and Step 06 remained `ready` with zero Artifact/Run/Approval.
- The user then clicked Adopt. The screenshot showed Step 06 `已确认` and `客服文档 Markdown V1` as `已采用、已落盘`. A separate read-only persistence check established the stronger result: `~/Documents/Cosmos OS/Workspaces/卓望/浙江/浙江活动测试/06_客服文档/客服文档_V1.md` exists at 28,360 bytes with SHA-256 `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`, exactly matching the persisted Artifact content bytes. Step 06 is `approved`; it has one succeeded AI Run, one approved Approval linked to that Run and one Markdown Artifact V1, uniquely adopted in `workflow.customerService.primary`. Prototype V3 remains the unique adopted upstream prototype.
- The post-adoption Workflow primary SHA-256 is `b71226b12c2914282aff5f3451266353f6d73fcaab679cc1756c5fbbc5ff79bc`; its backup is the pre-adoption primary `88ab71fe2108aaa2ce2ff8cba848add423089e6c535fc833d03f79d452fc8c0d`. All four Evidence/Quarantine files still match the original accident hash; the knowledge-base customer-service directory remains empty.
- The earlier focused/full isolated XCTest, Universal Debug/Release builds and Release isolation scan are prior verification, not newly rerun after adoption. The formal re-acceptance exercises one real generation and adoption round trip. App restart recovery, future Harness-version confinement and cross-process persistence guarantees were not validated by this UI pass. No additional Harness run, test suite or P3 fix belongs to this closeout.
