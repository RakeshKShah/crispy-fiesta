#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv_catalog_${SUFFIX}@example.com"
PASSWORD="Passw0rd!${SUFFIX}"

register_user() {
  cv_http POST /auth/register "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"CV Catalog $SUFFIX\"}"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from register got $CV_HTTP_STATUS" $LINENO
  TOKEN=$(echo "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected token in register response got none" $LINENO
}

create_product() {
  cv_http POST /products "{\"name\":\"CV Product $SUFFIX\",\"description\":\"Desc $SUFFIX\",\"price\":19.99}" -H "Authorization: Bearer $TOKEN"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product got $CV_HTTP_STATUS" $LINENO
  PRODUCT_ID=$(echo "$CV_HTTP_BODY" | jq -r ".product.id // empty")
  [ -n "$PRODUCT_ID" ] || cv_fail "expected product id in create response got none" $LINENO
}

# product code may be exposed as code / productCode / product_code
CODE_JQ="(.code // .productCode // .product_code)"

# Given
cv_step Given "a registered user has added a product to the catalog" $LINENO
register_user
create_product

# When
cv_step When "an anonymous visitor requests the catalog without any token" $LINENO
cv_http GET /products

# Then
cv_step Then "the full catalog is returned with name, description, price and product code for every product" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 for anonymous catalog got $CV_HTTP_STATUS" $LINENO
echo "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected products array got $CV_HTTP_BODY" $LINENO
ENTRY=$(echo "$CV_HTTP_BODY" | jq -c --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)')
[ -n "$ENTRY" ] || cv_fail "expected product $PRODUCT_ID in catalog got none" $LINENO
[ "$(echo "$ENTRY" | jq -r .name)" = "CV Product $SUFFIX" ] || cv_fail "expected name 'CV Product $SUFFIX' got $(echo "$ENTRY" | jq -r .name)" $LINENO
[ "$(echo "$ENTRY" | jq -r .description)" = "Desc $SUFFIX" ] || cv_fail "expected description 'Desc $SUFFIX' got $(echo "$ENTRY" | jq -r .description)" $LINENO
[ "$(echo "$ENTRY" | jq -r '.price == 19.99')" = "true" ] || cv_fail "expected price 19.99 got $(echo "$ENTRY" | jq -r .price)" $LINENO
MISSING=$(echo "$CV_HTTP_BODY" | jq "[.products[] | select((.name|type) != \"string\" or (.description|type) != \"string\" or (.price|type) != \"number\" or ($CODE_JQ) == null)] | length")
[ "$MISSING" = "0" ] || cv_fail "expected every catalog product to have name, description, price and product code got $MISSING product(s) missing a field, e.g. $ENTRY" $LINENO

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:api_43736470_1"
