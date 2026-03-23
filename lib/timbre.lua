-- timbre.lua
-- timbre engineering system for riga
--
-- 6 mindsets that shape each voice's internal synthesis params
-- with different creative philosophies:
--
-- SCULPTOR:     slow deliberate carving. one param at a time.
--               waits, listens, nudges. subtractive.
-- ALCHEMIST:    cross-links params into relationships.
--               if cutoff rises, noise falls. transmutation.
-- PROVOCATEUR:  pushes to extremes then snaps back.
--               tension/release. sudden jumps.
-- ARCHAEOLOGIST: explores the edges. finds hidden sounds
--               in unusual parameter territories nobody visits.
-- WEAVER:       interlocking counterpoint between voices.
--               when one brightens, another darkens.
-- PYROMANIAC:   everything burns. drives all params toward
--               maximum intensity, distortion, chaos.
--
-- each voice mode (Bassline/Perkons/Steampipe/Syntrx) has its own
-- set of shapeable params. the timbre engineer knows which params
-- matter for each mode and how to move them musically.

local Timbre = {}
Timbre.__index = Timbre

Timbre.MINDSET_NAMES = {
  "SCULPTOR", "ALCHEMIST", "PROVOCATEUR",
  "ARCHAEOLOGIST", "WEAVER", "PYROMANIAC"
}

-- mode-specific param definitions with musical ranges
-- {name, min, max, default, description}
local MODE_PARAMS = {
  -- Mode 0: BASSLINE
  [0] = {
    {name="saw",       min=0, max=1, default=0.8},
    {name="pulse",     min=0, max=1, default=0},
    {name="tri",       min=0, max=1, default=0},
    {name="sub",       min=0, max=1, default=0.6},
    {name="noise",     min=0, max=0.6, default=0},
    {name="bbdDetune", min=0, max=0.8, default=0.2},
    {name="envMod",    min=0, max=1, default=0.7},
    {name="pitchEnv",  min=0, max=8, default=2},
    {name="pulseWidth",min=0.1, max=0.9, default=0.5},
  },
  -- Mode 1: PERKONS
  [1] = {
    {name="drumMode",    min=0, max=1, default=0},
    {name="fmIndex",     min=0, max=6, default=1.5},
    {name="fmRatio",     min=0.5, max=4, default=1.0},
    {name="noiseAmt",    min=0, max=1, default=0.1},
    {name="shape",       min=0, max=1, default=0},
    {name="pitchEnvAmt", min=0, max=12, default=6},
    {name="pitchDecay",  min=0.005, max=0.2, default=0.04},
  },
  -- Mode 2: STEAMPIPE
  [2] = {
    {name="exciterNoise", min=0, max=1, default=0.6},
    {name="feedback",     min=0.8, max=0.999, default=0.96},
    {name="brightness",   min=0, max=1, default=0.5},
    {name="splitPoint",   min=0.1, max=0.9, default=0.4},
    {name="splitMix",     min=0, max=1, default=0.3},
    {name="overblow",     min=0, max=3, default=0},
    {name="stretch",      min=0, max=1, default=0},
  },
  -- Mode 3: SYNTRX
  [3] = {
    {name="osc1Shape",  min=0, max=1, default=0.3},
    {name="osc1Level",  min=0, max=1, default=0.7},
    {name="osc2Ratio",  min=0.5, max=4, default=1.5},
    {name="osc2Shape",  min=0, max=1, default=0.5},
    {name="osc2Level",  min=0, max=1, default=0.5},
    {name="ringMod",    min=0, max=1, default=0.2},
    {name="noiseLevel", min=0, max=0.6, default=0.15},
    {name="noiseColor", min=0, max=1, default=0.5},
    {name="chaosAmt",   min=0, max=1, default=0.3},
  },
}

function Timbre.new()
  local self = setmetatable({}, Timbre)

  self.active = false
  self.mindset = 1           -- 1-6
  self.intensity = 0.5       -- 0-1 how aggressive
  self.tick = 0
  self.bar = 0

  -- per-voice state for mindset algorithms
  self.focus = {1, 1, 1, 1}        -- which param index each voice is focused on
  self.direction = {1, 1, 1, 1}    -- +1 or -1
  self.tension = {0, 0, 0, 0}      -- 0-1 tension accumulator (PROVOCATEUR)
  self.target = {nil, nil, nil, nil} -- target values (PROVOCATEUR snap)

  -- WEAVER: phase offsets for counterpoint
  self.weave_phase = {0, 0.25, 0.5, 0.75}

  -- pending extra param changes (returned to host)
  self.pending = {}

  return self
end

-- get the param list for a voice's current mode
function Timbre:get_mode_params(mode)
  return MODE_PARAMS[mode] or MODE_PARAMS[0]
end

