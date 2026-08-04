{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local) default-monospace-font username;
in
{
  config.local.home-manager.users.${username} =
    { pkgs, ... }:
    let
      theme = flakeConfig.local.mkTheme pkgs;
      terminalTheme = theme.defaultTerminalTheme;
    in
    {
      programs.wezterm = {
        enable = true;
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

          ${builtins.readFile ../wezterm.lua}

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
    };
}
