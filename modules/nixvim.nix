{ config, inputs, ... }:

let
  flakeConfig = config;
in
{
  config.local.nixos.modules.host =
    { lib, pkgs, ... }:
    let
      theme = flakeConfig.local.mkTheme pkgs;
      terminalTheme = theme.defaultTerminalTheme;
    in
    {
      imports = [ inputs.nixvim.nixosModules.nixvim ];

      programs.nixvim = {
        enable = true;
        dependencies.lean.enable = lib.mkForce false;
        diagnostic.settings.virtual_text = true;
        extraConfigLua = ''
          local theme_path = vim.fn.expand('~/.local/state/caelestia/theme/nvim.lua')
          local last_theme_mtime = nil

          local function theme_mtime(path)
            local uv = vim.uv or vim.loop
            local stat = uv.fs_stat(path)
            if stat == nil then
              return nil
            end
            return stat.mtime.sec .. ':' .. stat.mtime.nsec
          end

          local function apply_dynamic_theme(force)
            local mtime = theme_mtime(theme_path)
            if not force and mtime == last_theme_mtime then
              return
            end

            last_theme_mtime = mtime
            local ok = false
            if mtime ~= nil then
              ok = pcall(dofile, theme_path)
            end
            if not ok then
              ${terminalTheme.editor.lua}
            end
          end

          apply_dynamic_theme(true)

          vim.api.nvim_create_autocmd("FocusGained", {
            callback = function()
              apply_dynamic_theme(false)
            end,
          })

          local timer = (vim.uv or vim.loop).new_timer()
          timer:start(60000, 60000, vim.schedule_wrap(function()
            apply_dynamic_theme(false)
          end))
        '';
        extraPlugins =
          (lib.optional (terminalTheme.editor.package != null) terminalTheme.editor.package)
          ++ (with pkgs.vimPlugins; [ Coqtail ]);
        globals.mapleader = " ";
        nixpkgs.source = inputs.nixpkgs;
        opts = rec {
          autoread = true;
          background = terminalTheme.mode;
          backspace = [
            "eol"
            "indent"
            "start"
          ];
          belloff = "all";
          cursorcolumn = true;
          cursorline = true;
          cursorlineopt = "both";
          digraph = false;
          display = [ "uhex" ];
          endofline = true;
          errorbells = false;
          expandtab = true;
          fixendofline = true;
          foldenable = true;
          hlsearch = true;
          icon = true;
          ignorecase = true;
          incsearch = true;
          joinspaces = false;
          linebreak = false;
          list = true;
          modeline = false;
          mouse = "";
          mousehide = true;
          number = true;
          relativenumber = true;
          ruler = true;
          scrolloff = 8;
          shiftwidth = tabstop;
          sidescroll = scrolloff;
          sidescrolloff = scrolloff;
          smartcase = true;
          smarttab = true;
          softtabstop = tabstop;
          splitbelow = true;
          splitright = true;
          tabstop = 4;
          title = true;
          visualbell = false;
          wildmenu = true;
          wrap = false;
        };
        performance.byteCompileLua = {
          configs = true;
          enable = true;
          initLua = true;
          luaLib = true;
          nvimRuntime = true;
          plugins = true;
        };
        plugins = builtins.mapAttrs (_k: v: v // { enable = true; }) {
          cmp = {
            autoEnableSources = true;
            settings = {
              sources = [
                { name = "nvim_lsp"; }
                { name = "path"; }
                { name = "buffer"; }
              ];
              mapping = {
                "<C-Space>" = "cmp.mapping.complete()";
                "<C-d>" = "cmp.mapping.scroll_docs(-4)";
                "<C-e>" = "cmp.mapping.close()";
                "<C-f>" = "cmp.mapping.scroll_docs(4)";
                "<CR>" = "cmp.mapping.confirm({ select = true })";
                "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
                "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
              };
            };
          };
          gitsigns = { };
          lean.package = pkgs.vimPlugins.lean-nvim;
          lsp = {
            inlayHints = true;
            keymaps = {
              silent = true;
              diagnostic = {
                # Navigate in diagnostics
                "<leader>k" = "goto_prev";
                "<leader>j" = "goto_next";
              };

              lspBuf = {
                gd = "definition";
                gD = "references";
                gt = "type_definition";
                gi = "implementation";
                K = "hover";
                "<F2>" = "rename";
              };
            };
            servers = builtins.mapAttrs (_k: v: { enable = true; } // v) {
              clangd = { };
              hls.installGhc = false;
              hyprls = { };
              lua_ls.settings.diagnostics.globals = [ "vim" ];
              nil_ls = { };
              nixd = { };
              ocamllsp.package = null;
              ruff = { };
              rust_analyzer = {
                # cargoPackage = rust-toolchain;
                installCargo = false;
                installRustc = false;
                # package = rust-toolchain;
                settings = {
                  cargo = {
                    features = "all";
                    allTargets = true;
                    # loadOutDirsFromCheck = true;
                    # runBuildScripts = true;
                  };
                  check = {
                    features = "all";
                    allTargets = true;
                    command = "clippy";
                    extraArgs = [
                      "--"
                      "--no-deps"
                      # enable the kitchen sink:
                      "-Wclippy::cargo"
                      "-Wclippy::complexity"
                      "-Dclippy::correctness"
                      "-Wclippy::perf"
                      "-Wclippy::pedantic"
                      "-Wclippy::style"
                      "-Wclippy::suspicious"
                      # then disable selectively:
                      "-Aclippy::blanket-clippy-restriction-lints"
                      "-Aclippy::field-scoped-visibility-modifiers"
                      "-Aclippy::from-iter-instead-of-collect"
                      "-Aclippy::implicit-return"
                      "-Aclippy::inline-always"
                      "-Aclippy::map-err-ignore"
                      "-Aclippy::min-ident-chars"
                      "-Aclippy::mod-module-files"
                      "-Aclippy::needless-borrowed-reference"
                      "-Aclippy::pub-with-shorthand"
                      "-Aclippy::question-mark-used"
                      "-Aclippy::ref-patterns"
                      "-Aclippy::semicolon-if-nothing-returned"
                      "-Aclippy::semicolon-outside-block"
                      "-Aclippy::separated-literal-suffix"
                      "-Aclippy::shadow-reuse"
                      "-Aclippy::shadow-same"
                      "-Aclippy::shadow-unrelated"
                      "-Aclippy::single-char-lifetime-names"
                      "-Aclippy::type-complexity"
                      "-Aclippy::wildcard-enum-match-arm"
                    ];
                  };
                  checkOnSave = true;
                  procMacro.enable = true;
                };
              };
              taplo = { };
            };
          };
          lsp-format.lspServersToEnable = "all";
          # lualine.settings.options.globalstatus = true;
          # From <https://github.com/GaetanLepage/nix-config/blob/81a6c06fa6fc04a0436a55be344609418f4c4fd9/modules/home/core/programs/neovim/_plugins/telescope.nix>:
          telescope = {

            keymaps = {
              # Find files using Telescope command-line sugar.
              "<leader>fb" = "buffers";
              "<leader>fd" = "lsp_definitions";
              "<leader>ff" = "git_files"; # "find_files";
              "<leader>fg" = "live_grep";
              "<leader>fh" = "help_tags";
              "<leader>fl" = "loogle";
              "<leader>fm" = "man_pages";
              "<leader>fo" = "oldfiles";
              "<leader>fr" = "lsp_references";

              # FZF like bindings
              "<C-p>" = "git_files";
              "<leader>p" = "oldfiles";
              "<C-f>" = "live_grep";
            };

            settings.defaults = {
              file_ignore_patterns = [
                "^.direnv/"
                "^.git/"
                "^.mypy_cache/"
                "^__pycache__/"
                "^data/"
                "^output/"
                "^result/"
                "^target/"
                "%.lock"
              ];
              set_env.COLORTERM = "truecolor";
            };
          };
          treesitter.settings = {
            ensure_installed = "all";
            highlight.enable = true;
            ignore_install = [
              "ipkg"
              "norg"
            ];
            incremental_selection.enable = true;
            indent.enable = true;
          };
          web-devicons = { };
        };
        version.enableNixpkgsReleaseCheck = false;
        viAlias = true;
        vimAlias = true;
      };
    };
}
