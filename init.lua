-- ============================================================
--  Everyday Neovim config — Python-focused, autocomplete + file tree
--  Location: ~/.config/nvim/
--  Launch:   nvim   (or nvim somefile.py)
-- ============================================================

require("config.options")
require("config.keymaps")
require("config.lazy")
require("config.lsp")
require("config.autocmds")

vim.uv = vim.uv or vim.loop
