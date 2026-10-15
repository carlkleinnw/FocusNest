# 最近任务划除后的专注保护：开源源码核对

研究日期：2026-10-15。范围是开源项目实际实现、权限条件与适用边界；本文件的源码研究步骤没有安装这些应用、改动手机权限或执行它们的安装/修复脚本。FocusNest 本轮由主代理执行的手机设置对照及最终验收另见验证记录，不以本研究代替。

研究阶段的「最终 APK 待验收」保留在下文作为当时证据边界；后续最终 0.2.7+11 的条件性通过、反向对照和完整范围见[最终真机记录](../validation/0.2.7-device-checks.json)。

## 结论与证据边界

本次读取的成熟项目没有提供“普通应用权限下，被 Xiaomi Android 16 的 SwipeUpClean 执行包级 FORCE STOP 后仍保证自主恢复”的源码证据。前台服务、独立进程、START_STICKY/START_REDELIVER_INTENT、WorkManager/JobScheduler 都是降低普通进程死亡影响或恢复的手段，不能由它们的存在推出抗强停。DetoxDroid 与 Curbox 的源码还明确承认强停边界。[Detox 强停说明][detox-force] [Curbox watchdog][cur-watch]

随后主代理回传了本机自启动开关对照，支持另一个更窄的可行方向：**通过厂商可见授权，避免最近任务划除进入包级 FORCE STOP，使原有系统重绑机制有机会恢复保护**。这与“真正强停之后自行抵抗强停”不同；详细的已知观测、未知事项及最终 APK 待验收状态见下文。

更强限制来自额外管理能力：OpenTimeLimit 的 Device Owner 系统挂起；DetoxDroid 的 Shizuku shell `pm suspend`。这改变了执行主体和恢复责任，不能直接当作现有无障碍保护的补丁。尤其 shell 挂起会在控制进程死亡后继续存在，结束专注时若 Shizuku 不可用就可能无法放行。[TimeLimit 挂起实现][otl-suspend] [Detox 挂起实现][detox-suspend]

普通 active Device Admin 与 Device Owner 必须分开。前者可以由用户在系统确认页激活；后者需要设备管理部署条件。代码里出现 DeviceAdminReceiver 或 BIND_DEVICE_ADMIN 不证明应用已经是 Device Owner；声明签名权限也不等于取得它。AOSP 设置页对 active admin 的强停按钮处理，不证明 Xiaomi SwipeUpClean 必然遵守；要以本机划除行为验收。[TimeLimit 管理级别][otl-admin] [TimeLimit 普通管理员申请][otl-request] [Detox 两种身份检查][detox-admin]

## 固定的源码快照

源仓浅克隆保存在项目已忽略的 `work/source-research/`，未安装依赖。以下哈希由本地 `git log -1` 核对；不是对浮动 main/master 的引用。

| 项目 | 固定提交 | 提交日期 | 作用与许可 |
| --- | --- | --- | --- |
| OpenTimeLimit，作者官方 Codeberg 仓 | `fad71e34adf03f57d945b97ca5427a27e8d9d1eb` | 2024-07-29 | Release 7.1.0；GPL v3。[许可证][otl-license] |
| flxapps/DetoxDroid | `263df3ded046a8e5bb1ffea0e5806260bd68b01e` | 2026-10-13 | 当前 v2.9.1 源码；GPL v3。[许可证][detox-license] |
| nethical6/curbox | `90444ce3fa0c0d86781368166b80f9337bf5830a` | 2026-10-15 | DigiPaws 官方后续项目；GPL v3 或更新版本声明。[许可证][cur-license] [声明][cur-license-readme] |
| haku4130/hyperos-accessibility-guard | `959ce7cd924c35847426d0f8e730bf90bf25ba1b` | 2026-09-28 | 小型单设备案例，不能作为成熟抗强停证明；MIT。[许可证][guard-license] |
| nethical6/digipaws | `1f89542ebefad0786942f25a255563e594962c17` | 2026-06-09 | 当前仓仅剩停更及迁移 README，所以本轮不冒称读取了 DigiPaws 当前运行源码，改查 Curbox。[迁移声明][digi-move] |

