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

NAME="CV Anon ${SUFFIX}"
CODE="CV-ANON-${SUFFIX}"

# Given
cv_step Given "an anonymous visitor with no token, and a product code not yet used" $LINENO
cv_http GET /products 200
[ "$(count_products_named "$NAME")" = "0" ] || cv_fail "expected no product named $NAME before the attempt" $LINENO

# When
cv_step When "the visitor adds a product without signing in" $LINENO
BODY=$(jq -nc --arg n "$NAME" --arg c "$CODE" '{name:$n,description:"anonymous attempt",price:9.99,productCode:$c}')
cv_http POST /products "$BODY"
WHEN_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the request is refused, no product is added, and the product code is still free" $LINENO
case "$WHEN_STATUS" in 2??) cv_fail "expected anonymous product creation to be refused got HTTP $WHEN_STATUS: $CV_HTTP_BODY" $LINENO ;; esac
cv_http GET /products 200
[ "$(count_products_named "$NAME")" = "0" ] || cv_fail "expected no product named $NAME after anonymous attempt got $(count_products_named "$NAME")" $LINENO
N=$(printf "%s" "$CV_HTTP_BODY" | jq --arg c "$CODE" '[.products[] | select((.productCode // .code // .product_code) == $c)] | length')
[ "$N" = "0" ] || cv_fail "expected product code $CODE unused got $N products with it" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the anonymous attempt created nothing" $LINENO
echo "Nothing created"

echo "CODEVALID_TEST_ASSERTION_OK:api_33804615_5"
