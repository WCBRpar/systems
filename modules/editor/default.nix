{ pkgs, ... }:

{

  # Variáveis e Pacotes necessários ao Editor
  environment = {
    variables.SUDO_EDITOR = "nvim";
    systemPackages = with pkgs; [
      meslo-lgs-nf
      nil
      nix-zsh-completions
      nix-bash-completions
      ripgrep
      meslo-lgs-nf
    ];
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };

}
