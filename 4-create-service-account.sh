#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

SA_REQUIRED_ROLES=() # "roles/serviceusage.serviceUsageConsumer"

apply_roles_to_sa() {
  local sa_email project ROLE AVAILABLE_ROLES
  sa_email="$1"
  project="$2"
  # shellcheck disable=SC2076
  AVAILABLE_ROLES=($(gcloud projects get-iam-policy "${project}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${sa_email}" |
    grep -v deleted | grep -A 1 members | grep role | sed -e 's/role: //'))

  for j in "${!SA_REQUIRED_ROLES[@]}"; do
    ROLE=${SA_REQUIRED_ROLES[j]}
    printf "    check the role %s...\n" "$ROLE"
    if ! [[ ${AVAILABLE_ROLES[*]} =~ "${ROLE}" ]]; then
      printf "Adding role %s...\n" "${ROLE}"

      echo "gcloud projects add-iam-policy-binding ${project} \
                 --condition=None \
                 --member=serviceAccount:${sa_email} \
                 --role=${ROLE}"
      if gcloud projects add-iam-policy-binding "${project}" \
        --condition=None \
        --member="serviceAccount:${sa_email}" \
        --role="${ROLE}" --quiet 2>&1; then
        printf "Success\n"
      else
        printf "\n*** FAILED\n\n"
        printf "You must manually run:\n\n"
        echo "gcloud projects add-iam-policy-binding ${project} \
                 --condition=None \
                 --member=serviceAccount:${sa_email} \
                 --role=${ROLE}"
      fi
    else
      printf "      That role is already set.\n"
    fi
  done
}

check_and_maybe_create_sa() {
  local short_service_account project sa_email
  short_service_account="$1"
  project="$2"
  sa_email="${short_service_account}@${project}.iam.gserviceaccount.com"
  printf "Checking for service account %s...\n" "$sa_email"
  echo "gcloud iam service-accounts describe \"$sa_email\""
  if gcloud iam service-accounts describe "$sa_email" --quiet >>/dev/null 2>&1; then
    printf "That service account exists...\n"
  else
    printf "Creating service account %s ...\n" "${short_service_account}"
    echo "gcloud iam service-accounts create \"${short_service_account}\" --project=\"${project}\""
    if gcloud iam service-accounts create "${short_service_account}" --project="${project}" --quiet; then
      if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
        printf "There can be errors if all these changes happen too quickly, so we need to sleep a bit...\n"
        sleep 12
        apply_roles_to_sa "$sa_email" "$project"
      fi
    else
      printf "Failed to create the service account.\n\n"
      exit 1
    fi
  fi
}

check_shell_variables CLOUDRUN_PROJECT_ID CLOUDRUN_SHORT_SA
check_required_commands gcloud

printf "\nThis script creates the service account the Access Control service will run as.\n"

check_and_maybe_create_sa "$CLOUDRUN_SHORT_SA" "$CLOUDRUN_PROJECT_ID"

printf "\nOK.\n\n"

SA_EMAIL="${CLOUDRUN_SHORT_SA}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"

printf "The Service Account email is:\n  %s\n" "$SA_EMAIL"
printf "\nShare the sheet created previously, with this ^^ email address, as Commenter or Viewer.\n\n"
