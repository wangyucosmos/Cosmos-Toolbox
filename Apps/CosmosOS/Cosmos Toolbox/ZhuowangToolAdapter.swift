import Foundation

// MARK: - Tool Adapter Protocol

/// Cosmos OS 所有外部执行工具统一接口。
/// AI 负责理解和生成任务。
/// Tool Adapter 负责调用具体执行能力并返回工作产物。
///
/// 注意：
/// 这里不绑定具体产品。
/// Figma、Pixso、HTML Prototype、Claude、Codex、DeepSeek 等未来都可以通过 Adapter 接入。

protocol ZhuowangToolAdapter {

    /// 工具唯一标识
    var toolID: UUID { get }

    /// 工具名称
    var name: String { get }

    /// 支持能力
    var capabilities: [ZhuowangWorkflowCapability] { get }

    /// 是否支持当前任务能力
    func supports(
        capability: ZhuowangWorkflowCapability
    ) -> Bool

    /// 执行 AI 任务
    func execute(
        taskPackage: ZhuowangAITaskPackage
    ) async throws -> ZhuowangArtifact
}


// MARK: - Default Capability Check

extension ZhuowangToolAdapter {

    func supports(
        capability: ZhuowangWorkflowCapability
    ) -> Bool {

        capabilities.contains(capability)
    }
}


// MARK: - Adapter Registry

/// Cosmos OS 未来统一管理所有执行器。
/// 不直接依赖 Figma / Claude / Codex 等具体产品。

struct ZhuowangToolAdapterRegistry {

    private var adapters: [any ZhuowangToolAdapter]

    init(
        adapters: [any ZhuowangToolAdapter] = []
    ) {
        self.adapters = adapters
    }

    mutating func register(
        _ adapter: any ZhuowangToolAdapter
    ) {
        adapters.append(adapter)
    }

    func availableAdapters(
        for capability: ZhuowangWorkflowCapability
    ) -> [any ZhuowangToolAdapter] {

        adapters.filter {
            $0.supports(
                capability: capability
            )
        }
    }

    func find(
        toolID: UUID
    ) -> (any ZhuowangToolAdapter)? {

        adapters.first {
            $0.toolID == toolID
        }
    }
}


// MARK: - Future Adapter Examples
//
// 后续可分别实现：
//
// DeepSeekHarnessAdapter
// ChatGPTAdapter
// ClaudeDesktopAdapter
// CodexAdapter
// FigmaAdapter
// PixsoAdapter
// HTMLPrototypeAdapter
//
// 它们只需要遵守 ZhuowangToolAdapter。
// Cosmos Workflow 不需要知道具体工具名称。



