#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   GPG\n\n"

# Not installed on the owner's Mac. Left commented so a fresh setup
# does not bring them back.
# brew_install "GPG" "gpg"
# brew_install "Pinentry" "pinentry-mac"
printf "jump installation of GPG tools"
printf "\n"
