# 小米自启动对照：历史证据而非通用结论

日期：2026-10-15。设备 Xiaomi 15，Android 16 / API 36，HyperOS OS3.0.305.0.WOCCNXM。应用 FocusNest 0.2.6+8；最终条件性验收为 0.2.7+11。未来工作仍需重查实际配置。

| 相同动作：最近任务单卡上划 | 包/进程结果 | 保护结果 |
| --- | --- | --- |
| 自启动关闭，省电已无限制 | USER REQUESTED / FORCE STOP，stopped=true | 无障碍被关闭，保护失效 |
| 仅开启本应用自启动，并在可见界面恢复无障碍 | OTHER KILLS BY SYSTEM / SwipeUpClean，stopped=false | 系统重绑；未重开 FocusNest，直接启动受限应用出现提醒 |

最终 +11 在开启自启动条件下通过 3 次单卡划除、横屏提醒持续 30 秒、必要应用、约 5 分钟锁屏、自然到期和新会话两轮退出。反向关闭自启动时再次出现 FORCE STOP。因此采用的是避免进入该强停路径的设备配置，进程仍会死亡，恢复仍可能有间隙。

此前“无限制 + 锁定任务卡片也失败”的证据遗漏了自启动条件，不能据此认定所有普通应用方案不可用。自启动、Doze 豁免、省电无限制、锁定任务卡片分别核查；不批量关闭手机全局优化、安全扫描或其他应用保护。

同轮另一缺陷：应用信息意图解析为 com.android.settings，但运行时跳转到 com.miui.securitycenter。只验证解析目标会漏测。最终补充包可见性，并经 checkSignatures("android", package) 通过才作为必要设置承载包放行。不要将这个包名推广到所有厂商。

可复核依据：

- [FocusNest v0.2.7-demo 真机摘要](https://github.com/carlkleinnw/FocusNest/blob/v0.2.7-demo/docs/validation/0.2.7-device-checks.json)（私有仓，需已授权访问）；本机历史文件 `E:/FocusNest/docs/validation/0.2.7-device-checks.json`。
- [小米自启动管理说明](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1624)仅支持用户知情后自行开启，不保证划除存活。
- [Android stopped 状态](https://developer.android.com/about/versions/15/behavior-changes-all#stopped-state)：强停状态及 PendingIntent 行为需与普通回收分开。
- [FLAG_SYSTEM 文档](https://developer.android.com/reference/android/content/pm/ApplicationInfo#FLAG_SYSTEM)建议安全判断使用签名核对等依据。

官方页可能更新；实现新修改时复核当前官方说明。历史标签说明历史行为，不认证今天手机的状态。
