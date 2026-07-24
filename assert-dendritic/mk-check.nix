top-level-configuration-to-inspect:
let

  is-deeply-dendritic = configuration-to-inspect: throw (toString configuration-to-inspect);

  is-dendritic = is-deeply-dendritic top-level-configuration-to-inspect;
in
assert is-dendritic;
inputs.pkgs.writeTextFile {
  name = "assert-dendritic";
  text = "assert-dendritic";
}