-- call every 16th note
function Timbre:step(voices)
  if not self.active then return {} end

  self.tick = self.tick + 1
  self.pending = {}

  local beat = ((self.tick - 1) % 16) + 1
  if beat == 16 then self.bar = self.bar + 1 end

  local fn = self.mindset_fns[self.mindset]
  if fn then
    fn(self, voices, beat)
  end

  return self.pending
end

-- push a change to a voice's extra param
function Timbre:push(ch, param_name, value)
  table.insert(self.pending, {
    ch = ch,
    param = param_name,
    value = value,
  })
end

-- helper: get current value of an extra param
function Timbre:get_extra(voices, ch, param_name)
  return voices[ch].extra[param_name] or 0
end

-- helper: set and push
function Timbre:nudge(voices, ch, param_name, delta, mode)
  local mp = self:get_mode_params(mode)
  for _, p in ipairs(mp) do
    if p.name == param_name then
      local current = voices[ch].extra[param_name] or p.default
      local new_val = util.clamp(current + delta * self.intensity, p.min, p.max)
      voices[ch].extra[param_name] = new_val
      self:push(ch, param_name, new_val)
      return new_val
    end
  end
end

---------- MINDSET ALGORITHMS ----------

Timbre.mindset_fns = {}

-- 1: SCULPTOR — slow, deliberate, one param at a time
Timbre.mindset_fns[1] = function(self, voices, beat)
  -- every 4 beats: nudge the focused param on one voice
  if beat % 4 ~= 1 then return end

  local ch = ((self.bar) % 4) + 1  -- rotate through voices
  local mode = voices[ch].mode
  local mp = self:get_mode_params(mode)
  if #mp == 0 then return end

  local focus_idx = self.focus[ch]
  local p = mp[focus_idx]

  -- small deliberate nudge
  local delta = self.direction[ch] * 0.06
  local new_val = self:nudge(voices, ch, p.name, delta, mode)

  if new_val then
    -- if we hit a boundary, reverse or move to next param
    if new_val <= p.min + 0.01 or new_val >= p.max - 0.01 then
      if math.random() < 0.5 then
        self.direction[ch] = -self.direction[ch]
      else
        -- move focus to next param (the "listen, then move on" moment)
        self.focus[ch] = (focus_idx % #mp) + 1
        self.direction[ch] = math.random() < 0.5 and 1 or -1
      end
    end
  end

  -- occasionally shift focus (every ~8 bars)
  if beat == 1 and self.bar % 8 == 0 and math.random() < 0.4 then
    self.focus[ch] = math.random(1, #mp)
  end
end

-- 2: ALCHEMIST — cross-linked param relationships
Timbre.mindset_fns[2] = function(self, voices, beat)
  if beat % 8 ~= 1 then return end

  for ch = 1, 4 do
    local mode = voices[ch].mode
    local mp = self:get_mode_params(mode)
    if #mp < 2 then goto continue end

    -- pick two params and create a relationship
    local a_idx = math.random(1, #mp)
    local b_idx = a_idx
    while b_idx == a_idx do b_idx = math.random(1, #mp) end

    local pa = mp[a_idx]
    local pb = mp[b_idx]
    local va = voices[ch].extra[pa.name] or pa.default
    local vb = voices[ch].extra[pb.name] or pb.default

    -- transmutation: normalize A, invert, apply to B
    local norm_a = (va - pa.min) / math.max(0.001, pa.max - pa.min)
    local inverted = 1 - norm_a
    local new_b = pb.min + inverted * (pb.max - pb.min)

    -- blend toward target (don't snap, drift)
    local blend = 0.15 * self.intensity
    new_b = vb + (new_b - vb) * blend
    new_b = util.clamp(new_b, pb.min, pb.max)

    voices[ch].extra[pb.name] = new_b
    self:push(ch, pb.name, new_b)

    ::continue::
  end
end

-- 3: PROVOCATEUR — extremes then snap back
Timbre.mindset_fns[3] = function(self, voices, beat)
  for ch = 1, 4 do
    local mode = voices[ch].mode
    local mp = self:get_mode_params(mode)
    if #mp == 0 then goto continue end

    -- build tension every beat
    if beat % 2 == 1 then
      self.tension[ch] = math.min(1, self.tension[ch] + 0.04 * self.intensity)
    end

    -- tension drives params toward extremes
    if beat % 4 == 1 and self.tension[ch] > 0.3 then
      local p_idx = math.random(1, #mp)
      local p = mp[p_idx]
      local current = voices[ch].extra[p.name] or p.default

      -- push toward whichever extreme is further away
      local dist_lo = current - p.min
      local dist_hi = p.max - current
      local target = dist_hi > dist_lo and p.max or p.min
      local delta = (target - current) * 0.12 * self.tension[ch] * self.intensity

      self:nudge(voices, ch, p.name, delta / math.max(0.01, self.intensity), mode)
    end

    -- SNAP: release tension (return toward defaults)
    if self.tension[ch] > 0.8 and math.random() < 0.15 then
      self.tension[ch] = 0
      -- snap all params back toward defaults
      for _, p in ipairs(mp) do
        local current = voices[ch].extra[p.name] or p.default
        local snap_val = current + (p.default - current) * 0.7
        snap_val = util.clamp(snap_val, p.min, p.max)
        voices[ch].extra[p.name] = snap_val
        self:push(ch, p.name, snap_val)
      end
    end

    ::continue::
  end
end

-- 4: ARCHAEOLOGIST — explores unusual territories
Timbre.mindset_fns[4] = function(self, voices, beat)
  if beat % 8 ~= 1 then return end

  -- pick one voice to excavate
  local ch = math.random(1, 4)
  local mode = voices[ch].mode
  local mp = self:get_mode_params(mode)
  if #mp == 0 then return end

  -- find the param furthest from center (least explored territory)
  local most_central_idx = 1
  local most_central_dist = 999
  for i, p in ipairs(mp) do
    local current = voices[ch].extra[p.name] or p.default
    local center = (p.min + p.max) / 2
    local norm_dist = math.abs(current - center) / math.max(0.001, p.max - p.min)
    if norm_dist < most_central_dist then
      most_central_dist = norm_dist
      most_central_idx = i
    end
  end

  -- push the most "boring" (central) param toward an edge
  local p = mp[most_central_idx]
  local current = voices[ch].extra[p.name] or p.default
  local center = (p.min + p.max) / 2

  -- pick a direction away from center
  local target
  if math.random() < 0.5 then
    -- push toward low edge (the dark/minimal territory)
    target = p.min + (p.max - p.min) * 0.1
  else
    -- push toward high edge (the extreme territory)
    target = p.min + (p.max - p.min) * 0.9
  end

  local delta = (target - current) * 0.2 * self.intensity
  self:nudge(voices, ch, p.name, delta / math.max(0.01, self.intensity), mode)
end

-- 5: WEAVER — interlocking counterpoint between voices
Timbre.mindset_fns[5] = function(self, voices, beat)
  if beat % 4 ~= 1 then return end

  -- sine wave phase per voice (offset creates counterpoint)
  local phase_speed = 0.03 * self.intensity

  for ch = 1, 4 do
    self.weave_phase[ch] = self.weave_phase[ch] + phase_speed
    local mode = voices[ch].mode
    local mp = self:get_mode_params(mode)
    if #mp == 0 then goto continue end

    -- pick two params: one follows sine, one follows cosine
    -- creates breathing, interlocking movement
    local wave = math.sin(self.weave_phase[ch] * math.pi * 2)
    local co_wave = math.cos(self.weave_phase[ch] * math.pi * 2)

    -- primary param: first timbral param (usually oscillator mix)
    local p1 = mp[1]
    local target1 = p1.min + (p1.max - p1.min) * (0.5 + wave * 0.4)
    local current1 = voices[ch].extra[p1.name] or p1.default
    local new1 = current1 + (target1 - current1) * 0.1
    voices[ch].extra[p1.name] = util.clamp(new1, p1.min, p1.max)
    self:push(ch, p1.name, voices[ch].extra[p1.name])

    -- secondary param: mid-list param (usually a shaping param)
    local p2_idx = math.floor(#mp / 2) + 1
    local p2 = mp[p2_idx]
    local target2 = p2.min + (p2.max - p2.min) * (0.5 + co_wave * 0.35)
    local current2 = voices[ch].extra[p2.name] or p2.default
    local new2 = current2 + (target2 - current2) * 0.1
    voices[ch].extra[p2.name] = util.clamp(new2, p2.min, p2.max)
    self:push(ch, p2.name, voices[ch].extra[p2.name])

    ::continue::
  end
end

-- 6: PYROMANIAC — everything burns toward maximum
Timbre.mindset_fns[6] = function(self, voices, beat)
  if beat % 2 ~= 1 then return end

  for ch = 1, 4 do
    local mode = voices[ch].mode
    local mp = self:get_mode_params(mode)
    if #mp == 0 then goto continue end

    -- pick a random param and push it toward its max
    local p_idx = math.random(1, #mp)
    local p = mp[p_idx]
    local current = voices[ch].extra[p.name] or p.default

    -- burn: push toward max (or toward "extreme" for params where max = chaos)
    local delta = (p.max - current) * 0.08 * self.intensity
    -- occasionally flicker (brief dip for rhythm)
    if math.random() < 0.15 then
      delta = -(current - p.min) * 0.3 * self.intensity
    end

    local new_val = util.clamp(current + delta, p.min, p.max)
    voices[ch].extra[p.name] = new_val
    self:push(ch, p.name, new_val)

    ::continue::
  end
end

-- get current tension values for display
function Timbre:get_tension()
  return self.tension
end

-- get focused param index per voice
function Timbre:get_focus()
  return self.focus
end

return Timbre
