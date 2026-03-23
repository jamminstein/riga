-- thunder.lua
-- autonomous rhythm engine for riga
--
-- inspired by Erica Synths Perkons HD-01:
-- per-step probability, ratchets, parameter locks
-- 4 shuffle algorithms, fill patterns, clock multiplication/division
--
-- also draws from Black Sequencer:
-- per-step glide, accent, pattern randomization

local Thunder = {}
Thunder.__index = Thunder

local NUM_CHANNELS = 4
local MAX_STEPS = 16

-- shuffle algorithms (Perkons-inspired)
local SHUFFLE_NONE = 1
local SHUFFLE_SWING = 2      -- classic swing (delay even beats)
local SHUFFLE_PUSH = 3       -- push odd beats early
local SHUFFLE_DRUNK = 4      -- random timing variation

function Thunder.new()
  local self = setmetatable({}, Thunder)

  self.channels = {}
  for ch = 1, NUM_CHANNELS do
    self.channels[ch] = {
      steps = {},
      length = 16,
      division = 1,    -- clock division: 1=normal, 2=half, 0.5=double
      position = 0,
      muted = false,
      fill_active = false,
      fill_density = 0.5,
    }
    for s = 1, MAX_STEPS do
      self.channels[ch].steps[s] = {
        active = false,
        probability = 1.0,  -- 0.0 to 1.0
        ratchet = 1,         -- 1-4 hits per step
        accent = 0.0,        -- 0.0 to 1.0
        glide = false,
        -- parameter locks (Perkons-style per-step automation)
        locks = {},          -- {param_name = value}
      }
    end
  end

  -- global
  self.shuffle = SHUFFLE_NONE
  self.shuffle_amount = 0.3   -- 0-1
  self.step_count = 0

  -- fill system
  self.fill_mode = false
  self.fill_patterns = {
    "euclid",    -- euclidean fill
    "random",    -- random density fill
    "double",    -- double-time fill
    "cascade",   -- cascade across channels
  }
  self.fill_type = 1

  return self
end

-- generate initial patterns per channel
function Thunder:init_patterns()
  -- ch1: kick pattern (4-on-floor base)
  local ch1 = self.channels[1]
  for _, s in ipairs({1, 5, 9, 13}) do
    ch1.steps[s].active = true
    ch1.steps[s].accent = 0.8
  end

  -- ch2: snare/clap pattern
  local ch2 = self.channels[2]
  for _, s in ipairs({5, 13}) do
    ch2.steps[s].active = true
    ch2.steps[s].accent = 0.7
  end
  ch2.steps[11].active = true
  ch2.steps[11].probability = 0.4
  ch2.steps[11].accent = 0.3

  -- ch3: hat pattern (offbeats with probability)
  local ch3 = self.channels[3]
  for s = 1, 16 do
    ch3.steps[s].active = (s % 2 == 0)
    if ch3.steps[s].active then
      ch3.steps[s].probability = s % 4 == 0 and 1.0 or 0.7
      ch3.steps[s].accent = math.random() * 0.4
    end
  end

  -- ch4: accent/texture hits
  local ch4 = self.channels[4]
  ch4.steps[1].active = true
  ch4.steps[7].active = true
  ch4.steps[7].probability = 0.6
  ch4.steps[10].active = true
  ch4.steps[10].ratchet = 2
  ch4.steps[14].active = true
  ch4.steps[14].probability = 0.5
end

-- advance one step, returns table of {ch, triggered, accent, ratchet, locks}
function Thunder:advance()
  self.step_count = self.step_count + 1
  local results = {}

  for ch = 1, NUM_CHANNELS do
    local channel = self.channels[ch]
    if not channel.muted then
      -- advance position (respecting clock division)
      local should_advance = true
      if channel.division > 1 then
        should_advance = (self.step_count % channel.division == 0)
      end

      if should_advance then
        channel.position = (channel.position % channel.length) + 1
        local step = channel.steps[channel.position]
        local is_active = step.active

        -- fill override
        if channel.fill_active or self.fill_mode then
          is_active = self:get_fill_step(ch, channel.position)
        end

        if is_active then
          -- probability gate
          local prob = step.probability
          if math.random() <= prob then
            table.insert(results, {
              ch = ch,
              triggered = true,
              accent = step.accent,
              ratchet = step.ratchet,
              glide = step.glide,
              locks = step.locks,
            })
          end
        end
      end
    end
  end

  return results
end

