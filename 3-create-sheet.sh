#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

#check_shell_variables CLOUDRUN_PROJECT_ID CLOUDRUN_SERVICE_NAME
check_required_commands gcloud npm node

printf "\nThis script creates the sheet to hold the Access Control Rules and Roles.\n"

cd create-sheet-tool
npm install
node ./create-sheet.js




