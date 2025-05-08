#!/bin/bash

PROJECT_ID="gke-cluster-458701"

# Get list of enabled APIs
ENABLED_APIS=$(gcloud services list --enabled --project="$PROJECT_ID" --format="value(config.name)")

# Define critical APIs to keep
CRITICAL_APIS=(
  "iam.googleapis.com"
  "cloudresourcemanager.googleapis.com"
  "serviceusage.googleapis.com"
  "billing.googleapis.com"
  "servicemanagement.googleapis.com"
  "cloudbilling.googleapis.com"
)

echo "Disabling non-critical APIs in project: $PROJECT_ID"

for api in $ENABLED_APIS; do
  if [[ ! " ${CRITICAL_APIS[@]} " =~ " ${api} " ]]; then
    echo "Disabling: $api"
    gcloud services disable "$api" --project="$PROJECT_ID" --quiet
  else
    echo "Keeping critical API: $api"
  fi
done

