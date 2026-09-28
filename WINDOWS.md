# Windows setup

This repo is built for macOS (nix-darwin and home-manager). Neither runs on Windows, so `bootstrap-windows.ps1` rebuilds the same setup with Windows tools instead.

## What maps to what

| macOS (Nix) | Windows (`bootstrap-windows.ps1`) |
|---|---|
| Homebrew casks and Nix packages | winget: Git, PowerShell 7, WezTerm, Neovim, ripgrep, fd, fzf, jq, lazygit, Starship. Also installs Hack Nerd Font (per-user), Claude Code and herdr (official installer) |
| `mkOutOfStoreSymlink` links | Symlinks for files and junctions for folders, all pointing into `~\.dotfiles\home` |
| zsh + autosuggestions + syntax highlighting | PowerShell 7 with PSReadLine inline history suggestions (`Ctrl+f` accepts one) |
| zsh aliases | Functions in the pwsh profile: `..`, `add`, `push`, `pull`, `m`, `cc`, `co` |
| `programs.starship` | `~\.config\starship.toml` with the same prompt |
| `system.defaults` | Dark mode, show file extensions, fast key repeat |

### Where the links point

| Link | Target in repo |
|---|---|
| `~\.config\wezterm` | `home\.config\wezterm` |
| `%LOCALAPPDATA%\nvim` | `home\.config\nvim` |
| `~\.claude\settings.json` | `home\.claude\settings.json` |
| `~\.claude\CLAUDE.md`, `~\.codex\AGENTS.md`, `~\.config\opencode\AGENTS.md` | `home\AGENTS.md` |
| `%APPDATA%\herdr\config.toml` | Not a link. The script generates it from `home\.config\herdr\config.toml` and adds a Windows-only `default_shell` (see below) |
| `~\.pi\agent\*` (only if `pi` is installed) | `home\.pi\agent\*` |

## Fresh-machine setup

1. **Turn on Developer Mode:** Settings → System → For developers → Developer Mode. Without it, Windows won't create file symlinks for a non-admin user.

   To check whether it's on (`1` means on):
   ```powershell
   (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock").AllowDevelopmentWithoutDevLicense
   ```

2. **Clone the repo and run the script** from a normal (non-admin) PowerShell window:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
   git clone https://github.com/hassanshahid520/dotfiles.git $HOME\.dotfiles
   cd $HOME\.dotfiles
   .\bootstrap-windows.ps1
   ```
   - If git isn't installed yet, run `winget install Git.Git` first and open a new window.
   - Use the HTTPS URL, because a fresh machine has no SSH key registered with GitHub yet. Once you've set up a key, switch the remote to SSH:
     ```powershell
     git -C $HOME\.dotfiles remote set-url origin git@github.com:hassanshahid520/dotfiles.git
     ```
   - If you downloaded the script instead of cloning it, run `Unblock-File .\bootstrap-windows.ps1` first.
   - If you start the script in Windows PowerShell 5.1, it installs the apps and then re-launches itself in PowerShell 7. It does this because 5.1 can't create symlinks without admin rights, even with Developer Mode on.

3. **Set your git identity:**
   ```powershell
   git config --global user.name "Hassan Shahid"
   git config --global user.email "hassanshahid520@gmail.com"
   ```

4. **Close every terminal**, so the updated PATH is picked up, and open WezTerm.

5. **Run `nvim` once.** lazy.nvim will install the plugins.

6. **Sign out and back in**, so the key-repeat setting and the font take effect.

## Script options

```powershell
.\bootstrap-windows.ps1                       # everything
.\bootstrap-windows.ps1 -SkipApps             # only re-do links, profile and settings
.\bootstrap-windows.ps1 -SkipWindowsSettings  # don't touch dark mode, key repeat or file extensions
.\bootstrap-windows.ps1 -RepoUrl <url> -Dotfiles <path>
```

You can run the script again at any time. It works like `rebuild.sh` does on the Mac:
- If a real file is already where a link should go, it gets backed up as `<name>.bak-<timestamp>`.
- The pwsh profile section sits between `# >>> dotfiles >>>` and `# <<< dotfiles <<<` markers. That section is replaced on every run; anything else in your profile is left alone.

## Daily use

- Editing a file under `home\` changes your live config right away, because the links point at the repo.
- Re-run the script only after changing the app list, the profile block or the Windows settings.
- Commit and push as usual from `~\.dotfiles`.

## WezTerm on Windows

`wezterm.lua` needs a Windows-only section. Without it, WezTerm opens `cmd.exe` instead of PowerShell. Put this just above `return config`:

```lua
if wezterm.target_triple:find("windows") then
  config.default_prog = { "pwsh.exe", "-NoLogo" }
  config.win32_system_backdrop = "Acrylic"  -- stands in for macos_window_background_blur
  config.font_size = 11.0                   -- 15 is large on Windows
end
```

## herdr on Windows

herdr runs natively on Windows (no WSL needed). Start it by typing `herdr` in WezTerm; the prefix key is `Ctrl+b`, as on the Mac. On Windows it reads its config from `%APPDATA%\herdr\config.toml`. Run `herdr --help` to see which config path it resolved.

That file is generated, not linked. The script copies `home\.config\herdr\config.toml` and adds:

```toml
[terminal]
default_shell = 'C:\Program Files\PowerShell\7\pwsh.exe'
```

Without this, herdr panes can open Windows PowerShell 5.1, which doesn't load the PowerShell 7 profile, so `cc`, `co`, the prompt and the suggestions are missing. The line can't go in the shared repo file because it would break herdr on macOS. **After editing the repo's herdr config, re-run `.\bootstrap-windows.ps1 -SkipApps`.**

herdr keeps a background server running, so config changes only take effect after `herdr server stop` (this closes all herdr panes). Start `herdr` again afterwards.

Its Windows docs list a few limitations compared with macOS/Linux: no direct terminal attach, no live server handoff, and some cursor flicker in panes. See https://herdr.dev/docs/windows-beta/.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `.\bootstrap-windows.ps1 is not recognized` | You're in the wrong folder. `cd` to the folder that has the script |
| Script refuses to run ("not digitally signed") | `Unblock-File .\bootstrap-windows.ps1` |
| Output shows "(hard link - enable Developer Mode…)" | Turn on Developer Mode, then re-run in PowerShell 7 with `-SkipApps`. Hard links break when git replaces a file |
| Checking whether links are correct | `Get-Item $HOME\.claude\settings.json \| Select LinkType, Target` should show `SymbolicLink` |
| Prompt shows `â¯` instead of `❯` | Console isn't using UTF-8. The profile block sets it; open a new window |
| Boxes instead of icons in WezTerm | Hack Nerd Font isn't loaded yet. Sign out and back in |
| Repo is on a different drive (e.g. `D:`) | Needs real symlinks, because hard links can't cross drives. Keeping it at `~\.dotfiles` is simplest |

## Heads-up

- `home\AGENTS.md` becomes your agent instructions for Claude, Codex and opencode.
- `cc` runs Claude Code with `--dangerously-skip-permissions`, and `co` runs Codex with `--full-auto`. Both let the agent act without asking you first.