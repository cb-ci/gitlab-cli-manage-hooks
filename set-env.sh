#!/bin/bash

# --- CONFIGURATION ---
# Your GitLab Personal Access Token (Scope: api)
export GITLAB_TOKEN="glpat-Mhm_y9rvvzNizY6mp6PUuW86MQp1Omo1dmhwCw.01.120lqnvs9"

# The Webhook URL you want to manage
export WEBHOOK_TARGET="https://webhook.example.com/hook"

# The Base API URL (Change if using self-hosted GitLab)
export API_URL="https://gitlab.com/api/v4"

# List of Project Paths (Namespace/ProjectName) or Numeric IDs
# You can add as many as you need inside the parentheses
export PROJECTS=(
    "group16860950/project1"
    "group16860950/project2"
)
