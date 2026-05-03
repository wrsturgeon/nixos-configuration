{ lib, pkgs }:
let
  removeHash = color: lib.removePrefix "#" color;
  quoteLua = value: "'${value}'";
  luaList = values: "{ ${lib.concatMapStringsSep ", " quoteLua values} }";

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

  terminalFromNeovimAyu =
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
      palette,
      terminal ? terminalFromNeovimAyu palette,
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
        palette
        terminal
        weztermScheme
        ;
      caelestiaScheme = {
        inherit name;
        flavour = "default";
        mode = "dark";
        variant = "content";
        colours = caelestiaColors;
      };
      weztermLua = ''
        config.color_schemes = {
          [${quoteLua name}] = ${luaAttrs weztermScheme}
        }
        config.color_scheme = ${quoteLua name}
      '';
    };

  ayuDarkPalette = extractNeovimAyu { package = pkgs.vimPlugins.neovim-ayu; };
  themes = {
    ayu = mkTheme {
      name = "neovim-ayu";
      palette = ayuDarkPalette;
    };
  };
  active = themes.ayu;
in
{
  inherit
    extractNeovimAyu
    terminalFromNeovimAyu
    mkTheme
    themes
    active
    ;

  ayuCaelestiaScheme = themes.ayu.caelestiaScheme;
  ayuWeztermLua = themes.ayu.weztermLua;
}
