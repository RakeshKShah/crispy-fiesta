#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
PASSWORD="Passw0rd-${SUFFIX}"

register_user() {
  # $1 = email; sets TOKEN
  local body
  body=$(jq -nc --arg e "$1" --arg p "$PASSWORD" '{email:$e,password:$p,name:"CV Tester"}')
  cv_http POST /auth/register "$body" 201
  TOKEN=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected token from /auth/register got none" $LINENO
}

count_products_named() {
  # $1 = name; uses CV_HTTP_BODY from GET /products
  printf "%s" "$CV_HTTP_BODY" | jq --arg n "$1" "[.products[] | select(.name == \$n)] | length"
}

NAME="CV NoCode ${SUFFIX}"

# Given
cv_step Given "a registered, signed-in user" $LINENO
register_user "cv3-${SUFFIX}@example.com"

# When
cv_step When "the user adds a product with name, description and price but no product code" $LINENO
BODY=$(jq -nc --arg n "$NAME" '{name:$n,description:"no code given",price:5.5}')
cv_http POST /products "$BODY" -H "Authorization: Bearer $TOKEN"
WHEN_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the request is refused and no product is added to the catalog" $LINENO
case "$WHEN_STATUS" in 2??) cv_fail "expected product without product code to be refused got HTTP $WHEN_STATUS" $LINENO ;; esac
cv_http GET /products 200
[ "$(count_products_named "$NAME")" = "0" ] || cv_fail "expected no product named $NAME got $(count_products_named "$NAME")" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and the API has no delete route" $LINENO
echo "No delete endpoint exists; test data uses unique suffix ${SUFFIX}"

echo "CODEVALID_TEST_ASSERTION_OK:api_33804615_3"
