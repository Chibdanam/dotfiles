return {
  {
    "williamboman/mason.nvim",
    tag = "v2.2.1",
    lazy = false,
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    tag = "v2.1.0",
    lazy = false,
    opts = {
      ensure_installed = { "ts_ls", "rust_analyzer", "lua_ls", "bashls" },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    lazy = false,
    opts = {
      ensure_installed = { "stylua", "prettier", "shfmt" },
      run_on_start = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    tag = "v2.7.0",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Roslyn LS is installed as a dotnet global tool (see scripts/modules/dotnet.sh).
      -- nvim-lspconfig's roslyn_ls auto-resolves the binary (roslyn-language-server on PATH).
      -- Razor is added to filetypes because the upstream config defaults to { "cs" } only.
      vim.lsp.config("roslyn_ls", {
        filetypes = { "cs", "razor" },
      })
      vim.lsp.enable("roslyn_ls")

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local opts = { buffer = event.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        end,
      })
    end,
  },
}
