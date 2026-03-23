-- mixer.lua
-- autonomous multi-track volume operator for riga
--
-- inspired by dub engineers (King Tubby, Lee Scratch Perry):
-- rides the faders, drops voices in and out, creates space,
-- builds tension by soloing one voice then bringing everything back
--
-- 5 strategies:
-- DUB:      drops voices in/out dramatically, heavy on bass
-- BUILDER:  starts sparse, adds voices one by one over time
-- CALL:     alternates between voice pairs (1+2 then 3+4)
-- SPOTLIGHT: solos one voice at a time, rotates
-- BREATHE:  all voices swell together like lungs
--
-- operates on amp levels (0-1) per voice, never fully kills —
-- "quiet" means 0.1-0.2, not zero. always musical.

local Mixer = {}
Mixer.__index = Mixer

Mixer.STRATEGY_NAMES = {"DUB", "BUILDER", "CALL", "SPOTLIGHT", "BREATHE"}

function Mixer.new()
  local self = setmetatable({}, Mixer)

  self.active = false
  self.strategy = 1
  self.intensity = 0.5   -- 0=subtle, 1=dramatic
  self.tick = 0
  self.bar = 0

  -- per-voice level targets (0-1, blended toward over time)
  self.targets = {1, 1, 1, 1}
  -- current smooth levels
  self.levels = {1, 1, 1, 1}
  -- slew rate (how fast levels move toward targets)
  self.slew = 0.08

  -- strategy state
  self.spotlight_ch = 1
  self.builder_count = 1
  self.call_phase = 1      -- 1 = voices 1+2, 2 = voices 3+4
  self.breathe_phase = 0

  return self
end

-- call every 16th note, returns {ch, level} pairs
function Mixer:step()
  if not self.active then return {} end

  self.tick = self.tick + 1
  local beat = ((self.tick - 1) % 16) + 1
  if beat == 16 then self.bar = self.bar + 1 end

  -- run strategy to set targets
  local fn = self.strategy_fns[self.strategy]
  if fn then fn(self, beat) end

  -- slew levels toward targets
  local changes = {}
  for ch = 1, 4 do
    local diff = self.targets[ch] - self.levels[ch]
    if math.abs(diff) > 0.01 then
      self.levels[ch] = self.levels[ch] + diff * self.slew
      table.insert(changes, {ch = ch, level = self.levels[ch]})
    end
  end

  return changes
end

-- get current level for display
function Mixer:get_levels()
  return self.levels
end

function Mixer:get_targets()
  return self.targets
end

Mixer.strategy_fns = {}

-- 1: DUB — King Tubby style drops and returns
Mixer.strategy_fns[1] = function(self, beat)
  if beat ~= 1 then return end

  -- every 2-4 bars: randomly drop or restore a voice
  if self.bar % (2 + math.random(2)) == 0 then
    local ch = math.random(1, 4)
    if self.levels[ch] > 0.5 then
      -- drop it (but bass stays louder)
      local floor = ch == 1 and 0.35 or (0.08 + math.random() * 0.12)
      self.targets[ch] = floor
      self.slew = 0.15 * self.intensity  -- fast drop
    else
      -- bring it back
      self.targets[ch] = 0.6 + math.random() * 0.4
      self.slew = 0.06  -- slower return
    end
  end

  -- every 8 bars: bring everything back (the drop resolves)
  if self.bar % 8 == 0 then
    for ch = 1, 4 do
      self.targets[ch] = 0.7 + math.random() * 0.3
    end
    self.slew = 0.04
  end
end

-- 2: BUILDER — starts sparse, adds voices over time
Mixer.strategy_fns[2] = function(self, beat)
  if beat ~= 1 then return end

  -- every 4 bars: add one more voice
  if self.bar % 4 == 0 then
    self.builder_count = math.min(4, self.builder_count + 1)

    -- set levels: first N voices up, rest down
    local order = {1, 2, 3, 4}
    -- shuffle order for variety
    if self.bar % 16 == 0 then
      for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
      end
    end

    for i = 1, 4 do
      if i <= self.builder_count then
        self.targets[order[i]] = 0.5 + (i / self.builder_count) * 0.5
      else
        self.targets[order[i]] = 0.05 + math.random() * 0.1
      end
    end
    self.slew = 0.05
  end

  -- after all 4 are in, reset cycle
  if self.builder_count >= 4 and self.bar % 16 == 0 then
    self.builder_count = 1
    -- dramatic drop to one voice
    for ch = 1, 4 do
      self.targets[ch] = 0.05
    end
    self.targets[math.random(1, 4)] = 0.8
    self.slew = 0.12 * self.intensity
  end
end

-- 3: CALL — alternates between voice pairs
Mixer.strategy_fns[3] = function(self, beat)
  if beat ~= 1 then return end

  -- swap pairs every 2-4 bars
  if self.bar % (2 + math.random(2)) == 0 then
    self.call_phase = self.call_phase == 1 and 2 or 1

    if self.call_phase == 1 then
      -- voices 1+2 up, 3+4 down
      self.targets[1] = 0.7 + math.random() * 0.3
      self.targets[2] = 0.6 + math.random() * 0.3
      self.targets[3] = 0.05 + math.random() * 0.15
      self.targets[4] = 0.05 + math.random() * 0.15
    else
      -- voices 3+4 up, 1+2 down
      self.targets[1] = 0.1 + math.random() * 0.15
      self.targets[2] = 0.05 + math.random() * 0.15
      self.targets[3] = 0.7 + math.random() * 0.3
      self.targets[4] = 0.6 + math.random() * 0.3
    end
    self.slew = 0.08 * self.intensity
  end

  -- every 8 bars: all together moment
  if self.bar % 8 == 0 and math.random() < 0.4 then
    for ch = 1, 4 do
      self.targets[ch] = 0.65 + math.random() * 0.3
    end
    self.slew = 0.06
  end
end

-- 4: SPOTLIGHT — solos one voice, rotates
Mixer.strategy_fns[4] = function(self, beat)
  if beat ~= 1 then return end

  -- every 4 bars: rotate spotlight
  if self.bar % 4 == 0 then
    self.spotlight_ch = (self.spotlight_ch % 4) + 1

    for ch = 1, 4 do
      if ch == self.spotlight_ch then
        self.targets[ch] = 0.85 + math.random() * 0.15
      else
        -- background: quiet but present
        self.targets[ch] = 0.1 + math.random() * 0.15 * (1 - self.intensity)
      end
    end
    self.slew = 0.1 * self.intensity
  end

  -- every 16 bars: all voices moment
  if self.bar % 16 == 0 then
    for ch = 1, 4 do
      self.targets[ch] = 0.7 + math.random() * 0.3
    end
    self.slew = 0.03
  end
end

-- 5: BREATHE — all voices swell together
Mixer.strategy_fns[5] = function(self, beat)
  self.breathe_phase = self.breathe_phase + 0.008 * self.intensity

  local breath = (math.sin(self.breathe_phase) + 1) / 2  -- 0-1
  local base = 0.15 + breath * 0.8

  for ch = 1, 4 do
    -- slight per-voice offset for organic feel
    local offset = math.sin(self.breathe_phase + ch * 0.7) * 0.15
    self.targets[ch] = util.clamp(base + offset, 0.05, 1.0)
  end
  self.slew = 0.04
end

return Mixer
