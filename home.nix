args@{
  default-font,
  default-serif-font,
  default-monospace-font,
  home,
  inputs,
  lib,
  location,
  pkgs,
  stateVersion,
  username,
  ...
}:
let

  caelestia-wallpaper = inputs.desktop-background;
  theme = import ./theme.nix {
    caelestiaCliSrc = inputs.caelestia-shell.inputs.caelestia-cli.outPath;
    inherit lib pkgs;
    inherit (inputs) onedark zed-one;
  };
  desktopTheme = theme.active;
  desktopThemes = theme.themeFamilies.${theme.activeFamily};
  terminalTheme = theme.defaultTerminalTheme;
  terminalThemeEditorLua = pkgs.writeText "caelestia-terminal-theme-nvim.lua" terminalTheme.editor.lua;
  terminalThemeWeztermLua = pkgs.writeText "caelestia-terminal-theme-wezterm.lua" terminalTheme.weztermRuntimeLua;
  caelestiaResourceActiveWindow = ./caelestia-resource-active-window.qml;
  caelestiaWorkspaces = ./caelestia-workspaces.qml;
  caelestiaWorkspace = ./caelestia-workspace.qml;
  caelestiaActiveIndicator = ./caelestia-active-indicator.qml;
  caelestiaShellWithResources =
    inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli.overrideAttrs
      (old: {
        postPatch = (old.postPatch or "") + ''
          grep -q 'roleValue: "activeWindow"' modules/bar/Bar.qml
          grep -q 'sourceComponent: ActiveWindow' modules/bar/Bar.qml
          test -f modules/bar/components/ActiveWindow.qml
          grep -q 'model: Config.bar.workspaces.shown' modules/bar/components/workspaces/Workspaces.qml
          grep -q 'const label = Config.bar.workspaces.label || displayName;' modules/bar/components/workspaces/Workspace.qml
          grep -q 'i % Config.bar.workspaces.shown' modules/bar/components/workspaces/ActiveIndicator.qml
          cp ${caelestiaResourceActiveWindow} modules/bar/components/ActiveWindow.qml
          cp ${caelestiaWorkspaces} modules/bar/components/workspaces/Workspaces.qml
          cp ${caelestiaWorkspace} modules/bar/components/workspaces/Workspace.qml
          cp ${caelestiaActiveIndicator} modules/bar/components/workspaces/ActiveIndicator.qml
        '';
      });
  logseqCss = pkgs.writeText "logseq-custom.css" ''
    :root {
      color-scheme: light;
    }

    ${desktopThemes.light.logseqCss}

    @media (prefers-color-scheme: dark) {
    :root {
      color-scheme: dark;
    }

    ${desktopThemes.dark.logseqCss}
    }

    :root {
      --ls-font-family: "${default-font}", Inter, sans-serif;
    }

    .inline,
    .block-editor {
      font-family: "${default-font}", Inter, sans-serif;
    }

    .CodeMirror {
      font-family: "${default-monospace-font}", monospace;
    }

    .left-sidebar-inner {
      font-family: "${default-font}", Inter, sans-serif;
    }

    h1.title,
    h1.title input,
    .title {
      font-family: "${default-serif-font}", "Source Serif 4", serif;
      font-weight: 600;
    }

    :not(pre)>code {
      font-family: "${default-monospace-font}", monospace;
    }
  '';
