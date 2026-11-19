#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Image Tools\n\n"

# brew_install "ImageMagick" "imagemagick"

# Not installed on the owner's Mac. Left commented so a fresh setup
# does not bring them back.
# brew_install "ImageOptim" "imageoptim" "--cask"
# brew_install "pngquant" "pngquant"
brew_install "inkscape" "inkscape"

printf "jump installation of Image Tools"
printf "\n"
