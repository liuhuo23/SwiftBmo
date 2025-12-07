# Bmo

Bmo — 一个基于 SwiftUI 的 macOS 番茄钟（Pomodoro）应用，轻量、视觉友好，专注于高精度计时与会话记录。

## 目标用户

- 需要专注工作/学习的个人（程序员、设计师、学生等）
- 喜欢 macOS 原生体验、希望轻量化但可扩展的番茄钟工具的用户
- 关注可视化进度与会话历史的用户

## 核心功能（概要）

- 启动 / 暂停 / 重置番茄计时（可视化环形进度）
- 提示音 / 本地通知提醒（会话完成）
- 会话记录持久化（Core Data）与预览数据
- 可扩展的设置页、任务列表与历史视图

---

# 任务线与迭代计划

下面将功能拆成多条可执行任务，每条包含目的、验收标准、关联模块和预估难度/时间。

1) 基础计时器重构为 ViewModel 【已完成 50%】
- 目的：将 UI 内联计时逻辑抽离为 `TimerViewModel`，提升可测试性与复用性。
- 验收标准：`TimerView` 仅负责显示与交互绑定；所有计时状态与命令由 `TimerViewModel` 管理；提供基本单元测试。
- 关联文件：新增 `Sources/ViewModels/TimerViewModel.swift`；调整 `compoents/Timer+Compoents.swift`。
- 难度：中（约 1–2 天）。

2) 精确计时后端（睡眠/恢复兼容） 【已完成】
- 目的：用 `DispatchSourceTimer` 与基于时间差的算法替代简单轮询，处理系统睡眠与挂起恢复。
- 验收标准：系统挂起/恢复后剩余时间正确；误差可控（示例：<1s/分钟）。
- 关联文件：`TimerViewModel.swift`、`Timer+Compoents.swift`。
- 难度：中（约 1–2 天）。

3) Core Data 数据模型完善（Task / Session / Settings）
- 目的：将当前泛用 `Item` 扩展为更明确的实体以记录任务与会话。
- 验收标准：包含 `Task`、`Session`、`Settings`，支持 CRUD 与持久化；`PersistenceController.preview` 提供演示数据。
- 关联文件：`SwiftBmo.xcdatamodeld`、`Persistence.swift`。
- 难度：中（约 1–3 天）。

4) 通知与音频服务封装
- 目的：抽象 `NotificationService` 与 `AudioService`，支持用户偏好（静音/自定义音效）。
- 验收标准：会话完成时能发送本地通知并播放音效（使用 `Resource/ding.mp3`）；用户可关闭。
- 难度：小（约 0.5–1 天）。

5) 设置页与偏好持久化
- 目的：实现设置界面并保存用户偏好（工作/短休/长休时长、通知、音效）。
- 验收标准：设置即时生效并持久化（UserDefaults 或 Core Data `Settings` 实体）。
- 难度：小（约 0.5–1 天）。

6) 任务列表与会话历史视图
- 目的：允许管理多个任务并查看历史统计（按日/周/总计）。
- 验收标准：可创建/编辑/删除任务，查看统计汇总视图。
- 难度：中（约 2–4 天）。

7) UI polish 与可访问性/快捷键支持
- 目的：提高可用性，添加键盘快捷键、语义化标签、深色模式兼容。
- 验收标准：常用操作提供快捷键；无障碍标签齐全；主题兼容。
- 难度：小（约 1 天）。

8) 测试与 CI
- 目的：建立单元/UI 测试与 CI 流水线（GitHub Actions 或 Xcode Cloud）。
- 验收标准：主要 ViewModel 单元测试通过；可选 UI 测试；CI 能运行测试套件。
- 难度：中（约 1–3 天）。

---

# 设计逻辑细节

## 架构概览
- 推荐架构：MVVM（View / ViewModel / Model + Services）。
- 技术栈：SwiftUI、Core Data、DispatchSourceTimer（或时间差法）、AVFoundation、UserNotifications。
- 模块划分示例：
  - Models: `Task`, `Session`, `Settings`（Core Data）。
  - ViewModels: `TimerViewModel`, `TaskListViewModel`, `SettingsViewModel`。
  - Views: `TimerView`, `CircularProgressView`, `SettingsView`, `TaskListView`, `SessionHistoryView`。
  - Services: `PersistenceController`, `NotificationService`, `AudioService`, `TimerService`。

