// Engine_Riga
// Latvian Thunder Machine — inspired by the Erica Synths universe
//
// 4 voice channels, each switchable between 4 synthesis modes:
//   Mode 0: BASSLINE (DB-01) — saw/square/sub + Polivoks filter + BBD detune + overdrive
//   Mode 1: PERKONS (HD-01) — hybrid drum synthesis with analog filter + overdrive
//   Mode 2: STEAMPIPE — Karplus-Strong physical modeling with pipe splitting
//   Mode 3: SYNTRX — dual oscillator + ring mod + noise + trapezoid envelope
//
// FX chain: BBD Delay → Polivoks Filter → Plasma Drive → Zen Reverb
// Signal: voice → fxBus → bbd → polivoks → plasma → zen → out

Engine_Riga : CroneEngine {

    var pg;
    var fxGroup;
    var voiceSynths;
    var fxBus;
    var bbdSynth, polivoksSynth, plasmaSynth, zenSynth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        fxBus = Bus.audio(context.server, 2);

        pg = ParGroup.new(context.xg);
        fxGroup = Group.after(pg);

        voiceSynths = Array.fill(4, { nil });

        // ======== MODE 0: BASSLINE (DB-01 inspired) ========
        // Saw/Square/Tri + transistor sub-osc + Polivoks filter + BBD detune + overdrive
        SynthDef(\riga_bassline, {
            arg out, dryOut=0, fxSend=0.5, freq=110, amp=0.5, pan=0, gate=1,
                saw=0.8, pulse=0.0, tri=0.0, sub=0.5, noise=0.0,
                pulseWidth=0.5,
                // Polivoks filter
                cutoff=1200, res=0.4, filterMode=0, envMod=0.6,
                // BBD detune (bucket brigade emulation)
                bbdDetune=0.3, bbdRate=0.5,
                // overdrive
                drive=0.5,
                // envelope
                attack=0.005, decay=0.3, sustain=0.6, release=0.3,
                pitchEnv=0, pitchDecay=0.05,
                // accent
                accent=0;

            var sig, osc, subOsc, noiseSig, env, filterEnv, pitchMod;
            var detuned, bbdMod;
            var sigL, sigR;

            // pitch envelope (for acid slides)
            pitchMod = EnvGen.kr(Env.perc(0.001, pitchDecay, pitchEnv * 12, -8));
            freq = freq * (2 ** (pitchMod / 12));

            // main oscillators
            osc = (LFSaw.ar(freq) * saw)
                + (Pulse.ar(freq, pulseWidth) * pulse)
                + (LFTri.ar(freq) * tri);

            // transistor sub-oscillator (one octave down, slight grit)
            subOsc = Pulse.ar(freq * 0.5, 0.5) * sub;
            subOsc = (subOsc * 1.2).tanh; // transistor saturation

            // noise
            noiseSig = WhiteNoise.ar * noise;

            sig = osc + subOsc + noiseSig;

            // BBD detune emulation — two delayed copies with slow modulation
            bbdMod = SinOsc.kr(bbdRate * 2, 0, bbdDetune * 0.003, bbdDetune * 0.004);
            detuned = DelayC.ar(sig, 0.05, bbdMod) * bbdDetune;
            sig = sig + detuned;

            // amplitude envelope
            env = EnvGen.kr(
                Env.adsr(attack, decay, sustain, release, 1, -4),
                gate, doneAction: Done.freeSelf
            );

            // Polivoks-style filter — envelope modulated
            filterEnv = EnvGen.kr(Env.perc(0.005, decay * 1.5, envMod * cutoff * 2, -6));
            cutoff = (cutoff + filterEnv + (accent * 2000)).clip(40, 16000);

            sig = Select.ar(filterMode, [
                // 12dB lowpass (Polivoks characteristic)
                RLPF.ar(sig, cutoff, res.linlin(0, 1, 1, 0.04)),
                // 6dB bandpass
                BPF.ar(sig, cutoff, res.linlin(0, 1, 1, 0.08)) * 3
            ]);

            // overdrive (transistor style)
            sig = (sig * (1 + (drive * 4))).tanh;
            sig = sig * (1 / (1 + drive));

            sig = sig * env * amp * (1 + (accent * 0.5));

            sigL = sig; sigR = sig;
            sig = Balance2.ar(sigL, sigR, pan);
            sig = LeakDC.ar(sig);

            Out.ar(out, sig * fxSend);
            Out.ar(dryOut, sig * (1 - fxSend));
        }).add;

        // ======== MODE 1: PERKONS (HD-01 inspired) ========
        // Hybrid drum synth: FM + analog + noise modes with per-voice filter & overdrive
        SynthDef(\riga_perkons, {
            arg out, dryOut=0, fxSend=0.5, freq=200, amp=0.5, pan=0,
                // drum mode: 0=kick, 0.5=snare, 1=hat
                drumMode=0,
                // synthesis
                fmIndex=2.0, fmRatio=1.5, noiseAmt=0.0,
                shape=0, // 0=sine, 0.33=tri, 0.66=saw, 1=pulse
                // pitch
                pitchEnvAmt=4, pitchDecay=0.04,
                // amp
                attack=0.001, decay=0.3, curve=(-6),
                // filter (per-voice analog multimode)
                filterFreq=4000, filterRes=0.3, filterMode=0,
                filterEnvAmt=2000, filterDecay=0.1,
                // overdrive (per-voice)
                drive=0.3,
                // ratchet velocity
                accent=0,
                spread=0.3;

            var sig, env, pitchEnv, filterEnv, modulator, osc, noiseSig;
            var sigL, sigR;

            pitchEnv = EnvGen.kr(Env.perc(0.001, pitchDecay, pitchEnvAmt, -8));
            freq = freq * (1 + pitchEnv);

            // FM component
            modulator = SinOsc.ar(freq * fmRatio) * fmIndex * freq;

            // oscillator with shape morphing
            osc = SelectX.ar(shape * 3, [
                SinOsc.ar(freq + modulator),
                LFTri.ar(freq + (modulator * 0.3)),
                LFSaw.ar(freq + (modulator * 0.2)),
                Pulse.ar(freq + (modulator * 0.1), 0.5)
            ]);

            // noise layer (snare/hat character)
            noiseSig = SelectX.ar(drumMode * 2, [
                // kick: low rumble
                LPF.ar(PinkNoise.ar, 200),
                // snare: mid-band noise burst
                BPF.ar(WhiteNoise.ar, 3000, 0.5) * 2,
                // hat: high metallic noise
                HPF.ar(ClipNoise.ar + (Crackle.ar(1.8) * 0.5), 6000)
            ]);

            sig = osc + (noiseSig * noiseAmt);

            env = EnvGen.kr(Env.perc(attack, decay, 1, curve), doneAction: Done.freeSelf);

            // per-voice analog filter
            filterEnv = EnvGen.kr(Env.perc(0.001, filterDecay, filterEnvAmt, -6));
            sig = Select.ar(filterMode, [
                RLPF.ar(sig, (filterFreq + filterEnv).clip(40, 18000), filterRes.linlin(0, 1, 1, 0.05)),
                RHPF.ar(sig, (filterFreq + filterEnv).clip(40, 18000), filterRes.linlin(0, 1, 1, 0.05)),
                BPF.ar(sig, (filterFreq + filterEnv).clip(40, 18000), filterRes.linlin(0, 1, 1, 0.05)) * 3
            ]);

            // per-voice overdrive (Perkons style)
            sig = (sig * (1 + (drive * 6))).tanh;
            sig = sig * (1 / (1 + (drive * 2)));

            sig = sig * env * amp * (1 + (accent * 0.4));

            // binaural spread
            sigL = DelayN.ar(sig, 0.01, spread * 0.004);
            sigR = DelayN.ar(sig, 0.01, spread * 0.002);
            sig = Pan2.ar(sig, pan) + [sigL * spread * 0.3, sigR * spread * 0.3];
            sig = LeakDC.ar(sig);

            Out.ar(out, sig * fxSend);
            Out.ar(dryOut, sig * (1 - fxSend));
        }).add;

        // ======== MODE 2: STEAMPIPE (physical modeling) ========
        // Karplus-Strong with exciter control, pipe feedback, splitting, overblowing
        SynthDef(\riga_steampipe, {
            arg out, dryOut=0, fxSend=0.5, freq=220, amp=0.5, pan=0,
                // exciter: mix of DC burst and noise
                exciterNoise=0.7, exciterGain=1.0,
                // pipe resonator
                feedback=0.98, brightness=0.5,
                // pipe splitting (two unequal segments)
                splitPoint=0.5, splitMix=0.3,
                // overblowing (harmonic jumps)
                overblow=0.0,
                // harmonic stretch (inharmonicity for bells)
                stretch=0.0,
                // envelope
                attack=0.002, decay=1.5, curve=(-4),
                // filter in feedback path
                dampFreq=6000, dampLo=200,
                accent=0,
                spread=0.2;

            var exciter, pipe1, pipe2, sig, env;
            var delTime, delTime1, delTime2;
            var sigL, sigR;

            // overblow shifts to harmonics
            freq = freq * (1 + overblow).round;

            // harmonic stretch (inharmonicity)
            freq = freq * (1 + (stretch * 0.01 * freq / 200));

            delTime = (1 / freq).clip(0.0001, 0.05);

            // exciter: mix of DC impulse and noise burst
            exciter = EnvGen.ar(Env.perc(0.001, 0.01, 1, -8));
            exciter = exciter * ((1 - exciterNoise) + (WhiteNoise.ar * exciterNoise));
            exciter = exciter * exciterGain * (1 + (accent * 0.5));
            exciter = LPF.ar(exciter, brightness.linexp(0, 1, 400, 12000));

            // pipe 1: main resonator
            delTime1 = delTime * splitPoint.linlin(0, 1, 0.3, 0.7);
            pipe1 = CombL.ar(exciter, 0.05, delTime1, decay * feedback * 2);
            pipe1 = LPF.ar(pipe1, dampFreq);
            pipe1 = HPF.ar(pipe1, dampLo);

            // pipe 2: split segment (different length = inharmonic partials)
            delTime2 = delTime * (1 - splitPoint).linlin(0, 1, 0.3, 0.7);
            pipe2 = CombL.ar(exciter, 0.05, delTime2, decay * feedback * 1.5);
            pipe2 = LPF.ar(pipe2, dampFreq * 0.8);
            pipe2 = HPF.ar(pipe2, dampLo * 1.5);

            sig = pipe1 + (pipe2 * splitMix);

            // allpass diffusion (pipe body resonance)
            sig = AllpassN.ar(sig, 0.01, delTime * 0.37, decay * 0.3);
            sig = AllpassN.ar(sig, 0.01, delTime * 0.53, decay * 0.2);

            env = EnvGen.kr(Env.perc(attack, decay, 1, curve), doneAction: Done.freeSelf);
            sig = sig * env * amp;

            sigL = DelayN.ar(sig, 0.01, spread * 0.005);
            sigR = DelayN.ar(sig, 0.01, spread * 0.003);
            sig = Pan2.ar(sig, pan) + [sigL * spread * 0.3, sigR * spread * 0.3];
            sig = LeakDC.ar(sig);

            Out.ar(out, sig * fxSend);
            Out.ar(dryOut, sig * (1 - fxSend));
        }).add;

        // ======== MODE 3: SYNTRX (EMS-inspired chaos synth) ========
        // Dual oscillator + ring mod + multi-color noise + trapezoid envelope
        SynthDef(\riga_syntrx, {
            arg out, dryOut=0, fxSend=0.5, freq=220, amp=0.5, pan=0, gate=1,
                // osc1
                osc1Shape=0, osc1Level=0.7,
                // osc2 (detuned/ratio)
                osc2Ratio=1.5, osc2Shape=0.5, osc2Level=0.5,
                osc2Detune=0.01,
                // ring mod
                ringMod=0.3,
                // noise (multi-color: 0=white, 0.5=pink, 1=crackle)
                noiseColor=0.5, noiseLevel=0.2,
                // trapezoid envelope (3-stage: attack, sustain, decay — loopable)
                trapAttack=0.1, trapSustain=0.3, trapDecay=0.5,
                // filter
                cutoff=3000, res=0.4,
                // chaos modulation amount
                chaosAmt=0.0, chaosRate=5,
                accent=0,
                spread=0.3;

            var osc1, osc2, ring, noiseSig, sig, env;
            var chaos, freq2;
            var sigL, sigR;

            // chaos modulation (Syntrx joystick-like)
            chaos = LFNoise2.kr(chaosRate) * chaosAmt;

            // osc1: morphable waveform
            osc1 = SelectX.ar(osc1Shape * 3, [
                SinOsc.ar(freq * (1 + (chaos * 0.02))),
                Pulse.ar(freq * (1 + (chaos * 0.02)), 0.5 + (chaos * 0.2)),
                LFSaw.ar(freq * (1 + (chaos * 0.02))),
                VarSaw.ar(freq * (1 + (chaos * 0.02)), 0, 0.5 + (chaos * 0.3))
            ]) * osc1Level;

            // osc2: ratio-tuned, can track or run free
            freq2 = freq * osc2Ratio * (1 + osc2Detune + (chaos * 0.03));
            osc2 = SelectX.ar(osc2Shape * 3, [
                SinOsc.ar(freq2),
                Pulse.ar(freq2, 0.3),
                LFSaw.ar(freq2),
                Formant.ar(freq2, freq2 * 2, freq2 * 0.5)
            ]) * osc2Level;

            // ring modulator
            ring = osc1 * osc2 * ringMod * 2;

            // multi-color noise generator
            noiseSig = SelectX.ar(noiseColor * 2, [
                WhiteNoise.ar,
                PinkNoise.ar,
                Crackle.ar(1.7 + (chaos * 0.2))
            ]) * noiseLevel;

            sig = osc1 + osc2 + ring + noiseSig;

            // trapezoid envelope (EMS style — looping AD)
            env = EnvGen.kr(
                Env.adsr(trapAttack, trapDecay, trapSustain, trapDecay, 1, -3),
                gate, doneAction: Done.freeSelf
            );

            // dual filter with resonance
            cutoff = (cutoff * (1 + (chaos * 0.5)) + (accent * 1500)).clip(40, 16000);
            sig = RLPF.ar(sig, cutoff, res.linlin(0, 1, 1, 0.04));

            sig = sig * env * amp * (1 + (accent * 0.3));

            sigL = DelayN.ar(sig, 0.01, spread * 0.005);
            sigR = DelayN.ar(sig, 0.01, spread * 0.003);
            sig = Pan2.ar(sig, pan) + [sigL * spread * 0.3, sigR * spread * 0.3];
            sig = LeakDC.ar(sig);

            Out.ar(out, sig * fxSend);
            Out.ar(dryOut, sig * (1 - fxSend));
        }).add;

        // ======== FX 1: BBD DELAY (bucket brigade emulation) ========
        SynthDef(\riga_bbd, {
            arg in, out, delayTime=0.3, feedback=0.5, color=0.6, mix=0.4, rate=0.3;
            var sig, dry, delayed, modTime, fb;

            sig = In.ar(in, 2);    // wet from voices
            dry = In.ar(out, 2);   // dry from voices

            // BBD character: slight modulation + filtering
            modTime = delayTime + SinOsc.kr(rate, 0, delayTime * 0.02);
            modTime = modTime.clip(0.001, 2.0);

            fb = LocalIn.ar(2) * feedback;
            delayed = DelayC.ar(sig + fb, 2.1, modTime);

            // BBD bandwidth limiting (analog character)
            delayed = LPF.ar(delayed, color.linexp(0, 1, 800, 12000));
            delayed = HPF.ar(delayed, 80);

            // slight saturation in feedback path
            delayed = (delayed * 1.1).tanh;

            LocalOut.ar(delayed);

            // combine dry + wet (dry already on out_b, wet from fx bus)
            sig = dry + (sig * (1 - mix)) + (delayed * mix);
            ReplaceOut.ar(out, sig);
        }).add;

        // ======== FX 2: POLIVOKS FILTER (global resonant filter) ========
        SynthDef(\riga_polivoks, {
            arg in, out, cutoff=4000, res=0.3, mode=0, envFollow=0.3;
            var sig, env;

            sig = In.ar(in, 2);

            // envelope follower modulates cutoff (like Acidbox)
            env = Amplitude.kr(sig.sum, 0.01, 0.1) * envFollow * 4000;

            sig = Select.ar(mode, [
                // 12dB lowpass
                RLPF.ar(sig, (cutoff + env).clip(40, 16000), res.linlin(0, 1, 1, 0.04)),
                // 6dB bandpass
                BPF.ar(sig, (cutoff + env).clip(40, 16000), res.linlin(0, 1, 1, 0.08)) * 3,
                // highpass
                RHPF.ar(sig, (cutoff + env).clip(40, 16000), res.linlin(0, 1, 1, 0.06))
            ]);

            ReplaceOut.ar(out, sig);
        }).add;

        // ======== FX 3: PLASMA DRIVE (wavefolder + overdrive chain) ========
        SynthDef(\riga_plasma, {
            arg in, out, drive=0.3, foldAmt=0.0, mix=0.5;
            var sig, dry, processed;

            sig = In.ar(in, 2);
            dry = sig;

            // stage 1: wavefolder (Plasma Drive inspired — extreme harmonic generation)
            processed = sig * (1 + (foldAmt * 8));
            processed = processed.fold2(1.0);
            processed = processed.fold2(0.8); // second fold for more harmonics
            processed = processed.fold2(0.6); // third fold — Erica goes hard

            // stage 2: tube-style overdrive (asymmetric clipping)
            processed = (processed * (1 + (drive * 5))).tanh;

            // stage 3: gentle high shelf to tame extreme folding
            processed = BHiShelf.ar(processed, 8000, 1, -3 * foldAmt);

            sig = (dry * (1 - mix)) + (processed * mix * (1 / (1 + drive)));
            ReplaceOut.ar(out, sig);
        }).add;

        // ======== FX 4: ZEN REVERB (long dub tails) ========
        SynthDef(\riga_zen, {
            arg in, out, size=0.8, damp=0.5, mix=0.3, preDelay=0.04;
            var sig, wet;

            sig = In.ar(in, 2);

            // pre-delay (dub character)
            wet = DelayN.ar(sig, 0.2, preDelay);

            // reverb with long tail
            wet = FreeVerb2.ar(wet[0], wet[1], mix: 1, room: size, damp: damp);

            // gentle saturation on reverb tail
            wet = (wet * 1.05).tanh;

            sig = (sig * (1 - mix)) + (wet * mix);
            ReplaceOut.ar(out, sig);
        }).add;

        // ======== INSTANTIATE FX CHAIN ========
        context.server.sync;

        bbdSynth = Synth.new(\riga_bbd,
            [\in, fxBus, \out, context.out_b], fxGroup);
        polivoksSynth = Synth.after(bbdSynth, \riga_polivoks,
            [\in, context.out_b, \out, context.out_b], fxGroup);
        plasmaSynth = Synth.after(polivoksSynth, \riga_plasma,
            [\in, context.out_b, \out, context.out_b], fxGroup);
        zenSynth = Synth.after(plasmaSynth, \riga_zen,
            [\in, context.out_b, \out, context.out_b], fxGroup);

        // ======== COMMANDS ========

        // Voice triggers (mode selects which synthdef)
        this.addCommand("trig", "iff", { arg msg;
            var ch = msg[1].asInteger - 1;  // 0-indexed channel
            var mode = msg[2].asFloat;       // 0=bassline, 1=perkons, 2=steampipe, 3=syntrx
            var freq = msg[3].asFloat;

            if(voiceSynths[ch].notNil, { voiceSynths[ch].free });

            voiceSynths[ch] = Synth.new(
                [\riga_bassline, \riga_perkons, \riga_steampipe, \riga_syntrx][mode.asInteger],
                [\out, fxBus, \dryOut, context.out_b, \freq, freq],
                pg
            );
        });

        // Set voice parameter
        this.addCommand("voice_param", "isf", { arg msg;
            var ch = msg[1].asInteger - 1;
            var param = msg[2].asString.asSymbol;
            var val = msg[3].asFloat;
            if(voiceSynths[ch].notNil, {
                voiceSynths[ch].set(param, val);
            });
        });

        // Release voice (for sustained modes)
        this.addCommand("release", "i", { arg msg;
            var ch = msg[1].asInteger - 1;
            if(voiceSynths[ch].notNil, {
                voiceSynths[ch].set(\gate, 0);
            });
        });

        // BBD Delay params
        this.addCommand("bbd_time", "f", { arg msg; bbdSynth.set(\delayTime, msg[1]); });
        this.addCommand("bbd_feedback", "f", { arg msg; bbdSynth.set(\feedback, msg[1]); });
        this.addCommand("bbd_color", "f", { arg msg; bbdSynth.set(\color, msg[1]); });
        this.addCommand("bbd_mix", "f", { arg msg; bbdSynth.set(\mix, msg[1]); });
        this.addCommand("bbd_rate", "f", { arg msg; bbdSynth.set(\rate, msg[1]); });

        // Polivoks Filter params
        this.addCommand("poli_cutoff", "f", { arg msg; polivoksSynth.set(\cutoff, msg[1]); });
        this.addCommand("poli_res", "f", { arg msg; polivoksSynth.set(\res, msg[1]); });
        this.addCommand("poli_mode", "f", { arg msg; polivoksSynth.set(\mode, msg[1]); });
        this.addCommand("poli_env", "f", { arg msg; polivoksSynth.set(\envFollow, msg[1]); });

        // Plasma Drive params
        this.addCommand("plasma_drive", "f", { arg msg; plasmaSynth.set(\drive, msg[1]); });
        this.addCommand("plasma_fold", "f", { arg msg; plasmaSynth.set(\foldAmt, msg[1]); });
        this.addCommand("plasma_mix", "f", { arg msg; plasmaSynth.set(\mix, msg[1]); });

        // Zen Reverb params
        this.addCommand("zen_size", "f", { arg msg; zenSynth.set(\size, msg[1]); });
        this.addCommand("zen_damp", "f", { arg msg; zenSynth.set(\damp, msg[1]); });
        this.addCommand("zen_mix", "f", { arg msg; zenSynth.set(\mix, msg[1]); });
        this.addCommand("zen_predelay", "f", { arg msg; zenSynth.set(\preDelay, msg[1]); });
    }

    free {
        voiceSynths.do({ arg s; if(s.notNil, { s.free }) });
        bbdSynth.free;
        polivoksSynth.free;
        plasmaSynth.free;
        zenSynth.free;
        fxBus.free;
    }
}
