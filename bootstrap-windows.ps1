<#
  bootstrap-windows.ps1 - Windows port of github.com/kunchenguid/dotfiles
  (nix-darwin + home-manager on macOS  ->  winget + links + PowerShell profile on Windows)

  See WINDOWS.md. Short version, from a normal (non-admin) PowerShell window:
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    git clone https://github.com/hassanshahid520/dotfiles.git $HOME\.dotfiles
    cd $HOME\.dotfiles; .\bootstrap-windows.ps1

  Re-run it any time, it's idempotent (the Windows equivalent of ./rebuild.sh).
  For file symlinks, turn on Settings > System > For developers > Developer Mode first.
  Without it, the script falls back to hard links for files. Folders always use junctions,
  which need no admin rights.
#>

param(
  [string]$RepoUrl  = "https://github.com/hassanshahid520/dotfiles.git",
  [string]$Dotfiles = "$HOME\.dotfiles",
  [switch]$SkipApps,
  [switch]$SkipWindowsSettings
)

$ErrorActionPreference = "Stop"
function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Magenta }
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path","User")
}

# ---------------------------------------------------------------- 1. Apps (brew casks + nix packages)
if (-not $SkipApps) {
  Step "Installing apps with winget"
  $apps = @(
    "Git.Git",
    "Microsoft.PowerShell",      # pwsh 7, stands in for zsh
    "wez.wezterm",
    "Neovim.Neovim",
    "BurntSushi.ripgrep.MSVC",
    "sharkdp.fd",
    "junegunn.fzf",
    "jqlang.jq",
    "JesseDuffield.lazygit",
    "Starship.Starship"
  )
  foreach ($id in $apps) {
    winget list --id $id -e --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "  ok  $id"; continue }
    Write-Host "  +   $id"
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
  }
  Refresh-Path

  Step "Installing Hack Nerd Font (per-user)"
  $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
  if (-not (Test-Path "$fontDir\HackNerdFont-Regular.ttf")) {
    $zip = "$env:TEMP\Hack.zip"; $tmp = "$env:TEMP\HackNF"
    Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" -OutFile $zip
    Expand-Archive $zip $tmp -Force
    New-Item -ItemType Directory -Force $fontDir | Out-Null
    $reg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    Get-ChildItem $tmp -Filter "HackNerdFont-*.ttf" | ForEach-Object {
      Copy-Item $_.FullName $fontDir -Force
      New-ItemProperty $reg -Name "$($_.BaseName) (TrueType)" -Value "$fontDir\$($_.Name)" -Force | Out-Null
    }
    Remove-Item $zip, $tmp -Recurse -Force
  } else { Write-Host "  ok  already installed" }

  Step "Installing Claude Code"
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
  } else { Write-Host "  ok  already installed" }
}

# ---------------------------------------------------------------- Switch to PowerShell 7
# Windows PowerShell 5.1 can't create symlinks without admin, even with Developer Mode on.
if ($PSVersionTable.PSVersion.Major -lt 7 -and (Get-Command pwsh -ErrorAction SilentlyContinue)) {
  Step "Re-launching in PowerShell 7 (needed for symlinks)"
  $argv = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath,
            "-SkipApps", "-RepoUrl", $RepoUrl, "-Dotfiles", $Dotfiles)
  if ($SkipWindowsSettings) { $argv += "-SkipWindowsSettings" }
  & pwsh @argv
  exit $LASTEXITCODE
}

# ---------------------------------------------------------------- 2. Clone the repo
Step "Cloning dotfiles to $Dotfiles"
if (-not (Test-Path "$Dotfiles\.git")) { git clone $RepoUrl $Dotfiles }
else { Write-Host "  ok  already cloned (git pull it yourself to update)" }
$H = "$Dotfiles\home"

# ---------------------------------------------------------------- 3. Links (mkOutOfStoreSymlink equivalents)
function Link($target, $link) {
  $parent = Split-Path $link -Parent
  New-Item -ItemType Directory -Force $parent | Out-Null
  if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.LinkType) {
      # remove only the link itself, never the target's contents
      if ($item.PSIsContainer) { [System.IO.Directory]::Delete($link) } else { Remove-Item $link -Force }
    }
    else {
      $bak = "$link.bak-$(Get-Date -Format yyyyMMddHHmmss)"
      Move-Item $link $bak
      Write-Host "  backed up existing $link -> $bak" -ForegroundColor Yellow
    }
  }
  if ((Get-Item $target).PSIsContainer) {
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
  } else {
    try   { New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null }
    catch { New-Item -ItemType HardLink     -Path $link -Target $target | Out-Null
            Write-Host "  (hard link - enable Developer Mode for real symlinks)" -ForegroundColor Yellow }
  }
  Write-Host "  $link -> $target"
}

