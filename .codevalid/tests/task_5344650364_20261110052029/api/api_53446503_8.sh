#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" --arg n "CV User $SUFFIX" "{email:\$e,password:\$p,name:\$n}")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}

EMAIL="cv_owner_${SUFFIX}@example.com"; PASSWORD="CvPass-${SUFFIX}"; ANON_NAME="CV Anon Attempt $SUFFIX"
# Given
cv_step Given "a signed-in owner has a product in the catalog; an anonymous visitor has no token" $LINENO
register_user "$EMAIL" "$PASSWORD"
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
cv_http POST /products "$(jq -nc --arg n "CV Owner Item $SUFFIX" '{name:$n,price:3}')" 201 -H "Authorization: Bearer $TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')
cv_http GET /products 200
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.products | sort_by(.id)')
# When
cv_step When "the anonymous visitor tries to add a product without signing in" $LINENO
cv_http POST /products "$(jq -nc --arg n "$ANON_NAME" '{name:$n,price:1}')"
ANON_STATUS=$CV_HTTP_STATUS
# Then
cv_step Then "the attempt is refused and the catalog is unchanged" $LINENO
case "$ANON_STATUS" in 2*) cv_fail "anonymous product creation was accepted ($ANON_STATUS)" $LINENO ;; esac
cv_http GET /products 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg n "$ANON_NAME" '.products | any(.name==$n) | not' >/dev/null || cv_fail "anonymous product $ANON_NAME appears in the catalog" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" '.products | any(.id==$id and .price==3)' >/dev/null || cv_fail "owner product $PID changed or missing" $LINENO
# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_8"
