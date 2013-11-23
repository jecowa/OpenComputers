if not term.isAvailable() then
  return
end

local args, options = shell.parse(...)
if args.n == 0 then
  print("Usage: edit <filename>")
  return
end

local filename = shell.resolve(args[1])

local readonly = options.r or fs.get(filename).isReadOnly()

if fs.isDirectory(filename) or readonly and not fs.exists(filename) then
  print("file not found")
  return
end

term.clear()
term.setCursorBlink(true)

local running = true
local buffer = {}
local scrollX, scrollY = 0, 0

-------------------------------------------------------------------------------

local function getCursor()
  local cx, cy = term.getCursor()
  return cx + scrollX, cy + scrollY
end

local function line()
  local cbx, cby = getCursor()
  return buffer[cby]
end

local function setCursor(nbx, nby)
  local w, h = component.gpu.getResolution()

  local ncy = nby - scrollY
  if ncy > h then
    local sy = nby - h
    local dy = math.abs(scrollY - sy)
    scrollY = sy
    component.gpu.copy(1, 1 + dy, w, h - dy, 0, -dy)
    for by = nby - (dy - 1), nby do
      local str = text.pad(unicode.sub(buffer[by], 1 + scrollX), w)
      component.gpu.set(1, by - scrollY, str)
    end
  elseif ncy < 1 then
    local sy = nby - 1
    local dy = math.abs(scrollY - sy)
    scrollY = sy
    component.gpu.copy(1, 1, w, h - dy, 0, dy)
    for by = nby, nby + (dy - 1) do
      local str = text.pad(unicode.sub(buffer[by], 1 + scrollX), w)
      component.gpu.set(1, by - scrollY, str)
    end
  end

  local ncx = nbx - scrollX
  if ncx > w then
    local sx = nbx - w
    local dx = math.abs(scrollX - sx)
    scrollX = sx
    component.gpu.copy(1 + dx, 1, w - dx, h, -dx, 0)
    for by = 1 + scrollY, math.min(h + scrollY, #buffer) do
      local str = unicode.sub(buffer[by], nbx - (dx - 1), nbx)
      str = text.pad(str, dx)
      component.gpu.set(1 + (w - dx), by - scrollY, str)
    end
  elseif ncx < 1 then
    local sx = nbx - 1
    local dx = math.abs(scrollX - sx)
    scrollX = sx
    component.gpu.copy(1, 1, w - dx, h, dx, 0)
    for by = 1 + scrollY, math.min(h + scrollY, #buffer) do
      local str = unicode.sub(buffer[by], nbx, nbx + dx)
      --str = text.pad(str, dx)
      component.gpu.set(1, by - scrollY, str)
    end
  end

  term.setCursor(nbx - scrollX, nby - scrollY)
end

local function home()
  local cbx, cby = getCursor()
  setCursor(1, cby)
end

local function ende()
  local cbx, cby = getCursor()
  setCursor(unicode.len(line()) + 1, cby)
end

local function left()
  local cbx, cby = getCursor()
  if cbx > 1 then
    setCursor(cbx - 1, cby)
    return true -- for backspace
  elseif cby > 1 then
    setCursor(cbx, cby - 1)
    ende()
    return true -- again, for backspace
  end
end

local function right(n)
  n = n or 1
  local cbx, cby = getCursor()
  local be = unicode.len(line()) + 1
  if cbx < be then
    setCursor(math.min(be, cbx + n), cby)
  elseif cby < #buffer then
    setCursor(1, cby + 1)
  end
end

local function up()
  local cbx, cby = getCursor()
  if cby > 1 then
    setCursor(cbx, cby - 1)
    if getCursor() > unicode.len(line()) then
      ende()
    end
  end
end

local function down()
  local cbx, cby = getCursor()
  if cby < #buffer then
    setCursor(cbx, cby + 1)
    if getCursor() > unicode.len(line()) then
      ende()
    end
  end
end

local function delete()
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local w, h = component.gpu.getResolution()
  if cbx <= unicode.len(line()) then
    buffer[cby] = unicode.sub(line(), 1, cbx - 1) ..
                  unicode.sub(line(), cbx + 1)
    component.gpu.copy(cx + 1, cy, w - cx, 1, -1, 0)
    local br = cbx + (w - cx)
    local char = unicode.sub(line(), br, br)
    if not char or unicode.len(char) == 0 then
      char = " "
    end
    component.gpu.set(w, cy, char)
  elseif cby < #buffer then
    local append = table.remove(buffer, cby + 1)
    buffer[cby] = buffer[cby] .. append
    component.gpu.set(cx, cy, append)
    if cy < h then
      component.gpu.copy(1, cy + 2, w, h - (cy - 2), 0, -1)
      component.gpu.set(1, h, text.pad(buffer[cby + (h - cy)], w))
    end
  end
end

local function insert(value)
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local w, h = component.gpu.getResolution()
  buffer[cby] = unicode.sub(line(), 1, cbx - 1) ..
                value ..
                unicode.sub(line(), cbx)
  local len = unicode.len(value)
  local scroll = w - cx - len
  if scroll > 0 then
    component.gpu.copy(cx, cy, scroll, 1, len, 0)
  end
  component.gpu.set(cx, cy, value)
  right(len)
end

local function enter()
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local w, h = component.gpu.getResolution()
  table.insert(buffer, cby + 1, unicode.sub(buffer[cby], cbx))
  buffer[cby] = unicode.sub(buffer[cby], 1, cbx - 1)
  component.gpu.fill(cx, cy, w - (cx - 1), 1, " ")
  if cy < h then
    if cy < h - 1 then
      component.gpu.copy(1, cy + 1, w, h - (cy - 1), 0, 1)
    end
    component.gpu.set(1, cy + 1, text.pad(buffer[cby + 1], w))
  end
  setCursor(1, cby + 1)
end

local function onKeyDown(char, code)
  term.setCursorBlink(false)
  if code == keyboard.keys.back and not readonly then
    if left() then
      delete()
    end
  elseif code == keyboard.keys.delete and not readonly then
    delete()
  elseif code == keyboard.keys.left then
    left()
  elseif code == keyboard.keys.right then
    right()
  elseif code == keyboard.keys.home then
    home()
  elseif code == keyboard.keys["end"] then
    ende()
  elseif code == keyboard.keys.up then
    up()
  elseif code == keyboard.keys.down then
    down()
  elseif code == keyboard.keys.enter and not readonly then
    enter()
  elseif keyboard.isControlDown() then
    local cbx, cby = getCursor()
    if code == keyboard.keys.s and not readonly then
      local f = io.open(filename, "w")
      for _, line in ipairs(buffer) do
        f:write(line)
        f:write("\n")
      end
      f:close()
    elseif code == keyboard.keys.w then
      -- TODO ask to save if changed
      running = false
    end
  elseif not keyboard.isControl(char) and not readonly then
    insert(unicode.char(char))
  end
  term.setCursorBlink(true)
  term.setCursorBlink(true) -- force toggle to caret
end

local function onClipboard(value)
  term.setCursorBlink(false)
  local cbx, cby = getCursor()
  local l = value:find("\n", 1, true)
  if l then
    -- buffer[cby] = unicode.sub(line(), 1, cbx - 1)
    -- redraw()
    -- insert(unicode.sub(value, 1, l - 1))
    -- return true, line() .. "\n"

    -- TODO insert multiple lines
  else
    insert(value)
    term.setCursorBlink(true)
    term.setCursorBlink(true) -- force toggle to caret
  end
end

-------------------------------------------------------------------------------

do
  local f = io.open(filename)
  if f then
    local w, h = component.gpu.getResolution()
    for line in f:lines() do
      table.insert(buffer, line)
      if #buffer <= h then
        component.gpu.set(1, #buffer, line)
      end
    end
    f:close()
  else
    table.insert(buffer, "")
  end
end

while running do
  local event, address, charOrValue, code = event.pull()
  if type(address) == "string" and component.isPrimary(address) then
    if event == "key_down" then
      onKeyDown(charOrValue, code)
    elseif event == "clipboard" then
      onClipboard(charOrValue)
    end
  end
end

term.clear()
term.setCursorBlink(false)