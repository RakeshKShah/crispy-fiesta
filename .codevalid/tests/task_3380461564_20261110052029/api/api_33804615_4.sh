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

DESC_NONAME="CV no-name ${SUFFIX}"
NAME_NOPRICE="CV NoPrice ${SUFFIX}"

# Given
cv_step Given "a registered, signed-in user" $LINENO
register_user "cv4-${SUFFIX}@example.com"

# When
cv_step When "the user adds one product without a name and one without a price" $LINENO
BODY=$(jq -nc --arg d "$DESC_NONAME" --arg c "CV-NN-${SUFFIX}" '{description:$d,price:12,productCode:$c}')
cv_http POST /products "$BODY" -H "Authorization: Bearer $TOKEN"
STATUS_NONAME="$CV_HTTP_STATUS"
BODY=$(jq -nc --arg n "$NAME_NOPRICE" --arg c "CV-NP-${SUFFIX}" '{name:$n,description:"no price",productCode:$c}')
cv_http POST /products "$BODY" -H "Authorization: Bearer $TOKEN"
STATUS_NOPRICE="$CV_HTTP_STATUS"

# Then
cv_step Then "both requests are refused and neither product is in the catalog" $LINENO
case "$STATUS_NONAME" in 2??) cv_fail "expected product without name to be refused got HTTP $STATUS_NONAME" $LINENO ;; esac
case "$STATUS_NOPRICE" in 2??) cv_fail "expected product without price to be refused got HTTP $STATUS_NOPRICE" $LINENO ;; esac
cv_http GET /products 200
N1=$(printf "%s" "$CV_HTTP_BODY" | jq --arg d "$DESC_NONAME" '[.products[] | select(.description == $d)] | length')
[ "$N1" = "0" ] || cv_fail "expected no product with description $DESC_NONAME got $N1" $LINENO
[ "$(count_products_named "$NAME_NOPRICE")" = "0" ] || cv_fail "expected no product named $NAME_NOPRICE got $(count_products_named "$NAME_NOPRICE")" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and the API has no delete route" $LINENO
echo "No delete endpoint exists; test data uses unique suffix ${SUFFIX}"

echo "CODEVALID_TEST_ASSERTION_OK:api_33804615_4"