in
{
  gtk = {
    enable = true;
    font.name = default-font;
  };
  home = {
    inherit stateVersion username;
    packages = with pkgs; [
      bash-language-server
      discord
      element-desktop # matrix
      haskell-language-server
      libreoffice-qt6
      logseq
      luajitPackages.lua-lsp
      mailspring
      nixd
      ocamlPackages.ocaml-lsp
      pyright
      rust-analyzer
      spotify
      super-productivity
      tor-browser
      wayneko
      yaml-language-server
      zls
      zulip
    ];
    file = {
      ".agents/skills/enlightenment.md" = {
        force = true;
        text = builtins.readFile ./worse-is-better-monologue.md;
      };
      ".local/state/caelestia/wallpaper/current" = {
        force = true;
        source = caelestia-wallpaper;
      };
      ".local/state/caelestia/wallpaper/path.txt" = {
        force = true;
        text = "${caelestia-wallpaper}\n";
      };
      ".local/state/caelestia/scheme.json" = {
        force = true;
        text = builtins.toJSON desktopTheme.caelestiaScheme;
      };
    };
    activation.writeLogseqCustomCss = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      target=${lib.escapeShellArg "${home}/Logseq/logseq/custom.css"}
      if [ -L "$target" ]; then
        rm -f "$target"
      fi
      install -Dm0644 ${logseqCss} "$target"
      chmod u+w "$target"
    '';
    activation.initializeCaelestiaTerminalTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      state_dir=${lib.escapeShellArg "${home}/.local/state/caelestia/theme"}
      mkdir -p "$state_dir"

      for theme_file in "$state_dir/nvim.lua" "$state_dir/wezterm.lua"; do
        if [ -L "$theme_file" ]; then
          rm -f "$theme_file"
        fi
      done

      ${
        if theme.terminalTheme == null then
          ''
            if [ ! -e "$state_dir/nvim.lua" ]; then
              cat ${terminalThemeEditorLua} > "$state_dir/nvim.lua"
            fi

            if [ ! -e "$state_dir/wezterm.lua" ]; then
              cat ${terminalThemeWeztermLua} > "$state_dir/wezterm.lua"
            fi
          ''
        else
          ''
            cat ${terminalThemeEditorLua} > "$state_dir/nvim.lua"

            cat ${terminalThemeWeztermLua} > "$state_dir/wezterm.lua"
          ''
      }
    '';
    pointerCursor = {
      enable = true;
      hyprcursor.enable = true;
      package = pkgs.rose-pine-hyprcursor;
      name = "cursor";
    };
    homeDirectory = home;
  };

  imports = [
    ./pi/home-manager.nix
    inputs.caelestia-shell.homeManagerModules.default
    inputs.zen-browser.homeModules.twilight
  ];

  programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    btop = { };
    codex = {
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
      settings = { };
      skills.enlightenment = builtins.readFile ./worse-is-better-monologue.md;
    };
    gh = {
      gitCredentialHelper.enable = false;
      settings = {
        git_protocol = "https";
        prompt = "enabled";
      };
    };
    home-manager = { };
    htop = { };
    caelestia = {
      package = caelestiaShellWithResources;
      cli.enable = true;
      cli.package =
        theme.patchCaelestiaCli
          inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.caelestia-cli;
      cli.settings.theme = {
        enableTerm = false;
        postHook = theme.runtimeThemeHook;
      };
      settings = {
        # https://github.com/caelestia-dots/shell#example-configuration
        appearance = {
          anim.durations.scale = 0.0; # 0.5;
          deformScale = 0.5;
          font.family = {
            clock = "${default-monospace-font} Light";
            mono = default-monospace-font;
            sans = default-font;
          };
          rounding.scale = 0.5;
        };
        bar = {
          activeWindow.showOnHover = false;
          clock.showDate = true;
          status = {
            showAudio = true;
            showKbLayout = true;
            showMicrophone = true;
          };
        };
        border = {
          rounding = 8;
          thickness = 0;
        };
        dashboard.resourceUpdateInterval = 500;
        launcher = {
          showOnHover = true;
          vimKeybinds = true;
        };
        services = {
          useFahrenheit = true;
          useTwelveHourClock = false;
          inherit (location) weatherLocation;
        };
        session.vimKeybinds = true;
      };
    };
    opencode = {
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        agent.build = {
          mode = "primary";
          tools."*" = true;
        };
        permission = {
          bash = "allow";
          edit = "allow";
          glob = "allow";
          grep = "allow";
          list = "allow";
          lsp = "allow";
          question = "allow";
          read = "allow";
          skill = "allow";
          todoread = "allow";
          todowrite = "allow";
          webfetch = "allow";
          websearch = "allow";
        };
      };
      tui.theme = "system";
    };
    wezterm = {
      enableBashIntegration = true;
      enableZshIntegration = true;
      extraConfig = ''
        local wezterm = require 'wezterm'
        local config = wezterm.config_builder()

        local state_home = os.getenv('XDG_STATE_HOME') or (wezterm.home_dir .. '/.local/state')
        local theme_path = state_home .. '/caelestia/theme/wezterm.lua'
        local ok, theme = pcall(dofile, theme_path)

        if ok and type(theme) == 'table' then
          for key, value in pairs(theme) do
            config[key] = value
          end
        else
          ${terminalTheme.weztermLua}
        end

        config.font = wezterm.font('${default-monospace-font}')

        ${builtins.readFile ./wezterm.lua}

        local function sorted_table_keys(t)
          local keys = {}
          for key, _ in pairs(t) do
            table.insert(keys, key)
          end
          table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
          end)
          return keys
        end

        local function color_key_path(prefix, key)
          if type(key) == 'number' then
            return prefix .. '[' .. key .. ']'
          end
          if prefix == "" then
            return tostring(key)
          end
          return prefix .. '.' .. tostring(key)
        end

        local function is_indexed_key(prefix, key)
          return prefix == "" and key == 'indexed'
        end

        local function first_indexed_color_keys(t)
          local filtered = {}
          for key, _ in pairs(t) do
            if type(key) == 'number' and key >= 16 and key <= 31 then
              table.insert(filtered, key)
            end
          end
          table.sort(filtered)
          return filtered
        end

        local function collect_missing_default_color_keys(defaults, theme, prefix, missing)
          local keys = sorted_table_keys(defaults)
          if prefix == 'indexed' then
            keys = first_indexed_color_keys(defaults)
          end

          for _, key in ipairs(keys) do
            local path = color_key_path(prefix, key)
            local default_value = defaults[key]
            local theme_value = theme[key]

            if theme_value == nil then
              table.insert(missing, path)
            elseif type(default_value) == 'table' then
              if type(theme_value) ~= 'table' then
                table.insert(missing, path .. '.*')
              else
                if is_indexed_key(prefix, key) then
                  collect_missing_default_color_keys(default_value, theme_value, 'indexed', missing)
                else
                  collect_missing_default_color_keys(default_value, theme_value, path, missing)
                end
              end
            end
          end
        end

        local function collect_extraneous_color_keys(defaults, theme, prefix, extraneous)
          local keys = sorted_table_keys(theme)
          if prefix == 'indexed' then
            keys = first_indexed_color_keys(theme)
          end

          for _, key in ipairs(keys) do
            local path = color_key_path(prefix, key)
            local default_value = defaults[key]
            local theme_value = theme[key]

            if default_value == nil then
              table.insert(extraneous, path)
            elseif type(theme_value) == 'table' then
              if type(default_value) ~= 'table' then
                table.insert(extraneous, path .. '.*')
              else
                if is_indexed_key(prefix, key) then
                  collect_extraneous_color_keys(default_value, theme_value, 'indexed', extraneous)
                else
                  collect_extraneous_color_keys(default_value, theme_value, path, extraneous)
                end
              end
            end
          end
        end

        local function assert_selected_color_scheme_is_explicit()
          local scheme_name = config.color_scheme
          if scheme_name == nil then
            error('No WezTerm color_scheme is selected', 0)
          end

          local schemes = config.color_schemes or {}
          local scheme = schemes[scheme_name]
          if type(scheme) ~= 'table' then
            error('Selected WezTerm color_scheme is not defined locally: ' .. tostring(scheme_name), 0)
          end

          local defaults = wezterm.color.get_default_colors()
          local missing = {}
          collect_missing_default_color_keys(defaults, scheme, "", missing)
          local extraneous = {}
          collect_extraneous_color_keys(defaults, scheme, "", extraneous)

          local problems = {}
          if #missing > 0 then
            table.insert(
              problems,
              'missing explicit WezTerm color setting(s) present in wezterm.color.get_default_colors():\n  - '
                .. table.concat(missing, '\n  - ')
            )
          end
          if #extraneous > 0 then
            table.insert(
              problems,
              'extraneous WezTerm color setting(s) absent from wezterm.color.get_default_colors():\n  - '
                .. table.concat(extraneous, '\n  - ')
            )
          end

          if #problems > 0 then
            error('Theme "' .. scheme_name .. '" has invalid WezTerm color setting coverage:\n\n' .. table.concat(problems, '\n\n'), 0)
          end
        end

        assert_selected_color_scheme_is_explicit()

        return config
      '';
    };
    zen-browser.setAsDefaultBrowser = true;
  };

  services = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    hyprpolkitagent = { };
    hyprsunset = { };
    poweralertd = { };
    spotifyd.settings.global.bitrate = 320;
  };

  wayland.windowManager.hyprland = {
    configType = "lua";
    enable = true;
    package = null;
    portalPackage = null;
    settings = import ./hyprland.nix args;
    systemd.variables = [ "--all" ];
  };
}
