require("mini.pairs").setup()
require("mini.surround").setup()
require("mini.icons").setup()
require("mini.statusline").setup({ use_icons = true })
require("mini.tabline").setup()

-- Give the current tab a visible background. mini.tabline's defaults
-- link MiniTablineCurrent to TabLineSel which is bold-only — bold
-- alone isn't a strong enough cue against the rest of the tab bar.
local function set_current_tab_hl()
  vim.api.nvim_set_hl(0, "MiniTablineCurrent", {
    ctermbg = "NONE", ctermfg = "NONE", cterm = { bold = true, reverse = true },
  })
  vim.api.nvim_set_hl(0, "MiniTablineModifiedCurrent", {
    ctermbg = "NONE", ctermfg = "NONE", cterm = { bold = true, reverse = true, italic = true },
  })
end
set_current_tab_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("tabline-current-hl", { clear = true }),
  callback = set_current_tab_hl,
})