## 数据模型建议
- Task: id(UUID), title(String), workDuration(Int 秒), shortBreak(Int 秒), longBreak(Int 秒), cyclesBeforeLongBreak(Int), createdAt(Date), colorHex(String?), isArchived(Bool)
- Session: id(UUID), task(关系), type(String: work/shortBreak/longBreak), startTime(Date), endTime(Date), duration(Int 秒), isCompleted(Bool)
- Settings: defaultWork(Int), defaultShortBreak(Int), defaultLongBreak(Int), soundEnabled(Bool), soundName(String), notificationsEnabled(Bool)

> 注意：当前项目中存在 `Item` 实体（`Item.timestamp`），建议在模型编辑器中扩展或新增实体并准备迁移策略。

## 定时器状态机（建议）
- 状态集：`idle`, `runningWork`, `runningShortBreak`, `runningLongBreak`, `paused`, `finished`。
- 触发器：`start`, `tick`, `pause`, `resume`, `reset`, `complete`。
- 要点：基于绝对时间计算剩余（targetDate - Date()），支持睡眠恢复与幂等操作。

## 通知与音频策略
- 音频：使用 `AVAudioPlayer` 预加载并播放 `Resource/ding.mp3`，支持选择/静音。
- 通知：使用 `UNUserNotificationCenter` 发送本地通知，需请求权限并在权限被拒绝时回退为仅播放音效。

## 持久化策略
- 使用 `PersistenceController`（保留 `preview` 的 in-memory 用于测试）。
- 写操作在后台上下文处理，UI 使用 `viewContext`。开启 `automaticallyMergesChangesFromParent`。
- 迁移：采用版本化模型并支持轻量级迁移或提供迁移说明。

## 并发与计时精度
- 使用 `DispatchSourceTimer` 或时间差法避免主线程阻塞导致计时误差。
- 记录 `startTime/targetDate` 而非单纯累减；恢复时基于 `Date()` 或系统 uptime 计算。
- UI 更新在主线程（`@MainActor`）。

---

# UI / 组件清单与契约

- TimerView (`compoents/Timer+Compoents.swift`)
  - 责任：展示环形进度、时间文本与控制按钮。
  - 建议契约：接收 `@ObservedObject var viewModel: TimerViewModel`，不直接持有业务逻辑。
  - 事件：`onStart()`, `onPause()`, `onReset()`, `onComplete()`。

- CircularProgressView (`compoents/CircularProgressView.swift`)
  - 输入：`progress: Double (0...1)`, 可选渐变与宽度。
  - 无副作用，中心自定义视图可注入。

- ContentView
  - 目前：主容器仅嵌入 `TimerView`。
  - 建议：作为导航容器（任务列表 + 详情 + 设置）。

- 建议新增视图：`SettingsView`, `TaskListView`, `SessionHistoryView`。

---

# 测试策略

- 单元测试：重点覆盖 `TimerViewModel` 的状态转换、睡眠恢复与数据层 CRUD（使用 in-memory Core Data）。
- UI 测试：关键路径（启动->开始->完成->通知/音效），设置变更影响计时等流程。
- CI：使用 GitHub Actions 或 Xcode Cloud，在 macOS runner 上执行 `xcodebuild test`。

---

# 开发与运行说明

- 打开工程：在项目根目录用 Xcode 打开 `SwiftBmo.xcodeproj`（或 `.xcworkspace`）。
- 运行：选择 `SwiftBmo` scheme 并 Run。
- 模拟数据：`PersistenceController.preview` 提供演示 `Item`；在预览与测试中使用。
- 注意：开发时请确认 `PersistenceController.shared` 的 `inMemory` 配置（生产建议 `false`）。
- 声音资源：`Resource/ding.mp3` 已包含。

---

# 后续扩展建议（优先级可选）

1. 菜单栏/状态栏小组件（Menu bar app）
2. 会话统计仪表盘（天/周/月）
3. 多任务队列与自动切换
4. iCloud 同步（跨设备）
5. macOS 小组件与 Shortcuts 集成
6. 可自定义主题与声音包

---

# 小结与下一步建议

- 首要改造：提取 `TimerViewModel`、使用高精度计时与完善 Core Data 模型。
- 优先保证计时准确性、睡眠恢复与数据安全，然后逐步添加设置、任务与历史功能。
- 我可以将上述任务线转成 Issue 清单并生成 PR 模板，或直接帮你实现 `TimerViewModel` 的初始草案。请选择你希望下一步我做的事。
