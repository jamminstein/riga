-- riga
-- engine: Riga
-- latvian thunder machine — 4 voices inspired by Erica Synths
--
-- robot strategy: POLIVOKS FILTER FIRST. the global Polivoks filter
-- is the soul of the Erica sound — robot rides cutoff like a DJ
-- riding a filter sweep. it defines the timbral arc of the whole
-- performance, from dark/closed to bright/screaming.
--
-- secondary lever: PLASMA DRIVE fold amount. Erica's Plasma Drive
-- literally runs audio through lightning — the wavefolder is their
-- signature for extreme harmonic generation. robot pushes it from
-- subtle warmth to face-melting distortion.
--
-- BBD delay feedback for dub moments (Zen Delay character).
-- per-voice cutoff for individual timbral movement.
-- per-voice drive for grit dynamics.
-- chaos intensity for modulation depth (Black Code Source).
-- decay for rhythmic shape-shifting.
--
-- the philosophy: Erica Synths embraces noise, distortion, and
-- chaos as first-class musical tools. the robot should push toward
-- raw, aggressive territory while maintaining groove. harshness is
-- a feature, not a bug — but the robot knows when to pull back and
-- let the space breathe (Zen Delay / Steampipe moments).

return {
  name = "riga",
  description = "Latvian thunder machine - Bassline/Perkons/Steampipe/Syntrx voices, BBD/Polivoks/Plasma/Zen FX",
  phrase_len = 8,

  recommended_modes = {1, 3, 7, 10, 8},  -- FUNK, APHEX, DRUNK, CHAOS, EUCLIDEAN

  never_touch = {
    "clock_tempo",
    "clock_source",
    "midi_device",
    "midi_enabled",
    "midi_ch_1", "midi_ch_2", "midi_ch_3", "midi_ch_4",
    "opxy_device", "opxy_enabled",
    "opxy_ch_1", "opxy_ch_2", "opxy_ch_3", "opxy_ch_4",
    "bpm",             -- player territory
    "root",            -- player territory
    "scale",           -- player territory
    "division",        -- rhythmic foundation
    "bandmate_active", -- player controls bandmate
    "bandmate_style",
    "explorer_active",
  },

  params = {
    ---------- PRIMARY: Polivoks filter is THE Erica lever ----------
    poli_cutoff = {
      group = "timbral",
      weight = 1.0,
      sensitivity = 0.9,
      direction = "both",
      -- robot should RIDE this. slow sweeps across the whole
      -- performance, sudden openings for timbral explosions.
      -- the Polivoks filter defines the Erica sound.
      range_lo = 200,
      range_hi = 12000,
      euclidean_pulses = 7,
    },
    poli_res = {
      group = "timbral",
      weight = 0.7,
      sensitivity = 0.5,
      direction = "both",
      -- self-oscillation at high res = screaming acid.
      -- low res = warm, dark. the robot should know both.
      range_lo = 0.05,
      range_hi = 0.85,
      euclidean_pulses = 5,
    },
    poli_mode = {
      group = "structural",
      weight = 0.15,
      sensitivity = 0.3,
      direction = "both",
      -- LP/BP/HP mode switch: dramatic but rare.
      -- mostly LP (Polivoks default), BP for acid moments.
      range_lo = 0,
      range_hi = 2,
      euclidean_pulses = 3,
    },

    ---------- SECONDARY: Plasma Drive wavefolder ----------
    plasma_fold = {
      group = "timbral",
      weight = 0.95,
      sensitivity = 0.8,
      direction = "both",
      -- the Plasma Drive runs audio through lightning.
      -- fold amount = harmonic destruction. ride it.
      range_lo = 0,
      range_hi = 0.8,
      euclidean_pulses = 7,
    },
    plasma_drive = {
      group = "timbral",
      weight = 0.75,
      sensitivity = 0.6,
      direction = "both",
      -- tube-style overdrive on top of wavefolding.
      -- together they create the Erica filth.
      range_lo = 0,
      range_hi = 0.85,
      euclidean_pulses = 5,
    },
    plasma_mix = {
      group = "timbral",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0,
      range_hi = 0.9,
      euclidean_pulses = 5,
    },

    ---------- BBD DELAY (Zen Delay character) ----------
    bbd_feedback = {
      group = "timbral",
      weight = 0.7,
      sensitivity = 0.5,
      direction = "both",
      -- high feedback = dub washout. low = subtle echo.
      -- robot creates dub moments by pushing feedback.
      range_lo = 0.05,
      range_hi = 0.85,
      euclidean_pulses = 5,
    },
    bbd_time = {
      group = "rhythmic",
      weight = 0.4,
      sensitivity = 0.3,
      direction = "both",
      -- delay time shifts create rhythmic interest.
      range_lo = 0.05,
      range_hi = 1.2,
      euclidean_pulses = 3,
    },
    bbd_color = {
      group = "timbral",
      weight = 0.45,
      sensitivity = 0.4,
      direction = "both",
      -- BBD bandwidth: dark/lo-fi to bright/present.
      range_lo = 0.1,
      range_hi = 0.9,
      euclidean_pulses = 5,
    },
    bbd_mix = {
      group = "timbral",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0,
      range_hi = 0.7,
      euclidean_pulses = 5,
    },

    ---------- ZEN REVERB ----------
    zen_size = {
      group = "timbral",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.2,
      range_hi = 0.95,
      euclidean_pulses = 3,
    },
    zen_mix = {
      group = "timbral",
      weight = 0.45,
      sensitivity = 0.35,
      direction = "both",
      range_lo = 0.05,
      range_hi = 0.6,
      euclidean_pulses = 3,
    },

    ---------- PER-VOICE: BASSLINE (ch1) ----------
    ch1_cutoff = {
      group = "timbral",
      weight = 0.85,
      sensitivity = 0.7,
      direction = "both",
      -- Bassline DB-01 filter: the acid squelch.
      -- low = dark rumble. high = screaming acid.
      range_lo = 100,
      range_hi = 8000,
      euclidean_pulses = 7,
    },
    ch1_res = {
      group = "timbral",
      weight = 0.55,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.1,
      range_hi = 0.85,
      euclidean_pulses = 5,
    },
    ch1_drive = {
      group = "timbral",
      weight = 0.6,
      sensitivity = 0.5,
      direction = "up",
      -- overdrive only goes up for Bassline. always gritty.
      range_lo = 0.2,
      range_hi = 0.9,
      euclidean_pulses = 5,
    },
    ch1_decay = {
      group = "rhythmic",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.05,
      range_hi = 1.5,
      euclidean_pulses = 5,
    },
    ch1_amp = {
      group = "timbral",
      weight = 0.3,
      sensitivity = 0.25,
      direction = "both",
      range_lo = 0.3,
      range_hi = 1.0,
      euclidean_pulses = 3,
    },
    ch1_fxSend = {
      group = "timbral",
      weight = 0.35,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.05,
      range_hi = 0.7,
      euclidean_pulses = 3,
    },

    ---------- PER-VOICE: PERKONS (ch2) ----------
    ch2_cutoff = {
      group = "timbral",
      weight = 0.7,
      sensitivity = 0.6,
      direction = "both",
      -- Perkons per-voice filter: shapes drum character.
      range_lo = 200,
      range_hi = 10000,
      euclidean_pulses = 7,
    },
    ch2_res = {
      group = "timbral",
      weight = 0.45,
      sensitivity = 0.35,
      direction = "both",
      range_lo = 0.05,
      range_hi = 0.7,
      euclidean_pulses = 5,
    },
    ch2_drive = {
      group = "timbral",
      weight = 0.6,
      sensitivity = 0.5,
      direction = "both",
      -- Perkons per-voice overdrive: fat to nasty.
      range_lo = 0.1,
      range_hi = 0.8,
      euclidean_pulses = 5,
    },
    ch2_decay = {
      group = "rhythmic",
      weight = 0.55,
      sensitivity = 0.45,
      direction = "both",
      -- drum decay: tight to boomy.
      range_lo = 0.03,
      range_hi = 1.0,
      euclidean_pulses = 5,
    },
    ch2_amp = {
      group = "timbral",
      weight = 0.3,
      sensitivity = 0.25,
      direction = "both",
      range_lo = 0.3,
      range_hi = 1.0,
      euclidean_pulses = 3,
    },
    ch2_fxSend = {
      group = "timbral",
      weight = 0.35,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.05,
      range_hi = 0.7,
      euclidean_pulses = 3,
    },

    ---------- PER-VOICE: STEAMPIPE (ch3) ----------
    ch3_cutoff = {
      group = "timbral",
      weight = 0.6,
      sensitivity = 0.5,
      direction = "both",
      range_lo = 400,
      range_hi = 12000,
      euclidean_pulses = 5,
    },
    ch3_decay = {
      group = "rhythmic",
      weight = 0.65,
      sensitivity = 0.5,
      direction = "both",
      -- Steampipe decay: short plink to long resonance.
      -- this is a primary shaping tool for physical modeling.
      range_lo = 0.2,
      range_hi = 3.0,
      euclidean_pulses = 5,
    },
    ch3_amp = {
      group = "timbral",
      weight = 0.3,
      sensitivity = 0.25,
      direction = "both",
      range_lo = 0.2,
      range_hi = 0.9,
      euclidean_pulses = 3,
    },
    ch3_fxSend = {
      group = "timbral",
      weight = 0.45,
      sensitivity = 0.4,
      direction = "both",
      -- Steampipe into reverb/delay = gorgeous.
      range_lo = 0.1,
      range_hi = 0.85,
      euclidean_pulses = 5,
    },

    ---------- PER-VOICE: SYNTRX (ch4) ----------
    ch4_cutoff = {
      group = "timbral",
      weight = 0.7,
      sensitivity = 0.6,
      direction = "both",
      range_lo = 200,
      range_hi = 10000,
      euclidean_pulses = 7,
    },
    ch4_res = {
      group = "timbral",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.05,
      range_hi = 0.8,
      euclidean_pulses = 5,
    },
    ch4_drive = {
      group = "timbral",
      weight = 0.4,
      sensitivity = 0.35,
      direction = "both",
      range_lo = 0.05,
      range_hi = 0.7,
      euclidean_pulses = 5,
    },
    ch4_decay = {
      group = "rhythmic",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.1,
      range_hi = 2.0,
      euclidean_pulses = 5,
    },
    ch4_amp = {
      group = "timbral",
      weight = 0.3,
      sensitivity = 0.25,
      direction = "both",
      range_lo = 0.2,
      range_hi = 0.8,
      euclidean_pulses = 3,
    },
    ch4_fxSend = {
      group = "timbral",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      -- Syntrx into FX chain = cosmic.
      range_lo = 0.15,
      range_hi = 0.9,
      euclidean_pulses = 5,
    },

    ---------- CHAOS SYSTEM ----------
    chaos_intensity = {
      group = "timbral",
      weight = 0.65,
      sensitivity = 0.5,
      direction = "both",
      -- Black Code Source modulation depth.
      range_lo = 0.05,
      range_hi = 0.85,
      euclidean_pulses = 5,
    },
    chaos_rate = {
      group = "timbral",
      weight = 0.4,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.1,
      range_hi = 0.9,
      euclidean_pulses = 3,
    },

    ---------- EXPLORER ----------
    explorer_intensity = {
      group = "structural",
      weight = 0.2,
      sensitivity = 0.2,
      direction = "both",
      range_lo = 0.1,
      range_hi = 0.9,
      euclidean_pulses = 3,
    },

    ---------- SYNTHESIS INTERNALS: BASSLINE (ch1) ----------
    ch1_saw = {
      group = "timbral", weight = 0.7, sensitivity = 0.6, direction = "both",
      range_lo = 0, range_hi = 1, euclidean_pulses = 5,
    },
    ch1_pulse = {
      group = "timbral", weight = 0.5, sensitivity = 0.5, direction = "both",
      range_lo = 0, range_hi = 1, euclidean_pulses = 5,
    },
    ch1_sub = {
      group = "timbral", weight = 0.6, sensitivity = 0.5, direction = "both",
      -- sub oscillator: the transistor grunt of DB-01.
      range_lo = 0, range_hi = 1, euclidean_pulses = 5,
    },
    ch1_noise = {
      group = "timbral", weight = 0.35, sensitivity = 0.3, direction = "up",
      range_lo = 0, range_hi = 0.5, euclidean_pulses = 3,
    },
    ch1_bbdDetune = {
      group = "timbral", weight = 0.75, sensitivity = 0.6, direction = "both",
      -- BBD bucket brigade detune: the Erica secret weapon.
      -- chorus to massive poly-synth. robot should ride this.
      range_lo = 0, range_hi = 0.7, euclidean_pulses = 7,
    },
    ch1_envMod = {
      group = "timbral", weight = 0.8, sensitivity = 0.7, direction = "both",
      -- filter envelope depth: the acid squelch control.
      range_lo = 0, range_hi = 1, euclidean_pulses = 7,
    },
    ch1_pitchEnv = {
      group = "timbral", weight = 0.5, sensitivity = 0.4, direction = "both",
      -- pitch slide amount: subtle = groove, extreme = acid scream.
      range_lo = 0, range_hi = 6, euclidean_pulses = 5,
    },

    ---------- SYNTHESIS INTERNALS: PERKONS (ch2) ----------
    ch2_drumMode = {
      group = "structural", weight = 0.15, sensitivity = 0.3, direction = "both",
      -- kick/snare/hat morph. rare shifts for drama.
      range_lo = 0, range_hi = 1, euclidean_pulses = 3,
    },
    ch2_fmIndex = {
      group = "timbral", weight = 0.65, sensitivity = 0.5, direction = "both",
      -- FM depth: clean to metallic. Perkons hybrid character.
      range_lo = 0, range_hi = 5, euclidean_pulses = 5,
    },
    ch2_fmRatio = {
      group = "timbral", weight = 0.45, sensitivity = 0.35, direction = "both",
      -- integer = harmonic, non-integer = clangorous.
      range_lo = 0.5, range_hi = 3.5, euclidean_pulses = 3,
    },
    ch2_noiseAmt = {
      group = "timbral", weight = 0.55, sensitivity = 0.45, direction = "both",
      range_lo = 0, range_hi = 0.8, euclidean_pulses = 5,
    },
    ch2_shape = {
      group = "timbral", weight = 0.4, sensitivity = 0.35, direction = "both",
      range_lo = 0, range_hi = 1, euclidean_pulses = 5,
    },
    ch2_pitchEnvAmt = {
      group = "timbral", weight = 0.6, sensitivity = 0.5, direction = "both",
      -- pitch sweep: defines kick punch vs tom vs laser.
      range_lo = 0, range_hi = 10, euclidean_pulses = 5,
    },

    ---------- SYNTHESIS INTERNALS: STEAMPIPE (ch3) ----------
    ch3_exciterNoise = {
      group = "timbral", weight = 0.6, sensitivity = 0.5, direction = "both",
      -- DC=pluck, noise=breath. the soul of physical modeling.
      range_lo = 0, range_hi = 1, euclidean_pulses = 5,
    },
    ch3_feedback = {
      group = "timbral", weight = 0.7, sensitivity = 0.4, direction = "both",
      -- pipe resonance: short=pluck, long=sustained drone.
      range_lo = 0.85, range_hi = 0.995, euclidean_pulses = 5,
    },
    ch3_brightness = {
      group = "timbral", weight = 0.65, sensitivity = 0.55, direction = "both",
      -- exciter brightness: dark thud to bright chime.
      range_lo = 0, range_hi = 1, euclidean_pulses = 7,
    },
    ch3_splitPoint = {
      group = "timbral", weight = 0.4, sensitivity = 0.3, direction = "both",
      -- pipe splitting: creates inharmonic partials.
      range_lo = 0.15, range_hi = 0.85, euclidean_pulses = 3,
    },
    ch3_splitMix = {
      group = "timbral", weight = 0.45, sensitivity = 0.35, direction = "both",
      range_lo = 0, range_hi = 0.8, euclidean_pulses = 5,
    },

    ---------- SYNTHESIS INTERNALS: SYNTRX (ch4) ----------
    ch4_osc1Shape = {
      group = "timbral", weight = 0.55, sensitivity = 0.45, direction = "both",
      -- sine→pulse→saw→varssaw morphing.
      range_lo = 0, range_hi = 1, euclidean_pulses = 5,
    },
    ch4_osc2Ratio = {
      group = "timbral", weight = 0.5, sensitivity = 0.4, direction = "both",
      -- frequency ratio: harmonic vs inharmonic intervals.
      range_lo = 0.5, range_hi = 3.5, euclidean_pulses = 3,
    },
    ch4_ringMod = {
      group = "timbral", weight = 0.6, sensitivity = 0.5, direction = "both",
      -- ring modulator depth: the Syntrx signature.
      range_lo = 0, range_hi = 0.8, euclidean_pulses = 5,
    },
    ch4_noiseLevel = {
      group = "timbral", weight = 0.4, sensitivity = 0.35, direction = "up",
      -- multi-color noise: adds texture and chaos.
      range_lo = 0, range_hi = 0.5, euclidean_pulses = 3,
    },
    ch4_chaosAmt = {
      group = "timbral", weight = 0.7, sensitivity = 0.6, direction = "both",
      -- internal chaos modulation: the Syntrx joystick.
      -- robot should push this for otherworldly moments.
      range_lo = 0, range_hi = 0.8, euclidean_pulses = 7,
    },
  },
}
