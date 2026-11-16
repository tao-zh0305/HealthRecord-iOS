# 交接文档：健康记录 iOS App

> 用途：把当前会话的全部上下文交接给本地会话继续开发。拿到这份文档后，不需要重新做需求分析，直接从「下一步」开始。

## 1. 目标与用户背景

用户要做一个**自用的健康记录 App**，关键约束（都已确认，不要再重复询问）：

- 设备：iPhone，已有 Apple Watch
- 想要的记录范围：体重/体脂、睡眠/运动、血压/心率
- 要求：**本地存储、零服务器、零订阅、操作要顺手**
- 不接受网页方案（明确拒绝 PWA）
- 电脑：Windows，**没有 Mac**，不会 Xcode
- 签名：手上有轻松签/全能签（企业证书），但已选择改用**免费 Apple ID + Sideloadly**
- 明确要求「一键获取健康数据然后导入」→ 必须接 HealthKit
- 可以接受 GitHub Actions 云编译

## 2. 最终方案（已定，勿改）

| 项 | 决定 |
|---|---|
| 形态 | 原生 iOS App，SwiftUI，iOS 16+ |
| 数据 | 本地 JSON，存 App 沙盒 `Application Support/records.json` |
| 同步 | HealthKit 读最近 30 天，按天去重，不覆盖手动记录 |
| 构建 | GitHub Actions（macos-14）+ XcodeGen 生成工程 + xcodebuild 无签名构建 |
| 产物 | 两个 IPA：`HealthRecord-healthkit.ipa`（带 entitlement）、`HealthRecord-plain.ipa`（不带） |
| 安装 | Windows + Sideloadly + 免费 Apple ID，7 天续签 |
| Bundle ID | `com.local.healthrecord`（可改） |

## 3. 交付物位置

- 工程目录：`/workspace/health-ios`
- 压缩包：`/workspace/HealthRecord-iOS.zip`（43KB，26 个文件）
- 工作区没有其他相关代码；早期的 PWA 方案已删除，不要恢复

## 4. 工程结构

```
project.yml                      XcodeGen 工程描述（target HealthRecord）
.github/workflows/build.yml      Actions：xcodegen → xcodebuild → 打两个 IPA
.gitignore
README.md                        给用户的安装说明（中文）
HealthApp/
  HealthRecordApp.swift          @main 入口
  RootTabView.swift              三个 Tab：今日 / 趋势 / 设置
  Models.swift                   MetricType、Record、SeriesPoint、Fmt、DateText
  Store.swift                    ObservableObject，JSON 读写 + 查询/聚合/合并
  HealthKitManager.swift         HealthKit 授权与 9 类数据导入
  TodayView.swift                今日概览 4 卡 + 6 个快速记录 + 今日列表
  EntrySheet.swift               新增/编辑/删除记录的表单
  TrendsView.swift               Swift Charts 折线图 + 统计 + 最近记录
  SettingsView.swift             同步、概览、CSV/JSON 导出、JSON 恢复、清空
  Components.swift               SummaryCard / QuickButton / RecordRow / EmptyCard / ShareSheet
  Theme.swift                    配色、卡片样式、MetricType 颜色
  HealthRecord.entitlements      仅 com.apple.developer.healthkit = true
  Assets.xcassets/               AppIcon（单张 1024）、AccentColor
```

## 5. 数据模型（修改时保持兼容）

```swift
enum MetricType: String, Codable { case weight, bp, hr, sleep, exercise, steps }

struct Record: Identifiable, Codable {
    var id: UUID
    var type: MetricType
    var day: Date        // 归一化到当天 00:00
    var createdAt: Date  // 真实记录时间，列表按此倒序
    var v1: Double?
    var v2: Double?
    var v3: Double?
    var text: String?
    var note: String?
}
```

各类型字段语义：

| type | v1 | v2 | v3 | text |
|---|---|---|---|---|
| weight | kg | 体脂率 % | — | — |
| bp | 收缩压 | 舒张压 | 脉搏 | — |
| hr | bpm | — | — | — |
| sleep | 小时 | 质量 1–5 | — | — |
| exercise | 分钟 | — | — | 运动类型 |
| steps | 步数 | — | — | — |

持久化：ISO8601 日期；写入 `Application Support/records.json`；`add/update/delete/merge/clear` 后按 `createdAt` 倒序保存。

## 6. 关键业务规则

