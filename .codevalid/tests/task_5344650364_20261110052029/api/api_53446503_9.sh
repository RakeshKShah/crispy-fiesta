#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
b64url() { printf '%s' "$1" | base64 | tr -d '=\n' | tr '/+' '_-'; }
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}
EMAIL="cv_forge_${SUFFIX}@example.com"; PASSWORD="CvPass-${SUFFIX}"
PREFIX="CV forged $SUFFIX"

# Given
cv_step Given "a registered customer with a genuine token, and forged/altered tokens derived from it" $LINENO
register_user "$EMAIL" "$PASSWORD"
REAL_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$REAL_TOKEN" ] && [ -n "$USER_ID" ] || cv_fail "expected token and user id from register got $CV_HTTP_BODY" $LINENO
IFS='.' read -r H P S <<<"$REAL_TOKEN"
[ -n "$S" ] || cv_fail "expected a three-part token got $REAL_TOKEN" $LINENO
NOW=$(date +%s)
NONE_TOKEN="$(b64url '{"alg":"none","typ":"JWT"}').$(b64url "{\"sub\":\"$USER_ID\",\"email\":\"$EMAIL\",\"iat\":$NOW}")."
ALTERED_PAYLOAD="$(b64url "{\"sub\":\"$USER_ID\",\"email\":\"attacker_${SUFFIX}@example.com\",\"iat\":$NOW,\"exp\":$((NOW+86400))}")"
ALTERED_TOKEN="$H.$ALTERED_PAYLOAD.$S"
if [ "${S: -1}" = "A" ]; then BADSIG="${S%?}B"; else BADSIG="${S%?}A"; fi
BADSIG_TOKEN="$H.$P.${BADSIG:0:5}xyzQ${BADSIG:9}"
GARBAGE_TOKEN="not-a-real-token-$SUFFIX"

# When
cv_step When "forged, altered and never-issued tokens are presented to add a product" $LINENO
STATUSES=()
i=0
for T in "$NONE_TOKEN" "$ALTERED_TOKEN" "$BADSIG_TOKEN" "$GARBAGE_TOKEN"; do
  i=$((i+1))
  cv_http POST /products "$(jq -nc --arg n "$PREFIX #$i" '{name:$n,price:5}')" -H "Authorization: Bearer $T"
  STATUSES+=("$CV_HTTP_STATUS")
done

# Then
cv_step Then "every attempt is refused and the catalog contains none of the attempted products" $LINENO
for idx in "${!STATUSES[@]}"; do
  case "${STATUSES[$idx]}" in
    2*) cv_fail "expected forged token #$((idx+1)) to be refused got ${STATUSES[$idx]}" $LINENO ;;
  esac
done
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 listing products got $CV_HTTP_STATUS" $LINENO
LEAKED=$(printf '%s' "$CV_HTTP_BODY" | jq --arg p "$PREFIX" '[.products[] | select(.name | startswith($p))] | length')
[ "$LEAKED" = "0" ] || cv_fail "expected no products created with forged tokens got $LEAKED" $LINENO

# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist, unique data left in place" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_9"
