{
  caelestiaCliSrc,
  lib,
  pkgs,
  zed-one,
}:
let

  activeFamily = "zed";
  active = themeFamilies.${activeFamily}.dark;

  removeHash = color: lib.removePrefix "#" color;
  quoteLua = value: "'${value}'";
  shellQuote = lib.escapeShellArg;

  zedColor = color: if color == null then throw "Cannot use null Zed color" else color;

  luaList = values: "{ ${lib.concatMapStringsSep ", " quoteLua values} }";

  rgbaHexToQtHex =
    color:
    let
      length = builtins.stringLength color;
    in
    if length == 8 then (builtins.substring 6 2 color) + (builtins.substring 0 6 color) else color;

  rgbaHexToNeovimHex =
    color:
    if color == null then
      "NONE"
    else
      let
        hex = removeHash color;
        length = builtins.stringLength hex;
        alpha = if length == 8 then builtins.substring 6 2 hex else "ff";
      in
      if builtins.match "#?[[:xdigit:]]{6}([[:xdigit:]]{2})?" color != null then
        if lib.toLower alpha == "00" then "NONE" else "#${builtins.substring 0 6 hex}"
      else
        color;

  rgbaHexToNeovimBg =
    color:
    if color == null then
      null
    else
      let
        hex = removeHash color;
        length = builtins.stringLength hex;
        alpha = if length == 8 then hexByteToInt (builtins.substring 6 2 hex) else 255;
      in
      if builtins.match "#?[[:xdigit:]]{6}([[:xdigit:]]{2})?" color != null && alpha < 128 then
        null
      else
        rgbaHexToNeovimHex color;

  hexDigitToInt =
    digit:
    {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      a = 10;
      b = 11;
      c = 12;
      d = 13;
      e = 14;
      f = 15;
    }
    .${lib.toLower digit};

  hexByteToInt =
    byte:
    (16 * hexDigitToInt (builtins.substring 0 1 byte)) + hexDigitToInt (builtins.substring 1 1 byte);

  rgbaHexToWezTerm =
    color:
    let
      hex = removeHash color;
      length = builtins.stringLength hex;
      alpha = if length == 8 then hexByteToInt (builtins.substring 6 2 hex) else 255;
      alphaText =
        if alpha == 255 then
          "1.0"
        else if alpha == 0 then
          "0.0"
        else
          builtins.toString (alpha / 255.0);
    in
    if builtins.match "#?[[:xdigit:]]{6}([[:xdigit:]]{2})?" color != null then
      "rgba(${builtins.toString (hexByteToInt (builtins.substring 0 2 hex))},${
        builtins.toString (hexByteToInt (builtins.substring 2 2 hex))
      },${builtins.toString (hexByteToInt (builtins.substring 4 2 hex))},${alphaText})"
    else
      color;

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

  xtermLevelHex = [
    "00"
    "5f"
    "87"
    "af"
    "d7"
    "ff"
  ];

  xtermCubeColor =
    index:
    let
      n = index - 16;
      r = builtins.div n 36;
      g = builtins.div (n - r * 36) 6;
      b = n - (builtins.div n 6) * 6;
      component = i: builtins.elemAt xtermLevelHex i;
    in
    "#${component r}${component g}${component b}";

  xtermIndexed16 = builtins.listToAttrs (
    map (index: {
      name = toString index;
      value = xtermCubeColor index;
    }) (lib.range 16 31)
  );

  zedOne = builtins.fromJSON (builtins.readFile zed-one);
  zedOneTheme = mode: builtins.head (builtins.filter (theme: theme.appearance == mode) zedOne.themes);

  mkZedOnePalette =
    { mode }:
    let
      theme = zedOneTheme mode;
      inherit (theme) style;
      inherit (style) syntax;
      color = key: zedColor style.${key};
      syntaxColor = key: zedColor syntax.${key}.color;
    in
    {
      accent = color "text.accent";
      background = color "editor.background";
      foreground = color "editor.foreground";
      ui = color "text.muted";
      tag = syntaxColor "tag";
      func = syntaxColor "function";
      entity = syntaxColor "type";
      string = syntaxColor "string";
      regexp = syntaxColor "string.regex";
      markup = syntaxColor "link_text";
      keyword = syntaxColor "keyword";
      special = syntaxColor "string.special";
      comment = syntaxColor "comment";
      constant = syntaxColor "constant";
      operator = syntaxColor "operator";
      error = color "error";
      line = color "editor.active_line.background";
      panelBg = color "panel.background";
      panelShadow = color "elevated_surface.background";
      panelBorder = color "border";
      gutterNormal = color "editor.line_number";
      gutterActive = color "editor.active_line_number";
      selectionBg = color "element.selected";
      selectionInactive = color "ghost_element.selected";
      selectionBorder = color "border.selected";
      guideActive = color "editor.active_wrap_guide";
      guideNormal = color "editor.wrap_guide";
      vcsAdded = color "created";
      vcsModified = color "modified";
      vcsRemoved = color "deleted";
      vcsAddedBg = color "created.background";
      vcsRemovedBg = color "deleted.background";
      fgIdle = color "text.disabled";
      warning = color "warning";
    };

  mkZedOneTerminal =
    { mode }:
    let
      inherit ((zedOneTheme mode)) style;
      color = key: zedColor style.${key};
    in
    {
      ansi = [
        (color "terminal.ansi.black")
        (color "terminal.ansi.red")
        (color "terminal.ansi.green")
        (color "terminal.ansi.yellow")
        (color "terminal.ansi.blue")
        (color "terminal.ansi.magenta")
        (color "terminal.ansi.cyan")
        (color "terminal.ansi.white")
      ];
      brights = [
        (color "terminal.ansi.bright_black")
        (color "terminal.ansi.bright_red")
        (color "terminal.ansi.bright_green")
        (color "terminal.ansi.bright_yellow")
        (color "terminal.ansi.bright_blue")
        (color "terminal.ansi.bright_magenta")
        (color "terminal.ansi.bright_cyan")
        (color "terminal.ansi.bright_white")
      ];
    };

  mkZedOneEditorTheme =
    { mode }:
    let
      inherit ((zedOneTheme mode)) style;
      inherit (style) syntax;
      color = key: zedColor style.${key};
      syntaxSpec =
        key:
        let
          spec = syntax.${key};
        in
        {
          fg = zedColor spec.color;
          italic = spec.font_style == "italic";
          bold = spec.font_weight != null && spec.font_weight >= 600;
        };
    in
    {
      ui = {
        normal = {
          fg = color "editor.foreground";
          bg = color "editor.background";
        };
        normalInactive = {
          fg = color "editor.foreground";
          bg = color "editor.background";
        };
        float = {
          fg = color "text";
          bg = color "elevated_surface.background";
        };
        popup = {
          fg = color "text";
          bg = color "element.background";
        };
        popupSelected = {
          fg = color "text";
          bg = color "element.selected";
        };
        status = {
          fg = color "text";
          bg = color "status_bar.background";
        };
        statusInactive = {
          fg = color "text.muted";
          bg = color "title_bar.inactive_background";
        };
        tab = {
          fg = color "text.muted";
          bg = color "tab.inactive_background";
        };
        tabSelected = {
          fg = color "text";
          bg = color "tab.active_background";
        };
        border = color "border";
        borderFocused = color "border.focused";
        selection = color "element.selected";
        search = color "search.match_background";
        searchActive = color "search.active_match_background";
        cursorLine = color "editor.active_line.background";
        highlightedLine = color "editor.highlighted_line.background";
        gutter = color "editor.gutter.background";
        lineNumber = color "editor.line_number";
        activeLineNumber = color "editor.active_line_number";
        hoverLineNumber = color "editor.hover_line_number";
        guide = color "editor.wrap_guide";
        activeGuide = color "editor.active_wrap_guide";
        invisible = color "editor.invisible";
        documentHighlightRead = color "editor.document_highlight.read_background";
        documentHighlightWrite = color "editor.document_highlight.write_background";
        disabled = color "text.disabled";
        muted = color "text.muted";
        placeholder = color "text.placeholder";
        accent = color "text.accent";
      };
      diagnostics = {
        error = {
          fg = color "error";
          bg = color "error.background";
          border = color "error.border";
        };
        warning = {
          fg = color "warning";
          bg = color "warning.background";
          border = color "warning.border";
        };
        info = {
          fg = color "info";
          bg = color "info.background";
          border = color "info.border";
        };
        hint = {
          fg = color "hint";
          bg = color "hint.background";
          border = color "hint.border";
        };
        ok = {
          fg = color "success";
          bg = color "success.background";
          border = color "success.border";
        };
      };
      vcs = {
        added = {
          fg = color "created";
          bg = color "created.background";
          border = color "created.border";
        };
        modified = {
          fg = color "modified";
          bg = color "modified.background";
          border = color "modified.border";
        };
        deleted = {
          fg = color "deleted";
          bg = color "deleted.background";
          border = color "deleted.border";
        };
        conflict = {
          fg = color "conflict";
          bg = color "conflict.background";
          border = color "conflict.border";
        };
        ignored = {
          fg = color "ignored";
          bg = color "ignored.background";
          border = color "ignored.border";
        };
      };
      syntax = builtins.mapAttrs (name: _: syntaxSpec name) syntax;
    };

  expectedCaelestiaColourKeys =
    let
      schemesDir = "${caelestiaCliSrc}/src/caelestia/data/schemes";
      files = lib.filesystem.listFilesRecursive schemesDir;
      txtFiles = builtins.filter (file: lib.hasSuffix ".txt" (toString file)) files;
      keysFromFile =
        file:
        map (line: builtins.head (lib.splitString " " line)) (
          builtins.filter (line: line != "") (lib.splitString "\n" (builtins.readFile file))
        );
    in
    lib.unique (lib.sort lib.lessThan (lib.concatMap keysFromFile txtFiles));

  assertCaelestiaColourTotality =
    theme:
    let
      actual = lib.sort lib.lessThan (builtins.attrNames theme.caelestiaScheme.colours);
      missing = lib.subtractLists actual expectedCaelestiaColourKeys;
      extra = lib.subtractLists expectedCaelestiaColourKeys actual;
    in
    if missing != [ ] || extra != [ ] then
      throw ''
        Caelestia colour keys for ${theme.name} do not match the pinned Caelestia CLI scheme key set.
        Missing: ${builtins.toJSON missing}
        Extra: ${builtins.toJSON extra}
      ''
    else
      theme;

  mkTheme =
    {
      name,
      schemeName,
      flavour,
      mode,
      palette,
      terminal ? terminalFromPalette palette,
      editor,
      editorTheme ? null,
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
        inherit (palette) fgIdle ui;
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
      caelestiaColors = builtins.mapAttrs (_: rgbaHexToQtHex) {
        primary_paletteKeyColor = c.primary;
        secondary_paletteKeyColor = c.secondary;
        tertiary_paletteKeyColor = c.tertiary;
        neutral_paletteKeyColor = c.foreground;
        neutral_variant_paletteKeyColor = c.brightBlack;
        primaryPaletteKeyColor = c.primary;
        secondaryPaletteKeyColor = c.secondary;
        tertiaryPaletteKeyColor = c.tertiary;
        neutralPaletteKeyColor = c.foreground;
        neutralVariantPaletteKeyColor = c.brightBlack;
        errorPaletteKeyColor = c.brightRed;
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
        onSurfaceVariant = c.fgIdle;
        inverseSurface = c.foreground;
        inverseOnSurface = c.background;
        outline = c.brightBlack;
        outlineVariant = c.selection;
        shadow = "000000";
        scrim = "000000";
        surfaceTint = c.primary;
        inherit (c) primary;
        primaryDim = c.primary;
        onPrimary = c.background;
        primaryContainer = c.surfaceContainer;
        onPrimaryContainer = c.primary;
        inversePrimary = c.primary;
        primaryFixed = c.primary;
        primaryFixedDim = c.primary;
        onPrimaryFixed = c.background;
        onPrimaryFixedVariant = c.foreground;
        inherit (c) secondary;
        secondaryDim = c.secondary;
        onSecondary = c.background;
        secondaryContainer = c.surfaceContainer;
        onSecondaryContainer = c.secondary;
        secondaryFixed = c.secondary;
        secondaryFixedDim = c.secondary;
        onSecondaryFixed = c.background;
        onSecondaryFixedVariant = c.foreground;
        inherit (c) tertiary;
        tertiaryDim = c.tertiary;
        onTertiary = c.background;
        tertiaryContainer = c.surfaceContainer;
        onTertiaryContainer = c.tertiary;
        tertiaryFixed = c.tertiary;
        tertiaryFixedDim = c.tertiary;
        onTertiaryFixed = c.background;
        onTertiaryFixedVariant = c.foreground;
        error = c.brightRed;
        errorDim = c.brightRed;
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
        subtext1 = c.fgIdle;
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
      weztermIndexed = terminal.indexed or xtermIndexed16;
      luaIndexedAttrs =
        attrs:
        ''
          {
        ''
        + lib.concatMapStringsSep "\n" (
          key: "    [${key}] = ${quoteLua (rgbaHexToWezTerm attrs.${key})},"
        ) (lib.sort (a: b: (lib.toInt a) < (lib.toInt b)) (builtins.attrNames attrs))
        + ''

          }
        '';
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
        indexed = weztermIndexed;
        inherit (terminal) ansi;
        inherit (terminal) brights;
      };
      luaAttrs = attrs: ''
        {
          foreground = ${quoteLua (rgbaHexToWezTerm attrs.foreground)},
          background = ${quoteLua (rgbaHexToWezTerm attrs.background)},
          cursor_bg = ${quoteLua (rgbaHexToWezTerm attrs.cursor_bg)},
          cursor_border = ${quoteLua (rgbaHexToWezTerm attrs.cursor_border)},
          cursor_fg = ${quoteLua (rgbaHexToWezTerm attrs.cursor_fg)},
          selection_bg = ${quoteLua (rgbaHexToWezTerm attrs.selection_bg)},
          selection_fg = ${quoteLua (rgbaHexToWezTerm attrs.selection_fg)},
          scrollbar_thumb = ${quoteLua (rgbaHexToWezTerm attrs.scrollbar_thumb)},
          split = ${quoteLua (rgbaHexToWezTerm attrs.split)},
          indexed = ${luaIndexedAttrs attrs.indexed},
          ansi = ${luaList (map rgbaHexToWezTerm attrs.ansi)},
          brights = ${luaList (map rgbaHexToWezTerm attrs.brights)},
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
        editorTheme
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

  nvimHighlightSpec =
    spec:
    let
      colorField = key: value: "${key} = ${quoteLua (rgbaHexToNeovimHex value)},";
      bgField =
        value:
        let
          bg = rgbaHexToNeovimBg value;
        in
        if bg == null then [ ] else [ "bg = ${quoteLua bg}," ];
      boolField = key: value: "${key} = ${if value then "true" else "false"},";
      field =
        key: value:
        if value == null then
          [ ]
        else if key == "bg" then
          bgField value
        else if key == "fg" || key == "sp" then
          [ (colorField key value) ]
        else if builtins.isBool value then
          [ (boolField key value) ]
        else if key == "link" then
          [ "link = ${quoteLua value}," ]
        else if key == "border" then
          [ ]
        else
          [ "${key} = ${builtins.toString value}," ];
      fields = lib.concatLists (
        lib.mapAttrsToList field (
          builtins.removeAttrs spec (
            lib.filter (key: !(spec.${key} or false)) [
              "bold"
              "italic"
              "underline"
              "undercurl"
              "strikethrough"
            ]
          )
        )
      );
    in
    if fields == [ ] then null else "{ ${lib.concatStringsSep " " fields} }";

  nvimHighlightsLua =
    highlights:
    ''
      local highlights = {
    ''
    + lib.concatStringsSep "\n" (
      lib.filter (line: line != "") (
        lib.mapAttrsToList (
          name: spec:
          let
            rendered = nvimHighlightSpec spec;
          in
          if rendered == null then "" else "  [${quoteLua name}] = ${rendered},"
        ) highlights
      )
    )
    + ''

      }

      for group, spec in pairs(highlights) do
        vim.api.nvim_set_hl(0, group, spec)
      end
    '';

  nvimLuaFromEditorTheme =
    mode: theme:
    let
      inherit (theme)
        ui
        diagnostics
        vcs
        syntax
        ;
      syntaxHl = name: syntax.${name};
      ts = {
        "@attribute" = syntaxHl "attribute";
        "@attribute.builtin" = syntaxHl "attribute";
        "@boolean" = syntaxHl "boolean";
        "@character" = syntaxHl "string";
        "@character.special" = syntaxHl "string.special";
        "@comment" = syntaxHl "comment";
        "@comment.documentation" = syntaxHl "comment.doc";
        "@comment.error" = {
          inherit (diagnostics.error) fg;
          bold = true;
        };
        "@comment.note" = diagnostics.info;
        "@comment.todo" = {
          inherit (diagnostics.info) fg;
          bold = true;
        };
        "@comment.warning" = {
          inherit (diagnostics.warning) fg;
          bold = true;
        };
        "@constant" = syntaxHl "constant";
        "@constant.builtin" = syntaxHl "variable.special";
        "@constructor" = syntaxHl "constructor";
        "@diff.delta" = vcs.modified;
        "@diff.minus" = syntaxHl "diff.minus";
        "@diff.plus" = syntaxHl "diff.plus";
        "@function" = syntaxHl "function";
        "@function.builtin" = syntaxHl "function";
        "@function.call" = syntaxHl "function";
        "@function.method" = syntaxHl "function";
        "@function.method.call" = syntaxHl "function";
        "@keyword" = syntaxHl "keyword";
        "@keyword.conditional" = syntaxHl "keyword";
        "@keyword.directive" = syntaxHl "preproc";
        "@keyword.function" = syntaxHl "keyword";
        "@keyword.import" = syntaxHl "preproc";
        "@keyword.operator" = syntaxHl "operator";
        "@keyword.repeat" = syntaxHl "keyword";
        "@label" = syntaxHl "label";
        "@markup" = syntaxHl "primary";
        "@markup.heading" = syntaxHl "title";
        "@markup.italic" = syntaxHl "emphasis";
        "@markup.link" = syntaxHl "link_uri";
        "@markup.link.label" = syntaxHl "link_text";
        "@markup.link.url" = {
          inherit (syntax.${"link_uri"}) fg;
          underline = true;
        };
        "@markup.list" = syntaxHl "punctuation.list_marker";
        "@markup.raw" = syntaxHl "text.literal";
        "@markup.strikethrough" = {
          inherit (syntax.${"primary"}) fg;
          strikethrough = true;
        };
        "@markup.strong" = syntaxHl "emphasis.strong";
        "@markup.underline" = {
          inherit (syntax.${"primary"}) fg;
          underline = true;
        };
        "@module" = syntaxHl "namespace";
        "@module.builtin" = syntaxHl "namespace";
        "@number" = syntaxHl "number";
        "@number.float" = syntaxHl "number";
        "@operator" = syntaxHl "operator";
        "@property" = syntaxHl "property";
        "@punctuation" = syntaxHl "punctuation";
        "@punctuation.bracket" = syntaxHl "punctuation.bracket";
        "@punctuation.delimiter" = syntaxHl "punctuation.delimiter";
        "@punctuation.special" = syntaxHl "punctuation.special";
        "@string" = syntaxHl "string";
        "@string.documentation" = syntaxHl "comment.doc";
        "@string.escape" = syntaxHl "string.escape";
        "@string.regexp" = syntaxHl "string.regex";
        "@string.special" = syntaxHl "string.special";
        "@string.special.symbol" = syntaxHl "string.special.symbol";
        "@string.special.url" = {
          inherit (syntax.${"link_uri"}) fg;
          underline = true;
        };
        "@tag" = syntaxHl "tag";
        "@tag.attribute" = syntaxHl "attribute";
        "@tag.builtin" = syntaxHl "tag";
        "@tag.delimiter" = syntaxHl "punctuation.bracket";
        "@type" = syntaxHl "type";
        "@type.builtin" = syntaxHl "type";
        "@variable" = syntaxHl "variable";
        "@variable.builtin" = syntaxHl "variable.special";
        "@variable.member" = syntaxHl "property";
        "@variable.parameter" = syntaxHl "variable";
        "@variable.parameter.builtin" = syntaxHl "variable.special";
      };
      highlights = {
        Normal = ui.normal;
        NormalNC = ui.normalInactive;
        NormalFloat = ui.float;
        FloatBorder = {
          fg = ui.border;
          inherit (ui.float) bg;
        };
        FloatTitle = {
          fg = ui.accent;
          inherit (ui.float) bg;
          bold = true;
        };
        FloatFooter = {
          fg = ui.muted;
          inherit (ui.float) bg;
        };
        Pmenu = ui.popup;
        PmenuSel = ui.popupSelected;
        PmenuKind = {
          inherit (syntax.${"type"}) fg;
          inherit (ui.popup) bg;
        };
        PmenuKindSel = {
          inherit (syntax.${"type"}) fg;
          inherit (ui.popupSelected) bg;
        };
        PmenuExtra = {
          fg = ui.muted;
          inherit (ui.popup) bg;
        };
        PmenuExtraSel = {
          fg = ui.muted;
          inherit (ui.popupSelected) bg;
        };
        PmenuMatch = {
          fg = ui.accent;
          inherit (ui.popup) bg;
          bold = true;
        };
        PmenuMatchSel = {
          fg = ui.accent;
          inherit (ui.popupSelected) bg;
          bold = true;
        };
        PmenuSbar = { inherit (ui.float) bg; };
        PmenuThumb = {
          bg = ui.muted;
        };
        CursorLine = {
          bg = ui.cursorLine;
        };
        CursorColumn = {
          bg = ui.cursorLine;
        };
        ColorColumn = {
          bg = ui.highlightedLine;
        };
        CursorLineNr = {
          fg = ui.activeLineNumber;
          bg = ui.cursorLine;
          bold = true;
        };
        LineNr = {
          fg = ui.lineNumber;
          bg = ui.gutter;
        };
        LineNrAbove = {
          fg = ui.lineNumber;
          bg = ui.gutter;
        };
        LineNrBelow = {
          fg = ui.lineNumber;
          bg = ui.gutter;
        };
        CursorLineSign = {
          bg = ui.cursorLine;
        };
        SignColumn = {
          bg = ui.gutter;
        };
        FoldColumn = {
          fg = ui.muted;
          bg = ui.gutter;
        };
        Folded = {
          fg = ui.muted;
          bg = ui.highlightedLine;
        };
        Visual = {
          bg = ui.selection;
        };
        VisualNOS = {
          bg = ui.selection;
        };
        Search = {
          inherit (ui.normal) fg;
          bg = ui.selection;
        };
        IncSearch = {
          inherit (ui.normal) fg;
          bg = ui.selection;
        };
        CurSearch = {
          inherit (ui.normal) fg;
          bg = ui.selection;
        };
        Substitute = {
          inherit (ui.normal) fg;
          bg = ui.selection;
        };
        MatchParen = {
          fg = ui.accent;
          bg = ui.highlightedLine;
          bold = true;
        };
        NonText = {
          fg = ui.disabled;
        };
        EndOfBuffer = {
          fg = ui.disabled;
        };
        Whitespace = {
          fg = ui.invisible;
        };
        SpecialKey = {
          fg = ui.invisible;
        };
        Conceal = {
          fg = ui.placeholder;
        };
        Directory = {
          fg = ui.accent;
        };
        Title = {
          inherit (syntax.${"title"}) fg;
          bold = true;
        };
        ErrorMsg = {
          inherit (diagnostics.error) fg;
          bold = true;
        };
        WarningMsg = { inherit (diagnostics.warning) fg; };
        ModeMsg = {
          fg = ui.accent;
        };
        MoreMsg = { inherit (diagnostics.info) fg; };
        Question = { inherit (diagnostics.info) fg; };
        StatusLine = ui.status;
        StatusLineNC = ui.statusInactive;
        WinSeparator = {
          fg = ui.border;
        };
        VertSplit = {
          fg = ui.border;
        };
        TabLine = ui.tab;
        TabLineSel = ui.tabSelected;
        TabLineFill = { inherit (ui.tab) bg; };
        WinBar = {
          inherit (ui.normal) fg;
          inherit (ui.normal) bg;
        };
        WinBarNC = {
          fg = ui.muted;
          inherit (ui.normal) bg;
        };
        WildMenu = ui.popupSelected;
        QuickFixLine = {
          bg = ui.highlightedLine;
        };
        SpellBad = {
          sp = diagnostics.error.fg;
          undercurl = true;
        };
        SpellCap = {
          sp = diagnostics.warning.fg;
          undercurl = true;
        };
        SpellLocal = {
          sp = diagnostics.info.fg;
          undercurl = true;
        };
        SpellRare = {
          sp = diagnostics.hint.fg;
          undercurl = true;
        };

        Comment = syntaxHl "comment";
        Constant = syntaxHl "constant";
        String = syntaxHl "string";
        Character = syntaxHl "string";
        Number = syntaxHl "number";
        Boolean = syntaxHl "boolean";
        Float = syntaxHl "number";
        Identifier = syntaxHl "variable";
        Function = syntaxHl "function";
        Statement = syntaxHl "keyword";
        Conditional = syntaxHl "keyword";
        Repeat = syntaxHl "keyword";
        Label = syntaxHl "label";
        Operator = syntaxHl "operator";
        Keyword = syntaxHl "keyword";
        Exception = syntaxHl "keyword";
        PreProc = syntaxHl "preproc";
        Include = syntaxHl "preproc";
        Define = syntaxHl "preproc";
        Macro = syntaxHl "preproc";
        PreCondit = syntaxHl "preproc";
        Type = syntaxHl "type";
        StorageClass = syntaxHl "type";
        Structure = syntaxHl "type";
        Typedef = syntaxHl "type";
        Special = syntaxHl "string.special";
        SpecialChar = syntaxHl "string.special";
        Tag = syntaxHl "tag";
        Delimiter = syntaxHl "punctuation.delimiter";
        SpecialComment = syntaxHl "comment.doc";
        Debug = syntaxHl "comment.doc";
        Underlined = {
          inherit (syntax.${"link_uri"}) fg;
          underline = true;
        };
        Ignore = {
          fg = ui.disabled;
        };
        Error = diagnostics.error;
        Todo = {
          inherit (diagnostics.info) fg;
          inherit (diagnostics.info) bg;
          bold = true;
        };

        DiffAdd = vcs.added;
        DiffChange = vcs.modified;
        DiffDelete = vcs.deleted;
        DiffText = {
          inherit (vcs.modified) fg;
          bg = ui.selection;
          bold = true;
        };
        Added = vcs.added;
        Changed = vcs.modified;
        Removed = vcs.deleted;

        DiagnosticError = { inherit (diagnostics.error) fg; };
        DiagnosticWarn = { inherit (diagnostics.warning) fg; };
        DiagnosticInfo = { inherit (diagnostics.info) fg; };
        DiagnosticHint = { inherit (diagnostics.hint) fg; };
        DiagnosticOk = { inherit (diagnostics.ok) fg; };
        DiagnosticVirtualTextError = diagnostics.error;
        DiagnosticVirtualTextWarn = diagnostics.warning;
        DiagnosticVirtualTextInfo = diagnostics.info;
        DiagnosticVirtualTextHint = diagnostics.hint;
        DiagnosticVirtualTextOk = diagnostics.ok;
        DiagnosticFloatingError = { inherit (diagnostics.error) fg; };
        DiagnosticFloatingWarn = { inherit (diagnostics.warning) fg; };
        DiagnosticFloatingInfo = { inherit (diagnostics.info) fg; };
        DiagnosticFloatingHint = { inherit (diagnostics.hint) fg; };
        DiagnosticFloatingOk = { inherit (diagnostics.ok) fg; };
        DiagnosticSignError = { inherit (diagnostics.error) fg; };
        DiagnosticSignWarn = { inherit (diagnostics.warning) fg; };
        DiagnosticSignInfo = { inherit (diagnostics.info) fg; };
        DiagnosticSignHint = { inherit (diagnostics.hint) fg; };
        DiagnosticSignOk = { inherit (diagnostics.ok) fg; };
        DiagnosticUnderlineError = {
          sp = diagnostics.error.fg;
          undercurl = true;
        };
        DiagnosticUnderlineWarn = {
          sp = diagnostics.warning.fg;
          undercurl = true;
        };
        DiagnosticUnderlineInfo = {
          sp = diagnostics.info.fg;
          undercurl = true;
        };
        DiagnosticUnderlineHint = {
          sp = diagnostics.hint.fg;
          undercurl = true;
        };
        DiagnosticUnderlineOk = {
          sp = diagnostics.ok.fg;
          undercurl = true;
        };
        DiagnosticDeprecated = {
          fg = ui.disabled;
          strikethrough = true;
        };
        DiagnosticUnnecessary = {
          fg = ui.disabled;
        };
        LspReferenceText = {
          bg = ui.highlightedLine;
        };
        LspReferenceRead = {
          bg = ui.highlightedLine;
        };
        LspReferenceWrite = {
          bg = ui.selection;
        };
        LspReferenceTarget = {
          bg = ui.selection;
        };
        LspInlayHint = {
          inherit (syntax.${"hint"}) fg;
          inherit (diagnostics.hint) bg;
          italic = true;
        };
        LspCodeLens = {
          fg = ui.muted;
        };
        LspCodeLensSeparator = {
          fg = ui.disabled;
        };
        LspSignatureActiveParameter = {
          fg = ui.accent;
          bold = true;
        };

        CmpItemAbbr = { inherit (ui.normal) fg; };
        CmpItemAbbrDeprecated = {
          fg = ui.disabled;
          strikethrough = true;
        };
        CmpItemAbbrMatch = {
          fg = ui.accent;
          bold = true;
        };
        CmpItemAbbrMatchFuzzy = {
          fg = ui.accent;
          bold = true;
        };
        CmpItemMenu = {
          fg = ui.muted;
        };
        CmpItemKind = { inherit (syntax.${"type"}) fg; };
        CmpItemKindText = { inherit (syntax.${"primary"}) fg; };
        CmpItemKindMethod = { inherit (syntax.${"function"}) fg; };
        CmpItemKindFunction = { inherit (syntax.${"function"}) fg; };
        CmpItemKindConstructor = { inherit (syntax.${"constructor"}) fg; };
        CmpItemKindField = { inherit (syntax.${"property"}) fg; };
        CmpItemKindVariable = { inherit (syntax.${"variable"}) fg; };
        CmpItemKindClass = { inherit (syntax.${"type"}) fg; };
        CmpItemKindInterface = { inherit (syntax.${"type"}) fg; };
        CmpItemKindModule = { inherit (syntax.${"namespace"}) fg; };
        CmpItemKindProperty = { inherit (syntax.${"property"}) fg; };
        CmpItemKindUnit = { inherit (syntax.${"number"}) fg; };
        CmpItemKindValue = { inherit (syntax.${"constant"}) fg; };
        CmpItemKindEnum = { inherit (syntax.${"enum"}) fg; };
        CmpItemKindKeyword = { inherit (syntax.${"keyword"}) fg; };
        CmpItemKindSnippet = { inherit (syntax.${"string.special"}) fg; };
        CmpItemKindColor = {
          fg = ui.accent;
        };
        CmpItemKindFile = {
          fg = ui.accent;
        };
        CmpItemKindReference = { inherit (syntax.${"link_uri"}) fg; };
        CmpItemKindFolder = {
          fg = ui.accent;
        };
        CmpItemKindEnumMember = { inherit (syntax.${"constant"}) fg; };
        CmpItemKindConstant = { inherit (syntax.${"constant"}) fg; };
        CmpItemKindStruct = { inherit (syntax.${"type"}) fg; };
        CmpItemKindEvent = { inherit (syntax.${"variant"}) fg; };
        CmpItemKindOperator = { inherit (syntax.${"operator"}) fg; };
        CmpItemKindTypeParameter = { inherit (syntax.${"type"}) fg; };

        TelescopeNormal = ui.float;
        TelescopeBorder = {
          fg = ui.border;
          inherit (ui.float) bg;
        };
        TelescopeTitle = {
          fg = ui.accent;
          inherit (ui.float) bg;
          bold = true;
        };
        TelescopePromptNormal = ui.popup;
        TelescopePromptBorder = {
          fg = ui.borderFocused;
          inherit (ui.popup) bg;
        };
        TelescopePromptTitle = {
          fg = ui.accent;
          inherit (ui.popup) bg;
          bold = true;
        };
        TelescopePromptPrefix = {
          fg = ui.accent;
        };
        TelescopePromptCounter = {
          fg = ui.muted;
        };
        TelescopeResultsNormal = ui.float;
        TelescopeResultsBorder = {
          fg = ui.border;
          inherit (ui.float) bg;
        };
        TelescopeResultsTitle = {
          fg = ui.muted;
          inherit (ui.float) bg;
        };
        TelescopePreviewNormal = ui.float;
        TelescopePreviewBorder = {
          fg = ui.border;
          inherit (ui.float) bg;
        };
        TelescopePreviewTitle = {
          fg = ui.accent;
          inherit (ui.float) bg;
          bold = true;
        };
        TelescopeSelection = ui.popupSelected;
        TelescopeSelectionCaret = {
          fg = ui.accent;
          inherit (ui.popupSelected) bg;
        };
        TelescopeMatching = {
          fg = ui.accent;
          bold = true;
        };
        TelescopeMultiSelection = {
          inherit (diagnostics.info) fg;
          bg = ui.selection;
        };
        TelescopeResultsDiffAdd = { inherit (vcs.added) fg; };
        TelescopeResultsDiffChange = { inherit (vcs.modified) fg; };
        TelescopeResultsDiffDelete = { inherit (vcs.deleted) fg; };
        TelescopeResultsDiffUntracked = { inherit (vcs.ignored) fg; };
        TelescopeResultsComment = syntaxHl "comment";
        TelescopeResultsConstant = syntaxHl "constant";
        TelescopeResultsFunction = syntaxHl "function";
        TelescopeResultsIdentifier = syntaxHl "variable";
        TelescopeResultsNumber = syntaxHl "number";
        TelescopeResultsOperator = syntaxHl "operator";
        TelescopeResultsSpecialComment = syntaxHl "comment.doc";
        TelescopeResultsStruct = syntaxHl "type";
        TelescopeResultsVariable = syntaxHl "variable";
        TelescopeResultsLineNr = {
          fg = ui.lineNumber;
        };

        GitSignsAdd = { inherit (vcs.added) fg; };
        GitSignsChange = { inherit (vcs.modified) fg; };
        GitSignsDelete = { inherit (vcs.deleted) fg; };
        GitSignsTopdelete = { inherit (vcs.deleted) fg; };
        GitSignsChangedelete = { inherit (vcs.modified) fg; };
        GitSignsUntracked = { inherit (vcs.added) fg; };
        GitSignsAddNr = { inherit (vcs.added) fg; };
        GitSignsChangeNr = { inherit (vcs.modified) fg; };
        GitSignsDeleteNr = { inherit (vcs.deleted) fg; };
        GitSignsTopdeleteNr = { inherit (vcs.deleted) fg; };
        GitSignsChangedeleteNr = { inherit (vcs.modified) fg; };
        GitSignsUntrackedNr = { inherit (vcs.added) fg; };
        GitSignsAddLn = { inherit (vcs.added) bg; };
        GitSignsChangeLn = { inherit (vcs.modified) bg; };
        GitSignsDeleteLn = { inherit (vcs.deleted) bg; };
        GitSignsTopdeleteLn = { inherit (vcs.deleted) bg; };
        GitSignsChangedeleteLn = { inherit (vcs.modified) bg; };
        GitSignsUntrackedLn = { inherit (vcs.added) bg; };
        GitSignsCurrentLineBlame = {
          fg = ui.muted;
          italic = true;
        };
      }
      // ts;
    in
    ''
      vim.o.background = ${quoteLua mode}
      vim.cmd.colorscheme('default')

      ${nvimHighlightsLua highlights}
    '';

  mkZedOne =
    mode:
    let
      palette = mkZedOnePalette { inherit mode; };
      editorTheme = mkZedOneEditorTheme { inherit mode; };
    in
    mkTheme {
      name = "zed-one-${mode}";
      schemeName = "zed";
      flavour = "default";
      inherit mode palette editorTheme;
      terminal = mkZedOneTerminal { inherit mode; };
      accents = {
        primary = palette.constant;
        secondary = palette.entity;
        tertiary = palette.string;
        surfaceContainer = palette.panelBg;
      };
      editor = {
        colorscheme = "default";
        package = null;
        nixvimAyu = false;
        lua = nvimLuaFromEditorTheme mode editorTheme;
      };
    };

  themeFamilies = {
    ayu = {
      dark = assertCaelestiaColourTotality (mkAyu "dark");
      light = assertCaelestiaColourTotality (mkAyu "light");
    };
    everforest = {
      dark = assertCaelestiaColourTotality (mkEverforest "dark");
      light = assertCaelestiaColourTotality (mkEverforest "light");
    };
    zed = {
      dark = assertCaelestiaColourTotality (mkZedOne "dark");
      light = assertCaelestiaColourTotality (mkZedOne "light");
    };
  };

  allThemes = [
    themeFamilies.ayu.dark
    themeFamilies.ayu.light
    themeFamilies.everforest.dark
    themeFamilies.everforest.light
    themeFamilies.zed.dark
    themeFamilies.zed.light
  ];

  appTheme = active;

  themeCasePattern =
    theme: "${theme.schemeName}|${theme.flavour}|${theme.mode}|${theme.caelestiaScheme.variant}";

  runtimeThemeHook =
    let
      themeCases = lib.concatMapStringsSep "\n" (theme: ''
        ${shellQuote (themeCasePattern theme)})
          cat > "$state_dir/nvim.lua" <<${shellQuote "EOF"}
        ${theme.editor.lua}
        EOF

          cat > "$state_dir/wezterm.lua" <<${shellQuote "EOF"}
        ${theme.weztermRuntimeLua}
        EOF
          ;;
      '') allThemes;
    in
    ''
      set -eu

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/theme"
      mkdir -p "$state_dir"
      theme_key="$SCHEME_NAME|$SCHEME_FLAVOUR|$SCHEME_MODE|$SCHEME_VARIANT"
      rm -f "$state_dir/nvim.lua" "$state_dir/wezterm.lua"

      case "$theme_key" in
      ${themeCases}
        *)
          echo "No app runtime theme for $theme_key" >&2
          exit 1
          ;;
      esac

      if command -v wezterm >/dev/null 2>&1; then
        wezterm cli reload-configuration >/dev/null 2>&1 || :
      fi
    '';

  schemeFiles = pkgs.runCommand "caelestia-theme-schemes" { } ''
    mkdir -p "$out/ayu/default" "$out/everforest/hard" "$out/zed/default"
    cp ${pkgs.writeText "ayu-dark.txt" themeFamilies.ayu.dark.caelestiaSchemeText} "$out/ayu/default/dark.txt"
    cp ${pkgs.writeText "ayu-light.txt" themeFamilies.ayu.light.caelestiaSchemeText} "$out/ayu/default/light.txt"
    cp ${pkgs.writeText "everforest-hard-dark.txt" themeFamilies.everforest.dark.caelestiaSchemeText} "$out/everforest/hard/dark.txt"
    cp ${pkgs.writeText "everforest-hard-light.txt" themeFamilies.everforest.light.caelestiaSchemeText} "$out/everforest/hard/light.txt"
    cp ${pkgs.writeText "zed-dark.txt" themeFamilies.zed.dark.caelestiaSchemeText} "$out/zed/default/dark.txt"
    cp ${pkgs.writeText "zed-light.txt" themeFamilies.zed.light.caelestiaSchemeText} "$out/zed/default/light.txt"
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
          cp -R ${schemeFiles}/zed "$schemes/"
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
