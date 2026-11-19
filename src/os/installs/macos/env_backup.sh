#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Env backup\n\n"

# age encrypts dotenv snapshots. The private key stays in the
# login keychain; this install does not generate one.
brew_install "age" "age" \
    || true

if [ -x "../../../bin/env-backup" ]; then

    if "../../../bin/env-backup" install-agent; then
        print_success "LaunchAgent (env-backup)"
    else
        print_error "LaunchAgent (env-backup)" "run env-backup install-agent after setup"
    fi

fi
