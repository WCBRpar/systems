{ pkgs, ... }: 

{

  # Pacotes e variáveis necessárias ao sistema
  environment.systemPackages = with pkgs; [
    git
    gh
    nixpkgs-fmt
    neovim
    npins
    unzip
  ];
  
  # Configurações do shell padrão
  users.defaultUserShell = pkgs.zsh;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    histSize = 10000;
  };


}
