#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

source ./lib/utils.sh

check_shell_variables CLOUDRUN_PROJECT_ID CLOUDRUN_SHORT_SA CLOUDRUN_SERVICE_NAME CLOUDRUN_REGION SHEET_ID
check_required_commands gcloud

printf "\nThis script deploys or redeploys the Cloud Run service named '%s'\n" "$CLOUDRUN_SERVICE_NAME"
printf "in the project '%s'.\n" "$CLOUDRUN_PROJECT_ID"
printf "\nThe script uses the Cloud Run \"deploy from source\" approach.\n"
printf "\nNB: The example service will allow unauthenticated access.\n\n"

SA_EMAIL="${CLOUDRUN_SHORT_SA}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"

# log levels = Trace, Debug, Information, Warning, Error, Critical

echo "gcloud run deploy \"${CLOUDRUN_SERVICE_NAME}\" \\"
echo "  --source \"./\" \\"
echo "  --project \"${CLOUDRUN_PROJECT_ID}\" \\"
echo "  --concurrency 5 \\"
echo "  --cpu 1 \\"
echo "  --memory '512Mi' \\"
echo "  --min-instances 0 \\"
echo "  --max-instances 1 \\"
echo "  --set-env-vars SHEET_ID=\"${SHEET_ID}\" \\"
echo "  --set-env-vars Logging__LogLevel__Default=\"Information\" \\"
echo "  --allow-unauthenticated \\"
echo "  --update-build-env-vars=\"GCLOUD_BUILD=1\" \\"
echo "  --region \"${CLOUDRUN_REGION}\" \\"
echo "  --service-account \"${SA_EMAIL}\" \\"
echo "  --timeout 180"

gcloud run deploy "${CLOUDRUN_SERVICE_NAME}" \
  --source "./" \
  --project "${CLOUDRUN_PROJECT_ID}" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --set-env-vars SHEET_ID="${SHEET_ID}" \
  --set-env-vars Logging__LogLevel__Default="Information" \
  --allow-unauthenticated \
  --update-build-env-vars="GCLOUD_BUILD=1" \
  --region "${CLOUDRUN_REGION}" \
  --service-account "${SA_EMAIL}" \
  --timeout 180

printf "\nOK.\n"
