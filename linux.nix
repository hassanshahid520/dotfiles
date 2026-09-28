# Linux-only additions on top of home.nix (used by homeConfigurations."linux*").
{ ... }:
{
  # Non-NixOS distro (Ubuntu): wire up XDG data dirs, fonts, and locales for
  # Nix-installed programs.
  targets.genericLinux.enable = true;

  # Puts the `home-manager` command on PATH for ./rebuild-linux.sh.
  programs.home-manager.enable = true;

  # Claude Code and herdr install into ~/.local/bin; Ubuntu only adds that to
  # PATH in ~/.profile, which zsh never reads.
  home.sessionPath = [ "$HOME/.local/bin" ];
}
