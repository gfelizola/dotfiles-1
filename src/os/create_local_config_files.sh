#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

create_bash_local() {

    declare -r FILE_PATH="$HOME/.bash.local"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

   if [ ! -e "$FILE_PATH" ] || [ -z "$FILE_PATH" ]; then

        DOTFILES_BIN_DIR="$(dirname "$(pwd)")/bin/"

        printf "%s\n" \
"#!/bin/bash

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set PATH additions.

PATH=\"$DOTFILES_BIN_DIR:\$PATH\"

export PATH" \
        >> "$FILE_PATH"
   fi

    print_result $? "$FILE_PATH"

}

create_gitconfig_local() {

    declare -r FILE_PATH="$HOME/.gitconfig.local"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    if [ ! -e "$FILE_PATH" ] || [ -z "$FILE_PATH" ]; then

        cat >> "$FILE_PATH" <<'EOF'
# Machine-local Git settings. ~/.gitconfig includes this file last and
# stays portable. Put anything that only belongs on this computer here:
#
# [safe]
#     directory = /path/to/a/checkout
#
# [http]
#     postBuffer = 524288000
#     version = HTTP/1.1
#
# [credential]
#     helper = ~/.local/bin/origin

[commit]

    # Sign commits using GPG.
    # https://help.github.com/articles/signing-commits-using-gpg/

    # gpgsign = true


[user]

    name =
    email =
    # signingkey =

# Per-folder identities. The shared config sets user.useConfigOnly
# and does not store a global name or email, so each tree that needs
# a different identity includes its own file. Paths and addresses
# below are placeholders. Uncomment a block, point gitdir at a real
# checkout, and create the included file locally. Do not commit a
# real email.
#
# Personal GitHub identity (~/.gitconfig.personal):
# [user]
#     name = Your Name
#     email = personal@example.com
#
# [includeIf "gitdir:~/projects/personal/"]
#     path = ~/.gitconfig.personal
#
# Work identity, Trino (~/.gitconfig.work):
# [user]
#     name = Your Name
#     email = work@example.com
#
# [includeIf "gitdir:~/projects/trino/"]
#     path = ~/.gitconfig.work
EOF
    fi

    print_result $? "$FILE_PATH"

}

create_vimrc_local() {

    declare -r FILE_PATH="$HOME/.vimrc.local"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    if [ ! -e "$FILE_PATH" ]; then
        printf "" >> "$FILE_PATH"
    fi

    print_result $? "$FILE_PATH"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    print_in_purple "\n • Create local config files\n\n"

    create_bash_local
    create_gitconfig_local
    create_vimrc_local

}

main
