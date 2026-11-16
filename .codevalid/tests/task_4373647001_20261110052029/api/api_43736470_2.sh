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
cv_step Given "a signed-in user exists, a product is in the catalog, and the anonymous catalog is captured" $LINENO
register_user
create_product
cv_http GET /products 200
ANON=$(echo "$CV_HTTP_BODY" | jq -S '.products | sort_by(.id)')
echo "$ANON" | jq -e --arg id "$PRODUCT_ID" 'any(.[]; .id == $id)' >/dev/null || cv_fail "expected product $PRODUCT_ID in anonymous catalog got none" $LINENO

# When
cv_step When "the signed-in user requests the catalog with their bearer token" $LINENO
cv_http GET /products -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the signed-in catalog is identical to the anonymous catalog" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 for signed-in catalog got $CV_HTTP_STATUS" $LINENO
AUTHED=$(echo "$CV_HTTP_BODY" | jq -S '.products | sort_by(.id)')
[ "$(echo "$AUTHED" | jq length)" = "$(echo "$ANON" | jq length)" ] || cv_fail "expected $(echo "$ANON" | jq length) products as anonymous got $(echo "$AUTHED" | jq length)" $LINENO
[ "$AUTHED" = "$ANON" ] || cv_fail "expected signed-in catalog to equal anonymous catalog got a different set: $AUTHED" $LINENO

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:api_43736470_2"
