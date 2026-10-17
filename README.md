# 伴学小屋 · FocusNest

Flutter / Android 学习计划与沉浸专注应用。当前源码为 **0.4.1+16 体验版**，围绕「目标 → 每日任务 → 沉浸执行 → 周期复盘」精简。

[发布与下载](https://github.com/carlkleinnw/FocusNest/releases) · [核心功能与准确性设计](docs/核心功能重构.md) · [版本记录](CHANGELOG.md) · [发布与回滚](docs/版本发布与回滚.md)

## 核心功能

- **AI Agent**：结合原目标和后补要求，由模型决定是否需要追问，不设固定轮数，直到关键需求明确；能直接查询、新增、修改、删除计划，并读取工具结果继续操作。支持预览草稿，也支持明确要求后直接保存完整安排。新整套计划最多366天、366项具体任务，检查已有安排和每日容量。见[Agent与分层计划](docs/Agent与分层计划.md)。
- **分层计划表**：日、周、月、季度、总目标分别展示，各层都能增删改查；按日期、目标和关键词筛选，周期的每日任务默认折叠。完成后手动勾选，记录真实确认时间。未完成任务自动顺延，保留原定日期、完成量和顺延次数。
- **沉浸专注**：从具体任务进入，或单独开启自由专注。常用时长与30—180分钟自定义时长共用原生保护、白名单、真实计时和两轮提前退出。计时结束不自动勾选任务。
- **复盘**：周、月、季度、年度逐级压缩。程序核算任务数、完成量、专注次数和时长，AI 选择可验证的任务原文并提出下一步建议；保存成功后才移除对应来源。失败保留未总结数据。
- **设置**：密钥填写/显隐/移除、模型选择与真实连接测试、每日时间、自动复盘、AI 演示模式和保护权限入口。

主导航只保留「计划、AI 规划、沉浸专注、复盘」。宠物/小屋等旧模块和数据保留兼容，不再占用主流程，宠物状态不再阻止专注。新装 Android 不注入示例计划；覆盖安装保留原本的数据和白名单，不清空用户会话。

## 开始使用

1. 安装 [0.4.1 APK](https://github.com/carlkleinnw/FocusNest/releases/tag/v0.4.1-demo)。手机覆盖安装前必须核对签名；不要卸载或清数据。本轮只在模拟器安装测试，未覆盖用户手机。
2. 点右上角「设置」，填 DeepSeek 密钥并保存；留空保存会保留已有密钥。点击「测试连接」，以实际结果为准。首次保存密钥会开启自动复盘，可随时关闭。
3. 在「AI 规划」描述目标并继续补充；需要时模型才追问。可先预览后确认，也可说“直接保存”，或让 AI 查询、调整、删除已有计划。手动管理请切换计划页的日／周／月／季度／总目标视图。
4. 进入任务的沉浸模式；保护权限需本人在系统设置开启。在「设置 → 专注保护与白名单」管理允许应用。
5. 完成工作后勾选任务。周期结束后生成复盘，或在设置中管理自动复盘。

密钥使用 Android Keystore 的 AES/GCM 加密，存储在本机私有区域，不进入源码、SQLite 快照或日志。保存后显示掩码，点击眼睛时才读取完整密钥到当前设置页；普通配置查询不返回密钥。API 请求直连 DeepSeek 官方 HTTPS 地址，会把目标对话、计划目录、按需查询的具体计划、安排容量和相关复盘事实发给 DeepSeek，产生账户费用；不发送应用名单。

自动复盘在应用运行/恢复时处理结束周期，失败不清明细，下次打开补处理关闭期间的积压，不承诺手机完全关闭时在午夜联网。压缩后保留精确统计及最多6条关键任务原文，父周期取代子周期，其他逐项内容无法恢复。旧版没有完成时间的任务保留并显示日期未知，不编造时间。

## 验证状态

本轮追问修复见[0.4.1验证记录](docs/validation/0.4.1-checks.json)：72项Flutter测试、23项原生规则检查；模拟器专项验证连续6轮追问、第4轮后SQLite重读、需求明确后的预览和保存，分别覆盖固定响应与真实DeepSeek。原有计划管理与最终安装包验证一并记录，仅使用合成样例，用户手机未操作。追问不设固定轮数，但仍受单次输入、累计上下文与网关请求大小保护。

[0.4.0历史验证记录](docs/validation/0.4.0-checks.json)保留此前66项Flutter测试、23项原生规则、上下文／增删改查、五层手动管理、专注启动／退出、顺延与复盘的证据，不能视为本轮全部重测。

[0.3.2完整模拟器调试报告](docs/模拟器完整调试.md)和[0.3.2记录](docs/validation/0.3.2-checks.json)保留此前30分钟自然到期、锁屏、划除与到期放行的证据；0.4未修改原生保护，也未重新运行完整30分钟与长锁屏测试。多品牌长后台仍需独立验证。

0.2.7 的 Xiaomi 15 原生保护与30分钟稳定性是历史证据，不能视为0.3.0在用户手机已验收。历史记录见 [0.2.7 稳定性](docs/稳定性验收.md) 和 [原生保护机制](docs/原生专注与计划联动.md)。

## 网页 Demo

在当前源码目录运行 `启动Demo.cmd`（需先构建网页，并保留 `scripts/serve_demo.py`）。新版启动器运行仅绑定127.0.0.1的本地AI服务，并避开没有AI接口的旧版静态服务。旧版0.3.0网页包不支持密钥输入，不应继续用作真实接口调试。

网页计划仍是虚拟时间和内存数据，刷新重置，不能限制手机应用。设置页允许填写DeepSeek密钥：只保存在本机服务进程内存，不写文件或浏览器存储；刷新页面可继续使用，关闭服务后清除。0.3.2保存后显示掩码，点眼睛可查看完整值，留空保存保留原值。保存配置不发起模型请求，首次保存关闭AI演示和自动复盘；之后由用户测试连接、发送目标或主动开启自动复盘。未配置密钥时仍可体验明确标识的固定样例，失败不会自动伪装成AI成功。静态托管只能体验UI，真实请求必须使用新版启动器；启动器要求本地接口bridgeVersion至少为2，不复用旧服务。

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

模拟器集成测试要求先在测试模拟器开启本应用无障碍。Flutter 安装测试包后可能重置权限，套件开始前等待120秒供宿主在模拟器设置中恢复，避免运行中改变语义句柄基线；生产代码不自动授予权限。不要将测试指向正在使用的个人手机。

```powershell
flutter drive --driver test_driver/integration_test.dart --target integration_test/core_flow_test.dart -d emulator-5580
```

0.4真实Agent语义与五层管理场景使用 `integration_test/agent_management_test.dart`。本机服务保存密钥后，反向映射端口，并传入 `--dart-define=LIVE_AGENT=true --dart-define=HOST_AGENT_PORT=实际端口`；该套件通过Android原生网关请求，不能指向个人手机。真实AI是否追问由模型判断，不以“第一轮必定追问”作为验收条件。

0.4.1追问专项使用`integration_test/clarification_test.dart`：默认测试固定响应，传入同样的`LIVE_AGENT`和本机端口可额外运行真实DeepSeek场景。用户在合成对话中逐步补充仍未明确的条件，验证6轮追问、SQLite重读与最终预览保存，不以固定问卷决定生产行为。

真实API测试需本人先在本地服务保存密钥。将该服务端口反向映射给测试模拟器，再传入`LIVE_AGENT=true`和`HOST_AGENT_PORT`启用，默认测试仍用固定样例；`CHECK_NATIVE=true`额外验证Android Keystore和原生HTTPS，并让规划与复盘使用原生网关。仅在模拟器没有配置时从本机服务内存导入，已有Android密钥不替换；不把密钥作为测试参数或写入文件。测试内部恢复原任务快照，但Flutter测试运行器可能卸载测试包并清理模拟器数据，因此只能用于可清理的测试模拟器，不能指向个人设备。

集成测试后构建正式APK，使用`flutter build apk --release`保留工具生成步骤；不要在此切换时加`--no-pub`，否则Flutter 3.41.9可能保留包含integration_test的开发注册文件而导致Java编译失败。Flutter构建、分析和测试命令依次执行。

测试截图输出到被忽略的 `work/emulator-screens`。不同 Flutter 构建/测试命令依次执行，避免生成的插件注册文件互相覆盖。新克隆运行 `scripts/Install-ReleasePolicy.ps1`；每轮修改验证、提交并创建新附注标签，使用 `scripts/Publish-Version.ps1` 同推分支与标签，不移动旧标签。

## 架构与兼容

`lib/core` 保存模型、业务控制、规划与复盘校验；`lib/data` 保存平台适配和快照；`lib/pages` 每页一个核心功能；`lib/ui` 复用布局和编辑器。Android 原生保护、SQLite 和 Keystore/DeepSeek 通道位于 `android`。

本地快照升级为3，兼容读取2；原生保护通道保持v1，新增独立 Agent 通道。旧 `IntelligencePort` 的禁用实现保留，新功能使用 `PlannerGateway`，不把整个控制器或设备工具交给模型。详见 [扩展接口](docs/扩展接口.md)。

**回滚注意：** 0.2.7不能读取版本3快照，代码标签不恢复数据或已压缩明细。保留设备数据，在隔离环境验证回退，不直接覆盖旧格式或卸载清数据。签名私钥、密钥、数据库、个人截图、应用名单、缓存与构建产物均排除出Git；APK/网页包通过Release附件交付。
