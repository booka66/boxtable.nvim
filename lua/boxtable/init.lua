-- boxtable.nvim: turn pipe/tab-delimited rows into Unicode box-drawing tables.
local M = {}

M.config = {
  max_width = 90, -- max content width of a single column (cells wrap beyond this)
  pad = 1,        -- spaces on each side of cell content
}

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
end

local dw = vim.fn.strdisplaywidth

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Parse a block of lines into rows of cells.
-- Accepts: markdown-style `| a | b |` (or `a | b`), tab-separated, or an
-- existing box table (so re-running reflows it).
local function parse(lines)
  local rows = {}
  local is_box = false
  local function is_rule(l) return l:sub(1, 3) == "┌" or l:sub(1, 3) == "├" or l:sub(1, 3) == "└" end
  local function is_body(l) return l:sub(1, 3) == "│" end
  for _, l in ipairs(lines) do
    local t = trim(l)
    if is_rule(t) or is_body(t) then is_box = true break end
  end

  if is_box then
    local cur -- current row: list of cell-line lists
    for _, l in ipairs(lines) do
      l = trim(l)
      if is_rule(l) then
        if cur then rows[#rows + 1] = cur end
        cur = nil
      elseif is_body(l) then
        local cells = {}
        for _, c in ipairs(vim.split(l:sub(4, -4), "│", { plain = true })) do
          cells[#cells + 1] = trim(c)
        end
        if not cur then
          cur = {}
          for i = 1, #cells do cur[i] = {} end
        end
        for i, c in ipairs(cells) do
          cur[i] = cur[i] or {}
          if c ~= "" then cur[i][#cur[i] + 1] = c end
        end
      end
    end
    if cur then rows[#rows + 1] = cur end
    -- join wrapped lines back into single strings
    for _, r in ipairs(rows) do
      for i, parts in ipairs(r) do r[i] = table.concat(parts, " ") end
    end
    return rows
  end

  for _, l in ipairs(lines) do
    if trim(l) ~= "" and not l:match("^%s*|?%s*:?%-+") then -- skip md separator rows
      local sep = l:find("\t") and "\t" or "|"
      local s = l
      if sep == "|" then s = s:gsub("^%s*|", ""):gsub("|%s*$", "") end
      local cells = {}
      for c in (s .. sep):gmatch("(.-)" .. (sep == "|" and "|" or "\t")) do
        cells[#cells + 1] = trim(c)
      end
      rows[#rows + 1] = cells
    end
  end
  return rows
end

-- Word-wrap a string to width, returning a list of lines.
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

function M.render(lines, opts)
  opts = vim.tbl_extend("force", M.config, opts or {})
  local rows = parse(lines)
  if #rows == 0 then return lines end

  local ncols = 0
  for _, r in ipairs(rows) do ncols = math.max(ncols, #r) end
  for _, r in ipairs(rows) do for i = #r + 1, ncols do r[i] = "" end end

  -- column widths: longest wrapped line per column
  local widths = {}
  local wrapped = {}
  for ri, r in ipairs(rows) do
    wrapped[ri] = {}
    for ci = 1, ncols do
      local ls = wrap(r[ci], opts.max_width)
      wrapped[ri][ci] = ls
      for _, l in ipairs(ls) do widths[ci] = math.max(widths[ci] or 0, dw(l)) end
    end
  end

  local p = string.rep(" ", opts.pad)
  local function rule(l, m, r)
    local segs = {}
    for ci = 1, ncols do segs[ci] = string.rep("─", widths[ci] + 2 * opts.pad) end
    return l .. table.concat(segs, m) .. r
  end

  local out = { rule("┌", "┬", "┐") }
  for ri, cells in ipairs(wrapped) do
    local h = 0
    for _, ls in ipairs(cells) do h = math.max(h, #ls) end
    for li = 1, h do
      local segs = {}
      for ci = 1, ncols do
        segs[ci] = p .. pad_cell(cells[ci][li] or "", widths[ci], ri == 1) .. p
      end
      out[#out + 1] = "│" .. table.concat(segs, "│") .. "│"
    end
    out[#out + 1] = ri < #wrapped and rule("├", "┼", "┤") or rule("└", "┴", "┘")
  end
  return out
end

-- Replace lines [first, last] (1-indexed, inclusive) in buffer with a table.
function M.convert(first, last, opts)
  local buf = 0
  local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
  vim.api.nvim_buf_set_lines(buf, first - 1, last, false, M.render(lines, opts))
end

return M
