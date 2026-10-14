package cn.focusnest.focus_pet_demo;

import java.util.List;

/** Window metadata only; Android nodes/text never cross this seam. */
public final class ForegroundWindow {
    public record Candidate(String pkg, boolean application, boolean active,
                            boolean focused, int layer) {}

    public static String select(List<Candidate> windows) {
        Candidate best = null;
        for (Candidate window : windows) {
            if (!window.application()) continue;
            // getWindows supplies on-screen interactive windows in layer order.
            // Rotation and an accessibility cover can temporarily clear focus/active flags.
            if (best == null || window.layer() > best.layer()) best = window;
        }
        // Never fall through an unreadable foreground window to a background app.
        return best == null ? null : best.pkg();
    }
}
