{ pkgs, ... }:

{

  #Configurçoes do Shell
  
  programs.bash.completion.enable = true;
  programs.nix-index.enableBashIntegration = true;

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

