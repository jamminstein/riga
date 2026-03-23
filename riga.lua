-- riga
-- latvian thunder machine
--
-- inspired by the erica synths universe:
-- bassline db-01, perkons hd-01,
-- steampipe, syntrx ii, acidbox,
-- zen delay, plasma drive,
-- black code source, black sequencer
--
-- 4 voices: BASSLINE / PERKONS / STEAMPIPE / SYNTRX
-- autonomous rhythm, polynomial chaos, phase evolution
-- bandmate: 8 performance styles with breathing + song form
--
-- E1: page (thunder/voices/chaos/space/bandmate)
-- E2: select channel or param
-- E3: adjust value
-- K2: play/stop
-- K3 tap: GESTURE (musical event per page)
--     thunder: all-channel fill burst
--     voices: randomize voices within musical range
--     chaos: rewind + scramble coefficients
--     space: FX blast (feedback+reverb swell, auto-decay)
--     bandmate: force phrase boundary (new pattern)
-- K3 hold + E2: select channel
-- K3 hold + E3: secondary param
-- K2+K3: toggle bandmate
--
-- grid top 4 rows: step sequencer (16 x 4)
-- grid row 5-6: voice select + mutes + performance
-- grid row 7: chaos intensity bar
-- grid row 8: play + shuffle + fill + bandmate

engine.name = "Riga"

local musicutil = require "musicutil"
local Thunder = include "lib/thunder"
local Chaos = include "lib/chaos"
local Explorer = include "lib/explorer"
local Bandmate = include "lib/bandmate"

----------------------------------------------------------------
-- state
----------------------------------------------------------------

local thunder = nil
local chaos = nil
local explorer = nil
local bandmate = nil
local g = grid.connect()
local midi_out = nil

local playing = false
local page = 1
local NUM_PAGES = 5
local PAGE_NAMES = {"THUNDER", "VOICES", "CHAOS", "SPACE", "BANDMATE"}
local sel_ch = 1
local sel_param = 1

local screen_dirty = true
local grid_dirty = true

local key3_held = false
local key2_held = false
local grid_held = nil
local fill_release_timers = {}
local gesture_active = false   -- K3 gesture animation
local gesture_timer = 0
local fx_blast_active = false  -- FX blast auto-decay

local active_notes = {{}, {}, {}, {}}

local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local DIVISIONS = {1/4, 1/8, 1/16, 1/32}
local DIV_NAMES = {"1/4", "1/8", "1/16", "1/32"}
local MODE_NAMES = {"BASSLINE", "PERKONS", "STEAMPIPE", "SYNTRX"}
local SHUFFLE_NAMES = {"OFF", "SWING", "PUSH", "DRUNK"}
local FILTER_MODES = {"LP", "BP", "HP"}

-- voice configuration
local voices = {}
for ch = 1, 4 do
  voices[ch] = {
    mode = ch - 1,           -- 0=bassline, 1=perkons, 2=steampipe, 3=syntrx
    note = 36 + (ch - 1) * 7, -- starting notes spread across range
    octave = 0,
    cutoff = 2000,
    res = 0.4,
    drive = 0.3,
    decay = 0.4,
    amp = 0.7,
    pan = (ch - 2.5) * 0.4,
    fxSend = 0.5,
    filterMode = 0,
    -- mode-specific params stored as flat table
    extra = {},
  }
end

-- default voice presets inspired by Erica instruments
local VOICE_PRESETS = {
  -- ch1: BASSLINE — acid bass, low cutoff, heavy drive
  {mode=0, note=36, cutoff=800, res=0.6, drive=0.7, decay=0.3, amp=0.8, pan=0,
   fxSend=0.3, filterMode=0,
   extra={saw=0.8, pulse=0.0, sub=0.6, noise=0.0, bbdDetune=0.2, envMod=0.7, pitchEnv=2}},
  -- ch2: PERKONS — hybrid kick, punchy
  {mode=1, note=48, cutoff=3000, res=0.3, drive=0.4, decay=0.25, amp=0.75, pan=-0.2,
   fxSend=0.4, filterMode=0,
   extra={drumMode=0, fmIndex=1.5, fmRatio=1.0, noiseAmt=0.1, shape=0, pitchEnvAmt=6, pitchDecay=0.04}},
  -- ch3: STEAMPIPE — metallic pipe, medium decay
  {mode=2, note=60, cutoff=5000, res=0.2, drive=0.2, decay=1.2, amp=0.6, pan=0.3,
   fxSend=0.6, filterMode=0,
   extra={exciterNoise=0.6, feedback=0.96, brightness=0.5, splitPoint=0.4, splitMix=0.3, overblow=0}},
  -- ch4: SYNTRX — chaos synth, wide stereo
  {mode=3, note=55, cutoff=3500, res=0.5, drive=0.3, decay=0.6, amp=0.55, pan=0.0,
   fxSend=0.7, filterMode=0,
   extra={osc1Shape=0.3, osc2Ratio=1.5, ringMod=0.2, noiseLevel=0.15, chaosAmt=0.3}},
}

-- FX state
local fx = {
  bbd_time = 0.3, bbd_feedback = 0.4, bbd_color = 0.6, bbd_mix = 0.3, bbd_rate = 0.3,
  poli_cutoff = 4000, poli_res = 0.3, poli_mode = 0, poli_env = 0.2,
  plasma_drive = 0.2, plasma_fold = 0.1, plasma_mix = 0.3,
  zen_size = 0.75, zen_damp = 0.5, zen_mix = 0.25, zen_predelay = 0.04,
}

-- page-specific param lists for encoder navigation
local THUNDER_PARAMS = {"division", "shuffle", "shuffle_amt", "fill_type"}
local VOICE_PARAMS = {"mode", "cutoff", "res", "drive", "decay", "amp", "fxSend", "filterMode"}
local CHAOS_PARAMS = {"active", "intensity", "coeff_x", "coeff_y", "smooth", "loop_len"}
local CHAOS_LABELS = {"ON/OFF", "DEPTH", "DNA-X", "DNA-Y", "SLEW", "LOOP"}
local SPACE_PARAMS = {
  "bbd_time", "bbd_feedback", "bbd_color", "bbd_mix",
  "poli_cutoff", "poli_res", "poli_mode",
  "plasma_drive", "plasma_fold", "plasma_mix",
  "zen_size", "zen_mix",
}
local BANDMATE_PARAMS = {"active", "style", "intensity", "breathing", "form", "form_type", "phrase_len"}

