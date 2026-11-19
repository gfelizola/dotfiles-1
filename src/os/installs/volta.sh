#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

add_configs() {
    # Check if the configs need to be added.
    if command -v volta &> /dev/null; then
        return
    fi

    update_local_shell_configs "export PATH=\"\$HOME/.volta/bin:\$PATH\" # Volta"
}

install() {
    execute \
        "curl https://get.volta.sh | bash -s -- --skip-setup" \
        "Install"
}

install_node() {

    # Install Node.js LTS.
    # Note: This will also set it as the default.
    #
    # Do not `volta install yarn`, bun, or pnpm. Volta's Yarn shim is
    # broken. Node stays here. Bun is the official installer and pnpm
    # is Homebrew's keg-only pnpm@10.

    execute "volta install node" \
        "Install Node.js LTS"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    print_in_purple "\n   Volta\n\n"

    install
    add_configs
    install_node

}

main
