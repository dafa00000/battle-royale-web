// ============================================
// SOUND SYSTEM - Procedural Web Audio (no files)
// ============================================

export class SoundSystem {
  private ctx: AudioContext | null = null;
  private noiseBuffer: AudioBuffer | null = null;

  private ensureCtx(): AudioContext {
    if (!this.ctx) {
      const AC = (window as any).AudioContext || (window as any).webkitAudioContext;
      this.ctx = new AC();
      // Cache noise buffer for gunshots
      const buf = this.ctx.createBuffer(1, this.ctx.sampleRate * 0.3, this.ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
      this.noiseBuffer = buf;
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
    return this.ctx;
  }

  resume(): void {
    try { this.ensureCtx(); } catch {}
  }

  // Procedural gunshot: noise burst + low sine punch + fast decay
  gunshot(): void {
    try {
      const ctx = this.ensureCtx();
      const now = ctx.currentTime;

      // Noise burst (crack)
      const noise = ctx.createBufferSource();
      noise.buffer = this.noiseBuffer;
      const noiseFilter = ctx.createBiquadFilter();
      noiseFilter.type = 'bandpass';
      noiseFilter.frequency.value = 1800;
      noiseFilter.Q.value = 0.8;
      const noiseGain = ctx.createGain();
      noiseGain.gain.setValueAtTime(0.6, now);
      noiseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
      noise.connect(noiseFilter).connect(noiseGain).connect(ctx.destination);
      noise.start(now);
      noise.stop(now + 0.14);

      // Low sine punch (chest thump)
      const sine = ctx.createOscillator();
      sine.type = 'sine';
      sine.frequency.setValueAtTime(160, now);
      sine.frequency.exponentialRampToValueAtTime(50, now + 0.08);
      const sineGain = ctx.createGain();
      sineGain.gain.setValueAtTime(0.5, now);
      sineGain.gain.exponentialRampToValueAtTime(0.001, now + 0.1);
      sine.connect(sineGain).connect(ctx.destination);
      sine.start(now);
      sine.stop(now + 0.12);
    } catch (e) {
      console.warn('gunshot failed:', e);
    }
  }

  // Footstep thud: short low-passed noise click
  footstep(): void {
    try {
      const ctx = this.ensureCtx();
      const now = ctx.currentTime;
      const noise = ctx.createBufferSource();
      noise.buffer = this.noiseBuffer;
      const filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.value = 220;
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
      noise.connect(filter).connect(gain).connect(ctx.destination);
      noise.start(now);
      noise.stop(now + 0.1);
    } catch {}
  }

  // Jump: pitch-up quick whoosh
  jump(): void {
    try {
      const ctx = this.ensureCtx();
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(180, now);
      osc.frequency.exponentialRampToValueAtTime(420, now + 0.12);
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.3, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
      osc.connect(gain).connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.18);
    } catch {}
  }

  // Landing thud
  land(): void {
    try {
      const ctx = this.ensureCtx();
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(120, now);
      osc.frequency.exponentialRampToValueAtTime(40, now + 0.1);
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.35, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);
      osc.connect(gain).connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.16);
    } catch {}
  }
}

export const sound = new SoundSystem();
