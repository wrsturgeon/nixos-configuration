;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

(load (expand-file-name "~/.config/emacs-nix-constants.el"))

(defun read-secret (file)
  "Read and trim the secret stored in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (string-trim (buffer-string))))

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Will Sturgeon"
      user-mail-address "willstrgn@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!
(setq doom-font (font-spec :family nix-default-monospace-font :size 12))
(setq doom-symbol-font (font-spec :family "Symbols Nerd Font Mono" :size 12))
(setq doom-variable-pitch-font (font-spec :family nix-default-font :size 12))
(setq doom-big-font (font-spec :family nix-default-serif-font :size 18))
(setq doom-serif-font (font-spec :family nix-default-serif-font :size 12))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-ayu-dark)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Run formatters on the remote host for TRAMP buffers, including sudo edits.
(after! apheleia
  (setq apheleia-remote-algorithm 'remote))

(after! ghostel
  (add-to-list 'ghostel-tramp-shells
               '("sudo" "/run/current-system/sw/bin/zsh")))

(setq org-gcal-client-id
      (read-secret nix-org-gcal-client-id-file)
      org-gcal-client-secret
      (read-secret nix-org-gcal-client-secret-file)
      org-gcal-fetch-file-alist
      (mapcar
       (lambda (calendar)
         (cons (cdr calendar)
               (expand-file-name
                (format "calendars/%s.org" (car calendar))
                org-directory)))
       nix-email-addresses))

(defun use-org-gcal-account (function username provider)
  "Call FUNCTION with the configured account for the Org-gcal PROVIDER.
Preserve USERNAME for every other OAuth provider."
  (funcall function
           (if (eq provider 'org-gcal)
               nix-google-calendar-account
             username)
           provider))

(after! org-gcal
  (org-gcal-reload-client-id-secret)
  (advice-remove #'oauth2-auto-access-token #'use-org-gcal-account)
  (advice-add #'oauth2-auto-access-token :around #'use-org-gcal-account))

(after! org
  (dolist (calendar org-gcal-fetch-file-alist)
    (add-to-list 'org-agenda-files (cdr calendar) t)))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(defun reject-nested-sudo-tramp (file)
  "Reject applying Doom's sudo transport to an already privileged FILE."
  (when (member (file-remote-p file 'method) '("sudo" "sudoedit"))
    (user-error "File already uses privileged TRAMP: %s" file)))

(advice-add #'doom--sudo-file-path
            :before #'reject-nested-sudo-tramp)

(defun nixos-switch ()
  "Run the local NixOS switch app through sudo TRAMP."
  (interactive)
  (let ((default-directory "/sudo:root@localhost:/etc/nixos/"))
    (compilation-start
     "/run/current-system/sw/bin/nix run -L"
     t
     (lambda (_) "*nixos-switch*"))))
(set-popup-rule! "^\\*nixos-switch\\*$"
  :side 'bottom :size 0.35 :select nil :quit t :ttl nil)

(defun restart-emacs-service ()
  "Restart the user Emacs service from the current NixOS generation.

This intentionally disconnects existing emacsclient frames."
  (interactive)
  (when (yes-or-no-p "Restart Emacs daemon? Existing clients will disconnect. ")
    (save-some-buffers)
    (start-process
     "restart-emacs-service" nil
     "/run/current-system/sw/bin/systemd-run"
     "--user" "--collect" "--unit=restart-emacs-from-emacs"
     "/run/current-system/sw/bin/sh" "-lc"
     "sleep 1; systemctl --user daemon-reload; systemctl --user restart emacs.service")
    (message "Emacs service restart scheduled.")))

(map! :leader
      (:prefix-map ("N" . "NixOS")
       :desc "Switch"                "s" #'nixos-switch
       :desc "Restart Emacs service" "r" #'restart-emacs-service))
