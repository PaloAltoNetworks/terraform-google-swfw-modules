#!/bin/bash
set -uo pipefail

# Cloud Asset Inventory is eventually consistent. Google documents that "almost
# all asset updates are available in minutes" but with no hard upper bound, and
# that it "can miss some data updates". Cleanup therefore treats CAI as a signal
# to drain, not a single source of truth, and copes with lag in BOTH directions:
#   - creation lag  -> a resource created just before cleanup may not be indexed
#                      yet, so we keep polling before concluding "nothing here".
#   - deletion lag  -> a resource we already deleted may keep showing up in CAI
#                      for a while, so we track what we deleted and ignore it.

# How long to keep polling for the run's resources to first appear in CAI before
# concluding the project is genuinely empty (seconds), and how often to poll.
DISCOVERY_TIMEOUT=300
DISCOVERY_POLL=30

# Wait between deletion rounds, in seconds. Deletions are asynchronous: a VM
# keeps holding its disk/subnet until it finishes terminating, which can take a
# couple of minutes, so give slow deletes time before retrying dependents.
DELETE_DELAY=60

# Once everything seen has been deleted, re-query this many more times (spaced by
# DELETE_DELAY) confirming nothing new appears, so a resource that indexed late
# (e.g. from a second example that failed moments before cleanup) is still caught.
CONFIRM_EMPTY_ROUNDS=2

# Hard safety cap on deletion rounds, so a resource that can never be deleted
# (e.g. an unmapped service, see get_api_prefix) can't loop us forever.
MAX_ROUNDS=8

if [[ -n "${PR_ID:-}" ]]; then
  SEARCH_QUERY="displayName:ghcip${PR_ID}*"
  echo "Cleaning up resources for PR #${PR_ID} (prefix: ghcip${PR_ID})"
else
  SEARCH_QUERY="displayName:ghcitt*"
  echo "Cleaning up release CI resources (prefix: ghcitt)"
fi

get_api_prefix() {
  local service="$1"
  case "$service" in
    "compute.googleapis.com")          echo "https://compute.googleapis.com/compute/v1" ;;
    "iam.googleapis.com")              echo "https://iam.googleapis.com/v1" ;;
    "pubsub.googleapis.com")           echo "https://pubsub.googleapis.com/v1" ;;
    "secretmanager.googleapis.com")    echo "https://secretmanager.googleapis.com/v1" ;;
    "cloudfunctions.googleapis.com")   echo "https://cloudfunctions.googleapis.com/v2" ;;
    "networksecurity.googleapis.com")  echo "https://networksecurity.googleapis.com/v1" ;;
    "vpcaccess.googleapis.com")        echo "https://vpcaccess.googleapis.com/v1" ;;
    "logging.googleapis.com")          echo "https://logging.googleapis.com/v2" ;;
    *)                                 echo ""; return 1 ;;
  esac
}

delete_resource() {
  local full_name="$1"
  local asset_type="$2"
  local display_name="$3"
  local service path api_prefix url output

  service=$(echo "$full_name" | sed 's|//\([^/]*\)/.*|\1|')
  path=$(echo "$full_name" | sed 's|//[^/]*/||')

  # Service account keys are auto-deleted with their parent service account
  if [[ "$asset_type" == "iam.googleapis.com/ServiceAccountKey" ]]; then
    echo "    Skipped (auto-deleted with service account)"
    return 0
  fi

  # Storage buckets need special handling: empty contents then delete
  if [[ "$asset_type" == "storage.googleapis.com/Bucket" ]]; then
    local bucket_name="${path##*/}"
    output=$(gcloud storage rm -r "gs://${bucket_name}" 2>&1) || {
      handle_delete_error "$output" && return 0
      echo "    $output"; return 1
    }
    return 0
  fi

  api_prefix=$(get_api_prefix "$service")
  if [[ -z "$api_prefix" ]]; then
    echo "  WARNING: Unknown service '${service}' for resource '${display_name}'"
    echo "           Full name: ${full_name}"
    echo "           Manual cleanup may be required."
    return 1
  fi

  url="${api_prefix}/${path}"

  output=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    "$url") || {
    echo "    curl failed for ${url}"
    return 1
  }

  case "$output" in
    200|204)
      return 0
      ;;
    404)
      echo "    Already deleted (not found)"
      return 0
      ;;
    *)
      local body
      body=$(curl -s -X DELETE \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        "$url")
      echo "    HTTP ${output}: $(echo "$body" | jq -r '.error.message // .error.status // "unknown error"' 2>/dev/null || echo "$body")"
      return 1
      ;;
  esac
}

handle_delete_error() {
  local output="$1"
  if echo "$output" | grep -qi "not found\|NOT_FOUND\|notFound"; then
    echo "    Already deleted (not found)"
    return 0
  fi
  return 1
}

