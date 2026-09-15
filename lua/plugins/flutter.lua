-- Flutter/Dart: LSP (dartls), run/hot-reload, device picker, optional DAP
-- flutter-tools owns dartls — do not also configure it via lspconfig/vim.lsp.config
-- Keymaps use <leader>F* so they do not collide with Telescope (<leader>f*) or
-- LSP format (<leader>f).
return {
  {
    "akinsho/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim", -- nicer device/action pickers
      "mfussenegger/nvim-dap", -- used by :FlutterDebug when nvim-dap is installed
    },
    keys = {
      -- Command names match current flutter-tools.nvim (Reload/Restart, not Hot*)
      { "<leader>Fr", "<cmd>FlutterRun<cr>", desc = "Flutter: Run" },
      { "<leader>FR", "<cmd>FlutterReload<cr>", desc = "Flutter: Hot Reload" },
      { "<leader>FS", "<cmd>FlutterRestart<cr>", desc = "Flutter: Hot Restart" },
      { "<leader>Fq", "<cmd>FlutterQuit<cr>", desc = "Flutter: Quit" },
      { "<leader>Fd", "<cmd>FlutterDevices<cr>", desc = "Flutter: Select Device" },
      { "<leader>Fe", "<cmd>FlutterEmulators<cr>", desc = "Flutter: Select Emulator" },
      { "<leader>Fl", "<cmd>FlutterLogClear<cr>", desc = "Flutter: Clear Dev Log" },
      { "<leader>Fo", "<cmd>FlutterOutlineToggle<cr>", desc = "Flutter: Toggle Outline" },
      { "<leader>FD", "<cmd>FlutterDevTools<cr>", desc = "Flutter: Open DevTools" },
      { "<leader>Fg", "<cmd>FlutterDebug<cr>", desc = "Flutter: Run (DAP)" },
    },
    config = function()
      require("flutter-tools").setup({
        ui = {
          border = "rounded",
          notification_style = "native",
        },
        decorations = {
          statusline = {
            app_version = true,
            device = true,
          },
        },
        widget_guides = {
          enabled = true,
        },
        closing_tags = {
          highlight = "Comment",
          prefix = "// ",
          enabled = true,
        },
        dev_log = {
          enabled = true,
          open_cmd = "tabedit",
        },
        dev_tools = {
          autostart = false,
          auto_open_browser = false,
        },
        outline = {
          open_cmd = "30vnew",
          auto_open = false,
        },
        lsp = {
          -- Global LspAttach in config/lsp.lua already sets gd/gr/K/etc.
          -- Color swatches: plugin lsp.color is deprecated on Neovim 0.12+;
          -- enable the built-in document_color API instead.
          on_attach = function(_client, bufnr)
            if vim.lsp.document_color then
              vim.lsp.document_color.enable(true, { bufnr = bufnr })
            end
          end,
          capabilities = require("cmp_nvim_lsp").default_capabilities(),
          settings = {
            showTodos = true,
            completeFunctionCalls = true,
            renameFilesWithClasses = "prompt",
            enableSnippets = true,
            updateImportsOnRename = true,
          },
        },
        -- Current flutter-tools: debugger.enabled routes *all* FlutterRun through DAP.
        -- Keep false so :FlutterRun uses the normal job runner (hot reload/restart).
        -- :FlutterDebug / <leader>Fg force-debug=true and still launches via DAP.
        debugger = {
          enabled = false,
          register_configurations = function(_)
            require("dap").configurations.dart = {
              {
                type = "dart",
                request = "launch",
                name = "Launch Flutter (phone)",
                program = "${workspaceFolder}/lib/main.dart",
              },
              {
                type = "dart",
                request = "attach",
                name = "Attach Flutter",
              },
            }
          end,
        },
      })
    end,
  },
}
