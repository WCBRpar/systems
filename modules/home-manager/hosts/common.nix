{pkgs, ...}: {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.

  home = {
    packages = with pkgs; [
      bat
      compose2nix
      eza
      git
      magic-wormhole
      meslo-lgs-nf
      nil
      parallel
      shell-genie
      toot
      zsh-powerlevel10k
    ];

    #  Arquivos .dotfiles
    file = {
      ".p10k.zsh" = {
        enable = true;
        source = ~/.config/home-manager/dotfiles/.zsh/.p10k.zsh;
        target = ".dotfiles/.p10k.zsh";
        executable = true;
      };
      ".zshrc" = {
        enable = true;
        source = ~/.config/home-manager/dotfiles/.zsh/.zshrc;
        target = ".dotfiles/.zsh/.zshrc";
        executable = true;
      };
    };

    # Define the Home Manager environment variables.
    sessionVariables = {
      SUDO_EDITOR = "nvim";
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "zsh";
      LANG = "pt_BR.UTF-8";
    };

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can upjardate Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "24.11";
  };

  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  # Let Home Manager install and manage itself.
  programs = {
    home-manager = {
      enable = true;
    };

    direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
      };
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
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

    gitui = {
      enable = true;
    };

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
      extraConfig = ''
          colorscheme cyberdream
          set list listchars=tab:→\ ,nbsp:␣,trail:•,precedes:«,extends:»
          set et sts=0 ts=2 sw=2
          set nu rnu cc=80 so=6 siso=15
          set ls=3 stal=0 sb spr nowrap
          set scl=yes:1 shm+=sI
          let g:loaded_netrw=1
          let g:loaded_netrwPlugin=1
          nnoremap <C-N>     <cmd>NvimTreeToggle<CR>
          nnoremap <space>fd <cmd>Telescope find_files<CR>
          nnoremap <space>fg <cmd>Telescope grep_string<CR>
          nnoremap <space>ng <cmd>Neogit<CR>
          nnoremap <C-H> <C-W><C-H>
          nnoremap <C-J> <C-W><C-J>
          nnoremap <C-K> <C-W><C-K>
          nnoremap <C-L> <C-W><C-L>
          nnoremap <C-W>\ <cmd>vsplit<CR>
          nnoremap <C-W>- <cmd>split<CR>
          noremap <Esc> <C-\><C-n>
          nnoremap <A-,> <Cmd>BufferLineCyclePrev<CR>
          nnoremap <A-.> <Cmd>BufferLineCycleNext<CR>
          nnoremap <A-<> <Cmd>BufferLineMovePrev<CR>
          nnoremap <A->> <Cmd>BufferLineMoveNext<CR>
          nnoremap <A-x> <Cmd>bdelete<CR>
          nnoremap <A-X> <Cmd>bdelete!<CR>

          set ruler                   " Show the ruler
          set rulerformat=%30(%=\:b%n%y%m%r%w\ %l,%c%V\ %P%) " A ruler on steroids
          set showcmd                 " Show partial commands in status line and
          " Selected characters/lines in visual mode
          set laststatus=2

          " Broken down into easily includeable segments
          set statusline=%<%f\                     " Filename
          set statusline+=%w%h%m%r                 " Options
          set statusline+=%{fugitive#statusline()} " Git Hotness
          set statusline+=\ [%{&ff}/%Y]            " Filetype
          set statusline+=\ [%{getcwd()}]          " Current dir
          set statusline+=%=%-14.(%l,%c%V%)\ %p%%  " Right aligned file nav info

          set tabpagemax=15               " Only show 15 tabs
          set showmode                    " Display the current mode
          set cursorline                  " Highlight current line
          set backspace=indent,eol,start  " Backspace for dummies
          set showmatch                   " Show matching brackets/parenthesis
          set incsearch                   " Find as you type search
          set hlsearch                    " Highlight search terms
          set gdefault                    " makes the s% flag global by default. Use /g to turn the global option off.
          set ignorecase                  " Case insensitive search
          set smartcase                   " Case sensitive when uc present
          set wildmenu                    " Show list instead of just completing
          set wildmode=list:longest,full  " Command <Tab> completion, list matches, then longest common part, then all.
          set whichwrap=b,s,h,l,<,>,[,]   " Backspace and cursor keys wrap too
          set scrolljump=5                " Lines to scroll when cursor leaves screen
          set scrolloff=3                 " Minimum lines to keep above and below cursor
          set list
          set listchars=tab:›\ ,trail:•,extends:#,nbsp:. " Highlight problematic whitespace
          set splitright                  " split vertical splits to the right
          set splitbelow                  " split horizontal splits to the bottom

          autocmd TermOpen * setlocal nonumber norelativenumber
          autocmd TermOpen * startinsert
          lua << EOF
            require("bufferline").setup()
            require("Comment").setup()
            require("gitsigns").setup()
            require("neogit").setup()
            require("nvim-surround").setup()
            require("nvim-tree").setup()
            require("nvim-treesitter.configs").setup({
              highlight = { enable = true }
            })
            require("telescope").load_extension("fzf")

            local lspconfig = require('lspconfig')

            vim.api.nvim_create_autocmd("BufReadPost", {
              pattern = {"*"},
              callback = function()
                if vim.fn.line("'\"") > 1 and vim.fn.line("'\"") <= vim.fn.line("$") then
                  vim.api.nvim_exec("normal! g'\"",false)
                end
              end
            })

            vim.api.nvim_create_autocmd('LspAttach', {
              group = vim.api.nvim_create_augroup('UserLspConfig', {}),
              callback = function(ev)
                -- Enable completion triggered by <c-x><c-o>
                vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

                -- Buffer local mappings.
                -- See `:help vim.lsp.*` for documentation on any of the below functions
                local opts = { buffer = ev.buf }
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
                vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
                vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
                vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
                vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
                vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
              end,
            })
          lspconfig.nil_ls.setup{}
          lspconfig.emls.setup{}

          local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
          local null = require("null-ls")
          null.setup({
            sources = { null.builtins.formatting.alejandra },
            on_attach = function(client, bufnr)
              if client.supports_method("textDocument/formatting") then
                vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
                vim.api.nvim_create_autocmd("BufWritePre", {
                  group = augroup,
                  buffer = bufnr,
                  callback = function()
                    vim.lsp.buf.format({
                      bufnr = bufnr,
                      filter = function(c)
                        return c.name == "null-ls"
                      end,
                    })
                  end,
                })
              end
            end,
          })
          local toggle_formatters = function()
            null.toggle({ methods = null.methods.FORMATTING })
          end
          vim.api.nvim_create_user_command("ToggleFormatters", toggle_formatters, {})
        EOF
      '';
    };

    zsh = {
      enable = true;
      dotDir = ".dotfiles";

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
      initContent = ''
        # Carrega o Powerlevel10k
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '';
      shellAliases = {
        c = "clear";
        cat = "bat --paging=never --style=plain";
        cddv = " cd /W/Shared/RED/DEV/";
        cdnx = "cd /etc/nixos";
        cdhm = "cd ~/.config/home-manager";
        cp = "cp -riv";
        hm-upd = "home-manager switch --flake .";
        ls = "exa -a --icons";
        lsan = "ls -an";
        lsal = "ls -al";
        mv = "mv -iv";
        mkdir = "mkdir -vp";
        nx-upg = "sudo nixos-rebuild switch --upgrade --use-remote-sudo --build-host wjjunyor@yashuman.wcbrpar.com";
        nx-upd = "sudo nixos-rebuild switch --use-remote-sudo --build-host wjjunyor@yashuman.wcbrpar.com";
        vps-galactica = "vpsfreectl remote_console 27116";
        vps-pegasus = "vpsfreectl remote_console 27447";
        vps-yashuman = "vpsfreectl remote_console 27181";
        rm = "rm -rifv";
        tree = "exa --tree --icons";
        ssh-galactica = "ssh -p 22 wjjunyor@galactica.wcbrpar.com";
        ssh-pegasus = "ssh -p 22 wjjunyor@pegasus.wcbrpar.com";
        ssh-yashuman = "ssh -p 22 wjjunyor@yashuman.wcbrpar.com";
      };

      oh-my-zsh = {
        enable = true;
        plugins = [
          "dirhistory"
          "fzf-zsh"
          "git"
          "history"
          "sudo"
          "web-search"
        ];
        theme = "cyberdream";
      };
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      enableExtraSocket = true;
      extraConfig = ''
        enable-ssh-support
        allow-preset-passphrase
      '';
      # pinentryFlavor = pkgs.pinentry-tty;
      pinentry.package = pkgs.pinentry-curses;
      # pinentryBinary = lib.mkDefault pinentryProgram;
      defaultCacheTtl = 34560000;
      defaultCacheTtlSsh = 34560000;
      maxCacheTtl = 34560000;
      maxCacheTtlSsh = 34560000;
    };
  };

  # Enable custom fonts
  fonts = {
    fontconfig = {
      enable = true;
    };
  };
}
