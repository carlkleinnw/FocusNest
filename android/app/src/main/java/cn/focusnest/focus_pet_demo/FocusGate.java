package cn.focusnest.focus_pet_demo;

import java.util.function.BooleanSupplier;

/** Verified foreground observations only. Unknown windows cannot dismiss a reminder. */
public final class FocusGate {
    public enum Decision { IGNORE, SHOW, HIDE }
    private String target;

    public Decision onForeground(String pkg, boolean active, boolean allowed,
                                 boolean necessary, boolean reminderWindow) {
        if (!active) { target = null; return Decision.HIDE; }
        if (reminderWindow || pkg == null) return Decision.IGNORE;
        if (!allowed && !necessary) {
            if (pkg.equals(target)) return Decision.IGNORE;
            target = pkg;
            return Decision.SHOW;
        }
        target = null;
        return Decision.HIDE;
    }

    public boolean acknowledge(BooleanSupplier goHome) {
        if (target == null) return false;
        // The request can be accepted before the launcher is actually foreground.
        // Retain the cover until onForeground confirms an allowed window.
        return goHome.getAsBoolean();
    }

    public boolean visible() { return target != null; }
    public void clear() { target = null; }
}
