{ inputs, pkgs, ... }:

# Largely copied from <https://github.com/NixOS/nixpkgs/blob/30a61f056ac492e3b7cdcb69c1e6abdcf00e39cf/pkgs/development/python-modules/aider-chat/default.nix>.

let
  pypkgs = pkgs.python312Packages;
in
# pypkgs.buildPythonPackage {
pypkgs.buildPythonApplication {
  pname = "aider";
  version = "42.42.42";
  src = inputs.aider-src;

  enableParallelBuilding = true;

  build-system = with pypkgs; [ setuptools-scm ];
  pyproject = true;
  pythonRelaxDeps = true;
  dontCheckRuntimeDeps = true;

  dependencies = with pypkgs; [
    configargparse
    diff-match-patch
    diskcache
    grep-ast
    httpx
    importlib-resources
    json5
    litellm
    mixpanel
    oslex
    packaging
    pathspec
    pexpect
    pillow
    posthog
    prompt-toolkit
    psutil
    pydub
    pypandoc
    pyperclip
    python-dotenv
    pyyaml
    requests
    rich
    shtab
    tqdm
    watchfiles
  ];

  disabledTestPaths = [
    # Tests require network access
    "tests/scrape/test_scrape.py"
    # Expected 'mock' to have been called once
    "tests/help/test_help.py"
  ];

  disabledTests = [
    # Tests require network
    "test_urls"
    "test_get_commit_message_with_custom_prompt"
    # FileNotFoundError
    "test_get_commit_message"
    # Expected 'launch_gui' to have been called once
    "test_browser_flag_imports_streamlit"
    # AttributeError
    "test_simple_send_with_retries"
    # Expected 'check_version' to have been called once
    "test_main_exit_calls_version_check"
    # AssertionError: assert 2 == 1
    "test_simple_send_non_retryable_error"
  ]
  ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    # Tests fails on darwin
    "test_dark_mode_sets_code_theme"
    "test_default_env_file_sets_automatic_variable"
    # FileNotFoundError: [Errno 2] No such file or directory: 'vim'
    "test_pipe_editor"
  ];

  makeWrapperArgs = [
    "--set"
    "AIDER_CHECK_UPDATE"
    "false"
    "--set"
    "AIDER_ANALYTICS"
    "false"
  ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export AIDER_ANALYTICS='false'
  '';

}
