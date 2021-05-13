-- Modules
local awful = require('awful')
---- Ratio that screen is split
local ratio = 0.733 -- 0.6465
-- Default resize amount
local resize_default_amount = 10
-- Table that holds all active fake screen variables
local screens = {}
-- Modkeys
local modkey = 'Mod4' -- Win/Super
local altkey = 'Mod1' -- Alt

local function screen_has_fake(s)
  s = s or awful.screen.focused()
  return s.has_fake or s.is_fake
end

local function create_fake(s)
  -- If screen was not passed
  s = s or awful.screen.focused()
  -- If already is or has fake
  if screen_has_fake(s) then return end
  -- Create variables
  local geo = s.geometry
  local real_w = math.floor(geo.width * ratio)
  local fake_w = geo.width - real_w
  -- Index for cleaner code
  local index = tostring(s.index)
  -- Set initial sizes into memory
  screens[index] = {}
  screens[index].geo = geo
  screens[index].real_w = real_w
  screens[index].fake_w = fake_w
  -- Create if doesn't exist
  -- Resize screen
  s:fake_resize(geo.x, geo.y, real_w, geo.height)
  -- Create fake for screen
  s.fake = _G.screen.fake_add(
    geo.x + real_w,
    geo.y,
    fake_w,
    geo.height
  )
  s.fake.parent = s
  -- Mark screens
  s.fake.is_fake = true
  s.has_fake = true
  -- Change status
  s.fake.is_open = true
  -- Because memory leak
  collectgarbage('collect')
  -- Emit signal
  s:emit_signal('fake_created')
end

local function remove_fake(s)
  -- Return if no screen presented
  s = s or awful.screen.focused()
  -- Ge real screen if fake was focused
  if s.is_fake then s = s.parent end
  -- If screen doesn't have fake
  if not s.has_fake then return end
  -- Index for cleaner code
  local index = tostring(s.index)
  s:fake_resize(
    screens[index].geo.x,
    screens[index].geo.y,
    screens[index].geo.width,
    screens[index].geo.height
  )
  -- Remove and handle variables
  s.fake:fake_remove()
  s.has_fake = false
  s.fake = nil
  screens[index] = {}
  -- Because memory leaks
  collectgarbage('collect')
  -- Emit signal
  s:emit_signal('fake_created')
end

-- Toggle fake screen
local function toggle_fake(s)
  -- No screen given as parameter
  s = s or awful.screen.focused()
  -- If screen doesn't have fake or isn't fake
  if not s.has_fake and not s.is_fake then return end
  -- Ge real screen if fake was focused
  if s.is_fake then s = s.parent end
  -- Index for cleaner code
  local index = tostring(s.index)
  -- If fake was open
  if s.fake.is_open then
    -- Resize real screen to be initial size
    s:fake_resize(
      screens[index].geo.x,
      screens[index].geo.y,
      screens[index].geo.width,
      screens[index].geo.height
    )
    -- Resize fake to 1px 'out of the view'
    -- 0px will move clients out of the screen.
    -- On multi monitor setups it will show up
    -- on screen on right side of the screen we're handling
    s.fake:fake_resize(
      screens[index].geo.width,
      screens[index].geo.y,
      1,
      screens[index].geo.height
    )
    -- Mark fake as hidden
    s.fake.is_open = false
  else -- Fake was selected
    -- Resize screens
    s:fake_resize(
      screens[index].geo.x,
      screens[index].geo.y,
      screens[index].real_w,
      screens[index].geo.height
    )
    s.fake:fake_resize(
      screens[index].geo.x + screens[index].real_w,
      screens[index].geo.y,
      screens[index].fake_w,
      screens[index].geo.height
    )
    -- Mark fake as open
    s.fake.is_open = true
  end
  -- Because memory leaks
  collectgarbage('collect')
  -- Emit signal
  s:emit_signal('fake_toggle')
end

-- Resize fake with given amount in pixels
local function resize_fake(amount, s)
  -- No screen given
  s = s or awful.screen.focused()
  amount = amount or resize_default_amount
  -- Ge real screen if fake was focused
  if s.is_fake then s = s.parent end
  -- Index for cleaner code
  local index = tostring(s.index)
  -- Resize only if fake is open
  if s.fake.is_open then
    -- Modify width variables
    screens[index].real_w = screens[index].real_w + amount
    screens[index].fake_w = screens[index].fake_w - amount
    -- Resize screens
    s:fake_resize(
      screens[index].geo.x,
      screens[index].geo.y,
      screens[index].real_w,
      screens[index].geo.height
    )
    s.fake:fake_resize(
      screens[index].geo.x + screens[index].real_w,
      screens[index].geo.y,
      screens[index].fake_w,
      screens[index].geo.height
    )
  end
  -- Because memory leak
  collectgarbage('collect')
  -- Emit signal
  s:emit_signal('fake_resize')
end

-- Reset screen widths to default value
local function reset_fake(s)
  -- No sreen given
  s = s or awful.screen.focused()
  -- Get real screen if fake was focused
  if s.is_fake then s = s.parent end
  -- In case screen doesn't have fake
  if not s.has_fake then return end
  -- Index for cleaner code
  local index = tostring(s.index)
  if s.fake.is_open then
    screens[index].real_w = math.floor(screens[index].geo.width * ratio)
    screens[index].fake_w = screens[index].geo.width - screens[index].real_w
    s:fake_resize(
      screens[index].geo.x,
      screens[index].geo.y,
      screens[index].real_w,
      screens[index].geo.height
    )
    s.fake:fake_resize(
      screens[index].real_w,
      screens[index].geo.y,
      screens[index].geo.width - screens[index].real_w,
      screens[index].geo.height
    )
  end
  -- Because memory leak
  collectgarbage('collect')
  -- Emit signal
  s:emit_signal('fake_reset')
end

-- Keybinds for git version
awful.keyboard.append_global_keybindings({

  -- Toggle/hide fake screen
  awful.key({ modkey }, '§',
    function()
      _G.screen.emit_signal('toggle_fake')
    end,
  { description = 'show/hide fake screen', group = 'fake screen' }),

  -- Create or remove
  awful.key({ modkey, altkey }, '§',
    function()
      if screen_has_fake() then
        _G.screen.emit_signal('remove_fake')
      else
        _G.screen.emit_signal('create_fake')
      end
    end,
  { description = 'create/remove fake screen', group = 'fake screen' }),

  -- Increase fake screen size
  awful.key({ modkey, altkey }, 'Left',
    function()
      _G.screen.emit_signal('resize_fake', -10)
    end,
  { description = 'resize fake screen', group = 'fake screen' }),

  -- Decrease fake screen size
  awful.key({ modkey, altkey }, 'Right',
    function()
      _G.screen.emit_signal('resize_fake', 10)
    end,
    { description = 'resize fake screen', group = 'fake screen' }),

  -- Reset screen sizes to initial size
  awful.key({ modkey, altkey }, 'r',
    function()
      _G.screen.emit_signal('reset_fake')
    end,
    { description = 'reset fake screen size', group = 'fake screen' }),

})

-- Signals, maybe useful for keybinds. s = screen, a = amount
_G.screen.connect_signal('remove_fake', function(s) remove_fake(s) end)
_G.screen.connect_signal('toggle_fake', function(s) toggle_fake(s) end)
_G.screen.connect_signal('create_fake', function(s) create_fake(s) end)
_G.screen.connect_signal('resize_fake', function(a, s) resize_fake(a, s) end)
_G.screen.connect_signal('reset_fake', function(s) reset_fake(s) end)
