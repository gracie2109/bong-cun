// CSV reading: character set, delimiter and RFC 4180 quoting. Pure TS.

import type { Cell } from "./cells";

const FALLBACK_CHARSETS = ["windows-1258", "windows-1252"];

/** Decodes file bytes: UTF-8 (with or without BOM) when valid, else Windows-1258, else Windows-1252. */
export const decodeCsvBytes = (bytes: ArrayBuffer): string => {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes).replace(/^﻿/, "");
  } catch {
    for (const charset of FALLBACK_CHARSETS) {
      try {
        return new TextDecoder(charset).decode(bytes);
      } catch {
        // this browser does not know the charset: try the next one
      }
    }
    return new TextDecoder("utf-8").decode(bytes);
  }
};

/** `,` or `;`, whichever the header line uses more outside quotes (Vietnamese Excel saves `;`). */
export const detectDelimiter = (textContent: string): "," | ";" => {
  const header = textContent.split(/\r?\n/, 1)[0] ?? "";
  let inQuotes = false;
  let commas = 0;
  let semicolons = 0;
  for (const char of header) {
    if (char === '"') inQuotes = !inQuotes;
    else if (!inQuotes && char === ",") commas++;
    else if (!inQuotes && char === ";") semicolons++;
  }
  return semicolons > commas ? ";" : ",";
};

/** Splits CSV text into rows of cells; quoted cells may hold delimiters, quotes ("") and line breaks. */
export const parseCsv = (content: string, delimiter = detectDelimiter(content)): Cell[][] => {
  const rows: Cell[][] = [];
  let row: Cell[] = [];
  let cell = "";
  let inQuotes = false;

  const endCell = () => {
    row.push(cell);
    cell = "";
  };
  const endRow = () => {
    endCell();
    rows.push(row);
    row = [];
  };

  for (let i = 0; i < content.length; i++) {
    const char = content[i];
    if (inQuotes) {
      if (char === '"' && content[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (char === '"') {
        inQuotes = false;
      } else {
        cell += char;
      }
    } else if (char === '"') {
      inQuotes = true;
    } else if (char === delimiter) {
      endCell();
    } else if (char === "\n" || char === "\r") {
      if (char === "\r" && content[i + 1] === "\n") i++;
      endRow();
    } else {
      cell += char;
    }
  }
  if (cell !== "" || row.length > 0) endRow();
  return rows;
};