本轮仅研究机制，没有复制这些 GPL 项目的运行代码进入 FocusNest。后续若引入实际源码，应先核对项目及引入文件的许可、版权告知与分发义务。

## OpenTimeLimit：明确区分普通模式与设备管理模式

1. `BackgroundService.setStatusMessage()` 调用本项目自己的 `isBackgroundActivityRestricted()` 分流：受限时仅发普通通知，否则 `startForegroundService()`；`onStartCommand()` 调用 `startForeground()` 并返回 `START_REDELIVER_INTENT`。该分流函数在 API 34+ 检查 `isAdminActive()`，未激活就返回受限；这是 **OpenTimeLimit 此版本的实现判断**，不是“Android 14 的所有前台服务都要设备管理员”的平台结论。该快照 targetSdk 33，BackgroundService 的 Manifest 没声明 FGS 类型，不能把它直接当作本项目 targetSdk/FGS 配置示范。该文件没有服务级 `onTaskRemoved()` 自重启实现。[后台服务][otl-bg] [构建配置][otl-build] [服务声明][otl-service]
2. 无障碍服务只保存实例、提供 GLOBAL_ACTION_HOME；`onAccessibilityEvent()` 不处理事件。不能把它的应用识别/拦截架构误认为完全依赖无障碍窗口事件。[无障碍服务][otl-access]
3. `AdminStatus.getAdminStatus()` 先检查 `isDeviceOwnerApp()`，再检查 `isAdminActive()`，分别返回 DeviceOwner 与 SimpleDeviceAdmin。普通管理员通过 `ACTION_ADD_DEVICE_ADMIN` 可见确认页申请。[身份判断][otl-admin] [申请路径][otl-request]
4. `setSuspendedApps()` 只有 DeviceOwner 且 API 24+ 时才调用 `DevicePolicyManager.setPackagesSuspended()`；普通管理员不行。`RunInBackgroundPermission.trySelfGrant()` 同样先要求 Device Owner 才尝试 app-op。[系统挂起][otl-suspend] [后台权限][otl-bgpermission]
5. `BOOT_COMPLETED` 接收器只初始化逻辑并报告重启，不含绕过 stopped 状态的机制。[开机接收器][otl-boot]

适用判断：借鉴权限等级和“系统挂起/实时覆盖”两条执行路径的明确区分。当前快照是 2024 年版本，不能据此保证 Android 16 与 HyperOS 的行为。Device Owner 需要部署环境验证，不能为了本轮修复改造已有个人手机、移除账户或清除数据。

Android 官方文档把 Device Admin 列为 `systemExempted` FGS 的可选资格之一，并非唯一资格；`specialUse` 的类型专属运行时前置条件为无，仍须满足通用 FGS 规则及正确声明。因此 OpenTimeLimit 的管理员分流、Device Owner 的后台 app-op 尝试、FocusNest 现有 specialUse 前台服务是三件事，不可混为同一必需权限。[Android 官方 FGS 类型说明][android-fgs-types]

## DetoxDroid：前台无障碍、健康检查与额外的 shell 挂起

