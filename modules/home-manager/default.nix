{ config, hm, lib, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "wjjunyor";
  home.homeDirectory = "/home/wjjunyor";

  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  # Packages that should be installed to the user profile.
  home.packages = [
    pkgs.compose2nix
    pkgs.git
    pkgs.toot
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
      };
    };
    git = {
      enable = true;
      userName = "wjjunyor";
      userEmail = "wjjunyor@gmail.com";
      extraConfig = {
        init.defaultBranch = "main";
        safe.directory = "/etc/nixos";
      };
    };
    gitui.enable = true;
    gpg = {
      enable = true;
      # homedir = "${hm.config.xdg.dataHome}/gnupg";
      # home.file."${hm.config.programs.gpg.homedir}/.keep".text = "";
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      plugins = with pkgs.vimPlugins; [
          bufferline-nvim
          catppuccin-nvim
          comment-nvim
          cyberdream-nvim
          ctrlp
          elm-vim
          fugitive
          gitsigns-nvim
          gruvbox-material
          lualine-nvim
          mini-nvim
          neogit
          null-ls-nvim
          nvim-lspconfig
          nvim-surround
          nvim-tree-lua
          nvim-treesitter.withAllGrammars
          nvim-web-devicons
          plenary-nvim
          telescope-fzf-native-nvim
          telescope-nvim
          vim-elm-syntax     
      ];
    };
    zsh = {
      enable = true;
      dotDir = ".config/dotfiles/zsh";

      autocd = true;
      autosuggestion = {
        enable = true;
	highlight = "fg=cyan,bg=ff00ff,bold,underline";
      };
      enableCompletion = true;
      history = {
        expireDuplicatesFirst = true;
	ignoreAllDups = true;
        size = 10000;
	share = true;
      };
      
      initExtra = ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '';

      # initExtraBeforeCompInit = ''
      #   # p10k instant prompt
      #   P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
      #   [[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"
      # '';

      shellAliases = {
        cdnx = "cd /etc/nixos";
	cdhm = "cd ~/.config/home-manager";
	hm-upd = "home-manager switch --flake .";
        lsan = "ls -an";
        lsl = "ls -l";
        nx-upg = "sudo nixos-rebuild switch --upgrade";
        nx-upd = "sudo nixos-rebuild switch";
        ssh-pegasus = "ssh -p 22 walter_wcbrpar_com@pegasus.wcbrpar.com";
        ssh-galactica = "ssh -p 22 walter_wcbrpar_com@galactica.wcbrpar.com";
      };

      oh-my-zsh = {
        enable = true;
	plugins = [
	  "git"
	  "dirhistory"
	  "history"
	]; 
      };

    };
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    enableExtraSocket = true;
    extraConfig = ''
      enable-ssh-support
      allow-preset-passphrase
    '';
    # pinentryFlavor = pkgs.pinentry-tty;
    pinentryPackage = pkgs.pinentry-curses;
    # pinentryBinary = lib.mkDefault pinentryProgram;
    defaultCacheTtl = 34560000;
    defaultCacheTtlSsh = 34560000;
    maxCacheTtl = 34560000;
    maxCacheTtlSsh = 34560000;
  };

  # .dotfiles
  home.file = {
    # ".p10k.zsh" = {
    # enable = true;
    # source = .config/dotfiles/zsh/.p10k.zsh;
    # };
  };

  # Define the Home Manager environment variables.
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "zhs";
    LANG = "pt_BR.UTF-8";
  };

  # Enable custom fonts
  fonts.fontconfig.enable = true;
}

