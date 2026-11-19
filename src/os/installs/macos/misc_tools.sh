#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Miscellaneous Tools\n\n"

# Not installed on the owner's Mac. Left commented so a fresh setup
# does not bring them back.
# brew_install "eyeD3" "eye-d3"
# brew_install "pdfcpu" "pdfcpu"

# ShellCheck is installed by CI, not as part of the desktop setup.
# brew_install "ShellCheck" "shellcheck"

# Yarn via Homebrew is not used. Volta's Yarn shim is broken; this
# machine uses Node (Volta) plus bun and pnpm.
# brew_install "Yarn" "yarn"
