package cn.focusnest.focus_pet_demo;

import java.util.concurrent.atomic.AtomicInteger;

/** Standalone JVM regression checks; run with JDK javac/java, no test dependency. */
public final class FocusGateCheck {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
    public static void main(String[] args) {
        FocusGate gate = new FocusGate();
        AtomicInteger homeRequests = new AtomicInteger();
        check(gate.onWindow("video",true,true,false,false,false)==FocusGate.Decision.SHOW,"restricted entry must show");
        check(homeRequests.get()==0 && gate.visible(),"wait for acknowledgement");
        check(gate.onWindow("systemui",true,false,true,false,true)==FocusGate.Decision.IGNORE,"system overlay must not bypass reminder");
        check(gate.onWindow("self",true,false,true,true,false)==FocusGate.Decision.IGNORE,"own overlay must not dismiss itself");
        check(gate.onWindow("video",true,true,false,false,false)==FocusGate.Decision.IGNORE,"duplicate event must retain same reminder");
        check(!gate.acknowledge(()->{homeRequests.incrementAndGet();return false;}),"failed return must be reported");
        check(gate.visible(),"failed return must keep the app covered");
        check(gate.acknowledge(()->{homeRequests.incrementAndGet();return true;}),"acknowledgement requests home");
        check(!gate.visible() && homeRequests.get()==2,"successful acknowledgement removes reminder");
        check(!gate.acknowledge(()->{throw new AssertionError("duplicate request");}),"duplicate acknowledgement does nothing");
        check(gate.onWindow("video",true,true,false,false,false)==FocusGate.Decision.SHOW,"fast reopening must block again");
        check(gate.onWindow("phone",true,true,true,false,false)==FocusGate.Decision.HIDE,"necessary phone must remain available");
        gate.onWindow("video",true,true,false,false,false);
        check(gate.onWindow("video",false,true,false,false,false)==FocusGate.Decision.HIDE,"expiry releases without acknowledgement");
        check(gate.onWindow("course",true,false,false,false,false)==FocusGate.Decision.HIDE,"allowed course stays available");
        System.out.println("FocusGate: 14 regression checks passed");
    }
}
