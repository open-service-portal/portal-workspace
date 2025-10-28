#!/usr/bin/env bash
exec node "$(dirname "$0")/../oidc-authenticator/bin/cli.js" "$@"