----------------------------------------------------------------
-- init
----------------------------------------------------------------

function init()
  thunder = Thunder.new()
  chaos = Chaos.new()
  explorer = Explorer.new(thunder, chaos)
  bandmate = Bandmate.new(thunder, chaos, explorer)

  -- apply voice presets
  for ch = 1, 4 do
    for k, v in pairs(VOICE_PRESETS[ch]) do
      if k == "extra" then
        voices[ch].extra = v
      else
        voices[ch][k] = v
      end
    end
  end

  -- init thunder patterns
  thunder:init_patterns()

  -- chaos routing defaults
  chaos:route("ch1_cutoff", 1, 0.3, 0)
  chaos:route("ch2_pitchEnvAmt", 2, 0.2, 0)
  chaos:route("ch3_brightness", 3, 0.25, 0)
  chaos:route("ch4_chaosAmt", 4, 0.3, 0)

  -- params
  params:add_separator("RIGA")

  params:add_number("bpm", "BPM", 20, 300, 120)
  params:set_action("bpm", function(v) params:set("clock_tempo", v) end)

  params:add_option("division", "division", DIV_NAMES, 3)

  params:add_option("root", "root note", NOTE_NAMES, 1)
  local scale_names = {}
  for i = 1, #musicutil.SCALES do
    scale_names[i] = musicutil.SCALES[i].name
  end
  params:add_option("scale", "scale", scale_names, 1)

  -- voice params
  for ch = 1, 4 do
    params:add_separator("VOICE " .. ch .. " (" .. MODE_NAMES[ch] .. ")")
    params:add_option("ch" .. ch .. "_mode", "mode", MODE_NAMES, ch)
    params:set_action("ch" .. ch .. "_mode", function(v) voices[ch].mode = v - 1 end)

    params:add_control("ch" .. ch .. "_cutoff", "cutoff",
      controlspec.new(40, 16000, 'exp', 0, voices[ch].cutoff, "hz"))
    params:set_action("ch" .. ch .. "_cutoff", function(v) voices[ch].cutoff = v end)

    params:add_control("ch" .. ch .. "_res", "resonance",
      controlspec.new(0, 1, 'lin', 0.01, voices[ch].res))
    params:set_action("ch" .. ch .. "_res", function(v) voices[ch].res = v end)

    params:add_control("ch" .. ch .. "_drive", "drive",
      controlspec.new(0, 1, 'lin', 0.01, voices[ch].drive))
    params:set_action("ch" .. ch .. "_drive", function(v) voices[ch].drive = v end)

    params:add_control("ch" .. ch .. "_decay", "decay",
      controlspec.new(0.01, 4, 'exp', 0.01, voices[ch].decay, "s"))
    params:set_action("ch" .. ch .. "_decay", function(v) voices[ch].decay = v end)

    params:add_control("ch" .. ch .. "_amp", "amp",
      controlspec.new(0, 1, 'lin', 0.01, voices[ch].amp))
    params:set_action("ch" .. ch .. "_amp", function(v) voices[ch].amp = v end)

    params:add_control("ch" .. ch .. "_fxSend", "fx send",
      controlspec.new(0, 1, 'lin', 0.01, voices[ch].fxSend))
    params:set_action("ch" .. ch .. "_fxSend", function(v) voices[ch].fxSend = v end)
  end

  -- explorer params
  params:add_separator("EXPLORER")
  params:add_option("explorer_active", "explorer", {"off", "on"}, 1)
  params:set_action("explorer_active", function(v) explorer.active = v == 2 end)

  params:add_control("explorer_intensity", "intensity",
    controlspec.new(0, 1, 'lin', 0.01, 0.5))
  params:set_action("explorer_intensity", function(v) explorer.intensity = v end)

  params:add_number("explorer_phase_len", "phase length", 32, 512, 128)
  params:set_action("explorer_phase_len", function(v) explorer.phase_length = v end)

  -- bandmate params
  params:add_separator("BANDMATE")
  params:add_option("bandmate_active", "bandmate", {"off", "on"}, 1)
  params:set_action("bandmate_active", function(v) bandmate.active = v == 2 end)

  params:add_option("bandmate_style", "style", Bandmate.STYLE_NAMES, 1)
  params:set_action("bandmate_style", function(v) bandmate.style = v end)

  params:add_number("bandmate_intensity", "intensity", 1, 10, 5)
  params:set_action("bandmate_intensity", function(v) bandmate.intensity = v end)

  params:add_option("bandmate_breathing", "breathing", {"off", "on"}, 2)
  params:set_action("bandmate_breathing", function(v) bandmate.breathing = v == 2 end)

  params:add_option("bandmate_form", "song form", {"off", "on"}, 1)
  params:set_action("bandmate_form", function(v) bandmate.form_enabled = v == 2 end)

  params:add_option("bandmate_form_type", "form type", bandmate.FORM_NAMES, 1)
  params:set_action("bandmate_form_type", function(v) bandmate.form_type = v end)

  params:add_number("bandmate_phrase_len", "phrase length", 2, 16, 4)
  params:set_action("bandmate_phrase_len", function(v) bandmate.phrase_len = v end)

  -- chaos params
  params:add_separator("CHAOS")
  params:add_option("chaos_active", "chaos", {"off", "on"}, 2)
  params:set_action("chaos_active", function(v) chaos.active = v == 2 end)

  params:add_control("chaos_intensity", "chaos intensity",
    controlspec.new(0, 1, 'lin', 0.01, 0.5))
  params:set_action("chaos_intensity", function(v) chaos.intensity = v end)

  params:add_control("chaos_rate", "chaos rate",
    controlspec.new(0, 1, 'lin', 0.01, 0.5))
  params:set_action("chaos_rate", function(v) chaos.rate = v end)

  -- FX params
  params:add_separator("BBD DELAY")
  params:add_control("bbd_time", "delay time",
    controlspec.new(0.01, 2, 'exp', 0.01, fx.bbd_time, "s"))
  params:set_action("bbd_time", function(v) fx.bbd_time = v; engine.bbd_time(v) end)

  params:add_control("bbd_feedback", "delay feedback",
    controlspec.new(0, 0.95, 'lin', 0.01, fx.bbd_feedback))
  params:set_action("bbd_feedback", function(v) fx.bbd_feedback = v; engine.bbd_feedback(v) end)

  params:add_control("bbd_color", "delay color",
    controlspec.new(0, 1, 'lin', 0.01, fx.bbd_color))
  params:set_action("bbd_color", function(v) fx.bbd_color = v; engine.bbd_color(v) end)

  params:add_control("bbd_mix", "delay mix",
    controlspec.new(0, 1, 'lin', 0.01, fx.bbd_mix))
  params:set_action("bbd_mix", function(v) fx.bbd_mix = v; engine.bbd_mix(v) end)

  params:add_separator("POLIVOKS FILTER")
  params:add_control("poli_cutoff", "filter cutoff",
    controlspec.new(40, 16000, 'exp', 0, fx.poli_cutoff, "hz"))
  params:set_action("poli_cutoff", function(v) fx.poli_cutoff = v; engine.poli_cutoff(v) end)

  params:add_control("poli_res", "filter res",
    controlspec.new(0, 1, 'lin', 0.01, fx.poli_res))
  params:set_action("poli_res", function(v) fx.poli_res = v; engine.poli_res(v) end)

  params:add_option("poli_mode", "filter mode", FILTER_MODES, 1)
  params:set_action("poli_mode", function(v) fx.poli_mode = v - 1; engine.poli_mode(v - 1) end)

  params:add_separator("PLASMA DRIVE")
  params:add_control("plasma_drive", "plasma drive",
    controlspec.new(0, 1, 'lin', 0.01, fx.plasma_drive))
  params:set_action("plasma_drive", function(v) fx.plasma_drive = v; engine.plasma_drive(v) end)

  params:add_control("plasma_fold", "plasma fold",
    controlspec.new(0, 1, 'lin', 0.01, fx.plasma_fold))
  params:set_action("plasma_fold", function(v) fx.plasma_fold = v; engine.plasma_fold(v) end)

  params:add_control("plasma_mix", "plasma mix",
    controlspec.new(0, 1, 'lin', 0.01, fx.plasma_mix))
  params:set_action("plasma_mix", function(v) fx.plasma_mix = v; engine.plasma_mix(v) end)

  params:add_separator("ZEN REVERB")
  params:add_control("zen_size", "reverb size",
    controlspec.new(0, 1, 'lin', 0.01, fx.zen_size))
  params:set_action("zen_size", function(v) fx.zen_size = v; engine.zen_size(v) end)

  params:add_control("zen_damp", "reverb damp",
    controlspec.new(0, 1, 'lin', 0.01, fx.zen_damp))
  params:set_action("zen_damp", function(v) fx.zen_damp = v; engine.zen_damp(v) end)

  params:add_control("zen_mix", "reverb mix",
    controlspec.new(0, 1, 'lin', 0.01, fx.zen_mix))
  params:set_action("zen_mix", function(v) fx.zen_mix = v; engine.zen_mix(v) end)

  -- MIDI
  params:add_separator("MIDI")
  params:add_number("midi_device", "midi device", 1, 4, 1)
  params:set_action("midi_device", function(v) midi_out = midi.connect(v) end)
  midi_out = midi.connect(params:get("midi_device"))

  params:add_option("midi_enabled", "midi out", {"off", "on"}, 1)
  for ch = 1, 4 do
    params:add_number("midi_ch_" .. ch, "ch " .. ch .. " midi ch", 1, 16, ch)
  end

  -- OP-XY MIDI out
  params:add_separator("OP-XY")
  params:add_number("opxy_device", "op-xy device", 1, 4, 2)
  params:add_option("opxy_enabled", "op-xy out", {"off", "on"}, 1)
  for ch = 1, 4 do
    params:add_number("opxy_ch_" .. ch, "ch " .. ch .. " op-xy ch", 1, 16, ch + 4)
  end

  -- init FX
  engine.bbd_time(fx.bbd_time)
  engine.bbd_feedback(fx.bbd_feedback)
  engine.bbd_color(fx.bbd_color)
  engine.bbd_mix(fx.bbd_mix)
  engine.bbd_rate(fx.bbd_rate)
  engine.poli_cutoff(fx.poli_cutoff)
  engine.poli_res(fx.poli_res)
  engine.poli_mode(fx.poli_mode)
  engine.poli_env(fx.poli_env)
  engine.plasma_drive(fx.plasma_drive)
  engine.plasma_fold(fx.plasma_fold)
  engine.plasma_mix(fx.plasma_mix)
  engine.zen_size(fx.zen_size)
  engine.zen_damp(fx.zen_damp)
  engine.zen_mix(fx.zen_mix)
  engine.zen_predelay(fx.zen_predelay)

  -- start clock
  clock.run(step_clock)

  -- screen refresh
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if screen_dirty then
        redraw()
        screen_dirty = false
      end
      if grid_dirty then
        grid_redraw()
        grid_dirty = false
      end
    end
  end)

  -- grid connection callback
  g.key = grid_key
