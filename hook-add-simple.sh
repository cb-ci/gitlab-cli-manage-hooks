#!/bin/bash

source ./set-env.sh

# --- SCRIPT LOGIC ---

for PROJECT in "${PROJECTS[@]}"
do
    echo "--------------------------------------------------"
    echo "Processing Project: $PROJECT"
    PROJECT=$GITLAB_GROUP/$PROJECT
    # 1. URL Encode the project path
    ENCODED_PROJECT=$(echo "$PROJECT" | sed 's/\//%2F/g')

    # 2. Get list of hooks to check for existence
    echo "Checking for existing webhook..."
    LIST_RESPONSE=$(curl --silent --write-out "\n%{http_code}" \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$API_URL/projects/$ENCODED_PROJECT/hooks")
    LIST_STATUS=$(echo "$LIST_RESPONSE" | tail -n1)
    LIST_BODY=$(echo "$LIST_RESPONSE" | sed '$d')

    if [ "$LIST_STATUS" -ne 200 ]; then
        if [ "$LIST_STATUS" -eq 404 ]; then
            echo "❌ ERROR: Project not found (404). Check permissions or project name."
        elif [ "$LIST_STATUS" -eq 401 ]; then
            echo "❌ ERROR: Unauthorized (401). Check your Access Token."
        else
            echo "⚠️ FAILED to list hooks: API returned HTTP status $LIST_STATUS"
        fi
        continue # Skip to next project
    fi

    # Check if the webhook URL already exists in the list of hooks.
    # The grep pattern allows for optional spaces after the colon.
    if echo "$LIST_BODY" | grep -q "\"url\":[ ]*\"$WEBHOOK_TARGET\""; then
        echo "ℹ️ INFO: Webhook with URL '$WEBHOOK_TARGET' already exists."
    else
        echo "Adding webhook..."
        # 3. Make the API Call to add the webhook
        CREATE_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
            --request POST \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --header "Content-Type: application/json" \
            --data "{
                \"url\": \"$WEBHOOK_TARGET\",
                \"push_events\": true,
                \"merge_requests_events\": true,
                \"tag_push_events\": true,
                \"enable_ssl_verification\": true
            }" \
            "$API_URL/projects/$ENCODED_PROJECT/hooks")

        # 4. Check the result of the creation
        if [ "$CREATE_STATUS" -eq 201 ]; then
            echo "✅ SUCCESS: Webhook added."
        # A 400 can mean "already exists", which would be a race condition if another
        # process added it between our check and our add.
        elif [ "$CREATE_STATUS" -eq 400 ]; then
            echo "⚠️ WARNING: Could not add webhook (400). It might have been added by another process, or the URL may be invalid."
        elif [ "$CREATE_STATUS" -eq 401 ]; then
            echo "❌ ERROR: Unauthorized (401). Token may have expired or permissions changed."
        elif [ "$CREATE_STATUS" -eq 404 ]; then
            echo "❌ ERROR: Project not found (404). It might have been deleted since the last check."
        else
            echo "⚠️ FAILED to add hook: API returned HTTP status $CREATE_STATUS"
        fi
    fi
done

echo "--------------------------------------------------"
echo "Done."
