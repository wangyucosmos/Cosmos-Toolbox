# Cosmos OS Technical Architecture

**版本：v0.1**  
**日期：2026-08-17**  
**技术栈：Swift / SwiftUI / macOS**

---

## 1. 架构目标

Cosmos OS 必须满足：

- 可维护；
- 可测试；
- 可扩展；
- 文件结构清晰；
- 低耦合；
- 不过度工程化。

第一阶段不采用复杂 Clean Architecture 全套模板，而采用：

> **Feature-based Modular Architecture**

即按业务模块组织代码。

---

## 2. 顶层目录

```text
CosmosToolbox/
│
├── App/
│   ├── CosmosToolboxApp.swift
│   ├── AppState.swift
│   └── AppRouter.swift
│
├── Core/
│   ├── Models/
│   ├── Services/
│   ├── Storage/
│   ├── Security/
│   └── Utilities/
│
├── Features/
│   ├── Dashboard/
│   ├── ZhuowangWorkspace/
│   ├── Projects/
│   ├── KnowledgeBase/
│   ├── AIWorkspace/
│   ├── PromptVault/
│   ├── LearningCenter/
│   ├── MacOptimizer/
│   └── Settings/
│
├── Shared/
│   ├── Components/
│   ├── Styles/
│   ├── Extensions/
│   └── Constants/
│
├── Resources/
│
├── Assets.xcassets
│
└── Tests/
```

---

## 3. Feature 目录规范

每个 Feature 采用尽量一致的结构：

```text
FeatureName/
├── Views/
├── ViewModels/
├── Models/
├── Services/
└── Components/
```

不是每个模块都必须拥有所有子目录。

原则：

> 需要时创建，不为目录完整而创建空文件。

---

## 4. Dashboard 示例

```text
Features/
└── Dashboard/
    ├── Views/
    │   └── DashboardView.swift
    ├── ViewModels/
    │   └── DashboardViewModel.swift
    ├── Models/
    │   └── DashboardSummary.swift
    └── Components/
        ├── RecentProjectsCard.swift
        └── LearningProgressCard.swift
```

---

## 5. 导航架构

第一阶段使用 SwiftUI 原生：

- `NavigationSplitView`
- Sidebar Selection
- Observable AppState

建议：

```text
AppState
  ↓
SelectedSidebarItem
  ↓
NavigationSplitView
  ↓
Feature Root View
```

不要在第一阶段引入第三方 Router。

---

## 6. 状态管理

优先级：

1. `@State`
2. `@Binding`
3. `@Observable`
4. Environment
5. SwiftData

原则：

- 页面局部状态不要放全局；
- 全局状态尽量少；
- 不使用 Redux 类复杂状态架构。

---

## 7. 数据层

### App 设置

使用：

- `AppStorage`
- `UserDefaults`

用于：

- 主题偏好；
- 默认路径；
- Sidebar 状态；
- 简单设置。

### 业务数据

使用：

- SwiftData

用于：

- 项目；
- 学习记录；
- Prompt 元数据；
- 活动记录；
- 最近使用；
- 标签。

### 文件

使用本地文件系统。

Cosmos OS 不复制所有文件进数据库，只保存：

- 路径；
- 类型；
- 元数据；
- 标签；
- 项目关联。

---

## 8. 文件系统策略

用户文件建议存放在用户指定 Workspace 根目录。

示例：

```text
~/Documents/Cosmos/
├── Zhuowang/
├── Projects/
├── Learning/
├── PromptVault/
└── Backups/
```

后续允许用户自定义。

---

## 9. Zhuowang Workspace 目录模型

示例：

```text
Zhuowang/
└── 2026/
    └── 河南/
        └── 2026-09_促活活动/
            ├── 01_策划/
            ├── 02_原型/
            ├── 03_客服/
            ├── 04_流程图/
            ├── 05_素材/
            ├── 06_截图/
            └── 99_归档/
```

目录模板必须配置化，不要把所有名字写死在 View 中。

---

## 10. 服务层

所有系统操作必须通过 Service，不允许 View 直接大量执行 Shell。

例如：

```text
InputMethodService
SystemInfoService
GitService
EnvironmentService
WorkspaceService
FileIndexService
BackupService
```

---

## 11. Shell 调用原则

Cosmos OS 可以调用 macOS 命令行工具，但必须：

- 集中封装；
- 参数可控；
- 不拼接未经处理的用户输入；
- 保留执行日志；
- 写操作需要确认。

禁止 View 中直接出现：

```swift
Process(...)
```

统一放 Service。

---

## 12. 权限设计

第一阶段尽可能避免获取不必要权限。

如需要：

- 文件夹访问：使用用户选择；
- 凭据：Keychain；
- Automation：按需；
- Full Disk Access：尽量不要求。

---

## 13. Security

### API Key

如果未来需要保存：

- 使用 Keychain；
- UI 默认遮罩；
- 不写入日志；
- 不提交 Git。

### Shell

禁止：

- `sudo rm -rf` 自动执行；
- 用户不可见的系统配置修改；
- 高风险命令无确认执行。

---

## 14. 日志

建立统一 Logger。

分类：

- App
- File
- Git
- Workspace
- Environment
- System

开发阶段使用 `Logger`。

用户日志必须避免记录：

- API Key；
- 私人内容全文；
- 输入法输入内容。

---

## 15. 备份

涉及重要写操作前：

- 项目配置先备份；
- App 数据定期导出；
- 设置支持恢复。

建议格式：

```text
CosmosBackup/
├── database/
├── settings/
├── manifests/
└── metadata.json
```

---

## 16. Git 策略

仓库：

```text
Cosmos-Toolbox
```

分支：

- `main`：稳定主线
- 后续复杂开发可使用 feature 分支

第一阶段无需过度复杂。

Commit 建议采用：

```text
feat:
fix:
refactor:
docs:
chore:
test:
```

示例：

```text
feat: add sidebar navigation
docs: add product baseline
fix: restore dashboard selection
```

---

## 17. 版本号

采用 Semantic Versioning：

```text
0.1.0
0.2.0
0.3.0
1.0.0
```

在 1.0 前允许快速演进。

---

## 18. 测试策略

第一阶段重点：

### Unit Tests

- 路径生成；
- Workspace 创建；
- 状态检测；
- 数据模型；
- Prompt 分类；
- 学习进度计算。

### UI Tests

后续加入：

- 新建项目；
- Sidebar 导航；
- 设置保存；
- 搜索。

---

## 19. 第三方依赖

原则：

> 能不用就不用。

第一阶段尽量只用 Apple 官方框架。

引入第三方库必须回答：

- 解决什么问题？
- 官方框架为什么不够？
- 是否长期维护？
- 是否影响 App 体积和稳定性？

---

## 20. 未来扩展接口

预留但不提前实现：

- GitHub Connector
- AI API
- MCP
- Plugin
- Cloud Sync
- iOS Companion
- Menu Bar Extension

---

## 21. 当前技术决策

### 已确认

- macOS 原生应用
- Swift
- SwiftUI
- SF Symbols
- Feature-based Architecture
- 本地优先
- GitHub 作为代码正式仓库

### 暂不确认

- 是否启用 iCloud Sync
- 是否使用 CloudKit
- 是否上架 Mac App Store
- 是否做插件系统
- 是否引入本地向量数据库

这些都延后到真实需求出现后决定。