end

----------------------------------------------------------------
-- clock / sequencer
----------------------------------------------------------------

function step_clock()
  while true do
    clock.sync(DIVISIONS[params:get("division")])

    if playing then
      -- advance chaos
      chaos:step()

      -- advance bandmate
      local bm_changes = bandmate:step()
      apply_explorer_changes(bm_changes)

      -- advance explorer
      local changes = explorer:step()
      apply_explorer_changes(changes)

      -- gesture animation decay
      if gesture_active then
        gesture_timer = gesture_timer - 1
        if gesture_timer <= 0 then gesture_active = false end
      end

      -- FX blast auto-decay (returns FX to normal over 4 bars)
      if fx_blast_active then
        fx.bbd_feedback = util.clamp(fx.bbd_feedback - 0.008, 0, 0.95)
        fx.zen_mix = util.clamp(fx.zen_mix - 0.005, 0, 1)
        engine.bbd_feedback(fx.bbd_feedback)
        engine.zen_mix(fx.zen_mix)
        if fx.bbd_feedback < 0.4 and fx.zen_mix < 0.3 then
          fx_blast_active = false
        end
      end

      -- advance thunder and trigger voices
      local results = thunder:advance()

      for _, r in ipairs(results) do
        if r.triggered then
          -- ratchet handling
          if r.ratchet > 1 then
            -- trigger first hit immediately
            trigger_voice(r.ch, r.accent, r.locks)
            -- schedule remaining ratchet hits
            local div = DIVISIONS[params:get("division")]
            for i = 2, r.ratchet do
              clock.run(function()
                clock.sleep(div * (i - 1) / r.ratchet * clock.get_beat_sec())
                trigger_voice(r.ch, r.accent * (1 - (i - 1) * 0.15), r.locks)
              end)
            end
          else
            trigger_voice(r.ch, r.accent, r.locks)
          end
        end
      end

      -- process fill release timers
      local new_timers = {}
      for _, t in ipairs(fill_release_timers) do
        t.delay = t.delay - 1
        if t.delay <= 0 then
          thunder.channels[t.ch].fill_active = false
        else
          table.insert(new_timers, t)
        end
      end
      fill_release_timers = new_timers

      screen_dirty = true
      grid_dirty = true
    end
  end
