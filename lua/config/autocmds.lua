-- Autocommands

-- Format on save via attached LSP (ruff for Python, clangd for C/C++)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.py", "*.c", "*.h", "*.cpp", "*.hpp", "*.cc", "*.cxx", "*.hh" },
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- Dart/Flutter style guide uses 2-space indent, not the global 4.
-- Registered here (not inside flutter-tools' lazy-loaded config()) so it's
-- active before the first buffer is read, since lazy.nvim defers loading
-- lazy=false plugins until VimEnter -- too late for a file opened via
-- `nvim foo.dart` on the command line.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dart",
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
})

-- Soft-wrap long lines so the full line stays visible on screen.
-- Global wrap is off; enable it only for prose buffers (markdown, plain text).
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true -- break on word boundaries, not mid-word
    vim.opt_local.breakindent = true -- keep indent on wrapped continuation lines
    vim.opt_local.showbreak = "↳ " -- visual marker for wrapped lines
  end,
})

-- Open file tree automatically when starting Neovim on a directory
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function(data)
    if vim.fn.isdirectory(data.file) == 1 then
      vim.cmd.cd(data.file)
      require("nvim-tree.api").tree.open()
    end
  end,
})
