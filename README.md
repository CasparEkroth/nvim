# nvim

Personal Neovim config focused on Python, C/C++, Jupyter notebooks, Flutter, and light DevOps editing. Plugins are managed with [lazy.nvim](https://github.com/folke/lazy.nvim); language servers via [Mason](https://github.com/williamboman/mason.nvim).

**Leader key:** `Space`

## Requirements

| Dependency | Notes |
|---|---|
| **Neovim 0.11+** | Uses the `vim.lsp.config` / `vim.lsp.enable` API |
| `git` | Plugin bootstrap + updates |
| `rsync` | Used by `./setup` to install the config |
| **Python ≥ 3.10** | Molten / jupytext / xlsx host env (created by `./setup`) |
| Nerd Font (optional) | Icons in nvim-tree, lualine, etc. |
| ImageMagick (optional) | Inline Jupyter plot rendering (`magick` or `convert`) |
| Kitty / Ghostty / WezTerm (optional) | Kitty graphics protocol for inline images |

### Install Neovim if needed

```bash
# macOS
brew install neovim

# Ubuntu / Debian
sudo apt install neovim

# Fedora
sudo dnf install neovim

# Arch
sudo pacman -S neovim
```

## Install

> **Destructive install.** `./setup` syncs this repo into `~/.config/nvim` with `rsync --delete` (extra files there are removed) and copies `.clang-format` to **`~/.clang-format`** (applies to C/C++ projects under your home directory).

```bash
# Optional: back up an existing config
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.clang-format ~/.clang-format.bak 2>/dev/null || true

git clone https://github.com/CasparEkroth/nvim.git
cd nvim
./setup
nvim   # lazy.nvim finishes plugin install on first launch
```

After the first open, if Molten’s remote plugin commands are missing, run:

```vim
:UpdateRemotePlugins
```

### What `./setup` does

1. Checks that `nvim` is on your `PATH`
2. Syncs the repo → `~/.config/nvim`
3. Installs `.clang-format` → `$HOME/.clang-format` (LLVM style, 4-space indent)
4. Creates a Python venv at `stdpath('data')/venv` and installs:
   `pynvim`, `jupyter_client`, `ipykernel`, `jupytext`, `nbformat`, `pillow`, `openpyxl`
5. Registers a Jupyter kernel named `nvim`
6. Warns if ImageMagick is missing (skipped entirely if `--no-images` was used)

Override the Python used for the venv with:

```bash
MOLTEN_PYTHON=/path/to/python3.12 ./setup
```

On a host with no graphics (e.g. SSH-only), skip image.nvim entirely — this also skips
its luarocks/hererocks build step:

```bash
./setup --no-images   # re-enable later with ./setup --images
```

## Features

- **LSP:** basedpyright, ruff, clangd, lua_ls, robotcode, dockerls, docker_compose_language_service (Mason `ensure_installed`); Dart via flutter-tools
- **Completion:** nvim-cmp + LuaSnip
- **Navigation:** Telescope, nvim-tree, Trouble
- **Git:** gitsigns
- **Debug:** nvim-dap + dap-ui (Flutter DAP keymaps included)
- **Jupyter:** jupytext.nvim (hydrogen `# %%` cells) + molten-nvim + image.nvim
- **Xlsx:** open sheets as editable aligned tables via openpyxl (diff-based save; formulas in untouched cells preserved)
- **UI:** Catppuccin, lualine, which-key, indent-blankline, fidget, render-markdown
- **QoL:** treesitter, comment, autopairs, toggleterm, format-on-save for Python and C/C++

`lazy-lock.json` is committed so plugin versions stay reproducible.

## Layout

```text
init.lua                 entry point
setup                    install script
lua/config/              options, keymaps, lazy bootstrap, LSP, autocmds
lua/plugins/             one file per plugin (or feature)
.clang-format            copied to $HOME by ./setup
lazy-lock.json           pinned plugin revisions
```

## Keymaps

`<leader>` is **Space**. Arrow keys are disabled (hjkl only). `jk` / `JK` escape insert mode.

### General

| Key | Action |
|---|---|
| `<leader>w` | Save |
| `<leader>q` | Quit |
| `<leader>e` | Toggle file tree |
| `<leader>pv` | Netrw explore |
| `<leader>cs` | Run cspell lint |
| `<C-h/j/k/l>` | Move between splits (also from terminal) |
| `<C-t>` | Toggle floating terminal |

### Telescope

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fs` | Document symbols |
| `<leader>fw` | Workspace symbols |
| `<leader>fd` | Diagnostics |

### LSP (buffer-local when attached)

| Key | Action |
|---|---|
| `gd` | Definition |
| `gr` | References |
| `K` | Hover |
| `<leader>rn` | Rename |
| `<leader>ca` | Code action |
| `<leader>f` | Format |
| `[d` / `]d` | Prev / next diagnostic |
| `<leader>e2` | Diagnostic float |
| `<leader>ih` | Toggle inlay hints |
| `<C-s>` (insert) | Signature help |

### Trouble

| Key | Action |
|---|---|
| `<leader>xx` | Diagnostics |
| `<leader>xs` | Symbols |

### Jupyter / Molten

Open `.ipynb` files normally; jupytext converts them to hydrogen-style Python (`# %%` cells).

| Key | Action |
|---|---|
| `<leader>ji` | Init kernel (registers active venv/conda if present) |
| `<leader>jc` | Run cell |
| `<leader>jn` | Run cell and go to next |
| `<leader>jl` | Run line |
| `<leader>jv` | Run visual selection |
| `<leader>jo` | Open output window |
| `<leader>jh` | Hide output window |
| `<leader>jr` | Restart kernel |
| `<leader>jI` | Interrupt kernel |
| `<leader>jx` | Clean stray jupytext `.py` sidecars |

Inline plots need Kitty/Ghostty/WezTerm + ImageMagick. Apple Terminal shows text output only. On WSL, prefer ueberzugpp under WSLg or text-only output. On SSH / headless hosts, run `./setup --no-images` to skip installing image.nvim altogether (molten falls back to text-only output).

### Xlsx

Open `.xlsx` files normally (openpyxl via the setup venv).

| Key | Action |
|---|---|
| `]s` / `[s` | Next / previous sheet |
| `o` / `O` | Insert row below / above |
| `<leader>c` / `<leader>C` | Insert column after / before |
| `<leader>f` | Realign columns |
| `:w` | Save (only changed cells written back) |

Very large sheets may open read-only past the truncation cap. Editing a formula cell replaces it with a static value.

### Debug (DAP)

| Key | Action |
|---|---|
| `<leader>db` | Toggle breakpoint |
| `<leader>dc` | Continue |
| `<leader>do` | Step over |
| `<leader>di` | Step into |
| `<leader>dO` | Step out |
| `<leader>dt` | Terminate |

### Flutter

| Key | Action |
|---|---|
| `<leader>Fr` | Run |
| `<leader>FR` | Hot reload |
| `<leader>FS` | Hot restart |
| `<leader>Fq` | Quit |
| `<leader>Fd` | Devices |
| `<leader>Fe` | Emulators |
| `<leader>Fl` | Clear dev log |
| `<leader>Fo` | Toggle outline |
| `<leader>FD` | DevTools |
| `<leader>Fg` | Run with DAP |

## Notable defaults

- 4-space indent globally; **2-space for Dart**
- Format on save for Python and C/C++ via LSP
- Spell check on (`spelllang=en_us`)
- Soft wrap for markdown and plain text only
- Opening nvim on a directory opens nvim-tree there
- System clipboard (`unnamedplus`)

## Uninstall / rollback

```bash
# Restore a backup if you made one
rm -rf ~/.config/nvim
mv ~/.config/nvim.bak ~/.config/nvim
mv ~/.clang-format.bak ~/.clang-format 2>/dev/null || true

# Optional: remove the Python host venv and molten kernel bits
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/venv"
# jupyter kernelspec uninstall nvim   # if you want the kernel gone too
```

## License

MIT — see [LICENSE](LICENSE).
