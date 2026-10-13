package cn.focusnest.focus_pet_demo

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

// User-enabled service. Package-change events only; no window text retrieval.
// https://developer.android.com/reference/android/accessibilityservice/AccessibilityService
class FocusGuardService : AccessibilityService() {
    companion object { @Volatile var connected = false; private set }
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var database: NestDatabase
    private var overlay: LinearLayout? = null
    private var lastBlocked = 0L
    private var foregroundPackage: String? = null
    private val returnHome = Runnable {
        val rule = database.rule()
        val blocked = rule?.optJSONArray("blocked")
        if (rule != null && blocked != null && System.currentTimeMillis() < rule.optLong("deadline") &&
            (0 until blocked.length()).any { blocked.optString(it) == foregroundPackage }) {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }
    private val dismiss = Runnable { hideReminder() }
    override fun onServiceConnected() {
        database = NestDatabase(this)
        connected = true
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!::database.isInitialized || event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        // Overlay window events are ours; they must not dismiss their own reminder.
        if (pkg == packageName && event.className?.toString() != MainActivity::class.java.name) return
        foregroundPackage = pkg
        val rule = database.rule() ?: return
        val deadline = rule.optLong("deadline", 0)
        if (System.currentTimeMillis() >= deadline) { handler.removeCallbacks(returnHome); hideReminder(); return }
        val blocked = rule.optJSONArray("blocked") ?: return
        val protected = InstalledApps.protectedPackages(this)
        val isBlocked = (0 until blocked.length()).any { blocked.optString(it) == pkg }
        if (pkg in protected || !isBlocked) {
            handler.removeCallbacks(returnHome)
            val home = packageManager.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)?.activityInfo?.packageName
            if (pkg != home && pkg != "com.android.systemui") hideReminder()
            return
        }
        if (System.currentTimeMillis() - lastBlocked < 800) return
        lastBlocked = System.currentTimeMillis()
        showReminder(rule.optString("title", "当前学习任务"), deadline)
        handler.removeCallbacks(returnHome)
        handler.postDelayed(returnHome, 180)
    }
    private fun showReminder(title: String, deadline: Long) {
        hideReminder()
        val density = resources.displayMetrics.density
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding((28*density).toInt(), (36*density).toInt(), (28*density).toInt(), (36*density).toInt())
            setBackgroundColor(Color.rgb(248, 246, 240))
        }
        fun line(text: String, size: Float) = TextView(this).apply {
            this.text = text; textSize = size; gravity = Gravity.CENTER
            setTextColor(Color.rgb(51,45,40)); setPadding(0, (12*density).toInt(), 0, (12*density).toInt())
        }
        content.addView(line("这个应用正在休息", 23f))
        content.addView(line("正在专注：${title.take(60)}", 16f))
        val minutes = ((deadline-System.currentTimeMillis())/60000+1).coerceAtLeast(1)
        content.addView(line("还剩约${minutes}分钟。把注意力留给你选择的事情。", 15f))
        content.addView(Button(this).apply {
            text = "返回伴学小屋"
            setOnClickListener {
                hideReminder()
                startActivity(Intent(this@FocusGuardService, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
            }
        })
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.CENTER }
        try {
            getSystemService(WindowManager::class.java).addView(content, params)
            overlay = content
            handler.postDelayed(dismiss, 2400)
        } catch (_: WindowManager.BadTokenException) { overlay = null }
    }
    private fun hideReminder() {
        handler.removeCallbacks(dismiss)
        overlay?.let { runCatching { getSystemService(WindowManager::class.java).removeView(it) } }
        overlay = null
    }
    override fun onInterrupt() { hideReminder() }
    override fun onUnbind(intent: Intent?): Boolean { connected = false; hideReminder(); return super.onUnbind(intent) }
    override fun onDestroy() { connected = false; hideReminder(); handler.removeCallbacksAndMessages(null); super.onDestroy() }
}
