---@module 'render-markdown'
---@type render.md.UserConfig
local opts = {
  heading = {
    -- empty list disables the per-line background highlight on headings
    backgrounds = {},
  },
}
require("render-markdown").setup(opts)
