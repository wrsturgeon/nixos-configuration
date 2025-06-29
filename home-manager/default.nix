{
  config,
  enable-hyprland,
  pkgs,
  username,
  ollama-default-model,
  ...
}:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    file = {
      ".aider-conventions.md".text =
        # Largely taken from <https://github.com/Aider-AI/conventions/blob/5d3b2409726b1ca8fa86835f476248a90a5df700/functional-programming/CONVENTIONS.md>.
        ''
          When writing code, you MUST follow these principles:
          - Code should be easy to read and understand.
          - Keep the code as simple as possible. Avoid unnecessary complexity.
          - Use meaningful names for variables, functions, etc. Names should reveal intent.
          - Functions should be small and do one thing well.
          - Function names should describe the action being performed.
          - Prefer fewer arguments in functions. Ideally, aim for no more than two or three.
          - Use comments only to add useful information that is not readily apparent from the code itself.
          - Properly represent all possible errors before they happen, then
            handle each possible error to ensure the software's safety and robustness.
          - Consider security implications of the code.
            Implement security best practices to protect against vulnerabilities and attacks.
          - Adhere to these 4 principles of Functional Programming:
            1. Pure Functions
            2. Immutability (whenever there would be no difference in performance)
            3. Function Composition
            4. Declarative Code
          - Do not use object oriented programming unless the language requires you to do so.
          - After all of the above rules have been satisfied, write performant implementations,
            so long as they would not notably contradict a rule above.

          Whenever you are asked to implement anything, do the following IN ORDER:
           1. FIRST, write tests that exhaustively specify the behavior you have been asked to implement.
              You need to consider all possible edge cases. Deliberately try to break the thing you're testing.
              When in doubt, write more tests, even if some would be partially redundant.
           2. AFTER you have written the exhaustive test suite, begin writing the implementation.
          If you have a property-based testing framework like QuickCheck (e.g. in Haskell or Rust), use it extensively.
        '';
      ".aider.conf.yml".text = ''

        ##########################################################
        # Sample .aider.conf.yml
        # This file lists *all* the valid configuration entries.
        # Place in your home dir, or at the root of your git repo.
        ##########################################################

        # Note: You can only put OpenAI and Anthropic API keys in the YAML
        # config file. Keys for all APIs can be stored in a .env file
        # https://aider.chat/docs/config/dotenv.html

        ##########
        # options:

        # show this help message and exit
        #help: xxx

        #############
        # Main model:

        # Specify the model to use for the main chat
        model: ollama/${ollama-default-model} # openrouter/deepseek/deepseek-chat-v3-0324:free

        ########################
        # API Keys and settings:

        # Set an environment variable (to control API settings, can be used multiple times)
        #set-env: xxx
        # Specify multiple values like this:
        #set-env:
        #  - xxx
        #  - yyy
        #  - zzz

        #################
        # Model settings:

        # List known models which match the (partial) MODEL name
        #list-models: xxx

        # Specify a file with aider model settings for unknown models
        #model-settings-file: .aider.model.settings.yml

        # Specify a file with context window and costs for unknown models
        #model-metadata-file: .aider.model.metadata.json

        # Add a model alias (can be used multiple times)
        #alias: xxx
        # Specify multiple values like this:
        #alias:
        #  - xxx
        #  - yyy
        #  - zzz

        # Set the reasoning_effort API parameter (default: not set)
        #reasoning-effort: xxx

        # Set the thinking token budget for models that support it. Use 0 to disable. (default: not set)
        #thinking-tokens: xxx

        # Verify the SSL cert when connecting to models (default: True)
        #verify-ssl: true

        # Timeout in seconds for API calls (default: None)
        #timeout: 10

        # Specify what edit format the LLM should use (default depends on model)
        #edit-format: xxx

        # Use architect edit format for the main chat
        #architect: false

        # Enable/disable automatic acceptance of architect changes (default: True)
        #auto-accept-architect: true

        # Specify the model to use for commit messages and chat history summarization (default depends on --model)
        #weak-model: todo

        # Specify the model to use for editor tasks (default depends on --model)
        #editor-model: xxx

        # Specify the edit format for the editor model (default: depends on editor model)
        #editor-edit-format: xxx

        # Only work with models that have meta-data available (default: True)
        #show-model-warnings: true

        # Check if model accepts settings like reasoning_effort/thinking_tokens (default: True)
        #check-model-accepts-settings: true

        # Soft limit on tokens for chat history, after which summarization begins. If unspecified, defaults to the model's max_chat_history_tokens.
        #max-chat-history-tokens: xxx

        #################
        # Cache settings:

        # Enable caching of prompts (default: False)
        #cache-prompts: false

        # Number of times to ping at 5min intervals to keep prompt cache warm (default: 0)
        #cache-keepalive-pings: false

        ###################
        # Repomap settings:

        # Suggested number of tokens to use for repo map, use 0 to disable
        #map-tokens: xxx

        # Control how often the repo map is refreshed. Options: auto, always, files, manual (default: auto)
        #map-refresh: auto

        # Multiplier for map tokens when no files are specified (default: 2)
        #map-multiplier-no-files: true

        ################
        # History Files:

        # Specify the chat input history file (default: .aider.input.history)
        #input-history-file: .aider.input.history

        # Specify the chat history file (default: .aider.chat.history.md)
        #chat-history-file: .aider.chat.history.md

        # Restore the previous chat history messages (default: False)
        #restore-chat-history: false

        # Log the conversation with the LLM to this file (for example, .aider.llm.history)
        #llm-history-file: xxx

        ##################
        # Output settings:

        # Use colors suitable for a dark terminal background (default: False)
        #dark-mode: false

        # Use colors suitable for a light terminal background (default: False)
        #light-mode: false

        # Enable/disable pretty, colorized output (default: True)
        #pretty: true

        # Enable/disable streaming responses (default: True)
        #stream: true

        # Set the color for user input (default: #00cc00)
        #user-input-color: "#00cc00"

        # Set the color for tool output (default: None)
        #tool-output-color: "xxx"

        # Set the color for tool error messages (default: #FF2222)
        #tool-error-color: "#FF2222"

        # Set the color for tool warning messages (default: #FFA500)
        #tool-warning-color: "#FFA500"

        # Set the color for assistant output (default: #0088ff)
        #assistant-output-color: "#0088ff"

        # Set the color for the completion menu (default: terminal's default text color)
        #completion-menu-color: "xxx"

        # Set the background color for the completion menu (default: terminal's default background color)
        #completion-menu-bg-color: "xxx"

        # Set the color for the current item in the completion menu (default: terminal's default background color)
        #completion-menu-current-color: "xxx"

        # Set the background color for the current item in the completion menu (default: terminal's default text color)
        #completion-menu-current-bg-color: "xxx"

        # Set the markdown code theme (default: default, other options include monokai, solarized-dark, solarized-light, or a Pygments builtin style, see https://pygments.org/styles for available themes)
        #code-theme: default

        # Show diffs when committing changes (default: False)
        #show-diffs: false

        ###############
        # Git settings:

        # Enable/disable looking for a git repo (default: True)
        #git: true

        # Enable/disable adding .aider* to .gitignore (default: True)
        #gitignore: true

        # Enable/disable the addition of files listed in .gitignore to Aider's editing scope.
        #add-gitignore-files: false

        # Specify the aider ignore file (default: .aiderignore in git root)
        #aiderignore: .aiderignore

        # Only consider files in the current subtree of the git repository
        #subtree-only: false

        # Enable/disable auto commit of LLM changes (default: True)
        #auto-commits: true

        # Enable/disable commits when repo is found dirty (default: True)
        #dirty-commits: true

        # Attribute aider code changes in the git author name (default: True). If explicitly set to True, overrides --attribute-co-authored-by precedence.
        #attribute-author: xxx

        # Attribute aider commits in the git committer name (default: True). If explicitly set to True, overrides --attribute-co-authored-by precedence for aider edits.
        #attribute-committer: xxx

        # Prefix commit messages with 'aider: ' if aider authored the changes (default: False)
        #attribute-commit-message-author: false

        # Prefix all commit messages with 'aider: ' (default: False)
        #attribute-commit-message-committer: false

        # Attribute aider edits using the Co-authored-by trailer in the commit message (default: True). If True, this takes precedence over default --attribute-author and --attribute-committer behavior unless they are explicitly set to True.
        #attribute-co-authored-by: true

        # Enable/disable git pre-commit hooks with --no-verify (default: False)
        #git-commit-verify: false

        # Commit all pending changes with a suitable commit message, then exit
        #commit: false

        # Specify a custom prompt for generating commit messages
        #commit-prompt: xxx

        # Perform a dry run without modifying files (default: False)
        #dry-run: false

        # Skip the sanity check for the git repository (default: False)
        #skip-sanity-check-repo: false

        # Enable/disable watching files for ai coding comments (default: False)
        #watch-files: false

        ########################
        # Fixing and committing:

        # Lint and fix provided files, or dirty files if none provided
        #lint: false

        # Specify lint commands to run for different languages, eg: "python: flake8 --select=..." (can be used multiple times)
        #lint-cmd: xxx
        # Specify multiple values like this:
        #lint-cmd:
        #  - xxx
        #  - yyy
        #  - zzz

        # Enable/disable automatic linting after changes (default: True)
        #auto-lint: true

        # Specify command to run tests
        #test-cmd: xxx

        # Enable/disable automatic testing after changes (default: False)
        auto-test: true

        # Run tests, fix problems found and then exit
        test: false

        ############
        # Analytics:

        # Enable/disable analytics for current session (default: random)
        #analytics: xxx

        # Specify a file to log analytics events
        #analytics-log: xxx

        # Permanently disable analytics
        #analytics-disable: false

        # Send analytics to custom PostHog instance
        #analytics-posthog-host: xxx

        # Send analytics to custom PostHog project
        #analytics-posthog-project-api-key: xxx

        ############
        # Upgrading:

        # Check for updates and return status in the exit code
        #just-check-update: false

        # Check for new aider versions on launch
        #check-update: true

        # Show release notes on first run of new version (default: None, ask user)
        #show-release-notes: xxx

        # Install the latest version from the main branch
        #install-main-branch: false

        # Upgrade aider to the latest version from PyPI
        #upgrade: false

        # Show the version number and exit
        #version: xxx

        ########
        # Modes:

        # Specify a single message to send the LLM, process reply then exit (disables chat mode)
        #message: xxx

        # Specify a file containing the message to send the LLM, process reply, then exit (disables chat mode)
        #message-file: xxx

        # Run aider in your browser (default: False)
        #gui: false

        # Enable automatic copy/paste of chat between aider and web UI (default: False)
        #copy-paste: false

        # Apply the changes from the given file instead of running the chat (debug)
        #apply: xxx

        # Apply clipboard contents as edits using the main model's editor format
        #apply-clipboard-edits: false

        # Do all startup activities then exit before accepting user input (debug)
        #exit: false

        # Print the repo map and exit (debug)
        #show-repo-map: false

        # Print the system prompts and exit (debug)
        #show-prompts: false

        #################
        # Voice settings:

        # Audio format for voice recording (default: wav). webm and mp3 require ffmpeg
        #voice-format: wav

        # Specify the language for voice using ISO 639-1 code (default: auto)
        #voice-language: en

        # Specify the input device name for voice recording
        #voice-input-device: xxx

        #################
        # Other settings:

        # Never prompt for or attempt to install Playwright for web scraping (default: False).
        #disable-playwright: false

        # specify a file to edit (can be used multiple times)
        #file: xxx
        # Specify multiple values like this:
        #file:
        #  - xxx
        #  - yyy
        #  - zzz

        # specify read-only files (can be used multiple times)
        read:
          - ~/.aider-conventions.md
          - CONVENTIONS.md
          - tests/*

        # Use VI editing mode in the terminal (default: False)
        #vim: false

        # Specify the language to use in the chat (default: None, uses system settings)
        #chat-language: xxx

        # Specify the language to use in the commit message (default: None, user language)
        #commit-language: xxx

        # Always say yes to every confirmation
        #yes-always: false

        # Enable verbose output
        #verbose: true

        # Load and execute /commands from a file on launch
        #load: xxx

        # Specify the encoding for input and output (default: utf-8)
        #encoding: utf-8

        # Line endings to use when writing files (default: platform)
        #line-endings: platform

        # Specify the config file (default: search for .aider.conf.yml in git root, cwd or home directory)
        #config: xxx

        # Specify the .env file to load (default: .env in git root)
        #env-file: .env

        # Enable/disable suggesting shell commands (default: True)
        #suggest-shell-commands: true

        # Enable/disable fancy input with history and completion (default: True)
        #fancy-input: true

        # Enable/disable multi-line input mode with Meta-Enter to submit (default: False)
        #multiline: false

        # Enable/disable terminal bell notifications when LLM responses are ready (default: False)
        notifications: true

        # Specify a command to run for notifications instead of the terminal bell. If not specified, a default command for your OS may be used.
        #notifications-command: xxx

        # Enable/disable detection and offering to add URLs to chat (default: True)
        #detect-urls: true

        # Specify which editor to use for the /editor command
        #editor: xxx

        # Print shell completion script for the specified SHELL and exit. Supported shells: bash, tcsh, zsh. Example: aider --shell-completions bash
        #shell-completions: xxx
      '';
      ".config/hypr/hyprland.conf".text = builtins.readFile ./hyprland.conf;
    };
    inherit username;
    homeDirectory = "/home/${username}";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      package = pkgs.gitFull;
    };
    git-credential-oauth.enable = true;
  };

  services =
    let
      without-hyprland = { };
    in
    if enable-hyprland then
      without-hyprland
      // {
        udiskie = {
          enable = true;
          settings = {
            # workaround for
            # https://github.com/nix-community/home-manager/issues/632
            program_options.file_manager = "${pkgs.wezterm}/bin/wezterm start -- ${pkgs.superfile}/bin/superfile";
          };
        };
      }
    else
      without-hyprland;
}
