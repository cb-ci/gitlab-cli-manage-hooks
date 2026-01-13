#!/bin/bash

source ./set-env.sh

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ ERROR: 'jq' is not installed. Please install it to use this script."
    exit 1
fi

echo "--------------------------------------------------"
echo "Fetching Reference Hook Config..."
echo "Reference Project: $REFERENCE_PROJECT"
echo "Reference URL:     $WEBHOOK_REFERENCE_URL"

# 1. Get Reference Hook Config
ENCODED_REF_PROJECT=$(echo "$REFERENCE_PROJECT" | sed 's/\//%2F/g')
REF_HOOKS_JSON=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$API_URL/projects/$ENCODED_REF_PROJECT/hooks")

# Check if we got a valid JSON response
if echo "$REF_HOOKS_JSON" | grep -q "404"; then
    echo "❌ ERROR: Reference project not found (404)."
    exit 1
fi

# Extract the payload from the reference hook
# We construct the payload for the target hooks here.
# Note: We use $WEBHOOK_TARGET as the 'url' for the new hook, but copy permissions from the reference.
HOOK_PAYLOAD=$(echo "$REF_HOOKS_JSON" | jq -c --arg url "$WEBHOOK_REFERENCE_URL" --arg target_url "$WEBHOOK_TARGET" --arg secret "$WEBHOOK_SECRET" '
  .[] | select(.url == $url) | 
  {
    url: $target_url,
    push_events,
    tag_push_events,
    merge_requests_events,
    repository_update_events,
    enable_ssl_verification,
    issues_events,
    confidential_issues_events,
    note_events,
    confidential_note_events,
    pipeline_events,
    wiki_page_events,
    deployment_events,
    job_events,
    releases_events
  } + (if $secret != "" then {token: $secret} else {} end)
')

if [ -z "$HOOK_PAYLOAD" ]; then
    echo "❌ ERROR: Could not find reference hook with URL '$WEBHOOK_REFERENCE_URL' in project '$REFERENCE_PROJECT'."
    exit 1
fi

echo "✅ Reference config loaded."
echo "--------------------------------------------------"

for PROJECT in "${PROJECTS[@]}"
do
    echo "Processing Project: $PROJECT"
    ENCODED_PROJECT=$(echo "$PROJECT" | sed 's/\//%2F/g')

    # 2. Check for existing hook in the target project
    LIST_RESPONSE=$(curl --silent --write-out "\n%{http_code}" \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$API_URL/projects/$ENCODED_PROJECT/hooks")
    
    LIST_STATUS=$(echo "$LIST_RESPONSE" | tail -n1)
    LIST_BODY=$(echo "$LIST_RESPONSE" | sed '$d')

    if [ "$LIST_STATUS" -ne 200 ]; then
        echo "⚠️ FAILED to list hooks for $PROJECT (Status: $LIST_STATUS). Skipping."
        continue
    fi

    # Find if the target hook already exists
    EXISTING_HOOK_ID=$(echo "$LIST_BODY" | jq -r --arg url "$WEBHOOK_TARGET" '.[] | select(.url == $url) | .id')

    if [ -n "$EXISTING_HOOK_ID" ] && [ "$EXISTING_HOOK_ID" != "null" ]; then
        echo "ℹ️ Hook exists (ID: $EXISTING_HOOK_ID). Updating..."
        
        # 3. Update existing hook (PUT)
        UPDATE_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
            --request PUT \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --header "Content-Type: application/json" \
            --data "$HOOK_PAYLOAD" \
            "$API_URL/projects/$ENCODED_PROJECT/hooks/$EXISTING_HOOK_ID")

        if [ "$UPDATE_STATUS" -eq 200 ]; then
            echo "✅ SUCCESS: Hook updated."
        else
            echo "❌ ERROR: Failed to update hook (Status: $UPDATE_STATUS)."
        fi
    else
        echo "ℹ️ Hook does not exist. Creating..."
        
        # 4. Create new hook (POST)
        CREATE_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
            --request POST \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --header "Content-Type: application/json" \
            --data "$HOOK_PAYLOAD" \
            "$API_URL/projects/$ENCODED_PROJECT/hooks")

        if [ "$CREATE_STATUS" -eq 201 ]; then
            echo "✅ SUCCESS: Hook added."
        else
            echo "❌ ERROR: Failed to create hook (Status: $CREATE_STATUS)."
        fi
    fi
    echo "--------------------------------------------------"
done

echo "Done."
