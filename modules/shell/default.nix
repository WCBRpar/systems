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

    shellAliases = {
      lsan = "ls -an";
      lsl = "ls -l";
      nixos-upg = "sudo nixos-rebuild switch --upgrade";
      nixos-upd = "sudo nixos-rebuild switch";
      ssh-pegasus = "ssh -p 22 walter_wcbrpar_com@pegasus.wcbrpar.com";
      ssh-galactic = "ssh -p 22 walter_wcbrpar_com@galactica.wcbrpar.com";
    };
    
    setOptions = [
      "AUTO_CD"
    ];
    
    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';

    ohMyZsh = {
      enable = true;
      # theme = "powerlevel10k/powerlevel10k";
      plugins = ["git" "dirhistory" "history"];
    };

  };

}

