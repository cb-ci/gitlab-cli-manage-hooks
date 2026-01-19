#!/bin/bash

source ./set-env.sh
set -x
# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ ERROR: 'jq' is not installed. Please install it to use this script."
    exit 1
fi


echo "✅ Reference config loaded."
echo "--------------------------------------------------"

for PROJECT in "${PROJECTS[@]}"
do
    echo "Processing Project: $PROJECT"
    PROJECT=$GROUP/$PROJECT
    ENCODED_PROJECT=$(echo "$PROJECT" | sed 's/\//%2F/g')

    # 2. Check for existing hook in the target project
    LIST_RESPONSE=$(curl --silent --write-out "\n%{http_code}" \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$API_URL/projects/$ENCODED_PROJECT/hooks")
    
    LIST_STATUS=$(echo "$LIST_RESPONSE" | tail -n1)
    LIST_BODY=$(echo "$LIST_RESPONSE" | sed '$d')
    echo -n  "LIST BODY: $LIST_BODY"
    if [ "$LIST_STATUS" -ne 200 ]; then
        echo "⚠️ FAILED to list hooks for $PROJECT (Status: $LIST_STATUS). Skipping."
        continue
    fi

    # Find if the target hook already exists
    EXISTING_HOOK_ID=$(echo "$LIST_BODY" | jq -r --arg url "$WEBHOOK_TARGET" '.[] | select(.url == $url) | .id')

    HOOK_PAYLOAD=$(echo "$LIST_BODY" | jq -c --arg url "$WEBHOOK_REFERENCE_URL" --arg target_url "$WEBHOOK_TARGET" --arg secret "$WEBHOOK_SECRET" '
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
    } + (if $secret != "" then {token: $secret} else {} end)
    ')





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
