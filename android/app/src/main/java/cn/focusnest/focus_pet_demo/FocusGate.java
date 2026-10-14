package cn.focusnest.focus_pet_demo;

import java.util.function.BooleanSupplier;

/** Package-only reminder state. No activity content, pending dismissal or auto exit. */
public final class FocusGate {
    public enum Decision { IGNORE, SHOW, HIDE }
    private String target;

    public Decision onWindow(String pkg, boolean active, boolean restricted,
                             boolean necessary, boolean ownOverlay, boolean transientWindow) {
        if (ownOverlay) return Decision.IGNORE;
        if (!active) { target = null; return Decision.HIDE; }
        if (restricted && !necessary) {
            if (pkg.equals(target)) return Decision.IGNORE;
            target = pkg;
            return Decision.SHOW;
        }
        if (transientWindow) return Decision.IGNORE;
        target = null;
        return Decision.HIDE;
    }

    public boolean acknowledge(BooleanSupplier goHome) {
        if (target == null) return false;
        if (!goHome.getAsBoolean()) return false;
        target = null;
        return true;
    }

    public boolean visible() { return target != null; }
    public void clear() { target = null; }
}