- **趋势聚合**（`Store.dailySeries(type, days)`）：体重、血压取当天最后一条；心率取当天平均；睡眠、运动、步数按天求和；无数据的天不出点。
- **重同步幂等**：`has(type, on: day)` 为真则跳过该天，避免重复导入、避免覆盖手动记录。
- **睡眠跨天切割**：按样本的起床时间就近归日（hour + 6 ≥ 12 归当天，否则归前一天），每天累计需 > 0.25 小时。
- **HealthKit 读取类型**：步数、运动时间、心率、体重、体脂率、收缩压、舒张压、睡眠分析。
- **授权**：`requestAuthorization(toShare: [], read: readTypes)`，不写健康数据。

## 7. 构建流水线细节

`.github/workflows/build.yml` 的逻辑：

1. `brew install xcodegen`
2. `xcodegen generate`
3. `xcodebuild -project HealthRecord.xcodeproj -scheme HealthRecord -configuration Release -sdk iphoneos -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
4. 产物 `build/Build/Products/Release-iphoneos/HealthRecord.app`
5. ad-hoc 签名（带 entitlements）→ `dist/HealthRecord-healthkit.ipa`
6. 重新 ad-hoc 签名（不带 entitlements）→ `dist/HealthRecord-plain.ipa`
7. 上传 artifact `HealthRecord-ipa`

注意：不带 entitlements 的版本仍包含 HealthKit 代码，调用会返回错误但不会崩溃，用于企业证书或免费签名失败时兜底。

## 8. 当前验证状态（重要）

已做：

- `swiftc -parse HealthApp/*.swift` 全部通过（语法）
- `swiftc -typecheck HealthApp/Models.swift` 通过（模型层）
- `project.yml`、`build.yml` 通过 YAML 解析
- Assets 三个 `Contents.json` 通过 JSON 校验
- 1024 图标已生成

**未做：从未在 macOS / Xcode 上真正编译过**（沙箱是 Linux，无 Xcode）。因此首次 Actions 失败属于预期内，需要按日志修。

已知的潜在编译风险点，排查时优先看：

1. `TrendsView` 的 `.chartForegroundStyleScale([...])` 字典字面量推断
2. `AxisValueLabel(format: .dateTime.month().day())`
3. `Chart` 内部 `if/else` + `ForEach` 的 ChartContentBuilder
4. `HealthKitManager` 中 `group.notify` 内对共享数组的写入（Swift 5 模式仅警告）
5. XcodeGen 版本差异导致 `scheme` / `entitlements` 生成不同

## 9. 下一步（本地会话按顺序做）

1. 把 `/workspace/HealthRecord-iOS.zip` 解压到本地仓库根目录并推送到 GitHub（`.github` 是隐藏目录，注意别漏）。
2. 触发 Actions，拿到构建日志。
3. **如果失败**：把完整报错贴进会话，逐条修复，重新推送。重点核对 bundle id、scheme 名、产物路径。
4. **如果成功**：确认两个 IPA 都存在，体积正常（约 1–3 MB）。
5. 指导用户用 Sideloadly 装 `healthkit` 包；失败则换 `plain` 包。
6. 用户装好后，收集体验反馈，再调 UI 与交互。

## 10. 备选方案（HealthKit 走不通时）

按优先级：

1. **plain IPA + 手动记录**：功能完整，只缺自动同步（已可用）。
2. **快捷指令桥接**：App 增加 URL Scheme（如 `healthrecord://import?payload=<base64>`），快捷指令读取健康样本后拼 URL 打开 App 导入。不需要 HealthKit entitlement，企业证书也能用。目前**未实现**，需要新增：
   - Info.plist 增加 `CFBundleURLTypes`
   - `HealthRecordApp` 上加 `.onOpenURL`
   - 解析 payload、按 id 去重合并
3. **付费开发者账号（$99/年）**：一劳永逸，一年免续签，但仍需 macOS 编译（可继续用 Actions）。

## 11. 不要做的事

- 不要恢复 PWA / 网页方案（用户明确不要）
- 不要给 `plain` 版本加 HealthKit entitlement
- 不要把 `.xcodeproj`、`build/`、`Payload/`、`*.ipa` 提交进仓库（`.gitignore` 已覆盖）
- 不要把 iOS 部署目标降到 16 以下（Swift Charts 需要 16）
- 不要在 UI 中引入英文文案，保持全中文
- 不要引入需要付费或联网的第三方依赖

## 12. 用户沟通要点

- 用户不懂开发细节，解释要落到「点哪里、会发生什么、失败了怎么办」
- 明确告知：Windows 不能本地编译 iOS，必须云端或 Mac
- 明确告知：免费签名 7 天过期，覆盖安装不丢数据，卸载才丢
- 明确告知：数据只在本机，App 不联网
