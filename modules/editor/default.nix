{ pkgs, ... }:

{

  # Variáveis e Pacotes necessários ao Editor
  environment = {
    variables.SUDO_EDITOR = "nvim";
    systemPackages = with pkgs; [
      meslo-lgs-nf
      neovim
      nil
      nix-index
      nix-zsh-completions
      nix-bash-completions
      ripgrep
    ];
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };

}
