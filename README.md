# 伴学小屋 · FocusNest

Flutter / Android 学习计划与沉浸专注应用。当前为 **0.3.0+12 体验版**，围绕「目标 → 每日任务 → 沉浸执行 → 周期复盘」精简。

[发布与下载](https://github.com/carlkleinnw/FocusNest/releases) · [核心功能与准确性设计](docs/核心功能重构.md) · [版本记录](CHANGELOG.md) · [发布与回滚](docs/版本发布与回滚.md)

## 核心功能

- **AI 规划**：在独立设置页填写自己的 DeepSeek API 密钥。输入目标，最多3轮追问，生成月、周、日计划；先预览，确认后整批保存。一次最多规划未来366天、366项具体任务，检查已有安排和每日容量。
- **计划表**：新增、编辑、删除、按日期或关键词查找任务；完成后手动勾选，记录真实确认时间。未完成任务自动顺延，保留原定日期、完成量和顺延次数。
- **沉浸专注**：从具体任务进入，或单独开启自由专注。常用时长与30—180分钟自定义时长共用原生保护、白名单、真实计时和两轮提前退出。计时结束不自动勾选任务。
- **复盘**：周、月、季度、年度逐级压缩。程序核算任务数、完成量、专注次数和时长，AI 选择可验证的任务原文并提出下一步建议；保存成功后才移除对应来源。失败保留未总结数据。
- **设置**：密钥填写/显隐/移除、模型选择与真实连接测试、每日时间、自动复盘、AI 演示模式和保护权限入口。

主导航只保留「今日计划、AI 规划、沉浸专注、复盘」。宠物/小屋等旧模块和数据保留兼容，不再占用主流程，宠物状态不再阻止专注。新装 Android 不注入示例计划；覆盖安装保留原本的数据和白名单，不清空用户会话。

## 开始使用

1. 安装 [0.3.0 APK](https://github.com/carlkleinnw/FocusNest/releases/tag/v0.3.0-demo)。手机覆盖安装前必须核对签名；不要卸载或清数据。本轮只在模拟器安装测试，未覆盖用户手机。
2. 点右上角「设置」，填 DeepSeek 密钥并保存；留空保存会保留已有密钥。点击「测试连接」，以实际结果为准。首次保存密钥会开启自动复盘，可随时关闭。
3. 在「AI 规划」描述目标，回答追问，检查假设与月/周/日安排，点击「确认并保存到计划表」。也可以手动新增任务。
4. 进入任务的沉浸模式；保护权限需本人在系统设置开启。在「设置 → 专注保护与白名单」管理允许应用。
5. 完成工作后勾选任务。周期结束后生成复盘，或在设置中管理自动复盘。

密钥使用 Android Keystore 的 AES/GCM 加密，存储在本机私有区域，不进入源码、SQLite 快照、网页或日志。API 请求直连 DeepSeek 官方 HTTPS 地址，会把你输入的目标对话、安排容量和相关复盘事实发给 DeepSeek，产生账户费用；不发送应用名单。当前真实账户调用需用户自行填写密钥后测试，本轮只验证了受控演示、校验、错误路径与加密保存，**未使用用户真实密钥调用 DeepSeek**。

自动复盘在应用运行/恢复时处理结束周期，失败不清明细，下次打开补处理关闭期间的积压，不承诺手机完全关闭时在午夜联网。压缩后保留精确统计及最多6条关键任务原文，父周期取代子周期，其他逐项内容无法恢复。旧版没有完成时间的任务保留并显示日期未知，不编造时间。

## 验证状态

检查明细见 [0.3.0 验证记录](docs/validation/0.3.0-checks.json)。本轮包括静态检查、规则与页面测试、23项原生回归检查、Android 模拟器端到端流程、Android/Web 构建；模拟器验证了任务/自由专注、37分钟自定义会话启动与两轮退出、真实 SQLite 和测试历史的逐级压缩。完整37分钟自然到期、用户手机新包保护、多品牌长后台与真实 DeepSeek 联通不在本轮已通过范围。

0.2.7 的 Xiaomi 15 原生保护与30分钟稳定性是历史证据，不能视为0.3.0在用户手机已验收。历史记录见 [0.2.7 稳定性](docs/稳定性验收.md) 和 [原生保护机制](docs/原生专注与计划联动.md)。

## 网页 Demo

下载 [0.3.0 发布页](https://github.com/carlkleinnw/FocusNest/releases/tag/v0.3.0-demo) 的网页包，解压后用已有 Python 在目录启动本地静态服务，或在源码目录运行 `启动Demo.cmd`（需先构建网页）。

网页使用虚拟时间、示例任务和固定 Python 采集规划，刷新重置，不能保存真实密钥或限制手机应用。Android 也可在设置中明确打开「AI 演示模式」体验固定样例；真实请求失败时不会自动切换样例冒充成功。

## 开发与验证

沿用 Flutter 3.41.9 / Dart 3.11.5、Riverpod、Flame、GoRouter；工具在D盘，项目和缓存优先E盘。安装或新增依赖前先检查磁盘余量。

```powershell
cd E:/FocusNest
$env:PUB_CACHE = 'E:/DeveloperCache/focus_pet/pub'
$env:GRADLE_USER_HOME = 'E:/DeveloperCache/focus_pet/gradle'
$env:ANDROID_USER_HOME = 'E:/DeveloperCache/focus_pet/android'
$env:JAVA_HOME = 'D:/Android/Android_studio/jbr'
flutter pub get
flutter analyze
flutter test
./android/check-focus-gate.ps1 -JavaHome $env:JAVA_HOME
flutter build apk --release
flutter build web --release --no-web-resources-cdn
```

模拟器集成测试要求先在测试模拟器开启本应用无障碍。Flutter 安装测试包后可能重置权限，测试等待60秒供宿主在模拟器设置中恢复；生产代码不自动授予权限。不要将测试指向正在使用的个人手机。

```powershell
flutter drive --driver test_driver/integration_test.dart --target integration_test/core_flow_test.dart -d emulator-5580
```

测试截图输出到被忽略的 `work/emulator-screens`。不同 Flutter 构建/测试命令依次执行，避免生成的插件注册文件互相覆盖。新克隆运行 `scripts/Install-ReleasePolicy.ps1`；每轮修改验证、提交并创建新附注标签，使用 `scripts/Publish-Version.ps1` 同推分支与标签，不移动旧标签。

## 架构与兼容

`lib/core` 保存模型、业务控制、规划与复盘校验；`lib/data` 保存平台适配和快照；`lib/pages` 每页一个核心功能；`lib/ui` 复用布局和编辑器。Android 原生保护、SQLite 和 Keystore/DeepSeek 通道位于 `android`。

本地快照升级为3，兼容读取2；原生保护通道保持v1，新增独立 Agent 通道。旧 `IntelligencePort` 的禁用实现保留，新功能使用 `PlannerGateway`，不把整个控制器或设备工具交给模型。详见 [扩展接口](docs/扩展接口.md)。

**回滚注意：** 0.2.7不能读取版本3快照，代码标签不恢复数据或已压缩明细。保留设备数据，在隔离环境验证回退，不直接覆盖旧格式或卸载清数据。签名私钥、密钥、数据库、个人截图、应用名单、缓存与构建产物均排除出Git；APK/网页包通过Release附件交付。
