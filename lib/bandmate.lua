-- bandmate.lua
-- autonomous performer for riga
--
-- 8 styles inspired by the Erica Synths universe:
-- TECHNO:     Perkons 4-on-floor, Bassline acid, building intensity
-- INDUSTRIAL: heavy drive, all voices hammering, plasma maxed
-- AMBIENT:    Steampipe resonances, Syntrx drones, Zen reverb wash
-- ACID:       Bassline focus, filter sweeps, accent ratchets
-- NOISE:      chaos maxed, pattern destruction, Plasma Drive
-- DUB:        Zen delay feedback, sparse patterns, heavy bass
-- RITUAL:     Perkons thunder, slow build, tribal polyrhythm
-- MINIMAL:    one or two voices, space, phasing evolution
--
-- breathing system: creates natural energy arcs
-- song form: A-B-A, build-drop, call-response templates
-- musical dynamics: a real bandmate, not a parameter randomizer

local Bandmate = {}
Bandmate.__index = Bandmate

Bandmate.STYLE_NAMES = {
  "TECHNO", "INDUSTRIAL", "AMBIENT", "ACID",
  "NOISE", "DUB", "RITUAL", "MINIMAL"
}

function Bandmate.new(thunder, chaos, explorer)
  local self = setmetatable({}, Bandmate)

  self.thunder = thunder
  self.chaos = chaos
  self.explorer = explorer
  self.active = false
  self.style = 1
  self.intensity = 5       -- 1-10
  self.tick = 0
  self.bar = 0
  self.phrase_len = 4

  -- breathing: long-form energy arc
  self.energy = 1.0
  self.breathing = true
  self.breath_bar = 0
  self.breath_phase = "play"  -- play, fade, silence, build

  -- song form
  self.form_enabled = false
  self.form_type = 1
  self.form_section = 1
  self.form_bar = 0
  self.form_phase = "home"
  self.home_state = nil     -- saved "home" configuration

  self.FORM_NAMES = {"A-B-A", "build-drop", "call-response", "rondo", "arc"}
  self.FORMS = {
    -- A-B-A: theme, variation, theme
    {{"home",8,16}, {"depart",4,8}, {"home",8,16}, {"depart",4,8}, {"home",8,12}},
    -- build-drop: steady build to climax then reset
    {{"home",8,12}, {"grow",4,8}, {"grow",4,6}, {"silence",1,2}, {"home",8,16}},
    -- call-response: short exchanges
    {{"home",4,6}, {"depart",2,4}, {"home",4,6}, {"depart",2,4}, {"home",4,8}},
    -- rondo: A-B-A-C-A-D-A
    {{"home",6,10}, {"depart",4,6}, {"home",4,8}, {"grow",4,6}, {"home",4,8}, {"depart",4,6}, {"home",6,10}},
    -- arc: slow build, peak, slow descent
    {{"home",8,12}, {"grow",4,8}, {"grow",4,6}, {"depart",4,8}, {"home",4,6}, {"silence",1,2}, {"home",8,12}},
  }

  -- pending param changes (returned to host)
  self.pending = {}

  -- per-style voice activity profiles
  -- {ch1_active, ch2_active, ch3_active, ch4_active}
  self.style_voices = {
    {true, true, true, true},   -- TECHNO: all voices
    {true, true, false, true},  -- INDUSTRIAL: bass+perc+syntrx (no pipe)
    {false, false, true, true}, -- AMBIENT: pipe+syntrx only
    {true, true, true, false},  -- ACID: bass+perc+pipe (no syntrx)
    {true, true, true, true},   -- NOISE: all voices (chaos)
    {true, true, true, false},  -- DUB: bass+perc+pipe
    {false, true, true, true},  -- RITUAL: perc+pipe+syntrx
    {true, false, true, false}, -- MINIMAL: bass+pipe only
  }

  return self
end

-- call every 16th note step from main clock
function Bandmate:step()
  if not self.active then return {} end

  self.tick = self.tick + 1
  self.pending = {}
  local int = self.intensity / 10
  local beat_in_bar = ((self.tick - 1) % 16) + 1

  -- style-specific behavior
  local style_fn = self.style_fns[self.style]
  if style_fn then
    style_fn(self, beat_in_bar, int)
  end

  -- end of bar
  if beat_in_bar == 16 then
    self.bar = self.bar + 1
    self.breath_bar = self.breath_bar + 1
    self:end_of_bar(int)
  end

  return self.pending
end

-- style behavior functions
Bandmate.style_fns = {}

