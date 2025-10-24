#!/usr/bin/env bash
#
# oidc-token-decode.sh - Decode OIDC token claims from current kubectl context
#
# Usage:
#   ./oidc-token-decode.sh
#
# Description:
#   Retrieves the OIDC token from kubectl oidc-login using the current context's
#   configuration and decodes the JWT claims.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current context
CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
if [[ -z "$CONTEXT" ]]; then
    echo -e "${RED}❌ Error: No current kubectl context set${NC}"
    echo -e "   Switch to an OIDC context first:"
    echo -e "   kubectl config use-context osp-openportal-oidc"
    exit 1
fi

echo -e "${BLUE}🔐 Fetching OIDC token for context: $CONTEXT${NC}"

# Get the user for this context
USER=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$CONTEXT')].context.user}" 2>/dev/null)
if [[ -z "$USER" ]]; then
    echo -e "${RED}❌ Error: Could not find user for context '$CONTEXT'${NC}"
    exit 1
fi

echo -e "   User: $USER"

# Check if user has exec configuration (OIDC)
HAS_EXEC=$(kubectl config view -o jsonpath="{.users[?(@.name=='$USER')].user.exec}" 2>/dev/null)
if [[ -z "$HAS_EXEC" ]]; then
    echo -e "${RED}❌ Error: User '$USER' does not use exec authentication (not OIDC)${NC}"
    echo -e "   This script only works with OIDC contexts that use kubectl oidc-login"
    exit 1
fi

# Check if it's using oidc-login
EXEC_COMMAND=$(kubectl config view -o jsonpath="{.users[?(@.name=='$USER')].user.exec.command}" 2>/dev/null)
EXEC_ARGS=$(kubectl config view -o jsonpath="{.users[?(@.name=='$USER')].user.exec.args}" 2>/dev/null)

if [[ "$EXEC_COMMAND" != "kubectl" ]] || [[ ! "$EXEC_ARGS" =~ "oidc-login" ]]; then
    echo -e "${RED}❌ Error: User '$USER' does not use kubectl oidc-login${NC}"
    exit 1
fi

echo -e "   Auth: OIDC (kubectl oidc-login) ${GREEN}✓${NC}"

# Extract the args array and build the command
# The args are stored as a JSON array, so we parse them
ARGS_JSON=$(kubectl config view -o json | jq -r ".users[] | select(.name==\"$USER\") | .user.exec.args")

# Build the kubectl oidc-login command from the args
CMD="kubectl oidc-login get-token"
while IFS= read -r arg; do
    # Skip the "oidc-login" and "get-token" args if they exist
    if [[ "$arg" != "oidc-login" ]] && [[ "$arg" != "get-token" ]]; then
        CMD="$CMD $arg"
    fi
done < <(echo "$ARGS_JSON" | jq -r '.[]')

echo -e "   Running token fetch..."

# Get the token
TOKEN_JSON=$(eval "$CMD")

# Extract the JWT token
JWT_TOKEN=$(echo "$TOKEN_JSON" | jq -r '.status.token')

# Split the JWT and get the payload (middle part)
PAYLOAD=$(echo "$JWT_TOKEN" | awk -F. '{print $2}')

# JWT uses base64url encoding without padding
# Add padding if needed for standard base64 decoding
PAYLOAD_PADDED="$PAYLOAD"
while [ $((${#PAYLOAD_PADDED} % 4)) -ne 0 ]; do
    PAYLOAD_PADDED="${PAYLOAD_PADDED}="
done

# Decode the base64 payload (convert base64url to base64 first)
echo ""
echo "📋 Token Claims:"
echo ""
echo "$PAYLOAD_PADDED" | tr '_-' '/+' | base64 -d 2>/dev/null | jq .

echo ""
echo -e "${BLUE}⏰ Token Expiration:${NC}"
EXP=$(echo "$PAYLOAD_PADDED" | tr '_-' '/+' | base64 -d 2>/dev/null | jq -r '.exp')
if command -v gdate &> /dev/null; then
    # Use gdate if available (macOS with coreutils)
    echo -e "   $(gdate -d "@$EXP" 2>/dev/null || echo "Timestamp: $EXP")"
elif command -v date &> /dev/null; then
    # Try standard date command
    echo -e "   $(date -r "$EXP" 2>/dev/null || echo "Timestamp: $EXP")"
else
    echo -e "   Timestamp: $EXP"
fi

echo ""
echo -e "${GREEN}✅ Token successfully decoded from context: $CONTEXT${NC}"