end

function trigger_voice(ch, accent, locks)
  local v = voices[ch]
  accent = accent or 0

  -- get note from scale
  local root = params:get("root") - 1
  local scale_idx = params:get("scale")
  local scale_notes = musicutil.generate_scale(root + 24, musicutil.SCALES[scale_idx].name, 4)

  -- find closest note in scale to voice's base note
  local note = v.note + v.octave * 12
  -- snap to nearest scale note
  local min_dist = 999
  local snapped = note
  for _, sn in ipairs(scale_notes) do
    local dist = math.abs(sn - note)
    if dist < min_dist then
      min_dist = dist
      snapped = sn
    end
  end
  note = snapped

  local freq = musicutil.note_num_to_freq(note)

  -- apply chaos modulation to voice params
  local mod_cutoff = chaos:modulate("ch" .. ch .. "_cutoff", v.cutoff, 40, 16000)
  local mod_decay = v.decay

  -- apply parameter locks from step
  if locks then
    if locks.cutoff then mod_cutoff = locks.cutoff end
    if locks.decay then mod_decay = locks.decay end
  end

  -- trigger engine
  engine.trig(ch, v.mode, freq)

  -- set voice params
  engine.voice_param(ch, "amp", v.amp)
  engine.voice_param(ch, "pan", v.pan)
  engine.voice_param(ch, "cutoff", mod_cutoff)
  engine.voice_param(ch, "res", v.res)
  engine.voice_param(ch, "drive", v.drive)
  engine.voice_param(ch, "decay", mod_decay)
  engine.voice_param(ch, "fxSend", v.fxSend)
  engine.voice_param(ch, "filterMode", v.filterMode)
  engine.voice_param(ch, "accent", accent)

  -- set mode-specific extra params
  for k, val in pairs(v.extra) do
    -- apply chaos modulation to specific params
    local mod_val = chaos:modulate("ch" .. ch .. "_" .. k, val, 0, 1)
    engine.voice_param(ch, k, mod_val)
  end

  -- MIDI out
  if params:get("midi_enabled") == 2 and midi_out then
    local midi_ch = params:get("midi_ch_" .. ch)
    -- note off previous
    for _, n in ipairs(active_notes[ch]) do
      midi_out:note_off(n, 0, midi_ch)
    end
    local vel = util.clamp(math.floor((v.amp + accent * 0.3) * 127), 1, 127)
    midi_out:note_on(note, vel, midi_ch)
    active_notes[ch] = {note}
  end

  -- OP-XY MIDI out
  if params:get("opxy_enabled") == 2 then
    local opxy = midi.connect(params:get("opxy_device"))
    if opxy then
      local opxy_ch = params:get("opxy_ch_" .. ch)
      local vel = util.clamp(math.floor((v.amp + accent * 0.3) * 127), 1, 127)
      opxy:note_on(note, vel, opxy_ch)
      -- auto note-off after decay
      clock.run(function()
        clock.sleep(mod_decay)
        opxy:note_off(note, 0, opxy_ch)
      end)
    end
  end
end

function apply_explorer_changes(changes)
  for _, c in ipairs(changes) do
    if c.type == "voice_delta" then
      local key = "ch" .. c.ch .. "_" .. c.param
      if c.param == "cutoff" then
        voices[c.ch].cutoff = util.clamp(voices[c.ch].cutoff + c.delta, 40, 16000)
      elseif c.param == "drive" then
        voices[c.ch].drive = util.clamp(voices[c.ch].drive + c.delta, 0, 1)
      elseif c.param == "res" then
        voices[c.ch].res = util.clamp(voices[c.ch].res + c.delta, 0, 1)
      elseif c.param == "decay" then
        voices[c.ch].decay = util.clamp(voices[c.ch].decay + c.delta, 0.01, 4)
      elseif c.param == "fxSend" then
        voices[c.ch].fxSend = util.clamp(voices[c.ch].fxSend + c.delta, 0, 1)
      end
    elseif c.type == "fx_delta" then
      if fx[c.param] then
        local new_val
        if string.find(c.param, "cutoff") then
          new_val = util.clamp(fx[c.param] + c.delta, 40, 16000)
        elseif string.find(c.param, "time") then
          new_val = util.clamp(fx[c.param] + c.delta, 0.01, 2)
        elseif string.find(c.param, "feedback") then
          new_val = util.clamp(fx[c.param] + c.delta, 0, 0.95)
        else
          new_val = util.clamp(fx[c.param] + c.delta, 0, 1)
        end
        fx[c.param] = new_val
        -- update via params system (which sends to engine)
        if params.lookup[c.param] then
          params:set(c.param, new_val)
        end
      end
    elseif c.type == "fill_release" then
      table.insert(fill_release_timers, {ch = c.ch, delay = c.delay})
    elseif c.type == "phase" then
      screen_dirty = true
    end
  end
end

----------------------------------------------------------------
-- input: encoders
----------------------------------------------------------------

