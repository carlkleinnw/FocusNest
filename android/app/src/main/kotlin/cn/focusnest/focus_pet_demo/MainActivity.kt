package cn.focusnest.focus_pet_demo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import org.json.JSONObject
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private lateinit var database: NestDatabase
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        database = NestDatabase(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusnest/device_v1")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "apps" -> result.success(InstalledApps.list(this))
                        "status" -> result.success(mapOf("ready" to FocusGuardService.connected,
                            "active" to ((database.rule()?.optLong("deadline") ?: 0) > System.currentTimeMillis())))
                        "settings" -> { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(null) }
                        "load" -> result.success(database.read("state"))
                        "save" -> {
                            val payload = call.argument<String>("snapshot") ?: error("Missing snapshot")
                            require(payload.length <= 2_000_000)
                            JSONObject(payload)
                            database.write("state", payload); result.success(null)
                        }
                        "start" -> {
                            require(FocusGuardService.connected) { "先开启专注保护服务" }
                            val deadline = call.argument<Number>("deadline")?.toLong() ?: error("Missing deadline")
                            val started = call.argument<Number>("started")?.toLong() ?: error("Missing start")
                            require(deadline-started in 1_800_000L..10_800_000L)
                            require(kotlin.math.abs(started-System.currentTimeMillis()) < 15_000)
                            val blocked = call.argument<List<String>>("blocked") ?: emptyList()
                            require(blocked.size <= 1000)
                            val safe = blocked.filter { it !in InstalledApps.protectedPackages(this) }
                            val rule = JSONObject().put("deadline", deadline).put("blocked", JSONArray(safe))
                                .put("title", call.argument<String>("title")?.take(60) ?: "当前任务")
                            val snapshot = call.argument<String>("snapshot") ?: error("Missing snapshot")
                            require(snapshot.length <= 2_000_000); JSONObject(snapshot)
                            database.beginFocus(rule, snapshot)
                            result.success(null)
                        }
                        "stop" -> {
                            val snapshot = call.argument<String>("snapshot")
                            if (snapshot != null) { require(snapshot.length <= 2_000_000); JSONObject(snapshot); database.beginFocus(JSONObject(), snapshot) }
                            else database.clearFocus()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("DEVICE_ERROR", e.message?.take(180) ?: "设备操作失败", null) }
            }
    }
}