-- 1: TECHNO — Perkons 4-on-floor, building intensity
Bandmate.style_fns[1] = function(self, beat, int)
  -- on the ONE: strong kick, accent bassline
  if beat == 1 then
    if math.random() < 0.3 * int then
      self:push_voice_param(1, "cutoff", math.random(-300, 500))
    end
  end
  -- every 4 beats: filter movement
  if beat % 4 == 1 and math.random() < 0.4 * int then
    self:push_fx_param("poli_cutoff", math.random(-600, 800))
  end
  -- hat density increases with intensity
  if beat % 2 == 0 and math.random() < int * 0.15 then
    local ch3 = self.thunder.channels[3]
    local s = math.random(1, 16)
    if not ch3.steps[s].active and math.random() < 0.3 then
      ch3.steps[s].active = true
      ch3.steps[s].probability = 0.5 + math.random() * 0.3
    end
  end
end

-- 2: INDUSTRIAL — heavy, driving, plasma maxed
Bandmate.style_fns[2] = function(self, beat, int)
  -- push drive constantly
  if beat == 1 then
    self:push_fx_param("plasma_drive", math.random() * 0.1 * int)
    self:push_fx_param("plasma_fold", math.random() * 0.08 * int)
  end
  -- aggressive ratchets
  if beat % 4 == 1 and math.random() < 0.25 * int then
    local ch = math.random(1, 4)
    local s = math.random(1, 16)
    if self.thunder.channels[ch].steps[s].active then
      self.thunder.channels[ch].steps[s].ratchet = math.random(2, 4)
    end
  end
  -- occasional noise bursts on Syntrx
  if math.random() < 0.05 * int then
    self:push_voice_param(4, "drive", math.random() * 0.15)
  end
end

-- 3: AMBIENT — Steampipe resonances, Zen reverb wash
Bandmate.style_fns[3] = function(self, beat, int)
  -- very slow filter sweeps
  if beat == 1 and self.tick % 16 == 1 then
    local sweep = math.sin(self.bar * 0.15) * 2000 * int
    self:push_fx_param("poli_cutoff", sweep * 0.1)
  end
  -- push reverb and delay
  if beat == 1 and self.bar % 2 == 0 then
    self:push_fx_param("zen_mix", (math.random() - 0.3) * 0.08 * int)
    self:push_fx_param("zen_size", (math.random() - 0.3) * 0.06 * int)
    self:push_fx_param("bbd_feedback", (math.random() - 0.3) * 0.05 * int)
  end
  -- Steampipe decay sweeps (longer = more resonant)
  if beat == 9 and math.random() < 0.3 * int then
    self:push_voice_param(3, "decay", (math.random() - 0.3) * 0.3)
  end
  -- strip patterns down
  if beat == 1 and self.bar % 4 == 0 and math.random() < 0.3 then
    for ch = 1, 4 do
      for s = 1, 16 do
        if self.thunder.channels[ch].steps[s].active and math.random() < 0.15 then
          self.thunder.channels[ch].steps[s].active = false
        end
      end
    end
  end
end

-- 4: ACID — Bassline focus, filter sweeps, ratchets
Bandmate.style_fns[4] = function(self, beat, int)
  -- bassline filter is THE lever
  if beat % 4 == 1 then
    local sweep = math.sin(self.tick * 0.08) * 800 * int
    self:push_voice_param(1, "cutoff", sweep * 0.15)
  end
  -- accent on strong beats
  if (beat == 1 or beat == 9) and math.random() < 0.4 * int then
    local s = self.thunder.channels[1].position
    if s and s > 0 and s <= 16 then
      self.thunder.channels[1].steps[s].accent = 0.6 + math.random() * 0.4
    end
  end
  -- ratchet patterns on bassline
  if beat == 1 and self.bar % 2 == 0 and math.random() < 0.3 * int then
    local s = math.random(1, 16)
    if self.thunder.channels[1].steps[s].active then
      self.thunder.channels[1].steps[s].ratchet = math.random(2, 3)
    end
  end
  -- resonance sweeps (acid squelch)
  if beat % 8 == 1 and math.random() < 0.35 * int then
    self:push_voice_param(1, "res", (math.random() - 0.5) * 0.15)
  end
end

