return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  init = function()
    -- snacks.dashboard terminal sections leave Neovim's "[Process exited 0]"
    -- footer when the polling-based cleanup in snacks.util.job races the
    -- terminal subsystem. After TermClose, watch the buffer for the next
    -- line append (which is the footer) via nvim_buf_attach and strip it.
    vim.api.nvim_create_autocmd("TermClose", {
      group = vim.api.nvim_create_augroup("snacks-strip-process-exited", { clear = true }),
      callback = function(args)
        local buf = args.buf
        local stripped = false
        vim.api.nvim_buf_attach(buf, false, {
          on_lines = function()
            if stripped then return true end -- detach
            vim.schedule(function()
              if stripped or not vim.api.nvim_buf_is_valid(buf) then return end
              local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
              for i = #lines, 1, -1 do
                if lines[i]:match("%[Process exited 0%]") then
                  vim.bo[buf].modifiable = true
                  pcall(vim.api.nvim_buf_set_lines, buf, i - 1, i, true, {})
                  vim.bo[buf].modifiable = false
                  stripped = true
                  return
                end
              end
            end)
          end,
        })
      end,
    })
  end,
  opts = {
    picker = {
      enabled = true,
      sources = {
        explorer = {
          layout = { layout = { position = "right" } },
          jump = { close = true },
          hidden = true, -- show dotfiles
          ignored = true, -- show .gitignore'd files (toggle in-explorer with I)
        },
      },
    },
    explorer = { enabled = true },
    bigfile = { enabled = true },
    quickfile = { enabled = true },
    dashboard = {
      sections = {
        { section = "header" },
        {
          pane = 2,
          section = "terminal",
          cmd = "colorscript -e square",
          height = 5,
          padding = 1,
        },
        { section = "keys", gap = 1, padding = 1 },
        {
          pane = 2,
          icon = " ",
          desc = "Browse Repo",
          padding = 1,
          key = "b",
          action = function()
            Snacks.gitbrowse()
          end,
        },
        function()
          local in_git = Snacks.git.get_root() ~= nil
          local cmds = {
            {
              icon = " ",
              title = "Git Status",
              cmd = "git --no-pager diff --stat -B -M -C | grep . || echo 'Working tree clean'",
              height = 10,
            },
          }
          return vim.tbl_map(function(cmd)
            return vim.tbl_extend("force", {
              pane = 2,
              section = "terminal",
              enabled = in_git,
              padding = 1,
              ttl = 5 * 60,
              indent = 3,
            }, cmd)
          end, cmds)
        end,
        { section = "startup" },
      },
    },
  },
  keys = {
    { "<leader> ", function() Snacks.picker.files() end, desc = "find file" },
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "live grep" },
    { "<leader>e", function() Snacks.explorer() end, desc = "file explorer" },
  },
}
