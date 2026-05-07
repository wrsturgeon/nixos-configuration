{ inputs, pkgs }:

pkgs.google-fonts.overrideAttrs (_old: {
  src = inputs.google-fonts;

  # google/fonts usually keeps the variable fonts in the family root
  # and generated/static instances under static/.  nixpkgs' default
  # package installs every TTF it can find, so fontconfig/browsers can
  # see both and pick the non-variable instance.  Install only root
  # variable fonts whenever a family provides them; fall back to all
  # TTFs only for families that do not have variable fonts.
  installPhase = ''
    adobeBlankDest=$adobeBlank/share/fonts/truetype
    install -m 444 -Dt $adobeBlankDest ofl/adobeblank/AdobeBlank-Regular.ttf
    rm -r ofl/adobeblank

    dest=$out/share/fonts/truetype
    installFamily() {
      local familyDir="$1"
      mapfile -t rootVariableFonts < <(find "$familyDir" -maxdepth 1 -type f -name '*.ttf' | grep -F '[' | sort || true)

      if (( ''${#rootVariableFonts[@]} )); then
        install -m 444 -Dt "$dest" "''${rootVariableFonts[@]}"
      else
        find "$familyDir" -type f -name '*.ttf' -exec install -m 444 -Dt "$dest" '{}' +
      fi
    }

    for familyDir in apache/* ofl/* ufl/*; do
      [[ -d "$familyDir" ]] || continue
      installFamily "$familyDir"
    done

    if find "$dest" -type f -printf '%f\n' | sort | uniq -d | grep .; then
      echo "error: duplicate installed font filenames"
      exit 1
    fi
  '';
})
