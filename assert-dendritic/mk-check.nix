{
  moduleRoot,
  pkgs,
  self,
}:

let
  root = self.outPath;
  rootText = toString root;
  moduleRootText = toString moduleRoot;
  moduleRootRelative =
    if pkgs.lib.hasPrefix "${rootText}/" moduleRootText then
      "./${pkgs.lib.removePrefix "${rootText}/" moduleRootText}"
    else
      throw "assert-dendritic.moduleRoot must be inside the flake source";
in
pkgs.runCommand "assert-dendritic" { nativeBuildInputs = [ pkgs.findutils ]; } ''
  set -eu

  root=${pkgs.lib.escapeShellArg rootText}
  module_root=${pkgs.lib.escapeShellArg moduleRootRelative}
  problems=$TMPDIR/problems

  cd "$root"
  touch "$problems"

  while IFS= read -r file; do
    case "$file" in
      "$module_root"/* | \
      ./flake.nix | \
      ./default.nix | \
      ./**/flake.nix | \
      ./**/default.nix | \
      ./**/*.pkg.nix | \
      ./assert-dendritic/*.nix | \
      ./secrets/secrets.nix)
        ;;
      *)
        echo "$file" >> "$problems"
        ;;
    esac
  done < <(find . -type f -name '*.nix' -print | sort)

  if [ -s "$problems" ]; then
    echo "Non-entry Nix files outside $module_root must be dendritic modules." >&2
    sed 's/^/  /' "$problems" >&2
    exit 1
  fi

  mkdir "$out"
  touch "$out/assert-dendritic"
''
