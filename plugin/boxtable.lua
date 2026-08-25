if vim.g.loaded_boxtable then return end
vim.g.loaded_boxtable = true

vim.api.nvim_create_user_command("BoxTable", function(a)
  local opts = {}
  if a.args ~= "" then opts.max_width = tonumber(a.args) end
  require("boxtable").convert(a.line1, a.line2, opts)
end, { range = true, nargs = "?", desc = "Convert pipe/tab rows to a box-drawing table" })
