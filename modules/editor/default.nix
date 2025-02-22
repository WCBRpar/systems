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

# environment.systemPackages = with pkgs.unstable; [alejandra nil ripgrep];
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
    configure = {
      customRC = ''
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
      packages.myVimPackage = with pkgs.vimPlugins; {
        # loaded on launch
        start = [
          bufferline-nvim
          catppuccin-nvim
          comment-nvim
          cyberdream-nvim
          ctrlp
          elm-vim
          fugitive
          gitsigns-nvim
          lualine-nvim
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
        # manually loadable by calling `:packadd $plugin-name`
        opt = [];
      };
    };
  };

}
