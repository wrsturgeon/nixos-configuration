{ lib, pkgs }:
let

  activeFamily = "ayu";
  active = themeFamilies.${activeFamily}.light;

  removeHash = color: lib.removePrefix "#" color;
  quoteLua = value: "'${value}'";
  luaList = values: "{ ${lib.concatMapStringsSep ", " quoteLua values} }";
  shellQuote = lib.escapeShellArg;

  extractLuaColor =
    lines: name:
    let
      matches = builtins.filter (
        line: builtins.match "[[:space:]]*colors\\.${name} = '([^']+)'" line != null
      ) lines;
    in
    builtins.elemAt (builtins.match "[[:space:]]*colors\\.${name} = '([^']+)'" (builtins.elemAt matches 0)) 0;

  extractNeovimAyu =
    {
      package,
      variant ? "dark",
      mirage ? false,
    }:
    let
      source = builtins.readFile "${package}/lua/ayu/colors.lua";
      darkTail = builtins.elemAt (lib.splitString "  if vim.o.background == 'dark' then\n" source) 1;
      variantBlock =
        if variant == "dark" && !mirage then
          let
            nonMirageTail = builtins.elemAt (lib.splitString "    else\n" darkTail) 1;
          in
          builtins.elemAt (lib.splitString "    end\n  else\n" nonMirageTail) 0
        else if variant == "dark" && mirage then
          let
            mirageTail = builtins.elemAt (lib.splitString "    if mirage then\n" darkTail) 1;
          in
          builtins.elemAt (lib.splitString "    else\n" mirageTail) 0
        else if variant == "light" then
          let
            lightTail = builtins.elemAt (lib.splitString "  else\n    colors.accent = '#FFAA33'\n" source) 1;
          in
          "    colors.accent = '#FFAA33'\n" + builtins.elemAt (lib.splitString "  end\nend\n" lightTail) 0
        else
          throw "Unsupported neovim-ayu variant";
      color = extractLuaColor (lib.splitString "\n" variantBlock);
    in
    {
      accent = color "accent";
      background = color "bg";
      foreground = color "fg";
      ui = color "ui";
      tag = color "tag";
      func = color "func";
      entity = color "entity";
      string = color "string";
      regexp = color "regexp";
      markup = color "markup";
      keyword = color "keyword";
      special = color "special";
      comment = color "comment";
      constant = color "constant";
      operator = color "operator";
      error = color "error";
      line = color "line";
      panelBg = color "panel_bg";
      panelShadow = color "panel_shadow";
      panelBorder = color "panel_border";
      gutterNormal = color "gutter_normal";
      gutterActive = color "gutter_active";
      selectionBg = color "selection_bg";
      selectionInactive = color "selection_inactive";
      selectionBorder = color "selection_border";
      guideActive = color "guide_active";
      guideNormal = color "guide_normal";
      vcsAdded = color "vcs_added";
      vcsModified = color "vcs_modified";
      vcsRemoved = color "vcs_removed";
      vcsAddedBg = color "vcs_added_bg";
      vcsRemovedBg = color "vcs_removed_bg";
      fgIdle = color "fg_idle";
      warning = color "warning";
    };

  mkEverforestPalette =
    { mode }:
    let
      dark = {
        bgDim = "#1E2326";
        bg0 = "#272E33";
        bg1 = "#2E383C";
        bg2 = "#374145";
        bg3 = "#414B50";
        bg4 = "#495156";
        bg5 = "#4F5B58";
        bgVisual = "#4C3743";
        bgRed = "#493B40";
        bgYellow = "#45443C";
        bgGreen = "#3C4841";
        bgBlue = "#384B55";
        bgPurple = "#463F48";
        fg = "#D3C6AA";
        red = "#E67E80";
        orange = "#E69875";
        yellow = "#DBBC7F";
        green = "#A7C080";
        aqua = "#83C092";
        blue = "#7FBBB3";
        purple = "#D699B6";
        grey0 = "#7A8478";
        grey1 = "#859289";
        grey2 = "#9DA9A0";
      };
      light = {
        bgDim = "#F2EFDF";
        bg0 = "#FFFBEF";
        bg1 = "#F8F5E4";
        bg2 = "#F2EFDF";
        bg3 = "#EDEADA";
        bg4 = "#E8E5D5";
        bg5 = "#BEC5B2";
        bgVisual = "#F0F2D4";
        bgRed = "#FFE7DE";
        bgYellow = "#FEF2D5";
        bgGreen = "#F3F5D9";
        bgBlue = "#ECF5ED";
        bgPurple = "#FCECED";
        fg = "#5C6A72";
        red = "#F85552";
        orange = "#F57D26";
        yellow = "#DFA000";
        green = "#8DA101";
        aqua = "#35A77C";
        blue = "#3A94C5";
        purple = "#DF69BA";
        grey0 = "#A6B0A0";
        grey1 = "#939F91";
        grey2 = "#829181";
      };
      e = if mode == "dark" then dark else light;
    in
    {
      accent = e.yellow;
      background = e.bgDim;
      foreground = e.fg;
      ui = e.grey1;
      tag = e.blue;
      func = e.yellow;
      entity = e.blue;
      string = e.green;
      regexp = e.aqua;
      markup = e.red;
      keyword = e.orange;
      special = e.orange;
      comment = e.grey0;
      constant = e.purple;
      operator = e.orange;
      error = e.red;
      line = e.bg0;
      panelBg = e.bg0;
      panelShadow = e.bgDim;
      panelBorder = e.bg5;
      gutterNormal = e.grey0;
      gutterActive = e.grey2;
      selectionBg = e.bgVisual;
      selectionInactive = e.bg1;
      selectionBorder = e.bg2;
      guideActive = e.bg5;
      guideNormal = e.bg1;
      vcsAdded = e.green;
      vcsModified = e.blue;
      vcsRemoved = e.red;
      vcsAddedBg = e.bgGreen;
      vcsRemovedBg = e.bgRed;
      fgIdle = e.grey1;
      warning = e.orange;
    };

  terminalFromPalette =
    palette: with palette; {
      ansi = [
        background
        markup
        string
        accent
        tag
        constant
        regexp
        foreground
      ];
      brights = [
        ui
        error
        string
        accent
        tag
        constant
        regexp
        comment
      ];
    };

  mkTheme =
    {
      name,
      schemeName,
      flavour,
      mode,
      palette,
      terminal ? terminalFromPalette palette,
      editor,
      accents ? { },
    }:
    let
      defaultAccents = {
        primary = palette.tag;
        secondary = palette.special;
        tertiary = palette.string;
        surfaceContainer = palette.guideNormal;
      };
      finalAccents = defaultAccents // accents;
      clean = removeHash;
      ansi = map clean terminal.ansi;
      brights = map clean terminal.brights;
      c = builtins.mapAttrs (_: clean) {
        inherit (palette) background foreground;
        cursor = palette.func;
        selection = palette.selectionBg;
        inherit (finalAccents) surfaceContainer;
        inherit (finalAccents) primary;
        inherit (finalAccents) secondary;
        inherit (finalAccents) tertiary;
        black = builtins.elemAt ansi 0;
        red = builtins.elemAt ansi 1;
        green = builtins.elemAt ansi 2;
        yellow = builtins.elemAt ansi 3;
        blue = builtins.elemAt ansi 4;
        magenta = builtins.elemAt ansi 5;
        cyan = builtins.elemAt ansi 6;
        white = builtins.elemAt ansi 7;
        brightBlack = builtins.elemAt brights 0;
        brightRed = builtins.elemAt brights 1;
        brightGreen = builtins.elemAt brights 2;
        brightYellow = builtins.elemAt brights 3;
        brightBlue = builtins.elemAt brights 4;
        brightMagenta = builtins.elemAt brights 5;
        brightCyan = builtins.elemAt brights 6;
        brightWhite = builtins.elemAt brights 7;
      };
      caelestiaColors = {
        primary_paletteKeyColor = c.primary;
        secondary_paletteKeyColor = c.secondary;
        tertiary_paletteKeyColor = c.tertiary;
        neutral_paletteKeyColor = c.foreground;
        neutral_variant_paletteKeyColor = c.brightBlack;
        inherit (c) background;
        onBackground = c.foreground;
        surface = c.background;
        surfaceDim = c.background;
        surfaceBright = c.brightBlack;
        surfaceContainerLowest = c.black;
        surfaceContainerLow = c.background;
        inherit (c) surfaceContainer;
        surfaceContainerHigh = c.selection;
        surfaceContainerHighest = c.selection;
        onSurface = c.foreground;
        surfaceVariant = c.selection;
        onSurfaceVariant = c.brightWhite;
        inverseSurface = c.foreground;
        inverseOnSurface = c.background;
        outline = c.brightBlack;
        outlineVariant = c.selection;
        shadow = "000000";
        scrim = "000000";
        surfaceTint = c.primary;
        inherit (c) primary;
        onPrimary = c.background;
        primaryContainer = c.surfaceContainer;
        onPrimaryContainer = c.primary;
        inversePrimary = c.primary;
        primaryFixed = c.primary;
        primaryFixedDim = c.primary;
        onPrimaryFixed = c.background;
        onPrimaryFixedVariant = c.foreground;
        inherit (c) secondary;
        onSecondary = c.background;
        secondaryContainer = c.surfaceContainer;
        onSecondaryContainer = c.secondary;
        secondaryFixed = c.secondary;
        secondaryFixedDim = c.secondary;
        onSecondaryFixed = c.background;
        onSecondaryFixedVariant = c.foreground;
        inherit (c) tertiary;
        onTertiary = c.background;
        tertiaryContainer = c.surfaceContainer;
        onTertiaryContainer = c.tertiary;
        tertiaryFixed = c.tertiary;
        tertiaryFixedDim = c.tertiary;
        onTertiaryFixed = c.background;
        onTertiaryFixedVariant = c.foreground;
        error = c.brightRed;
        onError = c.background;
        errorContainer = c.selection;
        onErrorContainer = c.brightRed;
        term0 = c.black;
        term1 = c.red;
        term2 = c.green;
        term3 = c.yellow;
        term4 = c.blue;
        term5 = c.magenta;
        term6 = c.cyan;
        term7 = c.white;
        term8 = c.brightBlack;
        term9 = c.brightRed;
        term10 = c.brightGreen;
        term11 = c.brightYellow;
        term12 = c.brightBlue;
        term13 = c.brightMagenta;
        term14 = c.brightCyan;
        term15 = c.brightWhite;
        rosewater = c.foreground;
        flamingo = c.magenta;
        pink = c.brightMagenta;
        mauve = c.magenta;
        inherit (c) red;
        maroon = c.brightRed;
        peach = c.yellow;
        yellow = c.brightYellow;
        inherit (c) green;
        teal = c.cyan;
        sky = c.brightCyan;
        sapphire = c.brightBlue;
        blue = c.brightBlue;
        lavender = c.brightBlue;
        klink = c.brightBlue;
        klinkSelection = c.brightBlue;
        kvisited = c.magenta;
        kvisitedSelection = c.magenta;
        knegative = c.brightRed;
        knegativeSelection = c.brightRed;
        kneutral = c.yellow;
        kneutralSelection = c.yellow;
        kpositive = c.green;
        kpositiveSelection = c.green;
        text = c.foreground;
        subtext1 = c.brightWhite;
        subtext0 = c.brightBlack;
        overlay2 = c.brightBlack;
        overlay1 = c.selection;
        overlay0 = c.selection;
        surface2 = c.selection;
        surface1 = c.brightBlack;
        surface0 = c.background;
        base = c.background;
        mantle = c.background;
        crust = c.black;
        success = c.green;
        onSuccess = c.background;
        successContainer = c.selection;
        onSuccessContainer = c.brightGreen;
      };
      weztermScheme = {
        inherit (palette) foreground;
        inherit (palette) background;
        cursor_bg = palette.func;
        cursor_border = palette.func;
        cursor_fg = palette.background;
        selection_bg = palette.selectionBg;
        selection_fg = palette.foreground;
        scrollbar_thumb = palette.guideNormal;
        split = palette.panelBorder;
        inherit (terminal) ansi;
        inherit (terminal) brights;
      };
      luaAttrs = attrs: ''
        {
          foreground = ${quoteLua attrs.foreground},
          background = ${quoteLua attrs.background},
          cursor_bg = ${quoteLua attrs.cursor_bg},
          cursor_border = ${quoteLua attrs.cursor_border},
          cursor_fg = ${quoteLua attrs.cursor_fg},
          selection_bg = ${quoteLua attrs.selection_bg},
          selection_fg = ${quoteLua attrs.selection_fg},
          scrollbar_thumb = ${quoteLua attrs.scrollbar_thumb},
          split = ${quoteLua attrs.split},
          ansi = ${luaList attrs.ansi},
          brights = ${luaList attrs.brights},
        }
      '';
    in
    {
      inherit
        name
        schemeName
        flavour
        mode
        palette
        terminal
        editor
        weztermScheme
        ;
      caelestiaScheme = {
        name = schemeName;
        inherit flavour mode;
        variant = "content";
        colours = caelestiaColors;
      };
      caelestiaSchemeText =
        lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key} ${value}") caelestiaColors)
        + "\n";
      weztermLua = ''
        config.color_schemes = {
          [${quoteLua name}] = ${luaAttrs weztermScheme}
        }
        config.color_scheme = ${quoteLua name}
      '';
      weztermRuntimeLua = ''
        return {
          color_schemes = {
            [${quoteLua name}] = ${luaAttrs weztermScheme}
          },
          color_scheme = ${quoteLua name},
        }
      '';
    };

  ayuPalette =
    variant:
    extractNeovimAyu {
      package = pkgs.vimPlugins.neovim-ayu;
      inherit variant;
    };

  mkAyu =
    mode:
    mkTheme {
      name = "ayu-${mode}";
      schemeName = "ayu";
      flavour = "default";
      inherit mode;
      palette = ayuPalette mode;
      editor = {
        colorscheme = "ayu";
        package = pkgs.vimPlugins.neovim-ayu;
        nixvimAyu = false;
        lua = ''
          vim.o.background = ${quoteLua mode}
          vim.cmd.colorscheme('ayu')
        '';
      };
    };

  mkEverforest =
    mode:
    mkTheme {
      name = "everforest-hard-${mode}";
      schemeName = "everforest";
      flavour = "hard";
      inherit mode;
      palette = mkEverforestPalette { inherit mode; };
      editor = {
        colorscheme = "everforest";
        package = pkgs.vimPlugins.everforest;
        nixvimAyu = false;
        lua = ''
          vim.o.background = ${quoteLua mode}
          vim.g.everforest_background = 'hard'
          vim.cmd.colorscheme('everforest')
        '';
      };
    };

  themeFamilies = {
    ayu = {
      dark = mkAyu "dark";
      light = mkAyu "light";
    };
    everforest = {
      dark = mkEverforest "dark";
      light = mkEverforest "light";
    };
  };

  allThemes = [
    themeFamilies.ayu.dark
    themeFamilies.ayu.light
    themeFamilies.everforest.dark
    themeFamilies.everforest.light
  ];

  appTheme = themeFamilies.ayu.dark;

  themeCasePattern =
    theme: "${theme.schemeName}|${theme.flavour}|${theme.mode}|${theme.caelestiaScheme.variant}";

  runtimeThemeHook =
    let
      themeCases = lib.concatMapStringsSep "\n" (theme: ''
        ${shellQuote (themeCasePattern theme)}) ;;
      '') allThemes;
    in
    ''
      set -eu

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/theme"
      mkdir -p "$state_dir"
      theme_key="$SCHEME_NAME|$SCHEME_FLAVOUR|$SCHEME_MODE|$SCHEME_VARIANT"

      case "$theme_key" in
      ${themeCases}
        *)
          echo "No app runtime theme for $theme_key" >&2
          exit 1
          ;;
      esac

      cat > "$state_dir/nvim.lua" <<${shellQuote "EOF"}
      ${appTheme.editor.lua}
      EOF

      cat > "$state_dir/wezterm.lua" <<${shellQuote "EOF"}
      ${appTheme.weztermRuntimeLua}
      EOF

      if command -v wezterm >/dev/null 2>&1; then
        wezterm cli reload-configuration >/dev/null 2>&1 || :
      fi
    '';

  schemeFiles = pkgs.runCommand "caelestia-theme-schemes" { } ''
    mkdir -p "$out/ayu/default" "$out/everforest/hard"
    cp ${pkgs.writeText "ayu-dark.txt" themeFamilies.ayu.dark.caelestiaSchemeText} "$out/ayu/default/dark.txt"
    cp ${pkgs.writeText "ayu-light.txt" themeFamilies.ayu.light.caelestiaSchemeText} "$out/ayu/default/light.txt"
    cp ${pkgs.writeText "everforest-hard-dark.txt" themeFamilies.everforest.dark.caelestiaSchemeText} "$out/everforest/hard/dark.txt"
    cp ${pkgs.writeText "everforest-hard-light.txt" themeFamilies.everforest.light.caelestiaSchemeText} "$out/everforest/hard/light.txt"
  '';

  patchCaelestiaCli =
    package:
    package.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''

        for schemes in "$out"/lib/python*/site-packages/caelestia/data/schemes; do
          [ -d "$schemes" ] || continue
          cp -R ${schemeFiles}/ayu "$schemes/"
          mkdir -p "$schemes/everforest"
          cp -R ${schemeFiles}/everforest/hard "$schemes/everforest/"
        done
      '';
    });
in
{
  inherit
    active
    activeFamily
    allThemes
    appTheme
    extractNeovimAyu
    mkTheme
    patchCaelestiaCli
    runtimeThemeHook
    schemeFiles
    terminalFromPalette
    themeFamilies
    ;

  themes = themeFamilies;

  ayuCaelestiaScheme = themeFamilies.ayu.dark.caelestiaScheme;
  ayuWeztermLua = themeFamilies.ayu.dark.weztermLua;
}
