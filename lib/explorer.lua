-- explorer.lua
-- autonomous evolution engine for riga
--
-- 4 phases of intensity, named after weather in Latvia:
--   CALM     — minimal changes, subtle drift
--   STORM    — building energy, more mutations
--   RAGE     — maximum chaos, pattern destruction
--   DISSOLVE — breaking down, returning to simplicity
--
-- manages thunder (rhythm), chaos (modulation), voice params, and FX
-- creates a living, breathing performance that evolves on its own

local Explorer = {}
Explorer.__index = Explorer

-- phase constants
local CALM = 1
local STORM = 2
local RAGE = 3
local DISSOLVE = 4

local PHASE_NAMES = {"CALM", "STORM", "RAGE", "DISSOLVE"}

function Explorer.new(thunder, chaos)
  local self = setmetatable({}, Explorer)

  self.thunder = thunder
  self.chaos = chaos
  self.active = false
  self.intensity = 0.5     -- 0=subtle, 1=maximum

  -- phase system
  self.phase = CALM
  self.phase_timer = 0
  self.phase_length = 128  -- steps per phase
  self.step_count = 0

  -- mutation intervals (in steps)
  self.rhythm_interval = 32
  self.voice_interval = 48
  self.fx_interval = 64
  self.chaos_interval = 24

  -- phase-specific multipliers
  self.phase_config = {
    [CALM] = {
      rhythm_prob = 0.15,   -- low chance of rhythm change
      voice_prob = 0.1,
      fx_prob = 0.05,
      chaos_intensity = 0.2,
      fill_prob = 0.0,
      mute_prob = 0.0,
    },
    [STORM] = {
      rhythm_prob = 0.35,
      voice_prob = 0.25,
      fx_prob = 0.15,
      chaos_intensity = 0.5,
      fill_prob = 0.1,
      mute_prob = 0.05,
    },
    [RAGE] = {
      rhythm_prob = 0.6,
      voice_prob = 0.4,
      fx_prob = 0.3,
      chaos_intensity = 0.9,
      fill_prob = 0.25,
      mute_prob = 0.1,
    },
    [DISSOLVE] = {
      rhythm_prob = 0.3,
      voice_prob = 0.2,
      fx_prob = 0.2,
      chaos_intensity = 0.4,
      fill_prob = 0.05,
      mute_prob = 0.2,  -- things start dropping out
    },
  }

  -- pending parameter changes (returned to main script)
  self.pending_changes = {}

  return self
end

-- call every sequencer step
function Explorer:step()
  if not self.active then return {} end

  self.step_count = self.step_count + 1
  self.phase_timer = self.phase_timer + 1
  self.pending_changes = {}

  local cfg = self.phase_config[self.phase]

  -- phase transition
  if self.phase_timer >= self.phase_length then
    self.phase_timer = 0
    self.phase = (self.phase % 4) + 1
    self:on_phase_change()
  end

  -- rhythm mutations
  if self.step_count % self.rhythm_interval == 0 then
    self:mutate_rhythm(cfg)
  end

  -- voice mutations
  if self.step_count % self.voice_interval == 0 then
    self:mutate_voice(cfg)
  end

  -- fx mutations
  if self.step_count % self.fx_interval == 0 then
    self:mutate_fx(cfg)
  end

  -- chaos coefficient drift
  if self.step_count % self.chaos_interval == 0 then
    self:mutate_chaos(cfg)
  end

  -- fill triggers (momentary)
  if math.random() < cfg.fill_prob * self.intensity then
    local ch = math.random(1, 4)
    self.thunder.channels[ch].fill_active = true
    -- auto-release fill after 4-8 steps
    table.insert(self.pending_changes, {
      type = "fill_release",
      ch = ch,
      delay = math.random(4, 8),
    })
  end

  -- mute toggling (DISSOLVE specialty)
  if math.random() < cfg.mute_prob * self.intensity then
    local ch = math.random(1, 4)
    if self.phase == DISSOLVE then
      -- mute channels during dissolve
      self.thunder.channels[ch].muted = true
    else
      -- unmute during other phases
      self.thunder.channels[ch].muted = false
    end
  end

  -- update chaos intensity based on phase
  self.chaos.intensity = cfg.chaos_intensity * self.intensity

  return self.pending_changes
end

