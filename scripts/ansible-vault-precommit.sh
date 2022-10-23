#!/usr/bin/env bash

if ! GITROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    error "We do not seem to be running in a git repository"
    _safeExit_ 1
fi

FILES_PATTERN='.*vault.*\.ya?ml$'
REQUIRED='ANSIBLE_VAULT'

EXIT_STATUS=0
wipe="\033[1m\033[0m"
yellow='\033[1;33m'
# carriage return hack. Leave it on 2 lines.
cr='
'
for f in $(git diff --cached --name-only | grep -E "${FILES_PATTERN}"); do
    # test for the presence of the required bit.
    MATCH="$(head -n1 "${GITROOT}/${f}" | grep --no-messages "${REQUIRED}")"
    echo "$MATCH"
    if [ ! "${MATCH}" ]; then
        # Build the list of unencrypted files if any
        UNENCRYPTED_FILES="${f}${cr}${UNENCRYPTED_FILES}"
        EXIT_STATUS=1
    fi
done
if [ ! $EXIT_STATUS = 0 ]; then
    echo '# COMMIT REJECTED'
    echo '# Looks like unencrypted ansible-vault files are part of the commit:'
    echo '#'
    while read -r line; do
        if [ -n "${line}" ]; then
            echo -e "#\t${yellow}unencrypted:   ${line}${wipe}"
        fi
    done <<<"${UNENCRYPTED_FILES}"
    echo '#'
    echo "# Please encrypt them with 'ansible-vault encrypt <file>'"
    echo "#   (or force the commit with '--no-verify')."
    exit $EXIT_STATUS
fi
exit $EXIT_STATUS