1. `onStartCommand()` 返回 `START_STICKY`；`onTaskRemoved()` 只有日志和 `super`，没有闹钟、强制重启或其他保证。`onServiceConnected()` 调度 watchdog。[服务生命周期][detox-life]
2. 前台通知使用 `FOREGROUND_SERVICE_TYPE_SPECIAL_USE`，只在用户启用 keepalive、暂停功能或紧急制动等条件满足时启用。Manifest 声明相应 FGS 权限、无障碍服务的 BIND_ACCESSIBILITY_SERVICE 绑定保护。[前台服务][detox-fgs] [Manifest][detox-manifest]
3. watchdog 每 15 分钟执行，检查“secure 设置启用”和进程内服务实例是否存在；有 WRITE_SECURE_SETTINGS 才尝试自动 activate，否则最终通知用户。它没有即时连续保护保证，源码明确接受两个连续失败检查后再提醒。[调度][detox-schedule] [检查与修复][detox-watch]
4. activate 会读取已有服务列表、追加自身、去重并写回；这比全局清空安全，但仍需要 WRITE_SECURE_SETTINGS，且源码的幂等启用不证明一定可以让系统 crashed service 重绑定。[服务控制][detox-control]
5. `DetoxDroidApplication` 的强停说明写出：包进入 stopped 状态后，boot 与 watchdog 都不会执行，用户重新打开应用才有机会运行恢复代码。这与“START_STICKY 无敌保活”说法相反。[强停边界][detox-force]
6. `AppSuspender` 通过可用且获授权的 Shizuku 执行 `pm suspend` / `pm unsuspend`，执行前持久记录包名，失败时保留记录；源码直接指出挂起状态跨进程死亡、重启、Shizuku 会话而存在，释放需额外执行。仅 shell 发出命令后，不需要控制应用持续活着才能保持已有挂起；但自动结束与应急放行仍依赖可运行的控制端与权限。[完整实现][detox-suspend]
7. 普通 `isAdminActive()` 与 Device Owner 检查分别实现；`setUninstallBlocked()` 先验证后者。普通设备管理员不具有该函数所需身份。[管理能力][detox-admin]

适用判断：可借鉴健康状态、保留原服务列表、停止时恢复状态的设计。不能把 15 分钟 watchdog 包装为持续防护。Shizuku 挂起虽然是不同的系统执行方向，但会增加安装授权、会话可用性、必要应用保护、结束与紧急解除的完整工程范围；本轮没有将其接入现有专注。

## Curbox：独立进程不是包级强停隔离

1. 应用限制无障碍服务放在 `:app_blocker_service` 进程；连接后启动 specialUse FGS。独立进程隔离 UI 进程问题，但服务仍属于同一包。[服务声明][cur-manifest] [生命周期][cur-base]
2. `ServiceWatchdogJob` 使用持久化 Job，每 15 分钟运行；代码注释直接说明不能对抗 force stop。不要把 `setPersisted(true)` 理解为强停以后仍运行。[watchdog][cur-watch]
3. `ServiceProtectionManager` 只有 Shizuku binder 存在且已授权才可 silent heal，执行添加 Doze 白名单、设置 RUN_IN_BACKGROUND/RUN_ANY_IN_BACKGROUND，以及把自身组件合并进已有 enabled_accessibility_services。Shizuku 是额外 shell 身份，不是安装应用就有的普通权限。[修复实现][cur-manager]
4. 同文件第 125 行注释称 Device Owner “survives force stop”，但实际第 129-133 行只是发送 `dpm set-device-owner`；这不是 Xiaomi 强停验收证据，更不能用这条注释跳过设备条件。项目自己的总注释和 watchdog 又明确承认强停限制。[同文件][cur-manager]
5. `AppSuspendHelper.suspendApps()` 当前实现的调用被注释掉，第 11 行直接保留“中途关闭 Shizuku 会 forever suspend”的 TODO。因此不能声称它当前稳定使用 suspend 完成专注。释放方法仍存在，也不能据此推出挂起流程已启用。[实际代码][cur-suspend]
6. ordinary admin 的用户激活与 Device Owner shell 部署分开；普通 `AdminReceiver` 的 `onDisableRequested()` 只是返回警告文字，不会自动变成拒绝停用的系统权限。[身份帮助类][cur-admin] [接收器][cur-receiver]

适用判断：可参考独立进程、状态提示、合并服务列表。未找到支持“同包多进程能抵抗 SwipeUpClean FORCE STOP”的证据；系统将整个包停掉时，多进程本身不能作为保证。

## HyperOS accessibility guard：证据采集思路可用，修复实现不可照搬

