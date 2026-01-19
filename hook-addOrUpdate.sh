#!/bin/bash

source ./set-env.sh
#set -x
# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ ERROR: 'jq' is not installed. Please install it to use this script."
    exit 1
fi

echo "✅ Reference config loaded."
echo "--------------------------------------------------"

# Create the payload
createPayLoad() {
    local list_body="$1"
    local hook_payload

    # The default payload, if no WEBHOOK_REFERENCE_URL is set
    hook_payload=$(jq -n \
        --arg url "$WEBHOOK_TARGET" \
        '{url: $url, push_events: true}')
    
    # If a reference WEBHOOK_REFERENCE_URL is set, copy permissions from it
    if [ ! -z "$WEBHOOK_REFERENCE_URL" ]; then
        echo -n "✅ Reference URL set to $WEBHOOK_REFERENCE_URL." >&2
        echo "" >&2
        hook_payload=$(echo "$list_body" | jq -c --arg url "$WEBHOOK_REFERENCE_URL" --arg target_url "$WEBHOOK_TARGET" '
                .[] | select(.url == $url) | 
                {
                    url: $target_url,
                    push_events,
                    tag_push_events,
                    merge_requests_events,
                    repository_update_events,
                    enable_ssl_verification,
                    alert_status,
                    disabled_until,
                    push_events_branch_filter,
                    branch_filter_strategy,
                    custom_webhook_template,
                    project_id,
                    issues_events,
                    confidential_issues_events,
                    note_events,
                    confidential_note_events,
                    pipeline_events,
                    wiki_page_events,
                    deployment_events,
                    feature_flag_events,
                    job_events,
                    releases_events,
                    milestone_events,
                    emoji_events,
                    resource_access_token_events,
                    vulnerability_events
                }
                ')
    fi

    # Add secret if WEBHOOK_SECRET set
    hook_payload=$(echo "$hook_payload" | jq --arg secret "$WEBHOOK_SECRET" '. + (if $secret != "" then {token: $secret} else {} end)')

    echo "$hook_payload"
}

for PROJECT in "${PROJECTS[@]}"
do
    echo "Processing Project: $PROJECT"
    PROJECT=$GITLAB_GROUP/$PROJECT
    ENCODED_PROJECT=$(echo "$PROJECT" | sed 's/\//%2F/g')

    # 2. Check for existing hook in the target project
    LIST_RESPONSE=$(curl --silent --write-out "\n%{http_code}" \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$API_URL/projects/$ENCODED_PROJECT/hooks")
    # 3. Check list status
    LIST_STATUS=$(echo "$LIST_RESPONSE" | tail -n1)
    # 4. Get list body
    LIST_BODY=$(echo "$LIST_RESPONSE" | sed '$d')
    if [ "$LIST_STATUS" -ne 200 ]; then
        echo "⚠️ FAILED to list hooks for $PROJECT (Status: $LIST_STATUS). Skipping."
        continue
    fi

    # 5. Find if the target hook already exists
    EXISTING_HOOK_ID=$(echo "$LIST_BODY" | jq -r --arg url "$WEBHOOK_TARGET" '.[] | select(.url == $url) | .id')

    # 6. Create the payload using the extracted function
    HOOK_PAYLOAD=$(createPayLoad "$LIST_BODY")

    echo "Hook payload: $HOOK_PAYLOAD"

    # 7. Update existing hook (PUT)
    if [ -n "$EXISTING_HOOK_ID" ] && [ "$EXISTING_HOOK_ID" != "null" ]; then
        echo "ℹ️ Hook exists (ID: $EXISTING_HOOK_ID). Updating..."
        
        # 8. Update existing hook (PUT)
        UPDATE_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
            --request PUT \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --header "Content-Type: application/json" \
            --data "$HOOK_PAYLOAD" \
            "$API_URL/projects/$ENCODED_PROJECT/hooks/$EXISTING_HOOK_ID")
        # 8. Check update status
        if [ "$UPDATE_STATUS" -eq 200 ]; then
            echo "✅ SUCCESS: Hook updated."
        else
            echo "❌ ERROR: Failed to update hook (Status: $UPDATE_STATUS)."
        fi
    # 9 . Create new hook (POST)
    else
        echo "ℹ️ Hook does not exist. Creating..."
        
        # 10. Create new hook (POST)
        CREATE_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
            --request POST \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --header "Content-Type: application/json" \
            --data "$HOOK_PAYLOAD" \
            "$API_URL/projects/$ENCODED_PROJECT/hooks")
        # 11. Check create status
        if [ "$CREATE_STATUS" -eq 201 ]; then
            echo "✅ SUCCESS: Hook added."
        else
            echo "❌ ERROR: Failed to create hook (Status: $CREATE_STATUS)."
        fi
    fi
    echo "--------------------------------------------------"
done

echo "Done."
