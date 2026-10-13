# 伴学小屋 · Focus Nest Demo

Flutter虚拟数据交互Demo。一个页面一个核心功能：小屋、计划、专注、记录、休息、允许的应用、重新领养、演示控制。

## 直接体验

双击 `启动Demo.cmd`。会在本机浏览器打开已构建的演示。当前电脑使用已有的 `E:/Conda/python.exe` 提供本地服务。

推荐体验顺序：

1. 小屋里点击“摸摸团子”“一起玩球”，或直接点击宠物、球和地板。
2. 在学习计划选择任务，到专注页手动开始。
3. 点击短视频体验模拟拦截；“提前结束”有两轮确认。
4. 去演示控制“完成当前专注”，返回小屋体验喂食。
5. 重置后推进7个未喂食的学习日，查看宠物消瘦、死亡。
6. 在领养页开始重启专注，快进完成后选择并命名新宠物。
7. 提前安排休息日，再推进日期，观察饥饿暂停。

网页只模拟应用限制和外部悬浮。没有真正锁定手机，也没有模型/Agent接入。内存数据刷新重置。饥饿恢复量暂定为：一次完整专注将连续饥饿清零。

## 开发

实际验证环境：Flutter 3.41.9、Dart 3.11.5、flutter_riverpod 3.3.2、Flame 1.38.2、go_router 17.5.0。确切依赖由pubspec.lock固定。

```powershell
$env:PUB_CACHE='E:/DeveloperCache/focus_pet/pub'
$env:TEMP='E:/DeveloperCache/focus_pet/temp'
$env:TMP=$env:TEMP
flutter pub get
flutter run -d chrome
```

构建与检查：

```powershell
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

源码与资产均在E盘。Flutter和Android SDK使用电脑已有的D盘安装。本地交付未推送到任何远程仓库。

## 结构

`lib/core` 模型、规则与扩展接口；`lib/data` 虚拟适配器；`lib/ui` 可复用组件与导航；`lib/pages` 单一职责页面；`lib/pet` 动态宠物和场景。

设计依据与具体约束见 `docs/设计约定.md`；未来AI/Agent连接位置见 `docs/扩展接口.md`。

## 素材

`assets/images/room.png` 是本次使用ImageGen生成、移除静态猫之后的小屋背景。宠物由独立的Dart绘制代码表现，能走动、互动和变瘦。背景并非全3D模型。

OpenClaw只读审查曾尝试调用，但因主模型余额不足和备用模型认证失败未产出审查结果。交付验证由本项目完成。