1. `GuardService` 是前台 Service，注册 ContentObserver 监视两项 secure 设置，并在亮屏/解锁时检查，`onStartCommand()` 返回 START_STICKY；HealthWorker 每 15 分钟再检查。没有独立于该包 stopped 状态的守护主体。[服务][guard-service] [worker][guard-worker]
2. 安装脚本需要 ADB 授予 WRITE_SECURE_SETTINGS、PACKAGE_USAGE_STATS、DUMP、GET_APP_OPS_STATS，并设置 SYSTEM_ALERT_WINDOW app-op、通知权限、Doze 白名单；还要求人工开启厂商自启动。脚本自身记录 Xiaomi 的 USB 调试安全设置/USB 安装前提。这些只是该项目脚本要求，是否能在用户本机授予必须另测，不能凭 manifest 认定已获授权。[安装脚本][guard-install] [Manifest][guard-manifest]
3. `AccessibilityRepairer.repair()` 第 28 行关闭无障碍全局开关，第 31 行把整个 ENABLED_SERVICES 写为空，第 37 行只写回硬编码 NoScroll 组件。**没有保存或恢复其他服务，必然会把原列表中其他服务移除**；不仅是短暂停顿。若中途写入失败，还可能停留在全局关闭/列表清空状态，函数没有完整回滚。[修复源码][guard-repair]
4. `AccessibilityRuntimeProbe` 尝试通过 dumpsys 读取 crashed/bound，明确承认 DUMP/SELinux 的设备依赖。`AccessibilityStateReader.isHealthy()` 实际仅要求设置正确且 `isCrashed()!=true`；unknown 会被视为健康，而且这个判断没有要求 bound 必须为 true。不能把该“healthy”标签当作已成功拦截应用的实测。[运行状态读取][guard-probe] [健康判断][guard-state]
5. 修复成功后只是标记“需要打开受保护应用”，到下一次解锁时借助覆盖权限请求 startActivity；主代码也承认缺少覆盖权限就要通知用户。这说明 settings 修复不等于业务保护恢复。[解锁恢复路径][guard-reopen]
6. README 的 force-stop 限制与其实际 START_STICKY/WorkManager 架构一致，但单设备案例与作者注释都不能代替本机验证。[作者限制说明][guard-limit]

适用判断：保留“先采证、再修复”“设置/绑定/覆盖/业务效果分开”思路。不要安装它来保护 FocusNest，不要运行其全局重置命令，不要复制清空服务列表的逻辑。它也不提供无权限抗包级强停能力。

## 最近任务卡片与普通管理员的补充核对

已搜索上述三套成熟实现的 Kotlin/Java 源码，没有找到 `AppTask.setExcludeFromRecents()`、`appTasks` 动态隐藏主任务的方法。它们确实给警告/锁定/辅助 Activity 设置 `excludeFromRecents=true`，但主入口保留：OpenTimeLimit MainActivity 与 LockActivity、DetoxDroid MainActivity 与辅助页、Curbox FragmentActivity 与 WarningActivity 都可对照 Manifest。**这些不是“专注时隐藏主卡片防误划”的成熟应用案例**。[TimeLimit 任务声明][otl-tasks] [Detox 任务声明][detox-tasks] [Curbox 任务声明][cur-tasks]

因此，若 FocusNest 采用动态排除主任务，应明确它是防止最近任务误划的另一个交互方案，验收其开始/结束/重开与恢复卡片行为，不能称“划除后保护仍存活”，也不能据此宣称通过原始强停场景。

本轮没有找到成熟项目源码证明：仅激活 legacy Device Admin，Xiaomi SwipeUpClean 就一定不再 FORCE STOP。OpenTimeLimit 确实支持 SimpleDeviceAdmin，Detox/Curbox 也有 ordinary admin 路径；能否改变当前手机划除行为，仍要用可见授权和最终安装包验证。不能把 Device Owner 的系统挂起/设备策略能力归到普通管理员名下。

