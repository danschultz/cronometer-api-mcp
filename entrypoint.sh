#!/bin/sh
set -eu

# Supported _FILE variables for Docker Secrets.
# For each FOO_FILE:FOO pair, if FOO_FILE is set, reads the file and exports
# FOO=<content>. If both FOO and FOO_FILE are set, FOO takes precedence.
FILE_VARS="
CRONOMETER_USERNAME_FILE:CRONOMETER_USERNAME
CRONOMETER_PASSWORD_FILE:CRONOMETER_PASSWORD
CRONOMETER_TOTP_SECRET_FILE:CRONOMETER_TOTP_SECRET
"

for entry in $FILE_VARS; do
    file_var="${entry%%:*}"
    target="${entry##*:}"
    eval "file_path=\${$file_var:-}"
    eval "current=\${$target:-}"

    [ -z "$file_path" ] && continue

    if [ -n "$current" ]; then
        echo >&2 "[entrypoint] ${target} already set; ignoring ${file_var}"
        continue
    fi

    if [ -f "$file_path" ]; then
        value=$(cat "$file_path")
        export "$target=$value"
        unset "$file_var"
        echo >&2 "[entrypoint] Loaded Docker Secret: ${target}"
    else
        echo >&2 "[entrypoint] Error: Secret file not found: ${file_path} (for ${file_var})"
        exit 1
    fi
done

# Default CMD serves the MCP over streamable HTTP; pass another command to run
# it instead.
exec "$@"