query_resources() {
  local result
  result=$(gcloud asset search-all-resources \
    --scope="projects/${PROJECT_ID}" \
    --query="${SEARCH_QUERY}" \
    --format="json(name,assetType,displayName,location)" \
    2>/dev/null || echo "[]")

  # gcloud may emit an empty result AND a non-zero exit (appending a second "[]"),
  # leaving the output with multiple JSON documents. Slurp them into a single
  # array so downstream counts/arithmetic don't receive multi-line values.
  echo "$result" | jq -s 'add // []' 2>/dev/null || echo "[]"
}

# Return the entries from a CAI query that we have NOT already deleted. Filtering
# by our own record of deletions (rather than trusting CAI to drop them) is what
# stops deletion-side lag from stalling the drain loop below.
remaining_resources() {
  query_resources | jq --argjson done "$DELETED_NAMES" \
    '[.[] | select((.name) as $n | ($done | index($n)) | not)]'
}

ACCESS_TOKEN=$(gcloud auth print-access-token)

DELETED_NAMES="[]"   # full names we have successfully deleted (or confirmed gone)
DELETED_COUNT=0
SEEN_ANY=false       # have we ever seen at least one resource?
EMPTY_STREAK=0       # consecutive "nothing left" observations (drain confirmation)
WAITED=0             # seconds spent waiting for resources to first appear
ROUND=0

echo "Querying Cloud Asset Inventory..."

while true; do
  REMAINING=$(remaining_resources)
  COUNT=$(echo "$REMAINING" | jq 'length')

  if [[ "$COUNT" -eq 0 ]]; then
    if [[ "$SEEN_ANY" == false ]]; then
      # Nothing indexed yet. Keep polling within the discovery window before
      # concluding the project is really empty (creation-lag tolerance).
      if [[ "$WAITED" -ge "$DISCOVERY_TIMEOUT" ]]; then
        echo "No resources found after ${DISCOVERY_TIMEOUT}s. Nothing to clean up."
        exit 0
      fi
      echo "Nothing indexed yet (${WAITED}s/${DISCOVERY_TIMEOUT}s). CAI may still be indexing; re-checking in ${DISCOVERY_POLL}s..."
      sleep "$DISCOVERY_POLL"
      WAITED=$((WAITED + DISCOVERY_POLL))
      continue
    fi

    # Everything we saw is gone. Confirm it stays empty a few more times so a
    # late-indexed resource still gets picked up (staggered-indexing tolerance).
    EMPTY_STREAK=$((EMPTY_STREAK + 1))
    if [[ "$EMPTY_STREAK" -ge "$CONFIRM_EMPTY_ROUNDS" ]]; then
      echo "All resources cleaned up (confirmed empty ${CONFIRM_EMPTY_ROUNDS}x)."
      break
    fi
    echo "No resources remaining (confirmation ${EMPTY_STREAK}/${CONFIRM_EMPTY_ROUNDS}); re-checking in ${DELETE_DELAY}s..."
    sleep "$DELETE_DELAY"
    continue
  fi

  SEEN_ANY=true
  EMPTY_STREAK=0
  ROUND=$((ROUND + 1))

  echo ""
  echo "=== Round ${ROUND} (${COUNT} resource(s) to delete) ==="
  echo "$REMAINING" | jq -r '.[] | "  - \(.assetType): \(.displayName) (\(.location))"'

  for i in $(seq 0 $((COUNT - 1))); do
    ENTRY=$(echo "$REMAINING" | jq -c ".[$i]")
    ASSET_TYPE=$(echo "$ENTRY" | jq -r '.assetType')
    FULL_NAME=$(echo "$ENTRY" | jq -r '.name')
    DISPLAY_NAME=$(echo "$ENTRY" | jq -r '.displayName')

    echo "  Deleting ${ASSET_TYPE}: ${DISPLAY_NAME}..."

    if delete_resource "$FULL_NAME" "$ASSET_TYPE" "$DISPLAY_NAME"; then
      echo "    OK"
      DELETED_NAMES=$(echo "$DELETED_NAMES" | jq --arg n "$FULL_NAME" '. + [$n]')
      DELETED_COUNT=$((DELETED_COUNT + 1))
    else
      echo "    FAILED (will retry)"
    fi
  done

  if [[ "$ROUND" -ge "$MAX_ROUNDS" ]]; then
    echo "Reached MAX_ROUNDS (${MAX_ROUNDS}); stopping retries."
    break
  fi

  echo "Waiting ${DELETE_DELAY}s before next round..."
  sleep "$DELETE_DELAY"
done

echo ""
echo "=== Cleanup Summary ==="
echo "Successfully deleted: ${DELETED_COUNT}"

FINAL=$(remaining_resources)
FINAL_REMAINING=$(echo "$FINAL" | jq 'length')
echo "Failed to delete: ${FINAL_REMAINING}"

if [[ "$FINAL_REMAINING" -gt 0 ]]; then
  echo ""
  echo "Resources that could not be deleted:"
  echo "$FINAL" | jq -r '.[] | "  - \(.assetType): \(.displayName)"'
  echo ""
  echo "WARNING: Manual cleanup required for the above resources."
  exit 1
fi