## 本机自启动对照：支持避免强停，尚非最终包验收

证据来源：主代理在 2026-10-15 回传的本人授权可见 UI 操作及现场系统观测。本研究子任务没有操作手机，也没有独立读取完整原始采集文件；最终结论应引用主验证记录中的原始证据及最终安装包标识。以下仅记录收到的对照，不宣称已完成发布验收。

两次均为 `0.2.6+8`，省电已经设置为无限制。自启动操作由系统设置 UI 完成，没有脚本直接授予厂商 app-op，也没有 Device Owner、Shizuku 或 root 新能力作为此次变化的解释。

| 时间（北京时间）与条件 | 划除后的系统观测 | 已观测结果 |
| --- | --- | --- |
| 21:04:29，自启动 UI 关闭，MIUI OP 10008 为 ignore | `USER REQUESTED`、subreason 21、`FORCE STOP`；包 `stopped=true`；无障碍解绑 | 已知失败路径仍可重现；仅“省电无限制”不足 |
| 21:06:52，仅通过系统 UI 开启自启动，10008 为 allow，再通过可见 UI 恢复无障碍，然后同样上划单张卡片 | `OTHER KILLS BY SYSTEM` reason 13，description `SwipeUpClean`；`stopped=false`；出现新 PID，无障碍已绑定、无 crashed | 未重新打开 FocusNest，打开受限制测试应用时得到 `FocusNestLockReminder` |

独立审阅判断：这组对照支持把厂商自启动作为**当前手机、当前系统和当前构建的可行配置条件**；它与已有普通杀进程恢复机制相容。第二次仍有进程死亡，只是没有进入第一种包级 stopped 状态，随后恢复业务提醒。不存在“本轮已突破 Android force-stop 边界”的证据。

尚不能证明：所有 Xiaomi/HyperOS 机型都同样处理；10008 的私有编号跨版本含义固定；后台清理、重启、一键清理与单卡上划等价；恢复间隙为零；设置页真正“强行停止”后也会恢复；最终新 APK 已通过。两次观测也不能单独替代完整重复实验或严格的长期因果验证。应继续对最终安装 APK 记录授权状态、划除动作、exit-info、stopped、绑定状态及实际提醒，并分别验收原始核心场景和其他交互。

小米官方《自启动权限管理说明》（页面更新于 2024-09-25，本轮读取）说明默认不允许应用自启动，需求应告知用户，由用户自行设置允许。这支持在权限引导中解释并打开可见设置；**官方页面没有保证最近任务划除后存活，也没有说明此次 SwipeUpClean 的具体分支或 10008 映射**，不得引用为通用存活承诺。[小米官方自启动说明][xiaomi-autostart]

## 交付判据

- 后台机制的参考实现存在，与“已经在本机解决”是两回事。
- 若最终 APK 的最近任务划除测试仍显示包 FORCE STOP、无障碍解绑、被限制应用直接打开，应保留候选状态，不能用重开应用后的恢复冒充划除后的持续保护。
- 必须同时核对：用户真实专注仍在、必要应用放行、提醒显示和持续遮挡、知道了返回桌面、重复打开、横竖屏、专注结束自动放行。引入管理员/额外权限时再核对其撤销方式和前置条件。

