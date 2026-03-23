-- chaos.lua
-- polynomial random CV generator for riga
--
-- inspired by Erica Synths Black Code Source:
-- polynomial calculations generate pseudo-random sequences
-- that can loop, evolve, and modulate any parameter
--
-- at high rates = chaotic noise-like modulation
-- at low rates = slowly evolving pseudo-random CV sequences
-- sequences can be "rewound" to repeat — deterministic chaos
--
-- also draws from:
-- - Black Modulator V2 (sample & hold, noise types)
-- - Syntrx II joystick (2D chaos field)
-- - Wogglebug (smooth random, stepped random, woggle)

local Chaos = {}
Chaos.__index = Chaos

function Chaos.new()
  local self = setmetatable({}, Chaos)

  -- polynomial state (4 independent channels like Black Code Source)
  self.x = {0.1, 0.5, 0.3, 0.7}
  self.y = {0.4, 0.2, 0.8, 0.6}
  self.rate = 0.5          -- 0=frozen, 1=fast
  self.intensity = 0.5     -- overall mod depth
  self.active = false

  -- polynomial coefficients (the "X" and "Y" knobs)
  self.coeff_x = 3.7       -- logistic map parameter (chaos at ~3.57+)
  self.coeff_y = 2.8       -- secondary polynomial

  -- output smoothing (smooth vs stepped)
  self.smooth = {0, 0, 0, 0}
  self.smooth_factor = 0.3  -- 0=stepped (S&H), 1=smooth (slew)

  -- seed for deterministic replay
  self.seed = 42
  self.step_count = 0
  self.loop_length = 0     -- 0=free, >0=loop after N steps
  self.loop_buffer = {}    -- stored outputs for looping

  -- modulation routing: {target_param = {ch=N, depth=0-1, offset=0}}
  self.routes = {}

  -- output values (normalized 0-1)
  self.outputs = {0, 0, 0, 0}

  return self
end

-- reset to seed (rewind — deterministic replay)
function Chaos:rewind()
  math.randomseed(self.seed)
  self.x = {0.1, 0.5, 0.3, 0.7}
  self.y = {0.4, 0.2, 0.8, 0.6}
  self.step_count = 0
  self.smooth = {0, 0, 0, 0}
end

-- advance the polynomial chaos one step
function Chaos:step()
  if not self.active then return end

  self.step_count = self.step_count + 1

  -- check loop point
  if self.loop_length > 0 and self.step_count > self.loop_length then
    -- replay from buffer
    local idx = ((self.step_count - 1) % self.loop_length) + 1
    if self.loop_buffer[idx] then
      self.outputs = self.loop_buffer[idx]
      return self.outputs
    end
  end

  for ch = 1, 4 do
    -- logistic map: x(n+1) = r * x(n) * (1 - x(n))
    -- this is THE classic chaos equation — simple but produces incredible complexity
    local x = self.x[ch]
    local y = self.y[ch]

    -- primary polynomial (logistic map)
    x = self.coeff_x * x * (1 - x)

    -- secondary polynomial (Hénon-like coupling)
    y = 1 - (self.coeff_y * x * x) + (0.3 * y)
    y = math.max(-1, math.min(1, y))

    -- combine for output
    local raw = (x + y * 0.5) / 1.5

    -- clamp to 0-1
    raw = math.max(0, math.min(1, raw))

    -- smoothing (slew limiter)
    self.smooth[ch] = self.smooth[ch] + (raw - self.smooth[ch]) * (1 - self.smooth_factor)

    -- store
    self.x[ch] = math.max(0.001, math.min(0.999, x))
    self.y[ch] = math.max(-0.999, math.min(0.999, y))
    self.outputs[ch] = self.smooth[ch]
  end

  -- store in loop buffer
  if self.loop_length > 0 and self.step_count <= self.loop_length then
    self.loop_buffer[self.step_count] = {
      self.outputs[1], self.outputs[2], self.outputs[3], self.outputs[4]
    }
  end

  return self.outputs
end

-- get current output for a channel (0-1)
function Chaos:get(ch)
  return self.outputs[ch] or 0
end

-- get bipolar output (-1 to 1)
function Chaos:get_bipolar(ch)
  return (self.outputs[ch] or 0.5) * 2 - 1
end

-- add modulation route
function Chaos:route(target_param, chaos_ch, depth, offset)
  self.routes[target_param] = {
    ch = chaos_ch,
    depth = depth or 0.5,
    offset = offset or 0,
  }
end

-- remove modulation route
function Chaos:unroute(target_param)
  self.routes[target_param] = nil
end

-- get modulated value for a parameter (base_value + chaos modulation)
function Chaos:modulate(target_param, base_value, min_val, max_val)
  local route = self.routes[target_param]
  if not route or not self.active then
    return base_value
  end

  local mod = self:get_bipolar(route.ch) * route.depth * self.intensity
  local result = base_value + (mod * (max_val - min_val)) + route.offset

  return util.clamp(result, min_val, max_val)
end

-- set polynomial coefficients (the "DNA" of the chaos)
function Chaos:set_coefficients(cx, cy)
  self.coeff_x = util.clamp(cx, 1.0, 4.0)
  self.coeff_y = util.clamp(cy, 0.5, 3.5)
end

-- get all 4 outputs as a table (for visualization)
function Chaos:get_all()
  return {self.outputs[1], self.outputs[2], self.outputs[3], self.outputs[4]}
end

-- mutate coefficients slightly (for explorer integration)
function Chaos:drift(amount)
  amount = amount or 0.1
  self.coeff_x = util.clamp(self.coeff_x + (math.random() - 0.5) * amount, 2.5, 4.0)
  self.coeff_y = util.clamp(self.coeff_y + (math.random() - 0.5) * amount, 1.0, 3.5)
end

return Chaos