Step "Linking config files"
Link "$H\.config\wezterm"          "$HOME\.config\wezterm"
Link "$H\.config\nvim"             "$env:LOCALAPPDATA\nvim"          # Neovim's config dir on Windows
Link "$H\.claude\settings.json"    "$HOME\.claude\settings.json"
Link "$H\AGENTS.md"                "$HOME\.claude\CLAUDE.md"
Link "$H\AGENTS.md"                "$HOME\.codex\AGENTS.md"
Link "$H\AGENTS.md"                "$HOME\.config\opencode\AGENTS.md"
# Pi (optional) - only if you use it
if (Get-Command pi -ErrorAction SilentlyContinue) {
  Link "$H\.pi\agent\themes"        "$HOME\.pi\agent\themes"
  Link "$H\.pi\agent\extensions"    "$HOME\.pi\agent\extensions"
  Link "$H\.pi\agent\models.json"   "$HOME\.pi\agent\models.json"
  Link "$H\.pi\agent\settings.json" "$HOME\.pi\agent\settings.json"
}
# herdr is skipped: it's a Homebrew-only (mac/Linux) tool.

# ---------------------------------------------------------------- 4. Shell (programs.zsh + programs.starship)
Step "Writing starship config"
New-Item -ItemType Directory -Force "$HOME\.config" | Out-Null
@'
add_newline = false
format = "$directory$git_branch$git_status$cmd_duration$line_break$character"

[character]
success_symbol = "[❯](purple)"
error_symbol = "[❯](red)"

[cmd_duration]
format = "[$duration]($style) "
'@ | ForEach-Object { [IO.File]::WriteAllText("$HOME\.config\starship.toml", $_, (New-Object Text.UTF8Encoding $false)) }

Step "Writing PowerShell 7 profile"
[Environment]::SetEnvironmentVariable("EDITOR", "nvim", "User")
$docs    = [Environment]::GetFolderPath("MyDocuments")    # handles OneDrive-redirected Documents
$profile7 = "$docs\PowerShell\Microsoft.PowerShell_profile.ps1"
New-Item -ItemType Directory -Force (Split-Path $profile7) | Out-Null
if (-not (Test-Path $profile7)) { New-Item -ItemType File $profile7 | Out-Null }

$block = @'
# >>> dotfiles >>>
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()  # so starship's glyphs render
$env:EDITOR = "nvim"
# zsh autosuggestions + syntax highlighting -> PSReadLine
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
Set-PSReadLineKeyHandler -Chord "Ctrl+f" -Function AcceptSuggestion
# aliases (PowerShell aliases can't carry args, so these are functions)
function ..   { Set-Location .. }
function add  { git add . }
function push { git push @args }
function pull { git pull @args }
function m    { git switch main }
function cc   { claude --dangerously-skip-permissions @args }
function co   { codex --full-auto @args }
Invoke-Expression (&starship init powershell)
# <<< dotfiles <<<
'@
$current = Get-Content $profile7 -Raw
if ($null -eq $current) { $current = "" }
$pattern = '(?s)# >>> dotfiles >>>.*?# <<< dotfiles <<<'
if ($current -match $pattern) { $current = [regex]::Replace($current, $pattern, $block.Trim()) }
else { $current = $current.TrimEnd() + "`r`n`r`n" + $block }
Set-Content $profile7 $current -Encoding utf8

# ---------------------------------------------------------------- 5. OS settings (system.defaults)
if (-not $SkipWindowsSettings) {
  Step "Applying Windows settings"
  $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
  Set-ItemProperty $p AppsUseLightTheme 0          # dark mode
  Set-ItemProperty $p SystemUsesLightTheme 0
  Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" HideFileExt 0  # show extensions
  Set-ItemProperty "HKCU:\Control Panel\Keyboard" KeyboardDelay "0"    # short delay before repeat
  Set-ItemProperty "HKCU:\Control Panel\Keyboard" KeyboardSpeed "31"   # fastest repeat
  Write-Host "  dark mode, file extensions, key repeat set (sign out/in for key repeat)"
}

Step "Done"
Write-Host @"
Next:
  - Open WezTerm. Its config comes from ~\.config\wezterm\wezterm.lua (linked to your repo).
  - Run 'nvim' once and lazy.nvim will install the plugins.
  - Set your git identity: git config --global user.name/user.email
  - Edit files under $H and the changes are live. Re-run this script after adding apps.
"@
