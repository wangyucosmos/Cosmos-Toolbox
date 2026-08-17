# Cosmos OS Workspace Vision

**版本：v0.1**  
**日期：2026-08-17**

---

## 1. 核心判断

Cosmos OS 属于用户本人，而不属于用户当前所在的任何一家公司。

公司、客户、岗位和项目都会变化，但 Cosmos OS 应该作为长期存在的个人工作操作系统持续演进。

因此，“卓望工作”不应被理解为 Cosmos OS 本身，而应被理解为 Cosmos OS 中的第一个真实 Company Workspace。

> 公司只是 Workspace，项目只是工作单元；真正长期存在的是用户自己的知识、工作流、工具链和成长记录。

---

## 2. 长期产品形态

未来 Cosmos OS 的 Work 模块应逐步支持多个 Workspace：

```text
Cosmos OS
│
├── 工作 Work
│   │
│   ├── 卓望工作
│   │   ├── 河南
│   │   ├── 安徽
│   │   ├── 浙江
│   │   ├── 全国促活
│   │   └── 历史项目
│   │
│   ├── XX 公司
│   │   ├── AI 产品运营
│   │   ├── 用户增长
│   │   ├── 内容营销
│   │   ├── Campaign
│   │   └── 工作知识库
│   │
│   └── 个人项目
│       ├── Cosmos OS
│       ├── 求职作品
│       └── 其他项目
│
├── AI
├── Knowledge Base
├── Learning
└── System
```

当用户离开一家企业时，对应 Workspace 可以进入 Archived 状态，而不是删除。

历史工作仍可作为职业经验和方法论沉淀，但后续需要注意公司机密、版权和合规边界，不应默认把不可带离公司的内部资料继续复制或迁移到个人系统。

---

## 3. Workspace 通用抽象

长期架构建议逐步从 `Zhuowang Workspace` 抽象为更通用的 `Workspaces`。

一个 Workspace 可以包含：

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

其中：

- **Organization / Company**：公司、客户、个人项目等工作上下文；
- **Projects**：具体工作项目；
- **Workflows**：该工作空间中的标准业务流程；
- **Artifacts**：策划案、原型、客服文档、流程图、图片、表格、链接等工作产物；
- **Knowledge**：项目经验、方法论、复盘和可复用知识；
- **Templates**：文档模板、Prompt、流程模板、页面结构等；
- **AI Connections**：该 Workspace 可使用的 AI Provider / Agent / Connector。

---

## 4. 为什么暂时不立即重构

当前不要为了“未来支持所有公司”而提前把代码重构成万能框架。

卓望是 Cosmos OS 当前最真实、最高频、信息最完整的实验场景，因此应继续先把以下闭环跑成熟：

```text
Campaign
→ Workflow
→ AI
→ Human Review
→ Artifact
→ File
→ Knowledge
```

只有当这套闭环在真实工作中稳定使用后，再抽离：

- 哪些能力属于卓望专属业务；
- 哪些能力属于所有 Workspace 通用能力；
- 哪些数据模型值得提升为系统级抽象。

原则：

> 从真实业务中抽象，而不是从想象中设计万能系统。

---

## 5. Knowledge Base 的长期分层

Knowledge Base 不应只是文件列表，而应逐步形成三层知识体系：

```text
Knowledge Base
│
├── Company Knowledge
│   ├── 卓望
│   ├── XX公司
│   └── YY公司
│
├── Professional Knowledge
│   ├── 活动运营
│   ├── AI 产品运营
│   ├── 用户增长
│   ├── 社媒运营
│   └── 数据分析
│
└── Personal Knowledge
    ├── Python
    ├── GitHub
    ├── Swift
    ├── AI Agent
    └── 视频剪辑
```

### Company Knowledge

保存与具体组织强相关的项目经验、结构和工作记录。

### Professional Knowledge

从多个公司和项目中抽象出的可迁移职业能力，例如：

- 活动策划方法；
- 客服 FAQ 组织方式；
- PRD 写法；
- 页面模块拆解方法；
- AI Workflow 设计；
- Prompt 模板；
- 项目复盘方法。

### Personal Knowledge

与个人学习、开发、工具使用和长期成长相关的知识。

---

## 6. 历史工作资产的价值

Cosmos OS 应逐步支持把过去已经完成的、合法可保存的工作资产纳入系统，例如：

- 策划案；
- Figma 原型或链接；
- 客服文档；
- 流程图；
- 活动规则；
- 题库；
- Banner；
- 截图；
- 数据复盘；
- Prompt；
- 项目结论。

这些资产不只是“存进去”，而应该逐步具备结构化元数据：

- 属于哪个 Workspace；
- 属于哪个项目；
- 属于哪个省份 / 市场 / 业务线；
- 资产类型；
- 创建时间；
- 版本；
- 是否最终采用；
- AI 来源；
- 相关 Workflow Step；
- 标签；
- 可否复用。

未来 Knowledge Base 才能实现真正有价值的检索和复用。

---

## 7. AI 与个人知识的长期循环

Cosmos OS 的理想状态不是 AI 凭空生成，而是 AI 在用户自己的工作资产和知识上工作。

长期闭环：

```text
完成更多真实工作
        ↓
Cosmos OS 积累更多项目与 Artifact
        ↓
Knowledge Base 越来越丰富
        ↓
AI 获得更好的历史上下文
        ↓
下一次工作效率和质量提高
        ↓
产生新的优质工作资产
        ↺
```

这意味着系统价值会随着长期使用增加，而不是每个任务结束后归零。

---

## 8. 职业生涯级产品原则

Cosmos OS 的长期目标可以总结为：

> 工作经历会变化，但工作系统不会消失。

> 人负责判断，系统负责记忆。

> Build once. Improve forever.

未来无论用户从内容运营转向 AI 产品运营、AI 应用运营、产品经理或其他方向，Cosmos OS 都应该允许新增新的 Workspace、Workflow、Template 和 Knowledge，而不是推翻已有系统。

最终它既可以是：

- 日常提高效率的工作工具；
- 长期个人知识库；
- 职业经验沉淀系统；
- AI 工作流实验平台；
- 个人软件作品；
- 面向未来职业发展的作品集核心项目。

---

## 9. 当前执行原则

当前阶段仍然坚持：

1. 先把卓望真实工作场景做深；
2. 先完成 Workflows over Features；
3. 先跑通 Artifact 与真实文件沉淀；
4. 再构建 Knowledge Base；
5. 当通用模式足够清晰后，再引入正式的多 Workspace 架构；
6. UI 视觉统一放在核心信息架构稳定之后集中完成。

> Cosmos OS 应该随着用户一起成长，而不是随着某一份工作结束。