-- get shuffle timing offset for current step (in fraction of step duration)
function Thunder:get_shuffle_offset(step_num)
  if self.shuffle == SHUFFLE_NONE then
    return 0
  elseif self.shuffle == SHUFFLE_SWING then
    -- classic swing: delay even-numbered steps
    if step_num % 2 == 0 then
      return self.shuffle_amount * 0.5
    end
    return 0
  elseif self.shuffle == SHUFFLE_PUSH then
    -- push: odd steps slightly early
    if step_num % 2 == 1 and step_num > 1 then
      return -self.shuffle_amount * 0.3
    end
    return 0
  elseif self.shuffle == SHUFFLE_DRUNK then
    -- drunk: random per-step variation
    return (math.random() - 0.5) * self.shuffle_amount * 0.4
  end
  return 0
end

-- generate fill step based on fill type
function Thunder:get_fill_step(ch, pos)
  local ft = self.fill_type
  if ft == 1 then
    -- euclidean fill
    local density = self.channels[ch].fill_density
    local hits = math.floor(density * 16)
    return self:euclidean(16, hits, ch - 1)[pos]
  elseif ft == 2 then
    -- random density
    return math.random() < self.channels[ch].fill_density
  elseif ft == 3 then
    -- double time (repeat pattern at 2x)
    local orig_pos = ((pos - 1) % 8) + 1
    -- use original step but at double density
    local step = self.channels[ch].steps[orig_pos]
    return step.active
  elseif ft == 4 then
    -- cascade: fill activates channels sequentially
    local phase = math.floor((pos - 1) / 4) + 1
    return phase >= ch
  end
  return false
end

-- bjorklund euclidean algorithm
function Thunder:euclidean(steps, pulses, offset)
  offset = offset or 0
  local pattern = {}
  if pulses >= steps then
    for i = 1, steps do pattern[i] = true end
    return pattern
  end
  if pulses <= 0 then
    for i = 1, steps do pattern[i] = false end
    return pattern
  end

  local bucket = 0
  for i = 1, steps do
    bucket = bucket + pulses
    if bucket >= steps then
      bucket = bucket - steps
      pattern[((i - 1 + offset) % steps) + 1] = true
    else
      pattern[((i - 1 + offset) % steps) + 1] = false
    end
  end
  return pattern
end

-- toggle step
function Thunder:toggle_step(ch, step)
  local s = self.channels[ch].steps[step]
  s.active = not s.active
  return s.active
end

-- set step probability
function Thunder:set_probability(ch, step, prob)
  self.channels[ch].steps[step].probability = util.clamp(prob, 0, 1)
end

-- set step ratchet count
function Thunder:set_ratchet(ch, step, count)
  self.channels[ch].steps[step].ratchet = util.clamp(count, 1, 4)
end

-- set parameter lock on a step
function Thunder:set_lock(ch, step, param, value)
  self.channels[ch].steps[step].locks[param] = value
end

-- clear parameter lock
function Thunder:clear_lock(ch, step, param)
  self.channels[ch].steps[step].locks[param] = nil
end

-- randomize channel pattern
function Thunder:randomize(ch, density)
  density = density or 0.4
  local channel = self.channels[ch]
  for s = 1, channel.length do
    local step = channel.steps[s]
    step.active = math.random() < density
    if step.active then
      step.probability = 0.5 + math.random() * 0.5
      step.accent = math.random() * 0.6
      step.ratchet = math.random() < 0.15 and math.random(2, 3) or 1
    end
  end
end

-- mutate a channel (subtle variation)
function Thunder:mutate(ch, amount)
  amount = amount or 0.3
  local channel = self.channels[ch]
  for s = 1, channel.length do
    local step = channel.steps[s]
    if math.random() < amount * 0.3 then
      step.active = not step.active
    end
    if step.active and math.random() < amount * 0.2 then
      step.probability = util.clamp(step.probability + (math.random() - 0.5) * 0.3, 0.1, 1.0)
    end
    if step.active and math.random() < amount * 0.1 then
      step.ratchet = math.random() < 0.2 and math.random(2, 4) or 1
    end
  end
end

-- shift pattern by N steps
function Thunder:rotate(ch, offset)
  local channel = self.channels[ch]
  local new_steps = {}
  for s = 1, channel.length do
    local src = ((s - 1 - offset) % channel.length) + 1
    new_steps[s] = {}
    for k, v in pairs(channel.steps[src]) do
      new_steps[s][k] = v
    end
    -- deep copy locks
    new_steps[s].locks = {}
    for k, v in pairs(channel.steps[src].locks) do
      new_steps[s].locks[k] = v
    end
  end
  channel.steps = new_steps
end

-- get pattern as flat boolean table (for grid display)
function Thunder:get_pattern(ch)
  local pat = {}
  for s = 1, self.channels[ch].length do
    pat[s] = self.channels[ch].steps[s].active
  end
  return pat
end

-- get current step position for channel
function Thunder:get_position(ch)
  return self.channels[ch].position
end

return Thunder
