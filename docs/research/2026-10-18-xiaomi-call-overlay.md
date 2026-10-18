# 小米真机来电与电源菜单遮挡：0.4.3 修正

0.4.2 的模拟器通过记录仍保留；随后经用户授权在 Xiaomi 15 / Android 16 / HyperOS 3.0.305 真机复验，发现它不足以解决本机故障。本记录说明新增证据，不将旧模拟器结果视为真机通过。

## 实际原因与实现

1. 小米独立通话组件与系统拨号器同签名，却与 Android 平台签名不同。只校验平台签名漏掉了真正的通话 UI。现在要求系统预装且与平台或当前系统／默认拨号器同签名；动态查询仍核验 `BIND_INCALL_SERVICE` 与通话 UI 元数据，系统拨号器角色本身继续受信任。不凭包名或预装标记单独放行。
2. 本机电源菜单未向无障碍服务稳定暴露可读取的根包名。继续依赖“识别后撤去高层无障碍覆盖”无法保证电源菜单可用。参考 [Mindful 与 DetoxDroid 的实际普通悬浮窗实现](2026-10-18-call-and-system-surfaces.md)，改用不获取键盘焦点的普通应用悬浮窗，保留可触摸的应用内容遮挡。
3. 仅把窗口属性改成 `TYPE_APPLICATION_OVERLAY` 仍然失败。真机窗口属性虽显示普通悬浮窗，窗口令牌仍是 `2032`（无障碍覆盖）。[AOSP AccessibilityService](https://android.googlesource.com/platform/frameworks/base/+/main/core/java/android/accessibilityservice/AccessibilityService.java) 的窗口管理器会设置服务默认令牌；[WindowManagerImpl](https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/view/WindowManagerImpl.java) 在无显式令牌时沿用它。最终通过 applicationContext 取得窗口管理器，添加、移除和屏幕测量使用同一实例。最终包在真机确认实际令牌为 `2038`，之后物理长按电源时菜单完整显示，用户亦确认可见。
4. 进一步转屏复验发现仅用 Application Context 会沿用错误的可用尺寸；初次手机修改旋转设置并未使计算器真正转屏，不计为横屏通过。最终采用 [Android 官方 WindowContext](https://developer.android.com/reference/android/content/Context#createWindowContext(int,%20android.os.Bundle))，从应用显示上下文创建普通悬浮窗上下文，窗口管理器、所有视图和资源共用该实例，使配置跟随窗口区域变化。
5. 使用 `FLAG_NOT_FOCUSABLE`，并在 Android 30+ 按系统栏与屏幕缺口留出边界，使状态栏、通知入口和导航条可用。提醒诊断从“获得焦点”改为“已附着且可见”，不再把不抢焦点误判为显示失败。

[Android 官方窗口契约](https://developer.android.com/reference/android/view/WindowManager.LayoutParams)说明普通应用悬浮窗位于关键系统窗口之下；不获取焦点并不等于不能接收提醒自身区域的触摸。系统可以调整普通悬浮窗的显示；这项能力优先保证电话和系统操作可用，不承诺设备所有者模式的强制锁定。

## 微信与QQ接听后的补充适配

用户在0.4.3+23确认系统电话正常，但微信／QQ接听后仍被提醒遮住。微信和QQ的普通应用包不属于系统拨号器，不能因为其中存在通话功能就将整个包加入必要应用。

本机实际任务组件记录确认微信通话位于 `com.tencent.mm.plugin.voip.ui.VideoActivity`；只读取安装APK的Manifest组件声明，核对QQ当前安装包中的 `com.tencent.av.ui.AVActivity` 与 `com.tencent.av.ui.VideoInviteActivity`。不反编译业务代码、不读取数据库或账号内容。开源参考项目所用普通覆盖层和系统拨号器豁免不能单独解决这类应用内通话；未找到已验证可直接套用的微信／QQ修复。

新增策略只接收这两个包的窗口状态事件，按[Android窗口事件元数据](https://developer.android.com/reference/android/view/accessibility/AccessibilityEvent)取得页面类标识，再向PackageManager核实它是该包已注册Activity。事件绑定实际窗口ID与根包名；只对真正选中的前台通话窗口放行，不给同包后台通话、普通聊天、朋友圈或视频页豁免。窗口消失立即清除已匹配记录，尚未匹配的事件限时1500ms；轮询不能让过期事件复活。页面类信息只在内存保留，不读事件正文、联系人、输入或通话内容，不加入诊断导出。

它覆盖已核实组件的来电和通话页，不提供绕过白名单进入聊天列表主动选择联系人拨出的能力；主动呼叫应在会话开始前设置本人需要的白名单。应用更新变更组件、群通话和其他VoIP产品需分别核对。服务重连后若没有新的页面事件，仍保留未知窗口限制；用户可通过系统通话通知重新进入通话页触发识别，不承诺读取不到页面标识时猜测放行。

## 权限与数据

新增 `SYSTEM_ALERT_WINDOW`，通过可见系统设置由用户授权；启动保护前同时检查无障碍连接、窗口访问与悬浮窗权限。缺少权限时不先写入专注规则或启动保护。权限指引支持逐项进入设置，拒绝后仍可使用计划功能。未新增电话状态、通话记录、接听、挂断权限；没有自动接听、挂断或关机代码。

覆盖安装沿用原签名，不卸载、不清数据、不导出手机数据库。测试只使用本轮创建的合成专注；来电观测只保留状态和窗口标识，不保存号码、联系人或通话页面截图。

最终同一 APK 的实测范围、失败尝试与未测边界见 [0.4.3 验收记录](../validation/0.4.3-checks.json)。