[otl-license]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/LICENSE#L1-L5
[detox-license]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/LICENSE#L1-L5
[cur-license]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/LICENSE#L1-L5
[cur-license-readme]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/README.md#L142-L144
[guard-license]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/LICENSE#L1-L21
[digi-move]: https://github.com/nethical6/digipaws/blob/1f89542ebefad0786942f25a255563e594962c17/README.md#L1-L8
[otl-bg]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/java/io/timelimit/android/integration/platform/android/BackgroundService.kt#L34-L150
[otl-access]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/java/io/timelimit/android/integration/platform/android/AccessibilityService.kt#L23-L56
[otl-admin]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/java/io/timelimit/android/integration/platform/android/AdminStatus.kt#L25-L44
[otl-request]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/java/io/timelimit/android/integration/platform/android/AndroidIntegration.kt#L715-L738
[otl-suspend]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/java/io/timelimit/android/integration/platform/android/AndroidIntegration.kt#L451-L466
[otl-bgpermission]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/java/io/timelimit/android/integration/platform/android/RunInBackgroundPermission.kt#L24-L41
[otl-boot]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/java/io/timelimit/android/integration/platform/android/receiver/BootReceiver.kt#L23-L30
[otl-tasks]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/AndroidManifest.xml#L60-L97
[detox-life]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/system_integration/DetoxDroidAccessibilityService.kt#L274-L334
[detox-fgs]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/system_integration/DetoxDroidAccessibilityService.kt#L550-L576
[detox-manifest]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/AndroidManifest.xml#L123-L145
[detox-schedule]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/workers/ServiceReliabilityScheduler.kt#L35-L49
[detox-watch]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/workers/ServiceWatchdogWorker.kt#L40-L97
[detox-control]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/system_integration/AccessibilityServiceController.kt#L29-L69
[detox-force]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/DetoxDroidApplication.kt#L130-L143
[detox-suspend]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/system_integration/AppSuspender.kt#L9-L79
[detox-admin]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/system_integration/DetoxDroidDeviceAdminReceiver.kt#L13-L41
[detox-tasks]: https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/AndroidManifest.xml#L71-L111
[cur-manifest]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/AndroidManifest.xml#L87-L104
[cur-base]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/java/neth/iecal/curbox/services/BaseBlockingService.kt#L38-L118
[cur-watch]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/java/neth/iecal/curbox/services/ServiceWatchdogJob.kt#L28-L88
[cur-manager]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/java/neth/iecal/curbox/utils/ServiceProtectionManager.kt#L18-L137
[cur-suspend]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/java/neth/iecal/curbox/utils/AppSuspendHelper.kt#L9-L28
[cur-admin]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/java/neth/iecal/curbox/utils/AntiUninstallManager.kt#L21-L38
[cur-receiver]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/java/neth/iecal/curbox/receivers/AdminReceiver.kt#L8-L12
[cur-tasks]: https://github.com/nethical6/curbox/blob/90444ce3fa0c0d86781368166b80f9337bf5830a/app/src/main/AndroidManifest.xml#L36-L61
[guard-service]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/app/src/main/java/io/github/haku4130/noscrollguard/service/GuardService.kt#L39-L90
[guard-worker]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/app/src/main/java/io/github/haku4130/noscrollguard/work/HealthWorker.kt#L16-L32
[guard-install]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/install.sh#L8-L88
[guard-manifest]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/app/src/main/AndroidManifest.xml#L5-L21
[guard-repair]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/app/src/main/java/io/github/haku4130/noscrollguard/repair/AccessibilityRepairer.kt#L16-L44
[guard-probe]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/app/src/main/java/io/github/haku4130/noscrollguard/state/AccessibilityRuntimeProbe.kt#L15-L37
[guard-state]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/app/src/main/java/io/github/haku4130/noscrollguard/state/AccessibilityStateReader.kt#L25-L45
[guard-reopen]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/app/src/main/java/io/github/haku4130/noscrollguard/service/GuardService.kt#L241-L286
[guard-limit]: https://github.com/haku4130/hyperos-accessibility-guard/blob/959ce7cd924c35847426d0f8e730bf90bf25ba1b/README.md#L287-L299
[otl-build]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/build.gradle#L24-L30
[otl-service]: https://codeberg.org/timelimit/opentimelimit-android/src/commit/fad71e34adf03f57d945b97ca5427a27e8d9d1eb/app/src/main/AndroidManifest.xml#L146-L153
[android-fgs-types]: https://developer.android.com/develop/background-work/services/fgs/service-types#system-exempted
[xiaomi-autostart]: https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1624
