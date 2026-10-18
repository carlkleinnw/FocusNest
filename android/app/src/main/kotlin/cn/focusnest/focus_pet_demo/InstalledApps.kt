package cn.focusnest.focus_pet_demo

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.telecom.TelecomManager
import android.telecom.InCallService
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
        val telecom = context.getSystemService(TelecomManager::class.java)
        val dialer = telecom?.defaultDialerPackage
        val systemDialer = if (Build.VERSION.SDK_INT >= 29) telecom?.systemDialerPackage else null
        fun signedLike(first: String?, second: String) = first != null && runCatching {
            context.packageManager.checkSignatures(first, second) == PackageManager.SIGNATURE_MATCH
        }.getOrDefault(false)
        fun trustedCompanion(pkg: String): Boolean {
            val preinstalled = runCatching {
                context.packageManager.getApplicationInfo(pkg, 0).flags and ApplicationInfo.FLAG_SYSTEM != 0
            }.getOrDefault(false)
            return CallUiPolicy.trustedCompanion(preinstalled, platformSigned(context, pkg),
                signedLike(dialer, pkg) || signedLike(systemDialer, pkg))
        }
        // Some ROMs host the incoming/in-call UI outside the default dialer.
        // Discover actual UI services, accepting only the chosen/system dialer or
        // preinstalled components signed by the platform/dialer. An intent alone
        // grants no exemption; OEM phone apps can use a separate signing key.
        val callUi = context.packageManager.queryIntentServices(
            Intent(InCallService.SERVICE_INTERFACE), PackageManager.GET_META_DATA
        ).mapNotNull { result ->
            val service = result.serviceInfo
            val pkg = service.packageName
            pkg.takeIf {
                service.permission == "android.permission.BIND_INCALL_SERVICE" &&
                    service.metaData?.getBoolean(TelecomManager.METADATA_IN_CALL_SERVICE_UI) == true &&
                    (pkg == dialer || pkg == systemDialer || trustedCompanion(pkg))
            }
        }.toSet()
        val legacyCallUi = setOf("com.android.incallui", "com.android.server.telecom")
            .filter { trustedCompanion(it) }
        val settingsHandlers = listOf(
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + context.packageName)),
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
        return setOfNotNull(context.packageName, launcher, dialer, systemDialer, "android", "com.android.settings",
            "com.android.systemui", "com.android.phone", "com.android.emergency",
            "com.android.permissioncontroller", "com.google.android.permissioncontroller") +
            settingsHandlers + redirectedSettings + callUi + legacyCallUi
    }
    private fun platformSigned(context: Context, pkg: String): Boolean = runCatching {
        context.packageManager.checkSignatures("android", pkg) == PackageManager.SIGNATURE_MATCH
    }.getOrDefault(false)
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
