package cn.focusnest.focus_pet_demo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.net.Uri
import org.json.JSONObject
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private lateinit var database: NestDatabase
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        database = NestDatabase(this)
        PlannerBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusnest/device_v1")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "apps" -> result.success(InstalledApps.list(this))
                        "status" -> {
                            val rule = database.rule()
                            val overlayAccess = Settings.canDrawOverlays(this)
                            result.success(mapOf("ready" to (FocusGuardService.connected && FocusGuardService.windowAccess && overlayAccess),
                                "windowAccess" to FocusGuardService.windowAccess,
                                "backgroundRunning" to FocusGuardService.backgroundRunning,
                                "active" to ((rule?.optLong("deadline") ?: 0) > System.currentTimeMillis()),
                                "blockedCount" to (rule?.optJSONArray("blocked")?.length() ?: 0),
                                "windowEvents" to FocusGuardService.windowEvents,
                                "connections" to FocusGuardService.connections,
                                "disconnections" to FocusGuardService.disconnections,
                                "reminders" to FocusGuardService.reminders,
                                "reminderAttempts" to FocusGuardService.reminderAttempts,
                                "reminderVisible" to FocusGuardService.reminderVisible,
                                "foregroundChecks" to FocusGuardService.foregroundChecks,
                                "unknownWindows" to FocusGuardService.unknownWindows,
                                "homeVerified" to FocusGuardService.homeVerified,
                                "hideReason" to FocusGuardService.lastHideReason,
                                "allowlistMode" to (rule?.optString("mode") == "allowlist"),
                                "homeResult" to FocusGuardService.lastHomeResult,
                                "error" to if (overlayAccess) FocusGuardService.lastError else "请允许显示悬浮窗，专注提醒会避开系统电话、状态栏和电源菜单",
                                "errorCode" to if (overlayAccess) FocusGuardService.lastErrorCode else "OVERLAY_PERMISSION_REQUIRED",
                                "version" to packageManager.getPackageInfo(packageName, 0).versionName))
                        }
                        "settings" -> {
                            val intent = if (!Settings.canDrawOverlays(this))
                                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + packageName))
                            else Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            startActivity(intent); result.success(null)
                        }
                        "backgroundSettings" -> {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:" + packageName)))
                            result.success(null)
                        }
                        "load" -> result.success(database.read("state"))
                        "save" -> {
                            val payload = call.argument<String>("snapshot") ?: error("Missing snapshot")
                            require(payload.length <= 2_000_000)
                            JSONObject(payload)
                            database.write("state", payload); result.success(null)
                        }
                        "start" -> {
                            require(FocusGuardService.connected && FocusGuardService.windowAccess) { "先开启具备窗口识别能力的专注保护服务" }
                            require(Settings.canDrawOverlays(this)) { "请先允许显示悬浮窗，再开始专注" }
                            val deadline = call.argument<Number>("deadline")?.toLong() ?: error("Missing deadline")
                            val started = call.argument<Number>("started")?.toLong() ?: error("Missing start")
                            require(deadline-started in 1_800_000L..10_800_000L)
                            require(kotlin.math.abs(started-System.currentTimeMillis()) < 15_000)
                            val requested = call.argument<List<String>>("allowed") ?: emptyList()
                            require(requested.size <= 1000)
                            val installed = InstalledApps.list(this).map { it["package"] as String }.toSet()
                            val necessary = InstalledApps.protectedPackages(this)
                            val allowed = requested.filter { it in installed }.toSet() + necessary
                            val blocked = (installed - allowed).sorted()
                            val rule = JSONObject().put("deadline", deadline).put("blocked", JSONArray(blocked))
                                .put("title", call.argument<String>("title")?.take(60) ?: "当前任务")
                            rule.put("allowed", JSONArray(allowed.sorted())).put("mode", "allowlist")
                            val snapshot = call.argument<String>("snapshot") ?: error("Missing snapshot")
                            require(snapshot.length <= 2_000_000); JSONObject(snapshot)
                            FocusGuardService.startBackgroundProtection()
                            database.beginFocus(rule, snapshot)
                            FocusGuardService.refreshRule()
                            result.success(null)
                        }
                        "stop" -> {
                            val snapshot = call.argument<String>("snapshot")
                            if (snapshot != null) { require(snapshot.length <= 2_000_000); JSONObject(snapshot); database.beginFocus(JSONObject(), snapshot) }
                            else database.clearFocus()
                            FocusGuardService.refreshRule()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("DEVICE_ERROR", e.message?.take(180) ?: "设备操作失败", null) }
            }
    }
}