function enc(n, d)
  if n == 1 then
    page = util.clamp(page + d, 1, NUM_PAGES)
    sel_param = 1
  elseif n == 2 then
    if page == 1 then -- THUNDER
      if key3_held then
        sel_param = util.clamp(sel_param + d, 1, #THUNDER_PARAMS)
      else
        sel_ch = util.clamp(sel_ch + d, 1, 4)
      end
    elseif page == 2 then -- VOICES
      if key3_held then
        sel_param = util.clamp(sel_param + d, 1, #VOICE_PARAMS)
      else
        sel_ch = util.clamp(sel_ch + d, 1, 4)
      end
    elseif page == 3 then -- CHAOS
      sel_param = util.clamp(sel_param + d, 1, #CHAOS_PARAMS)
    elseif page == 4 then -- SPACE
      sel_param = util.clamp(sel_param + d, 1, #SPACE_PARAMS)
    elseif page == 5 then -- BANDMATE
      sel_param = util.clamp(sel_param + d, 1, #BANDMATE_PARAMS)
    end
  elseif n == 3 then
    if page == 1 then -- THUNDER
      local p = THUNDER_PARAMS[sel_param]
      if p == "division" then
        params:delta("division", d)
      elseif p == "shuffle" then
        thunder.shuffle = util.clamp(thunder.shuffle + d, 1, 4)
      elseif p == "shuffle_amt" then
        thunder.shuffle_amount = util.clamp(thunder.shuffle_amount + d * 0.05, 0, 1)
      elseif p == "fill_type" then
        thunder.fill_type = util.clamp(thunder.fill_type + d, 1, 4)
      end
    elseif page == 2 then -- VOICES
      local p = VOICE_PARAMS[sel_param]
      local ch = sel_ch
      if p == "mode" then
        params:delta("ch" .. ch .. "_mode", d)
      elseif p == "cutoff" then
        params:delta("ch" .. ch .. "_cutoff", d)
      elseif p == "res" then
        params:delta("ch" .. ch .. "_res", d)
      elseif p == "drive" then
        params:delta("ch" .. ch .. "_drive", d)
      elseif p == "decay" then
        params:delta("ch" .. ch .. "_decay", d)
      elseif p == "amp" then
        params:delta("ch" .. ch .. "_amp", d)
      elseif p == "fxSend" then
        params:delta("ch" .. ch .. "_fxSend", d)
      elseif p == "filterMode" then
        voices[ch].filterMode = util.clamp(voices[ch].filterMode + d, 0, 2)
      end
    elseif page == 3 then -- CHAOS
      local p = CHAOS_PARAMS[sel_param]
      if p == "active" then
        chaos.active = not chaos.active
        params:set("chaos_active", chaos.active and 2 or 1)
      elseif p == "intensity" then
        chaos.intensity = util.clamp(chaos.intensity + d * 0.03, 0, 1)
        params:set("chaos_intensity", chaos.intensity)
      elseif p == "coeff_x" then
        chaos.coeff_x = util.clamp(chaos.coeff_x + d * 0.05, 2.5, 4.0)
      elseif p == "coeff_y" then
        chaos.coeff_y = util.clamp(chaos.coeff_y + d * 0.05, 0.5, 3.5)
      elseif p == "smooth" then
        chaos.smooth_factor = util.clamp(chaos.smooth_factor + d * 0.05, 0, 1)
      elseif p == "loop_len" then
        chaos.loop_length = util.clamp(chaos.loop_length + d * 4, 0, 256)
        if chaos.loop_length == 0 then chaos.loop_buffer = {} end
      end
    elseif page == 4 then -- SPACE
      local p = SPACE_PARAMS[sel_param]
      if p then params:delta(p, d) end
    elseif page == 5 then -- BANDMATE
      local p = BANDMATE_PARAMS[sel_param]
      if p == "active" then
        params:delta("bandmate_active", d)
      elseif p == "style" then
        params:delta("bandmate_style", d)
      elseif p == "intensity" then
        params:delta("bandmate_intensity", d)
      elseif p == "breathing" then
        params:delta("bandmate_breathing", d)
      elseif p == "form" then
        params:delta("bandmate_form", d)
      elseif p == "form_type" then
        params:delta("bandmate_form_type", d)
      elseif p == "phrase_len" then
        params:delta("bandmate_phrase_len", d)
      end
    end
  end
  screen_dirty = true
end

----------------------------------------------------------------
-- input: keys
----------------------------------------------------------------

function key(n, z)
  if n == 2 then
    key2_held = z == 1
    if z == 1 then
      -- K2+K3 combo: toggle bandmate
      if key3_held then
        bandmate.active = not bandmate.active
        params:set("bandmate_active", bandmate.active and 2 or 1)
      else
        playing = not playing
        if not playing then
          all_notes_off()
        end
      end
    end
  elseif n == 3 then
    key3_held = z == 1
    if z == 1 then
      -- K2+K3 combo: toggle bandmate
      if key2_held then
        bandmate.active = not bandmate.active
        params:set("bandmate_active", bandmate.active and 2 or 1)
      else
        -- GESTURE: dramatic one-shot musical event per page
        gesture_active = true
        gesture_timer = 8

        if page == 1 then
          -- THUNDER GESTURE: all-channel fill burst
          for ch = 1, 4 do
            thunder.channels[ch].fill_active = true
            table.insert(fill_release_timers, {ch = ch, delay = 16})
          end
        elseif page == 2 then
          -- VOICES GESTURE: randomize all voice timbres within musical range
          for ch = 1, 4 do
            voices[ch].cutoff = 200 + math.random() * 6000
            voices[ch].res = 0.1 + math.random() * 0.6
            voices[ch].drive = math.random() * 0.7
            voices[ch].decay = 0.05 + math.random() * 1.5
          end
        elseif page == 3 then
          -- CHAOS GESTURE: rewind + scramble coefficients
          chaos:rewind()
          chaos:drift(0.5)
          chaos.smooth_factor = math.random()
        elseif page == 4 then
          -- SPACE GESTURE: FX blast (max feedback + reverb, auto-decays)
          fx.bbd_feedback = 0.88
          fx.zen_mix = 0.7
          fx.zen_size = 0.92
          engine.bbd_feedback(fx.bbd_feedback)
          engine.zen_mix(fx.zen_mix)
          engine.zen_size(fx.zen_size)
          fx_blast_active = true
        elseif page == 5 then
          -- BANDMATE GESTURE: force phrase boundary
          for ch = 1, 4 do
            thunder:mutate(ch, 0.25)
          end
          bandmate.home_state = nil  -- reset form home
        end
      end
    else
      -- K3 release
      if page == 1 then
        for ch = 1, 4 do
          thunder.channels[ch].fill_active = false
        end
      end
    end
  end
  screen_dirty = true
end

----------------------------------------------------------------
-- grid
----------------------------------------------------------------

function grid_key(x, y, z)
  if z == 1 then
    if y <= 4 then
      -- step sequencer: toggle step
      local ch = y
      if x <= 16 then
        if key3_held then
          -- hold K3 + grid step: cycle ratchet 1→2→3→4→1
          local step = thunder.channels[ch].steps[x]
          step.ratchet = (step.ratchet % 4) + 1
        else
          thunder:toggle_step(ch, x)
        end
      end
    elseif y == 5 then
      -- voice select
      if x <= 4 then
        sel_ch = x
      -- mute toggles
      elseif x >= 5 and x <= 8 then
        local ch = x - 4
        thunder.channels[ch].muted = not thunder.channels[ch].muted
      -- fill triggers
      elseif x >= 9 and x <= 12 then
        local ch = x - 8
        thunder.channels[ch].fill_active = true
        grid_held = {type = "fill", ch = ch}
      -- pattern operations
      elseif x == 13 then
        thunder:randomize(sel_ch, 0.4)
      elseif x == 14 then
        thunder:mutate(sel_ch, 0.3)
      elseif x == 15 then
        thunder:rotate(sel_ch, 1)
      elseif x == 16 then
        thunder:rotate(sel_ch, -1)
      end
    elseif y == 6 then
      -- voice mode select per channel
      if x <= 4 then
        -- cycle mode for channel x
        voices[x].mode = (voices[x].mode + 1) % 4
        params:set("ch" .. x .. "_mode", voices[x].mode + 1)
      -- explorer controls
      elseif x == 9 then
        explorer.active = not explorer.active
        params:set("explorer_active", explorer.active and 2 or 1)
      elseif x >= 10 and x <= 13 then
        -- force explorer phase
        explorer:set_phase(x - 9)
      -- chaos controls
      elseif x == 15 then
        chaos.active = not chaos.active
        params:set("chaos_active", chaos.active and 2 or 1)
      elseif x == 16 then
        chaos:rewind()
      end
    elseif y == 7 then
      -- chaos routing intensity per column (1-16 = intensity levels)
      chaos.intensity = x / 16
      params:set("chaos_intensity", chaos.intensity)
    elseif y == 8 then
      -- bottom row: play/stop, shuffle, bandmate, fill, global fill
      if x == 1 then
        playing = not playing
        if not playing then all_notes_off() end
      elseif x >= 3 and x <= 6 then
        -- shuffle type
        thunder.shuffle = x - 2
      elseif x == 8 then
        -- bandmate toggle
        bandmate.active = not bandmate.active
        params:set("bandmate_active", bandmate.active and 2 or 1)
      elseif x >= 9 and x <= 12 then
        -- fill type
        thunder.fill_type = x - 8
      elseif x == 14 then
        -- cycle bandmate style
        bandmate.style = (bandmate.style % #Bandmate.STYLE_NAMES) + 1
        params:set("bandmate_style", bandmate.style)
      elseif x == 15 then
        -- toggle song form
        bandmate.form_enabled = not bandmate.form_enabled
        params:set("bandmate_form", bandmate.form_enabled and 2 or 1)
      elseif x == 16 then
        -- global fill (all channels)
        thunder.fill_mode = true
        grid_held = {type = "global_fill"}
      end
    end
  else
    -- release
    if grid_held then
      if grid_held.type == "fill" then
        thunder.channels[grid_held.ch].fill_active = false
      elseif grid_held.type == "global_fill" then
        thunder.fill_mode = false
      end
      grid_held = nil
    end
  end
  screen_dirty = true
  grid_dirty = true
end

function grid_redraw()
  g:all(0)

  -- top 4 rows: step sequencer
  for ch = 1, 4 do
    local channel = thunder.channels[ch]
    for s = 1, channel.length do
      local step = channel.steps[s]
      local bright = 0

      if step.active then
        -- brightness encodes probability
        bright = math.floor(step.probability * 10) + 2
        if step.ratchet > 1 then bright = math.min(15, bright + 2) end
      end

      -- playhead
      if playing and channel.position == s then
        bright = 15
      end

      -- muted channel dimming
      if channel.muted then
        bright = math.floor(bright * 0.3)
      end

      g:led(s, ch, util.clamp(bright, 0, 15))
    end
  end

  -- row 5: voice select + mutes + fills + pattern ops
  for x = 1, 4 do
    g:led(x, 5, sel_ch == x and 15 or 4)
  end
  for x = 5, 8 do
    local ch = x - 4
    g:led(x, 5, thunder.channels[ch].muted and 2 or 8)
  end
  for x = 9, 12 do
    local ch = x - 8
    g:led(x, 5, thunder.channels[ch].fill_active and 15 or 3)
  end
  g:led(13, 5, 5) -- randomize
  g:led(14, 5, 5) -- mutate
  g:led(15, 5, 4) -- rotate L
  g:led(16, 5, 4) -- rotate R

  -- row 6: voice modes + explorer + chaos
  for x = 1, 4 do
    g:led(x, 6, math.floor(voices[x].mode * 3) + 4)
  end
  g:led(9, 6, explorer.active and 12 or 3)
  for x = 10, 13 do
    g:led(x, 6, explorer.phase == (x - 9) and 15 or 4)
  end
  g:led(15, 6, chaos.active and 12 or 3)
  g:led(16, 6, 6) -- rewind

  -- row 7: chaos intensity bar
  local chaos_level = math.floor(chaos.intensity * 16)
  for x = 1, 16 do
    g:led(x, 7, x <= chaos_level and 8 or 1)
  end

  -- row 8: play + shuffle + fill type + bandmate + global fill
  g:led(1, 8, playing and 15 or 4)
  for x = 3, 6 do
    g:led(x, 8, thunder.shuffle == (x - 2) and 12 or 3)
  end
  -- bandmate toggle + style
  g:led(8, 8, bandmate.active and 15 or 3)
  for x = 9, 12 do
    g:led(x, 8, thunder.fill_type == (x - 8) and 12 or 3)
  end
  -- bandmate energy as brightness on 14-15
  local bm_bright = math.floor(bandmate.energy * 12) + 2
  g:led(14, 8, bandmate.active and bm_bright or 2)
  g:led(15, 8, bandmate.active and math.floor(bm_bright * 0.7) or 2)
  g:led(16, 8, thunder.fill_mode and 15 or 5)

  g:refresh()
end

----------------------------------------------------------------
-- screen
----------------------------------------------------------------

function redraw()
  screen.clear()

  -- header
  screen.level(playing and 15 or 5)
  screen.move(0, 7)
  screen.text("RIGA")

  -- page dots
  for i = 1, NUM_PAGES do
    screen.level(page == i and 15 or 3)
    screen.rect(30 + (i - 1) * 6, 2, 4, 4)
    screen.fill()
  end

  -- page name + status
  screen.level(10)
  screen.move(60, 7)
  screen.text(PAGE_NAMES[page])

  -- explorer phase indicator
  if explorer.active then
    screen.level(7)
    screen.move(100, 7)
    screen.text(explorer:get_phase_name())
  end

  -- BPM
  screen.level(5)
  screen.move(128, 7)
  screen.text_right(params:get("bpm") .. "")

  -- gesture flash
  if gesture_active then
    screen.level(15)
    screen.rect(0, 0, 128, 64)
    screen.stroke()
  end

  -- bandmate indicator in header
  if bandmate.active then
    screen.level(bandmate.energy > 0.5 and 10 or 4)
    screen.move(52, 7)
    screen.text("~")
  end

  -- page content
  if page == 1 then
    draw_thunder()
  elseif page == 2 then
    draw_voices()
  elseif page == 3 then
    draw_chaos()
  elseif page == 4 then
    draw_space()
  elseif page == 5 then
    draw_bandmate()
  end

  screen.update()
end

function draw_thunder()
  -- 4-track step view with probability bars and ratchet indicators
  local y_start = 14
  local step_w = 7
  local track_h = 10

  for ch = 1, 4 do
    local channel = thunder.channels[ch]
    local y = y_start + (ch - 1) * (track_h + 2)
    local is_sel = sel_ch == ch

    -- channel label
    screen.level(is_sel and 15 or 4)
    screen.move(0, y + 7)
    screen.text(ch)

    -- mute indicator
    if channel.muted then
      screen.level(2)
      screen.move(4, y + 7)
      screen.text("x")
    end

    -- steps
    for s = 1, channel.length do
      local step = channel.steps[s]
      local sx = 8 + (s - 1) * step_w
      local is_playing = playing and channel.position == s

      if step.active then
        -- probability as bar height
        local bar_h = math.floor(step.probability * track_h)
        screen.level(is_playing and 15 or (is_sel and 8 or 5))
        screen.rect(sx, y + track_h - bar_h, step_w - 1, bar_h)
        screen.fill()

        -- ratchet dots
        if step.ratchet > 1 then
          screen.level(12)
          for r = 1, step.ratchet do
            screen.rect(sx + r * 1.5, y, 1, 1)
            screen.fill()
          end
        end
      else
        -- empty step outline
        if is_playing then
          screen.level(6)
          screen.rect(sx, y, step_w - 1, track_h)
          screen.stroke()
        end
      end
    end
  end

  -- footer: selected param
  screen.level(8)
  screen.move(0, 63)
  local p = THUNDER_PARAMS[sel_param]
  if p == "division" then
    screen.text("DIV: " .. DIV_NAMES[params:get("division")])
  elseif p == "shuffle" then
    screen.text("SHUFFLE: " .. SHUFFLE_NAMES[thunder.shuffle])
  elseif p == "shuffle_amt" then
    screen.text("SWING: " .. string.format("%.0f%%", thunder.shuffle_amount * 100))
  elseif p == "fill_type" then
    local ft_names = {"EUCLID", "RANDOM", "DOUBLE", "CASCADE"}
    screen.text("FILL: " .. ft_names[thunder.fill_type])
  end
end

function draw_voices()
  local y_start = 12

  for ch = 1, 4 do
    local v = voices[ch]
    local y = y_start + (ch - 1) * 13
    local is_sel = sel_ch == ch

    -- channel label + mode
    screen.level(is_sel and 15 or 5)
    screen.move(0, y + 8)
    screen.text(ch .. ":" .. MODE_NAMES[v.mode + 1]:sub(1, 4))

    -- amp bar
    local bar_w = math.floor(v.amp * 24)
    screen.level(is_sel and 10 or 4)
    screen.rect(35, y + 1, bar_w, 5)
    screen.fill()
    screen.level(2)
    screen.rect(35, y + 1, 24, 5)
    screen.stroke()

    -- cutoff indicator (small arc/line)
    local cutoff_x = 64 + math.floor(math.log(v.cutoff / 40) / math.log(16000 / 40) * 25)
    screen.level(is_sel and 12 or 5)
    screen.move(64, y + 6)
    screen.line(cutoff_x, y + 2)
    screen.stroke()

    -- resonance as dot size
    local dot_r = math.floor(v.res * 4) + 1
    screen.level(is_sel and 10 or 4)
    screen.rect(cutoff_x - dot_r, y + 1, dot_r * 2, dot_r * 2)
    screen.fill()

    -- drive meter
    local drive_h = math.floor(v.drive * 8)
    screen.level(v.drive > 0.6 and 15 or (is_sel and 8 or 3))
    screen.rect(95, y + 8 - drive_h, 3, drive_h)
    screen.fill()

    -- fx send
    screen.level(is_sel and 7 or 3)
    screen.move(102, y + 8)
    screen.text(string.format("%.0f", v.fxSend * 100))

    -- filter mode
    screen.level(is_sel and 6 or 2)
    screen.move(120, y + 8)
    screen.text(FILTER_MODES[v.filterMode + 1])
  end

  -- footer: controls hint
  screen.level(8)
  screen.move(0, 63)
  screen.text("E2:voice E3:" .. VOICE_PARAMS[sel_param])
  screen.level(4)
  screen.move(128, 63)
  screen.text_right("K3+E2:param")
end

function draw_chaos()
  -- XY phase space plot (the main visual — big and central)
  local plot_x = 0
  local plot_y = 11
  local plot_w = 56
  local plot_h = 40

  -- plot border
  screen.level(chaos.active and 4 or 2)
  screen.rect(plot_x, plot_y, plot_w, plot_h)
  screen.stroke()

  -- plot chaos outputs as XY pairs (2 dots bouncing in phase space)
  if chaos.active then
    for i = 1, 2 do
      local cx = plot_x + 2 + chaos:get(i * 2 - 1) * (plot_w - 4)
      local cy = plot_y + 2 + chaos:get(i * 2) * (plot_h - 4)
      screen.level(i == 1 and 15 or 7)
      screen.rect(cx - 1, cy - 1, 3, 3)
      screen.fill()
    end
    -- 4 output bars along the bottom of the plot
    for ch = 1, 4 do
      local val = chaos:get(ch)
      local bw = math.floor(val * 12)
      screen.level(6)
      screen.rect(plot_x + 2 + (ch - 1) * 14, plot_y + plot_h - 4, bw, 3)
      screen.fill()
    end
  else
    screen.level(3)
    screen.move(plot_x + 12, plot_y + 22)
    screen.text("(OFF)")
  end

  -- right column: all params with selection highlight
  local rx = 62
  for i, p in ipairs(CHAOS_PARAMS) do
    local y = 12 + (i - 1) * 9
    local is_sel = sel_param == i
    local label = CHAOS_LABELS[i]
    local val_str = ""

    if p == "active" then
      val_str = chaos.active and "ON" or "OFF"
    elseif p == "intensity" then
      val_str = string.format("%.0f%%", chaos.intensity * 100)
    elseif p == "coeff_x" then
      val_str = string.format("%.2f", chaos.coeff_x)
    elseif p == "coeff_y" then
      val_str = string.format("%.2f", chaos.coeff_y)
    elseif p == "smooth" then
      val_str = string.format("%.0f%%", chaos.smooth_factor * 100)
    elseif p == "loop_len" then
      val_str = chaos.loop_length == 0 and "FREE" or tostring(chaos.loop_length)
    end

    -- selection indicator
    if is_sel then
      screen.level(15)
      screen.rect(rx - 2, y - 6, 68, 9)
      screen.fill()
      screen.level(0)
    else
      screen.level(6)
    end

    screen.move(rx, y)
    screen.text(label)
    screen.move(128, y)
    screen.text_right(val_str)
  end

  -- footer: K3 gesture hint
  screen.level(4)
  screen.move(0, 63)
  screen.text("K3:rewind+scramble")
end

function draw_space()
  -- FX chain visualization: BBD → POLIVOKS → PLASMA → ZEN
  local sections = {
    {name="BBD", x=0, params={"bbd_time","bbd_feedback","bbd_color","bbd_mix"}},
    {name="POLI", x=32, params={"poli_cutoff","poli_res","poli_mode"}},
    {name="PLSM", x=64, params={"plasma_drive","plasma_fold","plasma_mix"}},
    {name="ZEN", x=96, params={"zen_size","zen_mix"}},
  }

  for si, sec in ipairs(sections) do
    local x = sec.x
    local is_active_section = false

    -- check if selected param is in this section
    local sp = SPACE_PARAMS[sel_param]
    for _, p in ipairs(sec.params) do
      if p == sp then is_active_section = true end
    end

    -- section header
    screen.level(is_active_section and 15 or 6)
    screen.move(x + 2, 16)
    screen.text(sec.name)

    -- connection arrow
    if si < 4 then
      screen.level(3)
      screen.move(x + 28, 13)
      screen.line(x + 32, 13)
      screen.stroke()
    end

    -- param bars
    for pi, p in ipairs(sec.params) do
      local y = 20 + (pi - 1) * 10
      local val = fx[p] or 0
      local is_sel = sp == p

      -- normalize for display
      local norm
      if string.find(p, "cutoff") then
        norm = math.log(val / 40) / math.log(16000 / 40)
      elseif string.find(p, "time") then
        norm = val / 2
      else
        norm = val
      end
      norm = util.clamp(norm, 0, 1)

      local bar_w = math.floor(norm * 26)
      screen.level(is_sel and 12 or 5)
      screen.rect(x + 2, y, bar_w, 6)
      screen.fill()

      screen.level(is_sel and 8 or 2)
      screen.rect(x + 2, y, 26, 6)
      screen.stroke()

      -- param name (tiny)
      if is_sel then
        screen.level(10)
        screen.move(x + 2, y + 5)
        local short = p:gsub("bbd_",""):gsub("poli_",""):gsub("plasma_",""):gsub("zen_","")
        screen.text(short:sub(1, 4))
      end
    end
  end

  -- footer
  screen.level(8)
  screen.move(0, 63)
  local sp = SPACE_PARAMS[sel_param]
  if sp then
    local val = fx[sp] or 0
    local display
    if string.find(sp, "cutoff") then
      display = string.format("%.0fhz", val)
    elseif string.find(sp, "time") or string.find(sp, "predelay") then
      display = string.format("%.2fs", val)
    else
      display = string.format("%.0f%%", val * 100)
    end
    screen.text(sp:gsub("_"," ") .. ": " .. display)
  end
end

function draw_bandmate()
  -- bandmate status
  screen.level(bandmate.active and 15 or 4)
  screen.move(0, 18)
  screen.text("BANDMATE")

  -- style name (large)
  screen.level(bandmate.active and 15 or 5)
  screen.move(0, 32)
  screen.text(Bandmate.STYLE_NAMES[bandmate.style])

  -- intensity bar
  local int_w = math.floor(bandmate.intensity / 10 * 50)
  screen.level(8)
  screen.rect(70, 22, int_w, 8)
  screen.fill()
  screen.level(3)
  screen.rect(70, 22, 50, 8)
  screen.stroke()
  screen.level(6)
  screen.move(72, 29)
  screen.text("INT:" .. bandmate.intensity)

  -- breathing visualization
  if bandmate.breathing then
    local breath_w = math.floor(bandmate.energy * 40)
    local breath_phase = bandmate:get_breath_phase()
    screen.level(breath_phase == "silence" and 2 or (breath_phase == "build" and 10 or 7))
    screen.rect(0, 38, breath_w, 5)
    screen.fill()
    screen.level(2)
    screen.rect(0, 38, 40, 5)
    screen.stroke()

    screen.level(5)
    screen.move(44, 43)
    screen.text(breath_phase:upper())
  end

  -- song form
  if bandmate.form_enabled then
    screen.level(10)
    screen.move(0, 52)
    screen.text("FORM: " .. bandmate.FORM_NAMES[bandmate.form_type])
    screen.level(7)
    screen.move(80, 52)
    screen.text(bandmate.form_phase:upper())
  else
    screen.level(3)
    screen.move(0, 52)
    screen.text("form: off")
  end

  -- voice activity for current style
  screen.level(5)
  screen.move(70, 43)
  local v_active = bandmate.style_voices[bandmate.style]
  for ch = 1, 4 do
    screen.level(v_active[ch] and (thunder.channels[ch].muted and 4 or 10) or 2)
    screen.rect(70 + (ch - 1) * 12, 36, 10, 7)
    screen.fill()
  end

  -- footer
  screen.level(8)
  screen.move(0, 63)
  local p = BANDMATE_PARAMS[sel_param]
  screen.text("E3:" .. (p or ""))
  screen.level(4)
  screen.move(128, 63)
  screen.text_right("K2+K3:toggle")
end

----------------------------------------------------------------
-- cleanup
----------------------------------------------------------------

function all_notes_off()
  for ch = 1, 4 do
    engine.release(ch)
    if midi_out then
      local midi_ch = params:get("midi_ch_" .. ch)
      for _, n in ipairs(active_notes[ch]) do
        midi_out:note_off(n, 0, midi_ch)
      end
      active_notes[ch] = {}
    end
  end
end

function cleanup()
  playing = false
  all_notes_off()
end
