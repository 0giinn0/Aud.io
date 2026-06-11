import 'dart:js' as js;

class SoundSynthesizer {
  static void _init() {
    js.context.callMethod('eval', ['''
      if (!window._audioCtx) {
        window._audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }
    ''']);
  }

  static void playNote(double frequency, {double duration = 0.3, String waveType = 'sine'}) {
    _init();
    js.context.callMethod('eval', ['''
      (function() {
        const ctx = window._audioCtx;
        if (ctx.state === 'suspended') ctx.resume();
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = '$waveType';
        osc.frequency.setValueAtTime($frequency, ctx.currentTime);
        gain.gain.setValueAtTime(0.3, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + $duration);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + $duration);
      })();
    ''']);
  }

  static void resume() {
    _init();
    js.context.callMethod('eval', ['''
      const ctx = window._audioCtx;
      if (ctx.state === 'suspended') ctx.resume();
    ''']);
  }
}