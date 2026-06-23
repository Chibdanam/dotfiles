return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "lua",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "yaml",
        "markdown",
        "markdown_inline",
        "bash",
        "html",
        "css",
        "toml",
        "rust",
        "c_sharp",
        -- injection targets referenced by the above grammars' queries
        "c",
        "comment",
        "jsdoc",
        "luadoc",
        "luap",
        "printf",
        "query",
        "regex",
        "vim",
        "vimdoc",
      })

      -- v1 dropped the standalone jsonc parser; reuse json for .jsonc files.
      vim.treesitter.language.register("json", "jsonc")

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if lang and pcall(vim.treesitter.start, args.buf, lang) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
