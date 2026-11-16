# 健康记录（HealthRecord）

一个自用的 iOS 健康记录 App：SwiftUI 编写，数据全部保存在本机，支持一键读取 Apple 健康数据。

## 功能

- 快速记录：体重 / 体脂、血压 / 脉搏、心率、睡眠 / 质量、运动 / 类型、步数
- 一键同步：HealthKit 读取最近 30 天的步数、运动分钟、心率、体重、体脂、血压、睡眠
- 趋势：7 / 30 / 90 天折线图，最近、平均、最低、最高
- 备份：导出 CSV（可给医生看）、导出 JSON、从备份恢复
- 无服务器、无网络请求，卸载即删除数据

## 构建（无需 Mac）

1. 在 GitHub 新建一个仓库（公开或私有均可，公开仓库的 macOS runner 不消耗额度）
2. 把本目录全部文件上传到仓库根目录
   - 网页端可直接拖拽上传：`HealthApp/`、`.github/`、`project.yml`、`README.md`
   - `.github` 是隐藏目录，用 GitHub Desktop 或 git 命令上传更稳：
     ```bash
     git init
     git add .
     git commit -m "init"
     git branch -M main
     git remote add origin https://github.com/<你的用户名>/<仓库名>.git
     git push -u origin main
     ```
3. 打开仓库的 **Actions** 页 → 左侧 **Build IPA** → 右侧 **Run workflow**
4. 约 5 分钟后，进入该次运行页面，底部 **Artifacts** 下载 `HealthRecord-ipa`
5. 解压后会得到两个文件：
   - `HealthRecord-healthkit.ipa`：带 HealthKit 权限，**优先用这个**
   - `HealthRecord-plain.ipa`：无任何权限，签名失败时用这个（只能手动记录）

## 安装（Windows + Sideloadly）

1. Windows 安装 [Sideloadly](https://sideloadly.io) 和 iTunes（Microsoft Store 版即可）
2. iPhone 用数据线连接电脑，手机上点「信任此电脑」
3. 打开 Sideloadly：
   - `IPA` 先选 `HealthRecord-healthkit.ipa`
   - `Apple account` 填你的 Apple ID
4. 点 **Start**，按提示输入密码
   - 开启了双重认证时，用 Apple ID 的 **App 专用密码**（在 appleid.apple.com 生成）
5. 安装完成后，手机「设置 → 通用 → VPN 与设备管理」中信任该开发者
6. 打开 App，首次点右上角「同步健康」，在系统弹窗里允许读取

## 首次使用

- 点头部「同步健康」→ 允许健康权限 → 自动导入最近 30 天数据
- 手动补记：点「快速记录」里的任意按钮
- 想改或删某条记录：在「今天的记录」里点它

## 关于 7 天有效期

免费 Apple ID 签名的 App 有效期为 7 天，到期后打不开。处理方式：

- 重新用 Sideloadly 装一次（数据不会丢，记录存在 App 沙盒内，覆盖安装即可）
- 或改用 AltStore / SideStore，在同一 Wi-Fi 下自动续签

## HealthKit 签名失败怎么办

免费 Apple ID 通常支持 HealthKit，但个别 iOS 版本 + 签名工具组合会报 entitlement 错误。

如果 Sideloadly 报错或 App 内点同步没有弹出权限窗口，直接改用 `HealthRecord-plain.ipa` 重新安装即可——手动记录、图表、备份全部正常，只是不能自动同步健康数据。

## 数据位置与备份

- 记录文件：App 沙盒内 `Application Support/records.json`
- 覆盖安装 / 重签不会清除数据；**卸载 App 会清除**
- 建议每月在「设置 → 导出 JSON 备份」存一份到「文件」App

## 目录结构

```
project.yml                     XcodeGen 工程描述
HealthApp/
  HealthRecordApp.swift         入口
  RootTabView.swift             三个 Tab
  Models.swift                  数据模型与格式化
  Store.swift                   本地 JSON 存储
  HealthKitManager.swift        HealthKit 读取与去重导入
  TodayView.swift               今日页
  EntrySheet.swift              录入 / 编辑面板
  TrendsView.swift              趋势图表（Swift Charts）
  SettingsView.swift            设置、导出、恢复
  Components.swift              复用组件
  Theme.swift                   配色
  HealthRecord.entitlements     HealthKit 权限
  Assets.xcassets/              图标与强调色
.github/workflows/build.yml     云端构建未签名 IPA
```
