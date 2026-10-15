package cn.focusnest.focus_pet_demo

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.telecom.TelecomManager
import android.os.Build
import android.provider.Settings
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject

object InstalledApps {
    fun homePackages(context: Context): Set<String> = context.packageManager.queryIntentActivities(
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0
    ).map { it.activityInfo.packageName }.toSet()

    fun allowedForRule(context: Context, rule: JSONObject): Set<String> {
        val stored = rule.optJSONArray("allowed")
        if (stored != null) return (0 until stored.length()).map { stored.optString(it) }.toSet()
        val blocked = rule.optJSONArray("blocked") ?: JSONArray()
        val denied = (0 until blocked.length()).map { blocked.optString(it) }.toSet()
        val allowed = list(context).map { it["package"] as String }.filter { it !in denied }.toSet() + protectedPackages(context)
        rule.put("allowed", JSONArray(allowed.sorted())).put("mode", "allowlist")
        NestDatabase(context).use { it.write("protection", rule.toString()) }
        return allowed
    }
    fun protectedPackages(context: Context): Set<String> {
        val launcher = context.packageManager.resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0
        )?.activityInfo?.packageName
        val dialer = context.getSystemService(TelecomManager::class.java)?.defaultDialerPackage
        val settingsHandlers = listOf(
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + context.packageName)),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        ).mapNotNull { context.packageManager.resolveActivity(it, 0)?.activityInfo?.packageName }
        // HyperOS resolves app details to Settings, then redirects to Security Center.
        // Verify the platform signature rather than trusting a package name or FLAG_SYSTEM.
        // https://developer.android.com/reference/android/content/pm/ApplicationInfo#FLAG_SYSTEM
        val redirectedSettings = setOf("com.miui.securitycenter").filter { pkg ->
            runCatching {
                context.packageManager.checkSignatures("android", pkg) == PackageManager.SIGNATURE_MATCH
            }.getOrDefault(false)
        }
        return setOfNotNull(context.packageName, launcher, dialer, "com.android.settings",
            "com.android.systemui", "com.android.phone", "com.android.emergency",
            "com.android.permissioncontroller", "com.google.android.permissioncontroller") + settingsHandlers + redirectedSettings
    }
    fun list(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager
        val protected = protectedPackages(context)
        val results = pm.queryIntentActivities(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0
        )
        return results.distinctBy { it.activityInfo.packageName }.map { result ->
            val info = result.activityInfo.applicationInfo
            val name = result.loadLabel(pm).toString()
            val pkg = result.activityInfo.packageName
            val categoryId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) info.category else -1
            val category = when (categoryId) {
                ApplicationInfo.CATEGORY_GAME -> "游戏"
                ApplicationInfo.CATEGORY_VIDEO -> "视频"
                ApplicationInfo.CATEGORY_AUDIO -> "音乐"
                ApplicationInfo.CATEGORY_SOCIAL -> "社交"
                ApplicationInfo.CATEGORY_PRODUCTIVITY -> "工具"
                else -> "其他"
            }
            val recommended = categoryId in setOf(ApplicationInfo.CATEGORY_GAME,
                ApplicationInfo.CATEGORY_VIDEO, ApplicationInfo.CATEGORY_AUDIO) ||
                pkg in setOf("com.ss.android.ugc.aweme", "com.ss.android.ugc.aweme.lite",
                    "com.smile.gifmaker", "com.kuaishou.nebula", "tv.danmaku.bili") ||
                Regex("短视频|游戏|影视|直播").containsMatchIn(name)
            mapOf("package" to pkg, "name" to name, "category" to category,
                "protected" to (pkg in protected),
                "recommendedBlocked" to (recommended && pkg !in protected))
        }.sortedBy { it["name"].toString() }
    }
}
