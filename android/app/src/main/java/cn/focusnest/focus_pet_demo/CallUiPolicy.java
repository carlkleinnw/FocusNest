package cn.focusnest.focus_pet_demo;

/** Identity policy for a preinstalled UI accompanying the system/chosen dialer. */
public final class CallUiPolicy {
    public static boolean trustedCompanion(boolean preinstalled, boolean platformSigned,
                                            boolean dialerSigned) {
        return preinstalled && (platformSigned || dialerSigned);
    }
}
