#!/bin/bash

# Ensure the following is executed as if this script was in
# the project root.
#
# Note: The main reason for doing this is to simplify the
#       output and also have it relative to the project root.

cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
    && . "./scripts/utils/check_markdown_files.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_links() (

    local attempt=1
    local max_attempts=3

    # GitHub occasionally answers 503 for a live URL. Retry the file
    # before treating that as a broken link.
    while [ "$attempt" -le "$max_attempts" ]; do
        if npx markdown-link-check@3.14.1 \
            --config ./scripts/check_links/configs.json \
            --retry \
                "$1"; then
            return 0
        fi

        if [ "$attempt" -eq "$max_attempts" ]; then
            return 1
        fi

        printf 'link check failed for %s (attempt %s); retrying\n' "$1" "$attempt" >&2
        attempt=$((attempt + 1))
        sleep 15
    done

)

check_markdown_files \
    "." \
    check_links
