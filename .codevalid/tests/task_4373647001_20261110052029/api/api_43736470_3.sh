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
cv_step Given "a registered user has added a product and its catalog entry is known" $LINENO
register_user
create_product
cv_http GET /products 200
CATALOG_ENTRY=$(echo "$CV_HTTP_BODY" | jq -c --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)')
[ -n "$CATALOG_ENTRY" ] || cv_fail "expected product $PRODUCT_ID in catalog got none" $LINENO

# When
cv_step When "an anonymous visitor opens the product by its identifier" $LINENO
cv_http GET "/products/$PRODUCT_ID"

# Then
cv_step Then "the product is returned with name, description, price and product code matching its catalog entry" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 opening product anonymously got $CV_HTTP_STATUS" $LINENO
P=$(echo "$CV_HTTP_BODY" | jq -c '.product // empty')
[ -n "$P" ] || cv_fail "expected product object got $CV_HTTP_BODY" $LINENO
[ "$(echo "$P" | jq -r .id)" = "$PRODUCT_ID" ] || cv_fail "expected id $PRODUCT_ID got $(echo "$P" | jq -r .id)" $LINENO
[ "$(echo "$P" | jq -r .name)" = "CV Product $SUFFIX" ] || cv_fail "expected name 'CV Product $SUFFIX' got $(echo "$P" | jq -r .name)" $LINENO
[ "$(echo "$P" | jq -r .description)" = "Desc $SUFFIX" ] || cv_fail "expected description 'Desc $SUFFIX' got $(echo "$P" | jq -r .description)" $LINENO
[ "$(echo "$P" | jq -r '.price == 19.99')" = "true" ] || cv_fail "expected price 19.99 got $(echo "$P" | jq -r .price)" $LINENO
for f in name description price; do
  A=$(echo "$P" | jq -c ".$f"); B=$(echo "$CATALOG_ENTRY" | jq -c ".$f")
  [ "$A" = "$B" ] || cv_fail "expected $f to match catalog entry ($B) got $A" $LINENO
done
CODE=$(echo "$P" | jq -c "$CODE_JQ")
[ "$CODE" != "null" ] || cv_fail "expected product to include a product code got none in $P" $LINENO
[ "$CODE" = "$(echo "$CATALOG_ENTRY" | jq -c "$CODE_JQ")" ] || cv_fail "expected product code to match catalog entry got $CODE" $LINENO

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:api_43736470_3"