-- 5: NOISE — chaos maxed, pattern destruction
Bandmate.style_fns[5] = function(self, beat, int)
  -- push chaos coefficients toward edge
  if beat == 1 then
    self.chaos:drift(0.15 * int)
  end
  -- random pattern mutations every few beats
  if beat % 4 == 1 and math.random() < 0.3 * int then
    local ch = math.random(1, 4)
    self.thunder:mutate(ch, 0.25 * int)
  end
  -- plasma drive push
  if math.random() < 0.08 * int then
    self:push_fx_param("plasma_fold", math.random() * 0.1)
    self:push_fx_param("plasma_drive", math.random() * 0.08)
  end
  -- random fills
  if math.random() < 0.06 * int then
    local ch = math.random(1, 4)
    self.thunder.channels[ch].fill_active = true
    table.insert(self.pending, {type = "fill_release", ch = ch, delay = math.random(2, 6)})
  end
end

-- 6: DUB — Zen delay feedback, sparse patterns, heavy bass
Bandmate.style_fns[6] = function(self, beat, int)
  -- delay feedback rides (dub washout moments)
  if beat == 1 and math.random() < 0.25 * int then
    self:push_fx_param("bbd_feedback", (math.random() - 0.3) * 0.12)
  end
  -- delay time shifts for rhythmic interest
  if beat == 9 and math.random() < 0.15 * int then
    self:push_fx_param("bbd_time", (math.random() - 0.5) * 0.08)
  end
  -- reverb swells
  if beat % 8 == 1 and math.random() < 0.2 * int then
    self:push_fx_param("zen_mix", (math.random() - 0.3) * 0.06)
  end
  -- strip patterns to essentials (dub = space)
  if beat == 1 and self.bar % 4 == 0 then
    for ch = 2, 4 do
      for s = 1, 16 do
        if self.thunder.channels[ch].steps[s].active and math.random() < 0.2 then
          self.thunder.channels[ch].steps[s].active = false
        end
      end
    end
  end
  -- bass stays heavy
  if beat == 1 and math.random() < 0.2 * int then
    self:push_voice_param(1, "cutoff", math.random(-200, 100))
  end
end

-- 7: RITUAL — Perkons thunder, slow build, tribal polyrhythm
Bandmate.style_fns[7] = function(self, beat, int)
  -- build through pattern density over time
  if beat == 1 and self.bar % 4 == 0 then
    local density = 0.1 + (self.bar % 32) / 32 * 0.4 * int
    local ch = math.random(2, 4)  -- skip bassline
    for s = 1, 16 do
      if not self.thunder.channels[ch].steps[s].active and math.random() < density * 0.15 then
        self.thunder.channels[ch].steps[s].active = true
        self.thunder.channels[ch].steps[s].probability = 0.4 + math.random() * 0.4
      end
    end
  end
  -- Perkons drive builds
  if beat == 1 and math.random() < 0.2 * int then
    self:push_voice_param(2, "drive", math.random() * 0.06)
  end
  -- occasional pattern rotation (polyrhythmic feel)
  if beat == 1 and self.bar % 8 == 0 and math.random() < 0.35 then
    local ch = math.random(2, 4)
    self.thunder:rotate(ch, math.random(-1, 1))
  end
end

