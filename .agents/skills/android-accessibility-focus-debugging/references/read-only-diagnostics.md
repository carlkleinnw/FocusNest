# 只读采集的用法与边界

需要本机已有 Python 3 和 ADB；本脚本不安装工具。先选用户当前允许诊断的手机。多设备时显式传入 `--serial`；序列号用于寻址，不写入结果。

```powershell
python scripts/collect_protection_state.py --adb 'D:/Android/SDK/platform-tools/adb.exe' --package cn.focusnest.focus_pet_demo --service .FocusGuardService --out 'E:/FocusNest/work/protection-before.json'
```

在当前技能目录运行，或使用脚本绝对路径。`--out` 使用私有临时目录；默认输出脱敏 JSON。可选 `--apk` 只计算本地 APK 的 SHA-256，不能证明手机安装的是同一文件。

采集范围：指定应用版本、当前用户包停止状态、自身进程是否存在、无障碍设置中自身组件是否启用、绑定表能否明确找到自身组件、前台服务、最新退出时间/原因及是否有 SwipeUpClean 标记、系统版本。原始系统输出仅在内存解析，不保存其他服务列表、窗口内容、应用清单、数据库、序列号或完整日志；命令错误只输出阶段名称。

解释结果：

- `null` 是未知，命令失败、格式变化或无法归属均不当成正常。
- `accessibility.boundComponentVisible=true` 仅表示绑定表包含目标组件；某些 Android 只输出标签，此时为 null，即使服务实际可用。继续读取应用自己的诊断与实际拦截结果。
- `packageStopped=false` 不证明进程连续存活；对比动作前后的退出时间和原因。
- `foregroundService=true` 不等于已拦截。设置开启也不等于已绑定。
- `errors` 非空时保留摘要，不把缺失项补成通过；私有副本和发布摘要分开审查。

同一设备的 UI 自动化与采集应串行。脚本只负责取证；权限恢复、划除、启动应用、签名检查和验收由当前任务另行执行。

采集命令失败或关键格式不识别时退出码为 2，仍保留未知字段摘要；参数错误同样以非零退出。可离线运行 `python scripts/test_collect_protection_state.py` 验证解析、未知和隐私分支，测试使用合成输入，不访问手机。
