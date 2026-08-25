-- boxtable.nvim: Unicode box-drawing tables you can edit in place.
local M = {}

M.config = {
  width = 90,     -- target total table width; wide columns wrap to fit
  pad = 1,        -- spaces on each side of cell contents
  auto_mode = true, -- enable editing keymaps when the cursor enters a table
  keymaps = {
    next_cell = "<Tab>",
    prev_cell = "<S-Tab>",
    cell_left = "<A-h>",
    cell_down = "<A-j>",
    cell_up = "<A-k>",
    cell_right = "<A-l>",
    row_below = "<A-o>",
    row_above = "<A-O>",
    col_right = "<A-c>",
    col_left = "<A-C>",
    delete_row = "<A-d>",
    delete_col = "<A-D>",
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  if M.config.auto_mode then
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = vim.api.nvim_create_augroup("boxtable_auto", { clear = true }),
      callback = function()
        local inside = M.find_table(vim.api.nvim_win_get_cursor(0)[1]) ~= nil
        if inside ~= (vim.b.boxtable_mode == true) then M.set_mode(inside) end
      end,
    })
  end
end

local dw = vim.fn.strdisplaywidth
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function starts(l, ch) return l:sub(1, #ch) == ch end
local function is_rule(l) return starts(l, "┌") or starts(l, "├") or starts(l, "└") end
local function is_body(l) return starts(l, "│") end

---------------------------------------------------------------------------
-- Parsing
---------------------------------------------------------------------------

-- Parse an existing box table. Returns rows (list of list of strings) and,
-- per input line, {row=ri, parts={cell strings on this line}, starts={byte offsets}}.
local function parse_box(lines)
  local rows, linfo = {}, {}
  local cur
  local function flush()
    if cur then
      for i, parts in ipairs(cur) do cur[i] = table.concat(parts, " ") end
      rows[#rows + 1] = cur
    end
    cur = nil
  end
  for li, raw in ipairs(lines) do
    local l = trim(raw)
    if is_rule(l) then
      flush()
    elseif is_body(l) then
      local inner = l:sub(4)
      if inner:sub(-3) == "│" then inner = inner:sub(1, -4) end
      local parts, offs = {}, {}
      local pos = (raw:find("│", 1, true) or 1) + 2 -- byte index after leading │ in raw
      for _, seg in ipairs(vim.split(inner, "│", { plain = true })) do
        local lead = #seg:match("^%s*")
        parts[#parts + 1] = trim(seg)
        offs[#offs + 1] = pos + lead
        pos = pos + #seg + 3
      end
      if not cur then cur = {} end
      for i, p in ipairs(parts) do
        cur[i] = cur[i] or {}
        if p ~= "" then cur[i][#cur[i] + 1] = p end
      end
      linfo[li] = { row = #rows + 1, parts = parts, starts = offs }
    end
  end
  flush()
  return rows, linfo
end

-- Parse pipe- or tab-delimited rows (markdown-ish). Separator rows ignored.
local function parse_delim(lines)
  local rows = {}
  for _, l in ipairs(lines) do
    if trim(l) ~= "" and not l:match("^%s*|?%s*:?%-+") then
      local sep = l:find("\t") and "\t" or "|"
      local s = l
      if sep == "|" then s = s:gsub("^%s*|", ""):gsub("|%s*$", "") end
      local cells = {}
      for _, c in ipairs(vim.split(s, sep, { plain = true })) do cells[#cells + 1] = trim(c) end
      rows[#rows + 1] = cells
    end
  end
  return rows
end

local function parse(lines)
  for _, l in ipairs(lines) do
    local t = trim(l)
    if is_rule(t) or is_body(t) then return parse_box(lines) end
  end
  return parse_delim(lines), {}
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local function wrap(s, width)
  local out, line = {}, ""
  for word in s:gmatch("%S+") do
    if line == "" then
      line = word
    elseif dw(line) + 1 + dw(word) <= width then
      line = line .. " " .. word
    else
      out[#out + 1] = line
      line = word
    end
  end
  if line ~= "" or #out == 0 then out[#out + 1] = line end
  return out
end

local function pad_cell(s, width, center)
  local gap = width - dw(s)
  if center then
    local left = math.floor(gap / 2)
    return string.rep(" ", left) .. s .. string.rep(" ", gap - left)
  end
  return s .. string.rep(" ", gap)
end

-- Render rows to lines. Also returns meta: per row {first=line idx, lines={{parts, starts}}}
local function render_rows(rows, opts)
  opts = vim.tbl_extend("force", M.config, opts or {})
  local ncols = 0
  for _, r in ipairs(rows) do ncols = math.max(ncols, #r) end
  if ncols == 0 then ncols = 1 end
  for _, r in ipairs(rows) do for i = #r + 1, ncols do r[i] = "" end end

  -- natural (unwrapped) width and longest word per column
  local natural, minw = {}, {}
  for ci = 1, ncols do natural[ci], minw[ci] = 1, 1 end
  for _, r in ipairs(rows) do
    for ci = 1, ncols do
      natural[ci] = math.max(natural[ci], dw(r[ci]))
      for w in r[ci]:gmatch("%S+") do minw[ci] = math.max(minw[ci], dw(w)) end
    end
  end
  -- fit to total width: columns that fit their fair share keep their natural
  -- width; the rest share what remains proportionally (never below longest word)
  local limit = {}
  for ci = 1, ncols do limit[ci] = natural[ci] end
  local avail = (opts.width or math.huge) - (ncols * (2 * opts.pad + 1) + 1)
  local total = 0
  for ci = 1, ncols do total = total + natural[ci] end
  if total > avail then
    local fixed, flex = {}, {}
    local remaining = avail
    local changed = true
    while changed do
      changed = false
      local fsum, fn = 0, 0
      for ci = 1, ncols do if not fixed[ci] then fsum, fn = fsum + natural[ci], fn + 1 end end
      for ci = 1, ncols do
        if not fixed[ci] and natural[ci] <= remaining * natural[ci] / fsum + 0.5 and natural[ci] <= remaining / fn then
          fixed[ci], remaining, changed = true, remaining - natural[ci], true
        end
      end
    end
    local fsum = 0
    for ci = 1, ncols do if not fixed[ci] then fsum = fsum + natural[ci] end end
    for ci = 1, ncols do
      if not fixed[ci] then limit[ci] = math.max(minw[ci], math.floor(remaining * natural[ci] / fsum)) end
    end
  end

  local widths, wrapped = {}, {}
  for ci = 1, ncols do widths[ci] = 1 end
  for ri, r in ipairs(rows) do
    wrapped[ri] = {}
    for ci = 1, ncols do
      local ls = wrap(r[ci], limit[ci])
      wrapped[ri][ci] = ls
      for _, l in ipairs(ls) do widths[ci] = math.max(widths[ci], dw(l)) end
    end
  end

  local p = string.rep(" ", opts.pad)
  local function rule(l, m, r)
    local segs = {}
    for ci = 1, ncols do segs[ci] = string.rep("─", widths[ci] + 2 * opts.pad) end
    return l .. table.concat(segs, m) .. r
  end

  local out, meta = { rule("┌", "┬", "┐") }, {}
  for ri, cells in ipairs(wrapped) do
    local h = 0
    for _, ls in ipairs(cells) do h = math.max(h, #ls) end
    meta[ri] = { first = #out + 1, lines = {} }
    for li = 1, h do
      local line, parts, offs = "│", {}, {}
      for ci = 1, ncols do
        local txt = cells[ci][li] or ""
        line = line .. p
        offs[ci] = #line
        parts[ci] = txt
        line = line .. pad_cell(txt, widths[ci], ri == 1) .. p .. "│"
      end
      out[#out + 1] = line
      meta[ri].lines[li] = { parts = parts, starts = offs }
    end
    out[#out + 1] = ri < #wrapped and rule("├", "┼", "┤") or rule("└", "┴", "┘")
  end
  return out, meta
end

function M.render(lines, opts)
  local rows = parse(lines)
  if #rows == 0 then return lines end
  return (render_rows(rows, opts))
end

---------------------------------------------------------------------------
-- Buffer interaction
---------------------------------------------------------------------------

-- Find the table containing line lnum. Returns top, bot (1-indexed) or nil.
function M.find_table(lnum)
  local last = vim.api.nvim_buf_line_count(0)
  local function get(n) return trim(vim.api.nvim_buf_get_lines(0, n - 1, n, false)[1] or "") end
  local top = lnum
  while top >= 1 do
    local l = get(top)
    if starts(l, "┌") then break end
    if not (is_rule(l) or is_body(l)) then return nil end
    top = top - 1
  end
  if top < 1 then return nil end
  local bot = lnum
  while bot <= last do
    local l = get(bot)
    if starts(l, "└") then break end
    if not (is_rule(l) or is_body(l)) then return nil end
    bot = bot + 1
  end
  if bot > last then return nil end
  return top, bot
end

-- Snapshot the table under the cursor: rows plus cursor cell (r, c, off).
local function snapshot()
  local pos = vim.api.nvim_win_get_cursor(0)
  local top, bot = M.find_table(pos[1])
  if not top then return nil end
  local lines = vim.api.nvim_buf_get_lines(0, top - 1, bot, false)
  local rows, linfo = parse_box(lines)
  local li = pos[1] - top + 1
  local r, c, off = 1, 1, 0
  local info = linfo[li]
  if not info then
    -- on a rule line: pick the row below (or above for the bottom rule)
    for j = li + 1, #lines do if linfo[j] then info, li = linfo[j], j break end end
    if not info then for j = li - 1, 1, -1 do if linfo[j] then info, li = linfo[j], j break end end end
  end
  if info then
    r = info.row
    local col = pos[2]
    for i, s in ipairs(info.starts) do if col >= s - 1 - M.config.pad then c = i end end
    c = math.min(c, #info.parts)
    -- byte offset into the joined cell text
    for j = 1, li - 1 do
      local o = linfo[j]
      if o and o.row == r and o.parts[c] and o.parts[c] ~= "" then off = off + #o.parts[c] + 1 end
    end
    off = off + math.max(0, math.min(col - info.starts[c], #info.parts[c]))
  end
  return { top = top, bot = bot, rows = rows, r = r, c = c, off = off }
end

-- Re-render the table and put the cursor in cell (r, c) at byte offset off.
local function write(snap, r, c, off, opts, join)
  local lines, meta = render_rows(snap.rows, opts)
  local cur = vim.api.nvim_buf_get_lines(0, snap.top - 1, snap.bot, false)
  if not vim.deep_equal(cur, lines) then
    -- fold the re-render into the user's own edit so a single undo reverts both
    if join then pcall(vim.cmd, "undojoin") end
    vim.api.nvim_buf_set_lines(0, snap.top - 1, snap.bot, false, lines)
  end
  r = math.max(1, math.min(r, #meta))
  local m = meta[r]
  c = math.max(1, math.min(c, #m.lines[1].parts))
  off = off or 0
  local li, col = 1, 0
  for i, ln in ipairs(m.lines) do
    local n = #ln.parts[c]
    if off <= n or i == #m.lines then
      li, col = i, math.min(off, n)
      break
    end
    off = off - n - 1
  end
  local target = m.lines[li]
  vim.api.nvim_win_set_cursor(0, { snap.top + m.first - 1 + li - 1, target.starts[c] + col })
end

function M.refresh(opts, join)
  local s = snapshot()
  if s then write(s, s.r, s.c, s.off, opts, join) end
end

local function with_snap(fn)
  return function()
    local s = snapshot()
    if not s then return end
    local r, c, off = fn(s)
    write(s, r or s.r, c or s.c, off or 0)
  end
end

local function ncols(s) return #s.rows[1] end
local function empty_row(n) local t = {} for i = 1, n do t[i] = "" end return t end

M.next_cell = with_snap(function(s)
  local r, c = s.r, s.c + 1
  if c > ncols(s) then r, c = s.r + 1, 1 end
  if r > #s.rows then s.rows[#s.rows + 1] = empty_row(ncols(s)) end
  return r, c
end)
M.prev_cell = with_snap(function(s)
  local r, c = s.r, s.c - 1
  if c < 1 then r, c = s.r - 1, ncols(s) end
  if r < 1 then r, c = 1, 1 end
  return r, c
end)
M.cell_left = with_snap(function(s) return s.r, math.max(1, s.c - 1) end)
M.cell_right = with_snap(function(s) return s.r, math.min(ncols(s), s.c + 1) end)
M.cell_up = with_snap(function(s) return math.max(1, s.r - 1), s.c end)
M.cell_down = with_snap(function(s) return math.min(#s.rows, s.r + 1), s.c end)

M.row_below = with_snap(function(s)
  table.insert(s.rows, s.r + 1, empty_row(ncols(s)))
  return s.r + 1, 1
end)
M.row_above = with_snap(function(s)
  table.insert(s.rows, s.r, empty_row(ncols(s)))
  return s.r, 1
end)
M.col_right = with_snap(function(s)
  for _, row in ipairs(s.rows) do table.insert(row, s.c + 1, "") end
  return s.r, s.c + 1
end)
M.col_left = with_snap(function(s)
  for _, row in ipairs(s.rows) do table.insert(row, s.c, "") end
  return s.r, s.c
end)
M.delete_row = with_snap(function(s)
  if #s.rows > 1 then table.remove(s.rows, s.r) end
  return math.min(s.r, #s.rows), s.c
end)
M.delete_col = with_snap(function(s)
  if ncols(s) > 1 then for _, row in ipairs(s.rows) do table.remove(row, s.c) end end
  return s.r, math.min(s.c, ncols(s))
end)

---------------------------------------------------------------------------
-- Mode
---------------------------------------------------------------------------

local function map(mode, lhs, fn, desc)
  if lhs and lhs ~= "" then
    vim.keymap.set(mode, lhs, function()
      if vim.fn.mode() == "i" then vim.cmd("stopinsert") end
      vim.schedule(fn)
    end, { buffer = 0, desc = "boxtable: " .. desc })
  end
end
local function unmap(mode, lhs)
  if lhs and lhs ~= "" then pcall(vim.keymap.del, mode, lhs, { buffer = 0 }) end
end

function M.set_mode(on)
  local k = M.config.keymaps
  local actions = {
    next_cell = M.next_cell, prev_cell = M.prev_cell,
    cell_left = M.cell_left, cell_down = M.cell_down, cell_up = M.cell_up, cell_right = M.cell_right,
    row_below = M.row_below, row_above = M.row_above,
    col_right = M.col_right, col_left = M.col_left,
    delete_row = M.delete_row, delete_col = M.delete_col,
  }
  vim.b.boxtable_mode = on
  if on then
    for name, fn in pairs(actions) do map({ "n", "i" }, k[name], fn, name:gsub("_", " ")) end
    vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
      group = vim.api.nvim_create_augroup("boxtable_buf_" .. vim.api.nvim_get_current_buf(), { clear = true }),
      buffer = 0,
      callback = function()
        if not vim.b.boxtable_mode then return end
        -- don't fight undo/redo: an undo leaves seq_cur behind seq_last
        local u = vim.fn.undotree()
        if u.seq_cur ~= u.seq_last then return end
        M.refresh(nil, true)
      end,
    })
  else
    for name in pairs(actions) do unmap({ "n", "i" }, k[name]) end
    pcall(vim.api.nvim_del_augroup_by_name, "boxtable_buf_" .. vim.api.nvim_get_current_buf())
  end
end

function M.toggle_mode() M.set_mode(not vim.b.boxtable_mode) end

-- Replace lines [first, last] with a rendered table, then land the cursor in it.
function M.convert(first, last, opts)
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local rows = parse(lines)
  if #rows == 0 then rows = { { "", "" }, { "", "" } } end
  local out, meta = render_rows(rows, opts)
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, out)
  vim.api.nvim_win_set_cursor(0, { first + meta[1].first - 1, meta[1].lines[1].starts[1] })
  if not M.config.auto_mode then M.set_mode(true) end
end

return M
