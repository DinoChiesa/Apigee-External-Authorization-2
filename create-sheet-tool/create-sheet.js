// Copyright © 2025 Google LLC.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import * as fs from "node:fs/promises";
import path from "node:path";
import { exec } from "node:child_process";
import { promisify } from "node:util";
import { GoogleAuth } from "google-auth-library";
import { google } from "googleapis";
import dayjs from "dayjs";

const today = dayjs(new Date()).format("YYYY-MMM-DD");
const execP = promisify(exec);

function handleError(e) {
  if (e) {
    console.log(`Error: ${e}`);
    console.log(e.stack);
    process.exit(1);
  }
}

async function checkApplicationDefaultCreds() {
  const adcFilePath = path.join(
    process.env.HOME,
    ".config/gcloud/application_default_credentials.json",
  );
  try {
    // Attempt to get the file's statistics.
    await fs.stat(adcFilePath);
  } catch (error) {
    if (error.code === "ENOENT") {
      throw new Error(
        `You must signin with "gcloud auth application-default login"`,
      );
    }
    throw new Error(`Cannot read the Application Default Credentials.`);
  }
  const fileContent = await fs.readFile(adcFilePath, "utf8");
  return JSON.parse(fileContent);
}

async function execCmd(command) {
  try {
    console.log(`Running command: ${command}`);
    // Await the promise. On success, it resolves with { stdout, stderr }.
    const { stdout, stderr } = await execP(command);
    if (stderr) {
      console.error(stderr);
      throw new Error(stderr);
    }
    return stdout.trim();
  } catch (error) {
    // If the command fails (non-zero exit code), the promise rejects.
    console.error("❌ An error occurred:");
    console.error(error); // The error object contains stdout, stderr, and more.
  }
}

async function signin() {
  const command =
    "gcloud auth application-default print-access-token " +
    ' --scopes "https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive"';
  return await execCmd(command);
}

async function defaultProject() {
  const command = "gcloud config list --format 'value(core.project)'";
  return await execCmd(command);
}

async function createSheet() {
  try {
    const creds = await checkApplicationDefaultCreds();
    const accessToken = await signin();
    const quotaProject = await defaultProject();
    const auth = new GoogleAuth({});
    auth.getRequestHeaders = () => ({
      "x-goog-user-project": quotaProject,
      Authorization: `Bearer ${accessToken}`,
    });

    const initialSheetData = JSON.parse(
      await fs.readFile("initial-sheet-data.json", "utf8"),
    );

    const sheets = google.sheets({ version: "v4", auth });
    const tabnames = Object.keys(initialSheetData);
    var request = {
      resource: {
        properties: {
          title: `Access Control [created ${today}]`,
        },
        sheets: tabnames.map((title, ix) => ({
          properties: { sheetId: ix, title },
        })),
      },
    };

    console.log(`Creating the sheet...`);
    const createResponse = await sheets.spreadsheets.create(request);
    let spreadsheetId = createResponse.data.spreadsheetId;
    console.log();
    console.log(`Later, you will need to run this command:\n`);
    console.log(`  export SHEETID=${spreadsheetId}\n`);

    console.log(`Adding data...`);
    for (const tabname of tabnames) {
      const values = initialSheetData[tabname];
      const updateRequest = {
        spreadsheetId,
        valueInputOption: "USER_ENTERED",
        range: `${tabname}!R[0]C[0]:R[${values.length}]C[${values[0].length}]`,
        resource: { values },
      };
      await sheets.spreadsheets.values.update(updateRequest);
    }
    console.log("\nOK\n\n");

    console.log(
      `Later, you will need to share the sheet with the service account email.\n\n`,
    );
    const sheetUrl = `https://docs.google.com/spreadsheets/d/${spreadsheetId}/edit`;
    console.log(`To view the data, open this sheet url:\n    ${sheetUrl}`);
    console.log("\ndone\n\n");
  } catch (e) {
    handleError(e);
  }
}

await createSheet();
