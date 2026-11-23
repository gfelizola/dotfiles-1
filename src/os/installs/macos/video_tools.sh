#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Video Tools\n\n"

# Not installed on the owner's Mac. Left commented so a fresh setup
# does not bring it back.
# brew_install "AtomicParsley" "atomicparsley"

# brew_install "FFmpeg" "ffmpeg"
