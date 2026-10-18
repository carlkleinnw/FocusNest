package cn.focusnest.focus_pet_demo;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.List;
import java.util.Set;

/** Standalone JVM regression checks; run with JDK javac/java, no test dependency. */
public final class FocusGateCheck {
    private static int checks;
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
        checks++;
    }
    public static void main(String[] args) {
        FocusGate gate = new FocusGate();
        String wx = "com.tencent.mm", qq = "com.tencent.mobileqq";
        String wxCall = "com.tencent.mm.plugin.voip.ui.VideoActivity", qqCall = "com.tencent.av.ui.AVActivity";
        check(VoipCallWindows.callActivity(wx, wxCall), "WeChat call activity must be exempt without exempting the whole app");
        check(VoipCallWindows.callActivity(qq, qqCall), "QQ in-call activity must be exempt");
        check(VoipCallWindows.callActivity(qq, "com.tencent.av.ui.VideoInviteActivity"), "QQ invitation activity must stay accessible");
        check(!VoipCallWindows.callActivity(wx, "com.tencent.mm.ui.LauncherUI"), "WeChat chat list must remain restricted");
        check(!VoipCallWindows.callActivity(wx, "com.tencent.mm.ui.chatting.ChattingUI"), "WeChat chat must remain restricted");
        check(!VoipCallWindows.callActivity(qq, "com.tencent.mobileqq.activity.SplashActivity"), "QQ home must remain restricted");
        check(!VoipCallWindows.callActivity("other.app", wxCall), "another package cannot spoof a call class name");
        check(!VoipCallWindows.callActivity(wx, qqCall), "call classes cannot cross app identities");
        check(!VoipCallWindows.callActivity(wx, null), "an unknown page is not a call");
        var voip = new VoipCallWindows();
        voip.observe(7, wx, wxCall, false, 0);
        check(!voip.isCallWindow(7, wx, 0), "unregistered event classes cannot obtain an exemption");
        voip.observe(7, wx, wxCall, true, 0);
        check(!voip.isCallWindow(8, wx, 0), "a call event cannot exempt another window");
        check(!voip.isCallWindow(7, qq, 0), "a call event cannot exempt another package");
        voip.retain(Set.of(), 500);
        check(voip.isCallWindow(7, wx, 500), "early window-state event survives a short window-list delay");
        voip.observe(7, wx, "android.widget.FrameLayout", false, 700);
        check(voip.isCallWindow(7, wx, 700), "widget events must not erase a verified activity");
        voip.retain(Set.of(7), 90000);
        check(voip.isCallWindow(7, wx, 90000), "a continuously visible call remains usable beyond a timeout");
        voip.observe(7, wx, "com.tencent.mm.ui.LauncherUI", true, 90001);
        check(!voip.isCallWindow(7, wx, 90001), "same-window return to chat must revoke the exemption");
        voip.observe(7, wx, wxCall, true, 90002);voip.isCallWindow(7, wx, 90002);voip.retain(Set.of(), 90003);
        check(!voip.isCallWindow(7, wx, 90003), "a removed call window cannot leave an exemption behind");
        voip.observe(9, qq, qqCall, true, 0);voip.retain(Set.of(), 1501);
        check(!voip.isCallWindow(9, qq, 1501), "an event that never matched an actual window expires");
        voip.observe(10, qq, qqCall, true, 0);
        check(!voip.isCallWindow(10, qq, 2000), "first matching window after pending deadline cannot revive an old event");
        var callBehindChat = new ForegroundWindow.Candidate(wx,true,false,false,1);
        var foregroundChat = new ForegroundWindow.Candidate(wx,true,true,true,2);
        check(!Set.of(callBehindChat).contains(ForegroundWindow.selectCandidate(List.of(callBehindChat, foregroundChat))),
            "a background call cannot exempt the same package's foreground chat window");
        check(CallUiPolicy.trustedCompanion(true,false,true),
            "preinstalled Xiaomi call UI signed like the dialer must be trusted without platform signature");
        check(CallUiPolicy.trustedCompanion(true,true,false),
            "platform-signed preinstalled call UI remains trusted");
        check(!CallUiPolicy.trustedCompanion(true,false,false),
            "a preinstalled flag without trusted signer must not grant phone access");
        check(!CallUiPolicy.trustedCompanion(false,false,true),
            "a downloaded dialer companion must not obtain an automatic system exemption");
        check(!CallUiPolicy.trustedCompanion(false,false,false),
            "a third-party app spoofing the call UI package must remain restricted");
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
        var ordinaryReminder = new ForegroundWindow.Candidate("self",false,false,false,false,12);
        check("game".equals(ForegroundWindow.select(List.of(game, ordinaryReminder))),
            "own normal overlay is not a trusted system control and must not dismiss itself");
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
        var power = new ForegroundWindow.Candidate("android",false,true,true,true,8);
        check(ForegroundWindow.isSystemControl(true,true,false,false,664,368,168),
            "incoming call heads-up must work without focus or centre coverage");
        check(!ForegroundWindow.isSystemControl(true,true,false,false,720,132,168),
            "passive top bar must not be treated as a system control");
        check(!ForegroundWindow.isSystemControl(true,true,false,false,42,720,168),
            "passive side navigation must not release a landscape reminder");
        check(!ForegroundWindow.isSystemControl(true,false,true,true,720,1600,168),
            "large untrusted overlays must not qualify as system controls");
        check(!ForegroundWindow.isSystemControl(false,true,true,true,720,1600,168),
            "a keyboard or accessibility overlay is not a system control");
        check("android".equals(ForegroundWindow.select(List.of(covered,power))),
            "power menu must take priority over the covered app");
        var shade = new ForegroundWindow.Candidate("com.android.systemui",false,true,false,false,8);
        check("com.android.systemui".equals(ForegroundWindow.select(List.of(covered,shade))),
            "trusted system controls must work even while our overlay owns focus");
        var statusBar = new ForegroundWindow.Candidate("com.android.systemui",false,false,false,false,9);
        check("game".equals(ForegroundWindow.select(List.of(covered,statusBar))),
            "passive status bar must not release app protection");
        var fakeSystem = new ForegroundWindow.Candidate("untrusted.overlay",false,false,true,true,10);
        check("game".equals(ForegroundWindow.select(List.of(covered,fakeSystem))),
            "untrusted overlays must not release protection");
        check("game".equals(ForegroundWindow.select(List.of(game,
            new ForegroundWindow.Candidate("android",false,true,false,false,1)))),
            "system controls behind the foreground app must not bypass it");
        gate.onForeground("game",true,false,false,false);
        check(gate.onForeground("android",true,false,true,false)==FocusGate.Decision.HIDE,
            "system controls release the cover without ending the session");
        check(gate.onForeground("game",true,false,false,false)==FocusGate.Decision.SHOW,
            "dismissing system controls must immediately protect the app again");
        System.out.println("FocusGate/foreground: " + checks + " regression checks passed");
    }
}
