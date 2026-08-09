return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufWritePost" },
  config = function()
    require("lint").linters_by_ft = {
      ["*"] = { "cspell" },
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
      callback = function()
        require("lint").try_lint()
      end,
    })
  end,
}
