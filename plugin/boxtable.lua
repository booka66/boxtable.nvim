if vim.g.loaded_boxtable then return end
vim.g.loaded_boxtable = true

vim.api.nvim_create_user_command("BoxTable", function(a)
  local opts = {}
  if a.args ~= "" then opts.max_width = tonumber(a.args) end
  if a.range == 0 then
    -- no range: insert a fresh 2x2 table at the cursor
    local l = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, l, l, false, { "" })
    require("boxtable").convert(l + 1, l + 1, opts)
  else
    require("boxtable").convert(a.line1, a.line2, opts)
  end
end, { range = true, nargs = "?", desc = "Convert pipe/tab rows to a box-drawing table (or insert an empty one)" })

vim.api.nvim_create_user_command("BoxTableMode", function()
  require("boxtable").toggle_mode()
end, { desc = "Toggle boxtable editing keymaps for this buffer" })
