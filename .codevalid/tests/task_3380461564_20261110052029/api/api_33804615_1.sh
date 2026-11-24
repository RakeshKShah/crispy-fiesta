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

NAME="CV Widget ${SUFFIX}"
DESC="A widget for testing ${SUFFIX}"
PRICE=19.99
CODE="CV-${SUFFIX}"

# Given
cv_step Given "a registered, signed-in user and an unused product code" $LINENO
register_user "cv1-${SUFFIX}@example.com"

# When
cv_step When "the signed-in user adds a product with name, description, price and product code" $LINENO
BODY=$(jq -nc --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" --arg c "$CODE" '{name:$n,description:$d,price:$p,productCode:$c}')
cv_http POST /products "$BODY" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product got $CV_HTTP_STATUS" $LINENO
PID=$(printf "%s" "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in create response got none" $LINENO

# Then
cv_step Then "reading the product back returns the same name, description, price and product code" $LINENO
cv_http GET "/products/$PID" 200
P=$(printf "%s" "$CV_HTTP_BODY" | jq -c '.product')
[ "$(printf "%s" "$P" | jq -r '.name')" = "$NAME" ] || cv_fail "expected name $NAME got $(printf "%s" "$P" | jq -r '.name')" $LINENO
[ "$(printf "%s" "$P" | jq -r '.description')" = "$DESC" ] || cv_fail "expected description $DESC got $(printf "%s" "$P" | jq -r '.description')" $LINENO
printf "%s" "$P" | jq -e --argjson p "$PRICE" '.price == $p' >/dev/null || cv_fail "expected price $PRICE got $(printf "%s" "$P" | jq -r '.price')" $LINENO
GOT_CODE=$(printf "%s" "$P" | jq -r '.productCode // .code // .product_code // empty')
[ "$GOT_CODE" = "$CODE" ] || cv_fail "expected product code $CODE in stored product got '$GOT_CODE' (product: $P)" $LINENO
cv_http GET /products 200
[ "$(count_products_named "$NAME")" = "1" ] || cv_fail "expected product listed once in catalog got $(count_products_named "$NAME")" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and the API has no delete route" $LINENO
echo "No delete endpoint exists; test data uses unique suffix ${SUFFIX}"

echo "CODEVALID_TEST_ASSERTION_OK:api_33804615_1"
