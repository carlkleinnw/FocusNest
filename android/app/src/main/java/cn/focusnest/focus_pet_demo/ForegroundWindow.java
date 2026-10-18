package cn.focusnest.focus_pet_demo;

import java.util.List;

/** Window metadata only; Android nodes/text never cross this seam. */
public final class ForegroundWindow {
    public static boolean isSystemControl(boolean system, boolean trusted, boolean active,
                                          boolean focused, int width, int height, int minSize) {
        // Heads-up incoming calls do not cover the screen centre or gain focus while
        // our reminder is attached. Exclude thin passive bars in either orientation.
        return system && trusted && (active || focused || Math.min(width, height) >= minSize);
    }
    public record Candidate(String pkg, boolean application, boolean systemControl,
                            boolean active, boolean focused, int layer) {
        public Candidate(String pkg, boolean application, boolean active, boolean focused, int layer) {
            this(pkg, application, false, active, focused, layer);
        }
    }

    public static String select(List<Candidate> windows) {
        Candidate best = null;
        for (Candidate window : windows) {
            if (!window.application() && !window.systemControl()) continue;
            // getWindows supplies on-screen interactive windows in layer order.
            // Rotation and an accessibility cover can temporarily clear focus/active flags.
            if (best == null || window.layer() > best.layer()) best = window;
        }
        // Never fall through an unreadable foreground window to a background app.
        return best == null ? null : best.pkg();
    }
}
