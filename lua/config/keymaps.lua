-- Global keymaps (plugin-specific maps live with their plugins)

-- Disable arrow keys
vim.keymap.set({ "n", "i", "v" }, "<Up>", "<Nop>")
vim.keymap.set({ "n", "i", "v" }, "<Down>", "<Nop>")
vim.keymap.set({ "n", "i", "v" }, "<Left>", "<Nop>")
vim.keymap.set({ "n", "i", "v" }, "<Right>", "<Nop>")

-- Quick escape from insert mode
vim.keymap.set("i", "jk", "<Esc>")
vim.keymap.set("i", "JK", "<Esc>")

-- Quality-of-life
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left split" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to split below" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to split above" })
vim.keymap.set("n", "<leader>cs", function()
  require("lint").try_lint()
end, { desc = "Run cspell lint" })
