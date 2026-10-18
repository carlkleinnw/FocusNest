# 来电与电源菜单被专注提醒遮挡：源码核查与修复

日期：2026-10-18。仅操作 Android 36.1 测试模拟器，未操作个人手机。

## 已复现的失败链

0.4.1+16 开启30分钟自由专注，打开未允许的 Chrome，提醒显示后长按电源：系统已创建 `TYPE_SYSTEM` 电源菜单，提醒仍以 `TYPE_ACCESSIBILITY_OVERLAY` 覆盖并持有焦点。旧版只选择 `TYPE_APPLICATION`，把系统窗口当成未知；未知窗口保留提醒，所以菜单无法看到和操作。

来电可能以 SystemUI 顶部横幅出现，也可能进入默认拨号器以外的独立通话包。初次候选0.4.2+17已解决全屏电源菜单，但模拟器来电横幅只有664×368像素，不经过屏幕中心且没有焦点，仍被遮挡。这是失败的候选测试，未作为成品交付。最终包扩展为识别有实际交互面积的可信系统窗口。

## 参考项目与适用性

本次在线重新读取固定提交的实际源码，没有复制第三方运行代码。

| 参考 | 实际实现与权限 | 本项目判断 |
| --- | --- | --- |
| Mindful `b6eb68d500463c54e1127b6cc7ad540f02ae0c8e` | [必要应用识别](https://github.com/akaMrNagar/Mindful/blob/b6eb68d500463c54e1127b6cc7ad540f02ae0c8e/android/app/src/main/java/com/mindful/android/helpers/device/ImpSystemAppsHelper.kt#L28-L58)解析默认桌面、拨号器；[提醒窗口](https://github.com/akaMrNagar/Mindful/blob/b6eb68d500463c54e1127b6cc7ad540f02ae0c8e/android/app/src/main/java/com/mindful/android/services/tracking/OverlayManager.kt#L219-L232)使用普通应用悬浮窗、`FLAG_NOT_FOCUSABLE`。GPL-2.0。 | 参考必要应用豁免及让系统交互优先的原则。普通应用悬浮窗需要另行授权，不能直接替换本项目现有无障碍覆盖层。其默认拨号器豁免也不能证明覆盖所有厂商独立通话包。 |
| DetoxDroid `263df3ded046a8e5bb1ffea0e5806260bd68b01e` | [OverlayService](https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/system_integration/OverlayService.kt#L79-L100)同样使用普通悬浮窗及不获取焦点标记；[释放](https://github.com/flxapps/DetoxDroid/blob/263df3ded046a8e5bb1ffea0e5806260bd68b01e/app/src/main/java/com/flx_apps/digitaldetox/system_integration/OverlayService.kt#L143-L163)在关闭和销毁时移除窗口。GPL-3.0。 | 参考避免占住系统交互、明确撤除责任；未引入其权限、管理员、Shizuku或守护架构。 |

这些有公开发布和持续使用记录的项目提供设计参考，不能代替本项目最终APK的验证，也未发现可直接证明本项目故障已解决的现成补丁。

## 官方依据与本项目实现

- [AccessibilityWindowInfo.TYPE_SYSTEM](https://developer.android.com/reference/android/view/accessibility/AccessibilityWindowInfo#TYPE_SYSTEM)：系统交互窗口与普通应用、输入法、无障碍覆盖层是不同类型。读取窗口根包名、类型、层级、焦点、矩形，不读页面正文和子节点。
- [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager#getSystemDialerPackage())分别提供用户默认拨号器和系统拨号器；二者可能不同。
- [InCallService](https://developer.android.com/reference/android/telecom/InCallService)提供通话UI服务契约。查询带 `IN_CALL_SERVICE_UI` 元数据、要求 `BIND_INCALL_SERVICE` 的服务；只信任默认／系统拨号器或平台签名组件。补充平台签名核验后的旧式独立通话UI和Telecom包，不凭名称包含phone/call或普通系统标记放行。
- 必要系统组件每5秒刷新，用户白名单继续按会话冻结，不改SQLite格式和专注期限。
- 最高层的可信系统交互面优先于普通应用，撤掉提醒；系统操作结束，250ms常规巡检和窗口事件重新识别受限应用并拦截。普通输入法、自己的覆盖层、未知窗口和未受信任悬浮窗不获得豁免。
- 无焦点系统窗口的短边至少96dp才作为交互面，排除常驻的细状态栏和横屏导航条，同时覆盖顶部来电横幅。已有焦点／活动标记的可信系统窗口不受该尺寸条件限制。
- SystemUI通知面板／较大的系统横幅也享有同样优先级；显示期间底层应用可能可见，关闭后恢复限制。这是让系统操作始终可用的明确取舍，不读取通知内容来猜测是否为电话。
- 保留现有无障碍覆盖层与“知道了”确认回桌面流程，无新增电话状态、通话记录、接听电话或悬浮窗权限。服务没有替用户接听、挂断、关机或重启的代码。

## 验证边界

本轮结果见[0.4.2检查记录](../validation/0.4.2-checks.json)。模拟GSM来电用于验证真实系统电话UI、接听／拒接／挂断与拦截恢复。电源菜单测试核对可见和可操作，未实际关机。模拟器不包含小米独立通话UI；其识别路径已经补齐，但小米真机、运营商电话、微信／QQ网络通话及其他厂商ROM仍需分别实测，不能以模拟器通过代替。厂商小于96dp且不获得焦点的横幅、无法读取包名的系统窗口仍可能保留遮挡。个人手机未覆盖安装。

## 复验步骤

1. 仅在隔离模拟器安装同签名APK，确认无障碍已绑定。在应用中开启30分钟自由专注，打开未允许的测试应用，观察提醒持续显示并点击“知道了”核实桌面，再次打开应继续拦截。
2. 提醒显示时长按电源，核对关机／重启按钮可见，按返回键关闭后恢复提醒。不要实际拨打紧急号码。
3. 用模拟器GSM接口注入合成号码来电，核对顶部横幅可见；点击系统接听按钮，核实Telecom为ACTIVE和通话页显示。通话中再打开／关闭电源菜单，然后点击系统挂断按钮，返回受限应用应继续拦截。
4. 再次注入来电，点击拒接，核实无活动通话并恢复拦截。分别旋转横竖屏，等窗口和截图稳定后检查按钮。UIAutomator不保证包含无障碍覆盖层和无焦点来电横幅，采集失败不得读取上次XML冒充本次结果。
5. 打开默认拨号器、设置核对放行；返回伴学小屋，确认同一会话仍在计时。依次通过两轮退出确认，核对原生保护停止、受限测试应用恢复可用。

最终包验收中，首次横屏检查在窗口切换尚未稳定时取样失败；保留该失败记录，等待稳定后重跑横竖屏及后续检查通过，没有改动APK，也没有把失败尝试计作成功。
