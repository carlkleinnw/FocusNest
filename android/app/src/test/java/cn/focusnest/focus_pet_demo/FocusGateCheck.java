package cn.focusnest.focus_pet_demo;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.List;

/** Standalone JVM regression checks; run with JDK javac/java, no test dependency. */
public final class FocusGateCheck {
    private static int checks;
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
        checks++;
    }
    public static void main(String[] args) {
        FocusGate gate = new FocusGate();
        AtomicInteger homeRequests = new AtomicInteger();
        check(gate.onForeground("video",true,false,false,false)==FocusGate.Decision.SHOW,"restricted entry must show");
        check(homeRequests.get()==0 && gate.visible(),"wait for acknowledgement");
        check(gate.onForeground(null,true,false,false,false)==FocusGate.Decision.IGNORE,
            "an unrelated window notification must not uncover the restricted app");
        check(gate.visible(),"unknown foreground retains the cover");
        check(gate.onForeground("self",true,true,true,true)==FocusGate.Decision.IGNORE,"own overlay must not dismiss itself");
        check(gate.onForeground("video",true,false,false,false)==FocusGate.Decision.IGNORE,"duplicate event must retain same reminder");
        check(!gate.acknowledge(()->{homeRequests.incrementAndGet();return false;}),"failed return must be reported");
        check(gate.visible(),"failed return must keep the app covered");
        check(gate.acknowledge(()->{homeRequests.incrementAndGet();return true;}),"acknowledgement requests home");
        check(gate.visible() && homeRequests.get()==2,"accepted home request does not uncover a game before launcher appears");
        check(gate.onForeground("launcher",true,true,true,false)==FocusGate.Decision.HIDE,"verified launcher removes reminder");
        check(!gate.acknowledge(()->{throw new AssertionError("duplicate request");}),"duplicate acknowledgement does nothing");
        check(gate.onForeground("video",true,false,false,false)==FocusGate.Decision.SHOW,"fast reopening must block again");
        check(gate.onForeground("phone",true,false,true,false)==FocusGate.Decision.HIDE,"necessary phone must remain available");
        gate.onForeground("video",true,false,false,false);
        check(gate.onForeground(null,false,false,false,true)==FocusGate.Decision.HIDE,"expiry releases even on own overlay");
        check(gate.onForeground("course",true,true,false,false)==FocusGate.Decision.HIDE,"allowed course stays available");
        check(gate.onForeground("new-game",true,false,false,false)==FocusGate.Decision.SHOW,"apps absent from whitelist are blocked without category matching");
        var game = new ForegroundWindow.Candidate("game",true,true,true,4);
        var keyboard = new ForegroundWindow.Candidate("keyboard",false,true,true,9);
        check("game".equals(ForegroundWindow.select(List.of(game,keyboard))),"keyboard must not masquerade as foreground app");
        check(ForegroundWindow.select(List.of(keyboard))==null,"system-only observations are unknown");
        var home = new ForegroundWindow.Candidate("home",true,false,false,1);
        check("game".equals(ForegroundWindow.select(List.of(home,game))),"ignore background allowed app");
        var unreadable = new ForegroundWindow.Candidate(null,true,true,true,7);
        check(ForegroundWindow.select(List.of(game,unreadable))==null,"unreadable top app must not fall through");
        var covered = new ForegroundWindow.Candidate("game",true,false,false,4);
        check("game".equals(ForegroundWindow.select(List.of(home,covered))),"own cover does not erase underlying foreground app");
        check("game".equals(ForegroundWindow.select(List.of(covered))),
            "visible game must be identified during a rotation before focus flags settle");
        System.out.println("FocusGate/foreground: " + checks + " regression checks passed");
    }
}
