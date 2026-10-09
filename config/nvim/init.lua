require("vim-options")

-- Equivalent of lazy.nvim's `build = ":TSUpdate"`: parsers follow the plugin.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
      if not ev.data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      vim.cmd("TSUpdate")
    end
  end,
})

local gh = function(repo)
  return "https://github.com/" .. repo
end

vim.pack.add({
  gh("jeffkreeftmeijer/vim-dim"),
  gh("folke/snacks.nvim"),
  { src = gh("echasnovski/mini.nvim"), version = vim.version.range("*") },
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  { src = gh("saghen/blink.cmp"), version = vim.version.range("1") },
  { src = gh("williamboman/mason.nvim"), version = "v2.2.1" },
  { src = gh("williamboman/mason-lspconfig.nvim"), version = "v2.1.0" },
  gh("WhoIsSethDaniel/mason-tool-installer.nvim"),
  { src = gh("neovim/nvim-lspconfig"), version = "v2.7.0" },
  gh("stevearc/conform.nvim"),
  gh("MeanderingProgrammer/render-markdown.nvim"),
  gh("supermaven-inc/supermaven-nvim"),
  gh("YannickHerrero/nvim-note-helper"),
  gh("alexghergh/nvim-tmux-navigation"),
  { src = gh("folke/which-key.nvim"), version = "v3.17.0" },
}, { confirm = false })

for _, name in ipairs({
  "colorscheme",
  "snacks",
  "mini",
  "treesitter",
  "completion",
  "lsp",
  "conform",
  "render-markdown",
  "supermaven",
  "note-helper",
  "tmux",
  "which-key",
}) do
  require("plugins." .. name)
end
