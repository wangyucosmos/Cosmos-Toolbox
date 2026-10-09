import Foundation

// MARK: - AI Workspace Phase 1: local tool detection
//
// Detection only proves that a command-line tool exists on this Mac and that
// `<tool> --version` runs. It says nothing about login, quota, network or
// model availability, and it never installs, updates, logs in or reads keys.

/// The five tools covered by Phase 1.
nonisolated enum AIWorkspaceToolID: String, CaseIterable, Identifiable, Sendable {
    case claudeCode
    case codex
    case git
    case node
    case python

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex CLI"
        case .git: return "Git"
        case .node: return "Node.js"
        case .python: return "Python"
        }
    }

    /// The executable file name that is looked up.
    var commandName: String {
        switch self {
        case .claudeCode: return "claude"
        case .codex: return "codex"
        case .git: return "git"
        case .node: return "node"
        case .python: return "python3"
        }
    }

    var symbol: String {
        switch self {
        case .claudeCode: return "terminal"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .git: return "arrow.triangle.branch"
        case .node: return "hexagon"
        case .python: return "curlybraces"
        }
    }
}


/// How the executable was actually discovered (never guessed afterwards).
nonisolated enum AIWorkspaceDiscoverySource: String, Sendable, Equatable {
    case currentPath
    case commonLocation
    case claudeDesktopBundle
    case chatGPTDesktopBundle

    var title: String {
        switch self {
        case .currentPath: return "当前进程 PATH"
        case .commonLocation: return "常见安装位置"
        case .claudeDesktopBundle: return "Claude 桌面版内置"
        case .chatGPTDesktopBundle: return "ChatGPT 桌面版内置"
        }
    }
}


nonisolated enum AIWorkspaceToolFailure: Sendable, Equatable {
    case notFound
    case developerToolsMissing
    case notExecutable(path: String)
    case launchFailed(String)
    case timedOut(seconds: Int)
    case nonZeroExit(code: Int32, detail: String)

    var message: String {
        switch self {
        case .notFound:
            return "未找到。已查找当前进程 PATH、常见安装位置和桌面版内置目录。"
        case .developerToolsMissing:
            return "只找到系统自带入口，它依赖 Xcode 命令行工具，而本机未检测到。为避免弹出安装窗口，已跳过运行。"
        case .notExecutable(let path):
            return "找到了 \(path)，但它没有执行权限。"
        case .launchFailed(let reason):
            return "找到了文件，但无法启动：\(reason)"
        case .timedOut(let seconds):
            return "运行 --version 超过 \(seconds) 秒仍未返回，已终止。"
        case .nonZeroExit(let code, let detail):
            let suffix = detail.isEmpty ? "" : "：\(detail)"
            return "运行 --version 失败（退出码 \(code)）\(suffix)"
        }
    }

    var hint: String {
        switch self {
        case .notFound:
            return "如果已安装在其他位置，Phase 1 不会找到它。Cosmos OS 不会代为安装。"
        case .developerToolsMissing:
            return "需要时可在终端运行 xcode-select --install，或安装 Xcode；Cosmos OS 不会代为执行。"
        case .notExecutable:
            return "Cosmos OS 不会修改文件权限，请在终端自行检查。"
        case .launchFailed, .nonZeroExit:
            return "这只说明 --version 没有成功，请在终端手动运行同一命令查看详情。"
        case .timedOut:
            return "可能是首次启动较慢或被系统拦截，可稍后刷新。"
        }
    }
}


nonisolated enum AIWorkspaceToolStatus: Sendable, Equatable {
    /// Exists and `--version` ran with exit code 0.
    case ready
    /// Found, but could not be shown to run.
    case warning
    /// Not found (or deliberately not run).
    case missing
}


nonisolated struct AIWorkspaceToolResult: Identifiable, Sendable, Equatable {
    let tool: AIWorkspaceToolID
    let failure: AIWorkspaceToolFailure?
    /// Version number parsed from the output, when one could be recognised.
    let version: String?
    /// First line of the real output, shown as supporting detail.
    let versionLine: String?
    /// The path that was executed (as discovered, not symlink-resolved).
    let path: String?
    /// Symlink-resolved location, only when it differs from `path`.
    let resolvedPath: String?
    let source: AIWorkspaceDiscoverySource?
    /// True when the executable is a system developer-tools entry point.
    let isSystemShim: Bool
    let checkedAt: Date

    var id: AIWorkspaceToolID { tool }

    var status: AIWorkspaceToolStatus {
        switch failure {
        case nil: return .ready
        case .notFound?, .developerToolsMissing?: return .missing
        default: return .warning
        }
    }
}


/// The last completed detection, kept in memory only (never persisted).
nonisolated struct AIWorkspaceSnapshot: Sendable, Equatable {
    let results: [AIWorkspaceToolResult]
    let completedAt: Date
}


/// Reference holder that outlives the page so a finished result survives
/// switching the sidebar. It holds no persistent data.
final class AIWorkspaceResultCache {
    var snapshot: AIWorkspaceSnapshot?
}
