return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("lualine").setup({
      sections = {
        lualine_c = {
          "filename",
          { "diagnostics", sources = { "nvim_lsp" } },
        },
        lualine_x = {
          function()
            local clients = vim.lsp.get_clients({ bufnr = 0 })
            if #clients > 0 then
              return "  " .. clients[1].name
            end
            return ""
          end,
          "filetype",
        },
      },
    })
  end,
}
