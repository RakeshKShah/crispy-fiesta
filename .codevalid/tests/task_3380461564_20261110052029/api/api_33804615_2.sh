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

NAME1="CV Original ${SUFFIX}"
NAME2="CV Duplicate ${SUFFIX}"
CODE="CV-DUP-${SUFFIX}"

# Given
cv_step Given "a signed-in user and an existing product that owns a product code" $LINENO
register_user "cv2-${SUFFIX}@example.com"
BODY=$(jq -nc --arg n "$NAME1" --arg c "$CODE" '{name:$n,description:"original",price:10,productCode:$c}')
cv_http POST /products "$BODY" 201 -H "Authorization: Bearer $TOKEN"
PID1=$(printf "%s" "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID1" ] || cv_fail "expected id of the existing product got none" $LINENO

# When
cv_step When "the user adds another product with the same product code" $LINENO
BODY=$(jq -nc --arg n "$NAME2" --arg c "$CODE" '{name:$n,description:"duplicate",price:25,productCode:$c}')
cv_http POST /products "$BODY" -H "Authorization: Bearer $TOKEN"
WHEN_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the duplicate is refused, not in the catalog, and the original is unchanged" $LINENO
case "$WHEN_STATUS" in 2??) cv_fail "expected duplicate product code to be refused got HTTP $WHEN_STATUS" $LINENO ;; esac
cv_http GET /products 200
[ "$(count_products_named "$NAME2")" = "0" ] || cv_fail "expected no product named $NAME2 got $(count_products_named "$NAME2")" $LINENO
cv_http GET "/products/$PID1" 200
printf "%s" "$CV_HTTP_BODY" | jq -e --arg n "$NAME1" '.product.name == $n and .product.description == "original" and .product.price == 10' >/dev/null   || cv_fail "expected original product unchanged got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and the API has no delete route" $LINENO
echo "No delete endpoint exists; test data uses unique suffix ${SUFFIX}"

echo "CODEVALID_TEST_ASSERTION_OK:api_33804615_2"
