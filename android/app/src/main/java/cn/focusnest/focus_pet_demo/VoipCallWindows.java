package cn.focusnest.focus_pet_demo;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/** Registered activity metadata only, scoped to a currently observed app window. */
public final class VoipCallWindows {
    private record Key(int id, String pkg) {}
    private static final class Entry {
        final String activity;
        final long receivedAt;
        boolean observed;
        Entry(String activity, long receivedAt) { this.activity = activity; this.receivedAt = receivedAt; }
    }
    private final Map<Key, Entry> entries = new HashMap<>();

    public static boolean supportedPackage(String pkg) {
        return "com.tencent.mm".equals(pkg) || "com.tencent.mobileqq".equals(pkg);
    }
    public static boolean callActivity(String pkg, String activity) {
        if ("com.tencent.mm".equals(pkg))
            return "com.tencent.mm.plugin.voip.ui.VideoActivity".equals(activity);
        if ("com.tencent.mobileqq".equals(pkg))
            return "com.tencent.av.ui.AVActivity".equals(activity) ||
                "com.tencent.av.ui.VideoInviteActivity".equals(activity);
        return false;
    }
    public void observe(int windowId, String pkg, String activity, boolean registeredActivity, long now) {
        if (windowId < 0 || !supportedPackage(pkg) || activity == null || !registeredActivity) return;
        entries.put(new Key(windowId, pkg), new Entry(activity, now));
    }
    public boolean isCallWindow(int windowId, String pkg, long now) {
        Key key = new Key(windowId, pkg);
        Entry entry = entries.get(key);
        if (entry == null) return false;
        if (!entry.observed && now - entry.receivedAt > 1500) {
            entries.remove(key);
            return false;
        }
        entry.observed = true;
        return callActivity(pkg, entry.activity);
    }
    public void retain(Set<Integer> visibleApplicationIds, long now) {
        // Window-state events can precede getWindows. Keep an unmatched event briefly;
        // once observed, remove it as soon as that app window leaves the window list.
        entries.entrySet().removeIf(e -> !visibleApplicationIds.contains(e.getKey().id()) &&
            (e.getValue().observed || now - e.getValue().receivedAt > 1500));
    }
}