-- phase transition effects
function Explorer:on_phase_change()
  local phase = self.phase

  if phase == CALM then
    -- entering calm: unmute everything, reset fills
    for ch = 1, 4 do
      self.thunder.channels[ch].muted = false
      self.thunder.channels[ch].fill_active = false
    end
    -- gentle chaos
    self.chaos.smooth_factor = 0.7  -- very smooth
    table.insert(self.pending_changes, {type = "phase", phase = "CALM"})

  elseif phase == STORM then
    -- building: start adding ratchets and probability variation
    for ch = 1, 4 do
      self.thunder:mutate(ch, 0.15)
    end
    self.chaos.smooth_factor = 0.4
    table.insert(self.pending_changes, {type = "phase", phase = "STORM"})

  elseif phase == RAGE then
    -- maximum intensity: heavy mutations, all channels active
    for ch = 1, 4 do
      self.thunder.channels[ch].muted = false
      self.thunder:mutate(ch, 0.3)
    end
    self.chaos.smooth_factor = 0.1  -- stepped, aggressive
    -- push chaos coefficients toward edge of chaos
    self.chaos.coeff_x = util.clamp(self.chaos.coeff_x + 0.2, 3.5, 4.0)
    table.insert(self.pending_changes, {type = "phase", phase = "RAGE"})

  elseif phase == DISSOLVE then
    -- breaking down: patterns simplify, channels drop out
    self.chaos.smooth_factor = 0.6
    -- pull chaos back from the edge
    self.chaos.coeff_x = util.clamp(self.chaos.coeff_x - 0.3, 2.8, 3.8)
    table.insert(self.pending_changes, {type = "phase", phase = "DISSOLVE"})
  end
end

-- rhythm mutations based on phase config
function Explorer:mutate_rhythm(cfg)
  if math.random() > cfg.rhythm_prob * self.intensity then return end

  local ch = math.random(1, 4)
  local roll = math.random()

  if roll < 0.3 then
    -- flip a step
    local step = math.random(1, self.thunder.channels[ch].length)
    self.thunder:toggle_step(ch, step)
  elseif roll < 0.5 then
    -- adjust probability on a random active step
    for s = 1, 16 do
      if self.thunder.channels[ch].steps[s].active then
        local new_prob = util.clamp(
          self.thunder.channels[ch].steps[s].probability + (math.random() - 0.5) * 0.3,
          0.1, 1.0
        )
        self.thunder:set_probability(ch, s, new_prob)
        break
      end
    end
  elseif roll < 0.65 then
    -- add/remove ratchet
    local step = math.random(1, 16)
    if self.thunder.channels[ch].steps[step].active then
      local ratch = self.phase == RAGE and math.random(2, 4) or math.random(1, 2)
      self.thunder:set_ratchet(ch, step, ratch)
    end
  elseif roll < 0.8 then
    -- rotate pattern
    self.thunder:rotate(ch, math.random(-2, 2))
  else
    -- gentle randomize
    self.thunder:mutate(ch, cfg.rhythm_prob * self.intensity * 0.5)
  end
end

-- voice parameter mutations
function Explorer:mutate_voice(cfg)
  if math.random() > cfg.voice_prob * self.intensity then return end

  local ch = math.random(1, 4)
  local targets = {
    {param = "cutoff", delta = math.random(-500, 500), type = "voice"},
    {param = "drive", delta = (math.random() - 0.5) * 0.3, type = "voice"},
    {param = "res", delta = (math.random() - 0.5) * 0.2, type = "voice"},
    {param = "decay", delta = (math.random() - 0.5) * 0.3, type = "voice"},
    {param = "fxSend", delta = (math.random() - 0.5) * 0.2, type = "voice"},
  }

  local target = targets[math.random(1, #targets)]
  table.insert(self.pending_changes, {
    type = "voice_delta",
    ch = ch,
    param = target.param,
    delta = target.delta * self.intensity,
  })
end

-- FX parameter mutations
function Explorer:mutate_fx(cfg)
  if math.random() > cfg.fx_prob * self.intensity then return end

  local fx_targets = {
    {param = "bbd_feedback", delta = (math.random() - 0.5) * 0.15},
    {param = "bbd_color", delta = (math.random() - 0.5) * 0.2},
    {param = "bbd_time", delta = (math.random() - 0.5) * 0.1},
    {param = "poli_cutoff", delta = math.random(-800, 800)},
    {param = "poli_res", delta = (math.random() - 0.5) * 0.15},
    {param = "plasma_drive", delta = (math.random() - 0.5) * 0.1},
    {param = "plasma_fold", delta = (math.random() - 0.5) * 0.1},
    {param = "zen_size", delta = (math.random() - 0.5) * 0.15},
    {param = "zen_mix", delta = (math.random() - 0.5) * 0.1},
  }

  local target = fx_targets[math.random(1, #fx_targets)]
  table.insert(self.pending_changes, {
    type = "fx_delta",
    param = target.param,
    delta = target.delta * self.intensity,
  })
end

-- chaos system mutations
function Explorer:mutate_chaos(cfg)
  self.chaos:drift(cfg.chaos_intensity * self.intensity * 0.15)
end

-- get current phase name
function Explorer:get_phase_name()
  return PHASE_NAMES[self.phase]
end

-- get phase progress (0-1)
function Explorer:get_phase_progress()
  return self.phase_timer / self.phase_length
end

-- force phase change
function Explorer:set_phase(p)
  self.phase = util.clamp(p, 1, 4)
  self.phase_timer = 0
  self:on_phase_change()
end

return Explorer
