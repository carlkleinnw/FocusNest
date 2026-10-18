package cn.focusnest.focus_pet_demo

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.pm.ServiceInfo
import android.content.Intent
import android.content.ComponentName
import android.hardware.display.DisplayManager
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.PowerManager
import android.view.Gravity
import android.view.Display
import android.view.WindowManager
import android.view.WindowInsets
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.view.View
import android.view.ViewGroup
import android.widget.TextView

// User-enabled service. Root package metadata only: never traverse nodes or read text.
// https://developer.android.com/reference/android/accessibilityservice/AccessibilityService
class FocusGuardService : AccessibilityService() {
    companion object {
        @Volatile private var current: FocusGuardService? = null
        val connected: Boolean get() = runCatching { current?.serviceInfo != null }.getOrDefault(false)
        val windowAccess: Boolean get() = runCatching {
            val info = current?.serviceInfo ?: return@runCatching false
            info.capabilities and AccessibilityServiceInfo.CAPABILITY_CAN_RETRIEVE_WINDOW_CONTENT != 0 &&
                info.flags and AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS != 0
        }.getOrDefault(false)
        fun refreshRule() { current?.handler?.post { current?.inspectForeground() } }
        fun startBackgroundProtection() {
            checkNotNull(current) { "保护服务未连接" }.ensureForeground()
        }
        val backgroundRunning: Boolean get() = current?.foregroundRunning == true
        @Volatile var connections = 0L; private set
        @Volatile var disconnections = 0L; private set
        @Volatile var windowEvents = 0L; private set
        @Volatile var reminders = 0L; private set
        @Volatile var lastHomeResult = ""; private set
        @Volatile var lastError = ""; private set
        @Volatile var lastErrorCode = ""; private set
        @Volatile var foregroundChecks = 0L; private set
        @Volatile var unknownWindows = 0L; private set
        @Volatile var reminderAttempts = 0L; private set
        @Volatile var reminderVisible = false; private set
        @Volatile var homeVerified = 0L; private set
        @Volatile var lastHideReason = ""; private set
    }
    private val handler = Handler(Looper.getMainLooper())
    // AccessibilityService's WindowManager carries a TYPE_ACCESSIBILITY_OVERLAY
    // default token. Changing LayoutParams.type alone does not remove that token.
    // A window context also follows overlay-area configuration when rotating.
    private val reminderContext by lazy {
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            val display = getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
            applicationContext.createDisplayContext(display)
                .createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
        } else applicationContext
    }
    private val reminderWindowManager by lazy { reminderContext.getSystemService(WindowManager::class.java) }
    private lateinit var database: NestDatabase
    private var overlay: View? = null
    private var reminderDeadline = 0L
    private var lastAttempt = 0L
    private var homePending = false
    private var necessaryPackages = emptySet<String>()
    private var lastNecessaryRefresh = 0L
    private var lastFreshWindowRead = 0L
    private var foregroundRunning = false
    private val gate = FocusGate()
    private val voipCallWindows = VoipCallWindows()
    private val expiry = Runnable { gate.clear(); hideReminder("EXPIRED") }
    private val monitor = object : Runnable {
        override fun run() {
            val active = inspectForeground()
            handler.postDelayed(this, if (active) 250 else 1000)
        }
    }
    private val displayCheck = Runnable {
        reminderVisible = isReminderShown()
        if (gate.visible() && !reminderVisible && System.currentTimeMillis() < reminderDeadline) {
            lastError = "系统未让提醒正常显示，已请求返回桌面"
            lastErrorCode = "REMINDER_NOT_FOCUSED"
            homePending = requestHome()
        }
    }

    override fun onCreate() {
        super.onCreate()
        database = NestDatabase(this)
    }

    override fun onServiceConnected() {
        current = this
        connections++
        necessaryPackages = InstalledApps.protectedPackages(this)
        handler.removeCallbacks(monitor)
        handler.post(monitor)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType !in setOf(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
                AccessibilityEvent.TYPE_WINDOWS_CHANGED)) return
        windowEvents++
        // Class metadata is useful only for the two supported VoIP apps. Verify it
        // is a registered activity; widget/dialog events cannot widen an exemption.
        val eventPackage = event.packageName?.toString()
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            VoipCallWindows.supportedPackage(eventPackage)) {
            val activity = event.className?.toString()?.let {
                if (it.startsWith(".")) eventPackage + it else it
            }
            val registered = activity != null && runCatching {
                packageManager.getActivityInfo(ComponentName(eventPackage!!, activity), 0)
                    .packageName == eventPackage
            }.getOrDefault(false)
            voipCallWindows.observe(event.windowId, eventPackage, activity, registered, SystemClock.elapsedRealtime())
        }
        inspectForeground(event)
    }

    private fun inspectForeground(event: AccessibilityEvent? = null): Boolean {
        if (!::database.isInitialized || current !== this) return false
        reminderVisible = isReminderShown()
        try {
            val rule = database.rule()
            val deadline = rule?.optLong("deadline", 0) ?: 0
            if (System.currentTimeMillis() >= deadline) {
                gate.clear(); hideReminder("EXPIRED_OR_STOPPED")
                if (foregroundRunning) { stopForeground(STOP_FOREGROUND_REMOVE); foregroundRunning = false }
                return false
            }
            ensureForeground()
            if (!getSystemService(PowerManager::class.java).isInteractive) return true
            if (!windowAccess) {
                lastError = "当前服务缺少窗口识别能力，请在系统设置重新开启专注保护"
                lastErrorCode = "WINDOW_ACCESS_REQUIRED"
                return true
            }
            // Upgrade an in-flight 0.2.2 session without discarding the user's selection.
            val allowed = InstalledApps.allowedForRule(this, rule!!)
            if (SystemClock.elapsedRealtime()-lastNecessaryRefresh >= 5000) {
                necessaryPackages = InstalledApps.protectedPackages(this)
                lastNecessaryRefresh = SystemClock.elapsedRealtime()
            }
            foregroundChecks++
            if (android.os.Build.VERSION.SDK_INT >= 33 &&
                SystemClock.elapsedRealtime()-lastFreshWindowRead >= 200) {
                clearCache()
                lastFreshWindowRead = SystemClock.elapsedRealtime()
            }
            val observed = windows
            val callCandidates = mutableSetOf<ForegroundWindow.Candidate>()
            val applicationIds = mutableSetOf<Int>()
            val candidates = observed.map { window ->
                val application = window.type == AccessibilityWindowInfo.TYPE_APPLICATION
                val system = window.type == AccessibilityWindowInfo.TYPE_SYSTEM
                // Only the root's package identifier is read. No text, child nodes or screenshots.
                val root = if (application || system) window.root else null
                val pkg = root?.packageName?.toString() ?: if ((application || system) &&
                    (window.isActive || window.isFocused) && window.id == event?.windowId)
                    event?.packageName?.toString() else null
                @Suppress("DEPRECATION")
                root?.recycle()
                if (application) applicationIds.add(window.id)
                val bounds = Rect().also { window.getBoundsInScreen(it) }
                val metrics = resources.displayMetrics
                // Passive status/navigation bars must not release a restriction. A trusted
                // interactive system surface (power menu, notification/call UI, keyguard)
                // takes priority even when the accessibility cover previously owned focus.
                // TYPE_APPLICATION_OVERLAY is itself reported as TYPE_SYSTEM. Never
                // let our own reminder masquerade as a system control and dismiss itself.
                val systemControl = ForegroundWindow.isSystemControl(system,
                    pkg != packageName && pkg in necessaryPackages,
                    window.isActive, window.isFocused, bounds.width(), bounds.height(),
                    (96*metrics.density).toInt())
                ForegroundWindow.Candidate(pkg, application, systemControl,
                    window.isActive, window.isFocused, window.layer).also {
                    if (application && voipCallWindows.isCallWindow(window.id, pkg, SystemClock.elapsedRealtime())) callCandidates.add(it)
                }
            }
            voipCallWindows.retain(applicationIds, SystemClock.elapsedRealtime())
            val foreground = ForegroundWindow.selectCandidate(candidates)
            val pkg = foreground?.pkg()
            // Exempt the selected call window, never a background call or an entire
            // messaging package. Returning to its chat activity restores restriction.
            val voipCall = foreground in callCandidates
            @Suppress("DEPRECATION")
            observed.forEach { it.recycle() }
            if (pkg == null) unknownWindows++
            val necessary = pkg in necessaryPackages || voipCall
            val permitted = pkg in allowed
            when (gate.onForeground(pkg, true, permitted, necessary, false)) {
                FocusGate.Decision.SHOW -> {
                    reminderDeadline = deadline
                    showReminder(rule.optString("title", "当前学习任务"), deadline)
                }
                FocusGate.Decision.HIDE -> {
                    if (homePending && pkg in InstalledApps.homePackages(this)) {
                        homeVerified++; lastHomeResult = "HOME_VERIFIED"
                    }
                    homePending = false
                    hideReminder(if (voipCall) "VOIP_CALL_UI" else "ALLOWED_FOREGROUND")
                }
                FocusGate.Decision.IGNORE -> {
                    // An OEM detachment/focus loss must not make a duplicate event bypass protection.
                    if (pkg != null && !permitted && !necessary &&
                        !reminderVisible && SystemClock.elapsedRealtime()-lastAttempt >= 750) {
                        reminderDeadline = deadline
                        showReminder(rule.optString("title", "当前学习任务"), deadline)
                    }
                }
            }
            return true
        } catch (error: RuntimeException) {
            lastError = "当前窗口检查失败，保护状态需要核实"
            lastErrorCode = error.javaClass.simpleName
            return true
        }
    }

    private fun ensureForeground() {
        if (foregroundRunning) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = "focus_protection"
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(channel, "专注期间的后台保护", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (android.os.Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notice = builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("伴学小屋 · 专注保护进行中")
            .setContentText("正在核对白名单，打开未允许的应用会显示提醒")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true).build()
        if (android.os.Build.VERSION.SDK_INT >= 34) {
            startForeground(3105, notice, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else startForeground(3105, notice)
        foregroundRunning = true
    }

    private fun requestHome(): Boolean {
        val accepted = runCatching { performGlobalAction(GLOBAL_ACTION_HOME) }.getOrDefault(false)
        lastHomeResult = if (accepted) "HOME_ACCEPTED" else "HOME_REJECTED"
        return accepted
    }

    private fun acknowledge() {
        if (System.currentTimeMillis() >= reminderDeadline) { gate.clear(); hideReminder("EXPIRED"); return }
        if (gate.acknowledge { requestHome() }) {
            homePending = true
            lastError = ""
            lastErrorCode = ""
            handler.post { inspectForeground() }
        } else {
            lastError = "系统未能返回桌面，请再次点击知道了"
            overlay?.findViewWithTag<TextView>("homeError")?.apply { text = lastError; visibility = View.VISIBLE }
        }
    }
    private fun showReminder(title: String, deadline: Long, compactOverride: Boolean? = null) {
        hideReminder("REPLACED")
        reminderAttempts++
        lastAttempt = SystemClock.elapsedRealtime()
        val density = reminderContext.resources.displayMetrics.density
        fun dp(value: Int) = (value*density).toInt()
        val displayMetrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION")
        reminderWindowManager.defaultDisplay.getRealMetrics(displayMetrics)
        val compact = compactOverride ?: (displayMetrics.heightPixels/density < 480)
        val green = Color.rgb(68, 102, 79)
        val ink = Color.rgb(51, 45, 40)
        val muted = Color.rgb(117, 107, 97)
        fun rounded(color: Int, radius: Int, stroke: Int? = null) = GradientDrawable().apply {
            setColor(color); cornerRadius = dp(radius).toFloat()
            if (stroke != null) setStroke(dp(1), stroke)
        }
        val content = LinearLayout(reminderContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(if (compact) 8 else 40), dp(24), dp(if (compact) 8 else 40))
            setBackgroundColor(Color.rgb(248, 246, 240))
        }
        val card = LinearLayout(reminderContext).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(if (compact) 12 else 28), dp(24), dp(if (compact) 12 else 24))
            background = rounded(Color.rgb(255, 254, 250), 20, Color.rgb(232, 226, 214))
        }
        fun line(text: String, size: Float, color: Int = ink) = TextView(reminderContext).apply {
            this.text = text; textSize = size; gravity = Gravity.START
            setTextColor(color); setPadding(0, dp(if (compact) 3 else 8), 0, dp(if (compact) 3 else 8))
            setLineSpacing(dp(3).toFloat(), 1f)
        }
        card.addView(line("伴学小屋 · 沉浸专注", 12f, green).apply {
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = rounded(Color.rgb(232, 239, 227), 24)
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        card.addView(line("先把注意力留给自己", if (compact) 22f else 26f).apply {
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            setPadding(0, dp(if (compact) 10 else 24), 0, dp(if (compact) 4 else 8))
        })
        card.addView(line("这个应用正在休息。", 16f))
        card.addView(line("正在专注：" + title.take(60), 15f, muted))
        val minutes = ((deadline-System.currentTimeMillis())/60000+1).coerceAtLeast(1)
        card.addView(line("还剩约" + minutes + "分钟。坚持完成眼前这一小步，你的伙伴在小屋等你。", 15f, muted))
        card.addView(Button(reminderContext).apply {
            text = "知道了"; textSize = 16f; isAllCaps = false
            setTextColor(Color.WHITE)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            background = rounded(green, 12)
            setOnClickListener { acknowledge() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(if (compact) 44 else 52)).apply { topMargin=dp(if (compact) 10 else 22) })
        card.addView(line("", 13f, Color.rgb(172,77,53)).apply {
            tag = "homeError"
            if (compact) visibility = android.view.View.GONE
        })
        content.addView(card, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        val root = ScrollView(reminderContext).apply {
            isFillViewport = true
            setBackgroundColor(Color.rgb(248, 246, 240))
            addView(content, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            isFocusableInTouchMode = true
        }
        root.addOnLayoutChangeListener { _, _, top, _, bottom, _, _, _, _ ->
            val nowCompact = (bottom-top)/density < 480
            if (nowCompact != compact) {
                handler.post {
                    if (overlay === root && gate.visible() && System.currentTimeMillis() < deadline)
                        showReminder(title, deadline, nowCompact)
                }
            }
        }
        var counted = false
        root.viewTreeObserver.addOnPreDrawListener {
            if (overlay === root) {
                // A visible, touchable cover need not own keyboard/system focus.
                reminderVisible = isReminderShown()
                if (reminderVisible && !counted) { reminders++; counted = true }
            }
            true
        }
        root.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(view: View) = Unit
            override fun onViewDetachedFromWindow(view: View) {
                if (overlay === view) reminderVisible = false
            }
        })
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            // Normal overlays stay below critical system controls even when the OEM
            // exposes no accessible root/package for its power menu or call banner.
            if (android.os.Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            android.graphics.PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER; setTitle("FocusNestLockReminder")
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                // Leave status/navigation bars visible and directly touchable, including
                // notification shade access. Only app content needs an opaque cover.
                setFitInsetsTypes(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else if (android.os.Build.VERSION.SDK_INT >= 28) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        try {
            reminderWindowManager.addView(root, params)
            overlay = root
            handler.postDelayed(expiry, (deadline-System.currentTimeMillis()).coerceAtLeast(0))
            handler.postDelayed(displayCheck, 700)
            lastError = ""
            lastErrorCode = ""
        } catch (error: RuntimeException) {
            overlay = null
            lastError = "锁定提醒未能显示，已请求返回桌面"
            lastErrorCode = error.javaClass.simpleName
            homePending = requestHome()
        }
    }
    private fun isReminderShown(): Boolean = overlay?.let {
        it.isAttachedToWindow && it.isShown && it.windowVisibility == View.VISIBLE &&
            it.width > 0 && it.height > 0
    } == true
    private fun hideReminder(reason: String) {
        handler.removeCallbacks(expiry)
        handler.removeCallbacks(displayCheck)
        overlay?.let { runCatching { reminderWindowManager.removeView(it) } }
        if (overlay != null) lastHideReason = reason
        overlay = null
        reminderVisible = false
    }
    // Interrupting accessibility feedback is not the user ending a focus session.
    override fun onInterrupt() { handler.post { inspectForeground() } }
    override fun onUnbind(intent: Intent?): Boolean {
        if (current === this) current = null
        disconnections++
        gate.clear()
        hideReminder("SERVICE_DISCONNECTED")
        stopForeground(STOP_FOREGROUND_REMOVE); foregroundRunning = false
        handler.removeCallbacksAndMessages(null)
        return super.onUnbind(intent)
    }
    override fun onDestroy() {
        if (current === this) current = null
        gate.clear()
        hideReminder("SERVICE_DESTROYED")
        stopForeground(STOP_FOREGROUND_REMOVE); foregroundRunning = false
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
