{ lib, pkgs }:
let
  ayuSource = builtins.readFile "${pkgs.vimPlugins.neovim-ayu}/lua/ayu/colors.lua";
  ayuDarkBlock =
    let
      darkTail = builtins.elemAt (lib.splitString "  if vim.o.background == 'dark' then\n" ayuSource) 1;
      nonMirageTail = builtins.elemAt (lib.splitString "    else\n" darkTail) 1;
    in
    builtins.elemAt (lib.splitString "    end\n  else\n" nonMirageTail) 0;
  ayuDarkPalette =
    let
      lines = lib.splitString "\n" ayuDarkBlock;
      color =
        name:
        let
          matches = builtins.filter (
            line: builtins.match "[[:space:]]*colors\\.${name} = '([^']+)'" line != null
          ) lines;
        in
        builtins.elemAt (builtins.match "[[:space:]]*colors\\.${name} = '([^']+)'" (builtins.elemAt matches 0)) 0;
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
      comment = color "comment";
      constant = color "constant";
      error = color "error";
      line = color "line";
      panelBg = color "panel_bg";
      selectionBg = color "selection_bg";
      guideNormal = color "guide_normal";
    };
  neovimAyuToCaelestia =
    {
      name,
      flavor ? "default",
      mode ? "dark",
      variant ? "content",
      palette,
    }:
    let
      clean = color: lib.removePrefix "#" color;
      p = builtins.mapAttrs (_: clean) palette;
      ansi = with p; [
        background
        markup
        string
        accent
        tag
        constant
        regexp
        foreground
      ];
      brights = with p; [
        ui
        error
        string
        accent
        tag
        constant
        regexp
        comment
      ];
      c = builtins.mapAttrs (_: clean) {
        inherit (palette) background;
        inherit (palette) foreground;
        cursor = palette.func;
        selection = palette.selectionBg;
        surfaceContainer = palette.guideNormal;
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
      colors = {
        primary_paletteKeyColor = c.blue;
        secondary_paletteKeyColor = c.cyan;
        tertiary_paletteKeyColor = c.yellow;
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
        surfaceTint = c.blue;
        primary = c.blue;
        onPrimary = c.background;
        primaryContainer = c.selection;
        onPrimaryContainer = c.brightBlue;
        inversePrimary = c.brightBlue;
        primaryFixed = c.brightBlue;
        primaryFixedDim = c.blue;
        onPrimaryFixed = c.background;
        onPrimaryFixedVariant = c.foreground;
        secondary = c.cyan;
        onSecondary = c.background;
        secondaryContainer = c.selection;
        onSecondaryContainer = c.brightCyan;
        secondaryFixed = c.brightCyan;
        secondaryFixedDim = c.cyan;
        onSecondaryFixed = c.background;
        onSecondaryFixedVariant = c.foreground;
        tertiary = c.yellow;
        onTertiary = c.background;
        tertiaryContainer = c.selection;
        onTertiaryContainer = c.brightYellow;
        tertiaryFixed = c.brightYellow;
        tertiaryFixedDim = c.yellow;
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
        sapphire = c.blue;
        blue = c.brightBlue;
        lavender = c.brightBlue;
        klink = c.blue;
        klinkSelection = c.blue;
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
    in
    {
      inherit name mode variant;
      flavour = flavor;
      colours = colors;
    };
in
{
  ayuCaelestiaScheme = neovimAyuToCaelestia {
    name = "ayu";
    palette = ayuDarkPalette;
  };
}
