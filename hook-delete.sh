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

    # 2. Get list of hooks to find the one to delete
    echo "Checking for existing webhook..."
    LIST_RESPONSE=$(curl --silent --write-out "\n %{http_code}" \
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

    # Find the hook ID for the target URL
    HOOK_ID=$(echo "$LIST_BODY" | grep "\"url\":[ ]*\"$WEBHOOK_TARGET\"" | sed -n 's/.*\"id\":[ ]*\([0-9]\+\),.*/\1/p' | head -n 1)

    if [ -z "$HOOK_ID" ]; then
        echo "ℹ️ INFO: Webhook with URL '$WEBHOOK_TARGET' not found."
    else
        echo "Deleting webhook with ID: $HOOK_ID"
        # 3. Make the API Call to delete the webhook
        DELETE_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
            --request DELETE \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            "$API_URL/projects/$ENCODED_PROJECT/hooks/$HOOK_ID")

        # 4. Check the result of the deletion
        if [ "$DELETE_STATUS" -eq 204 ]; then
            echo "✅ SUCCESS: Webhook deleted."
        elif [ "$DELETE_STATUS" -eq 401 ]; then
            echo "❌ ERROR: Unauthorized (401). Token may have expired or permissions changed."
        elif [ "$DELETE_STATUS" -eq 404 ]; then
            echo "❌ ERROR: Webhook not found (404). It might have been deleted by another process."
        else
            echo "⚠️ FAILED to delete hook: API returned HTTP status $DELETE_STATUS"
        fi
    fi
done

echo "--------------------------------------------------"
echo "Done."