-- 8: MINIMAL — one or two voices, space, phasing
Bandmate.style_fns[8] = function(self, beat, int)
  -- very slow, subtle timbral shifts
  if beat == 1 and self.bar % 2 == 0 then
    local param_choices = {"cutoff", "decay", "res"}
    local p = param_choices[math.random(#param_choices)]
    local ch = math.random() < 0.5 and 1 or 3  -- bass or pipe
    local delta = (math.random() - 0.5) * 0.1 * int
    self:push_voice_param(ch, p, delta)
  end
  -- pattern rotation for phasing effect (Steve Reich)
  if beat == 1 and self.bar % 8 == 0 and math.random() < 0.4 then
    self.thunder:rotate(math.random() < 0.5 and 1 or 3, 1)
  end
  -- keep other channels muted
  self.thunder.channels[2].muted = true
  self.thunder.channels[4].muted = true
end

---------- BREATHING ----------

function Bandmate:breathe()
  if not self.breathing or self.form_enabled then return end

  if self.breath_phase == "play" then
    if self.breath_bar > 12 and math.random() < 0.08 then
      self.breath_phase = "fade"
      self.breath_bar = 0
    end
  elseif self.breath_phase == "fade" then
    self.energy = math.max(0, self.energy - (0.15 + math.random() * 0.15))
    if self.energy <= 0.05 then
      self.breath_phase = "silence"
      self.energy = 0
      self.breath_bar = 0
    end
  elseif self.breath_phase == "silence" then
    self.energy = 0
    if self.breath_bar >= 1 and math.random() < 0.6 then
      self.breath_phase = "build"
      self.breath_bar = 0
    end
  elseif self.breath_phase == "build" then
    self.energy = math.min(1, self.energy + (0.25 + math.random() * 0.25))
    if self.energy >= 0.95 then
      self.breath_phase = "play"
      self.energy = 1
      self.breath_bar = 0
    end
  end
end

---------- SONG FORM ----------

function Bandmate:advance_form()
  if not self.form_enabled then return end

  self.form_bar = self.form_bar + 1

  if not self.home_state then
    self.home_state = self:snapshot()
  end

  local form = self.FORMS[self.form_type] or self.FORMS[1]
  local section = form[self.form_section]
  if not section then
    self.form_section = 1
    self.form_bar = 0
    section = form[1]
  end

  local phase = section[1]
  local min_bars = section[2]
  local max_bars = section[3]

  if self.form_bar >= min_bars then
    local advance_chance = (self.form_bar - min_bars) / math.max(1, max_bars - min_bars)
    if self.form_bar >= max_bars or math.random() < advance_chance * 0.4 then
      self.form_section = self.form_section + 1
      self.form_bar = 0
      local next_section = form[self.form_section]
      if next_section then
        local next_phase = next_section[1]
        if next_phase == "home" then
          self:restore_snapshot(self.home_state)
          self.energy = 1
        elseif next_phase == "depart" then
          for ch = 1, 4 do self.thunder:mutate(ch, 0.2) end
        elseif next_phase == "grow" then
          for ch = 1, 4 do self.thunder:mutate(ch, 0.1) end
        elseif next_phase == "silence" then
          self.energy = 0.1
        end
        self.form_phase = next_phase
        table.insert(self.pending, {type = "form_phase", phase = next_phase})
      end
    end
  end

  if phase == "grow" and self.form_bar % 2 == 0 then
    self.thunder:mutate(math.random(1, 4), 0.15)
  elseif phase == "silence" then
    self.energy = math.max(0.05, self.energy - 0.3)
  end
end

---------- END OF BAR ----------

function Bandmate:end_of_bar(int)
  self:breathe()
  self:advance_form()

  -- pattern evolution (not during form — form owns structure)
  if not self.form_enabled then
    if self.bar % self.phrase_len == 0 then
      if math.random() < 0.2 then
        -- heavier mutation at phrase boundaries
        for ch = 1, 4 do
          self.thunder:mutate(ch, 0.2 * int)
        end
      else
        -- light mutation
        self.thunder:mutate(math.random(1, 4), 0.15 * int)
      end
    end
  end

  -- voice muting based on style + energy
  local voice_active = self.style_voices[self.style]
  for ch = 1, 4 do
    if not voice_active[ch] then
      self.thunder.channels[ch].muted = true
    else
      -- energy affects muting: low energy = more mutes
      if self.energy < 0.3 and math.random() < 0.3 then
        self.thunder.channels[ch].muted = true
      elseif self.energy > 0.5 then
        self.thunder.channels[ch].muted = false
      end
    end
  end
end

---------- HELPERS ----------

function Bandmate:push_voice_param(ch, param, delta)
  -- energy scales movement
  delta = delta * (0.3 + 0.7 * self.energy)
  table.insert(self.pending, {
    type = "voice_delta",
    ch = ch,
    param = param,
    delta = delta,
  })
end

function Bandmate:push_fx_param(param, delta)
  delta = delta * (0.3 + 0.7 * self.energy)
  table.insert(self.pending, {
    type = "fx_delta",
    param = param,
    delta = delta,
  })
end

function Bandmate:snapshot()
  -- save current thunder patterns for form system
  local state = {patterns = {}}
  for ch = 1, 4 do
    state.patterns[ch] = {}
    local channel = self.thunder.channels[ch]
    for s = 1, channel.length do
      state.patterns[ch][s] = {
        active = channel.steps[s].active,
        probability = channel.steps[s].probability,
        ratchet = channel.steps[s].ratchet,
        accent = channel.steps[s].accent,
      }
    end
  end
  return state
end

function Bandmate:restore_snapshot(state)
  if not state then return end
  for ch = 1, 4 do
    local channel = self.thunder.channels[ch]
    for s = 1, channel.length do
      if state.patterns[ch] and state.patterns[ch][s] then
        channel.steps[s].active = state.patterns[ch][s].active
        channel.steps[s].probability = state.patterns[ch][s].probability
        channel.steps[s].ratchet = state.patterns[ch][s].ratchet
        channel.steps[s].accent = state.patterns[ch][s].accent
      end
    end
  end
end

-- get energy-scaled intensity for display
function Bandmate:get_energy()
  return self.energy
end

function Bandmate:get_breath_phase()
  return self.breath_phase
end

return Bandmate
