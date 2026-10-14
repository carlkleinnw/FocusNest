package cn.focusnest.focus_pet_demo

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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
    companion object {
        @Volatile private var current: FocusGuardService? = null
        val connected: Boolean get() = runCatching { current?.serviceInfo != null }.getOrDefault(false)
        @Volatile var connections = 0L; private set
        @Volatile var disconnections = 0L; private set
        @Volatile var windowEvents = 0L; private set
        @Volatile var reminders = 0L; private set
        @Volatile var lastHomeResult = ""; private set
        @Volatile var lastError = ""; private set
        @Volatile var lastErrorCode = ""; private set
    }
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var database: NestDatabase
    private var overlay: LinearLayout? = null
    private var reminderDeadline = 0L
    private val gate = FocusGate()
    private val expiry = Runnable { gate.clear(); hideReminder() }

    override fun onCreate() {
        super.onCreate()
        database = NestDatabase(this)
        current = this
    }

    override fun onServiceConnected() {
        current = this
        connections++
        windowEvents = 0
        reminders = 0
        lastHomeResult = ""
        lastError = ""
        lastErrorCode = ""
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!::database.isInitialized || event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        windowEvents++
        val pkg = event.packageName?.toString() ?: return
        try {
            val ownOverlay = pkg == packageName && event.className?.toString() != MainActivity::class.java.name
            val rule = database.rule()
            val deadline = rule?.optLong("deadline", 0) ?: 0
            val blocked = rule?.optJSONArray("blocked")
            val restricted = blocked != null && (0 until blocked.length()).any { blocked.optString(it) == pkg }
            val necessary = pkg in InstalledApps.protectedPackages(this)
            val transientWindow = pkg == "com.android.systemui" || pkg == "com.miui.securitycenter"
            when (gate.onWindow(pkg, System.currentTimeMillis() < deadline, restricted, necessary, ownOverlay, transientWindow)) {
                FocusGate.Decision.SHOW -> {
                    reminders++
                    reminderDeadline = deadline
                    showReminder(rule?.optString("title", "当前学习任务") ?: "当前学习任务", deadline)
                }
                FocusGate.Decision.HIDE -> hideReminder()
                FocusGate.Decision.IGNORE -> Unit
            }
        } catch (error: RuntimeException) {
            lastError = "保护服务处理失败，请重新开启权限"
            lastErrorCode = error.javaClass.simpleName
            requestHome()
        }
    }

    private fun requestHome(): Boolean {
        val accepted = runCatching { performGlobalAction(GLOBAL_ACTION_HOME) }.getOrDefault(false)
        lastHomeResult = if (accepted) "HOME_ACCEPTED" else "HOME_REJECTED"
        return accepted
    }

    private fun acknowledge() {
        if (System.currentTimeMillis() >= reminderDeadline) { gate.clear(); hideReminder(); return }
        if (gate.acknowledge { requestHome() }) {
            lastError = ""
            lastErrorCode = ""
            hideReminder()
        } else {
            lastError = "系统未能返回桌面，请再次点击知道了"
            overlay?.findViewWithTag<TextView>("homeError")?.text = lastError
        }
    }
    private fun showReminder(title: String, deadline: Long) {
        hideReminder()
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value*density).toInt()
        val green = Color.rgb(68, 102, 79)
        val ink = Color.rgb(51, 45, 40)
        val muted = Color.rgb(117, 107, 97)
        fun rounded(color: Int, radius: Int, stroke: Int? = null) = GradientDrawable().apply {
            setColor(color); cornerRadius = dp(radius).toFloat()
            if (stroke != null) setStroke(dp(1), stroke)
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(40), dp(24), dp(40))
            setBackgroundColor(Color.rgb(248, 246, 240))
        }
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(28), dp(24), dp(24))
            background = rounded(Color.rgb(255, 254, 250), 20, Color.rgb(232, 226, 214))
        }
        fun line(text: String, size: Float, color: Int = ink) = TextView(this).apply {
            this.text = text; textSize = size; gravity = Gravity.START
            setTextColor(color); setPadding(0, dp(8), 0, dp(8))
            setLineSpacing(dp(3).toFloat(), 1f)
        }
        card.addView(line("伴学小屋 · 沉浸专注", 12f, green).apply {
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = rounded(Color.rgb(232, 239, 227), 24)
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        card.addView(line("先把注意力留给自己", 26f).apply {
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            setPadding(0, dp(24), 0, dp(8))
        })
        card.addView(line("这个应用正在休息。", 16f))
        card.addView(line("正在专注：" + title.take(60), 15f, muted))
        val minutes = ((deadline-System.currentTimeMillis())/60000+1).coerceAtLeast(1)
        card.addView(line("还剩约" + minutes + "分钟。坚持完成眼前这一小步，你的伙伴在小屋等你。", 15f, muted))
        card.addView(Button(this).apply {
            text = "知道了"; textSize = 16f; isAllCaps = false
            setTextColor(Color.WHITE)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            background = rounded(green, 12)
            setOnClickListener { acknowledge() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52)).apply { topMargin=dp(22) })
        card.addView(line("", 13f, Color.rgb(172,77,53)).apply { tag = "homeError" })
        content.addView(card, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        content.isFocusableInTouchMode = true
        content.setOnKeyListener { _, keyCode, keyEvent ->
            if (keyCode == android.view.KeyEvent.KEYCODE_BACK) {
                if (keyEvent.action == android.view.KeyEvent.ACTION_UP) acknowledge()
                true
            } else false
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            android.graphics.PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.CENTER; setTitle("FocusNestLockReminder") }
        try {
            getSystemService(WindowManager::class.java).addView(content, params)
            overlay = content
            content.requestFocus()
            handler.postDelayed(expiry, (deadline-System.currentTimeMillis()).coerceAtLeast(0))
            lastError = ""
        } catch (error: RuntimeException) {
            overlay = null
            lastError = "锁定提醒未能显示，已请求返回桌面"
            lastErrorCode = error.javaClass.simpleName
            gate.clear()
            requestHome()
        }
    }
    private fun hideReminder() {
        handler.removeCallbacks(expiry)
        overlay?.let { runCatching { getSystemService(WindowManager::class.java).removeView(it) } }
        overlay = null
    }
    override fun onInterrupt() { gate.clear(); hideReminder() }
    override fun onUnbind(intent: Intent?): Boolean {
        if (current === this) current = null
        disconnections++
        gate.clear()
        hideReminder()
        return super.onUnbind(intent)
    }
    override fun onDestroy() {
        if (current === this) current = null
        gate.clear()
        hideReminder()
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
