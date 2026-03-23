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
      -- how aggressively the explorer mutates. rare shifts.
      range_lo = 0.1,
      range_hi = 0.9,
      euclidean_pulses = 3,
    },
  },
}
