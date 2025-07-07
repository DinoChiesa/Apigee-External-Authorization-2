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
import { GoogleAuth } from "google-auth-library";
import { google } from "googleapis";
import dayjs from "dayjs";

const today = dayjs(new Date()).format("YYYY-MMM-DD");

function handleError(e) {
  if (e) {
    console.log(`Error: ${e}`);
    console.log(e.stack);
    process.exit(1);
  }
}

function formattingUpdate(spreadsheetId, tabName) {
  let range = {
    sheetId: tabName == "Rules" ? 0 : 1,
    startRowIndex: 0,
    endRowIndex: 1,
    startColumnIndex: 0,
    endColumnIndex: tabName == "Rules" ? 4 : 2,
  };
  let batch = {
    spreadsheetId,
    resource: {
      requests: [
        {
          // add a bottom border to the header row
          updateBorders: {
            range,
            bottom: {
              style: "SOLID",
              width: 2,
              color: { red: 0, green: 0, blue: 0 },
            },
          },
        },
        {
          // bold the header row
          repeatCell: {
            range,
            cell: {
              userEnteredFormat: { textFormat: { bold: true } },
            },
            fields: "userEnteredFormat(textFormat)",
          },
        },
      ],
    },
  };
  return batch;
}

async function createSheet() {
  try {
    // Authenticate using Application Default Credentials, with the right
    // scopes. These scopes must have been previously approved.
    const googleAuth = new GoogleAuth({
      scopes: [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive",
      ],
    });
    const auth = await googleAuth.getClient();
    const sheets = google.sheets({ version: "v4", auth });
    const initialSheetData = JSON.parse(
      await fs.readFile("initial-sheet-data.json", "utf8"),
    );
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
    console.log(
      `When the script finishes, copy/paste this command into your terminal:\n`,
    );
    console.log(`  export SHEET_ID=${spreadsheetId}\n`);

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
      await sheets.spreadsheets.batchUpdate(
        formattingUpdate(spreadsheetId, tabname),
      );
    }
    console.log("\nOK\n\n");

    console.log(
      `Later, you will need to share the sheet with the service account email.`,
    );
    const sheetUrl = `https://docs.google.com/spreadsheets/d/${spreadsheetId}/edit`;
    console.log(
      `To do so you will need to open this sheet url:\n    ${sheetUrl}`,
    );
    console.log("\ndone\n\n");
  } catch (e) {
    handleError(e);
  }
}

await createSheet();
