-- Debug Adapter Protocol UI (used by :FlutterDebug / <leader>Fg and DAP keymaps)
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    keys = {
      { "<leader>db", "<cmd>DapToggleBreakpoint<cr>", desc = "Debug: Toggle Breakpoint" },
      { "<leader>dc", "<cmd>DapContinue<cr>", desc = "Debug: Continue" },
      { "<leader>do", "<cmd>DapStepOver<cr>", desc = "Debug: Step Over" },
      { "<leader>di", "<cmd>DapStepInto<cr>", desc = "Debug: Step Into" },
      { "<leader>dO", "<cmd>DapStepOut<cr>", desc = "Debug: Step Out" },
      { "<leader>dt", "<cmd>DapTerminate<cr>", desc = "Debug: Terminate" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
}
