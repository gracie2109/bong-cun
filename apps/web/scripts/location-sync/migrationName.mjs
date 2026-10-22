// The migration version: later than the clock and than every migration already in the folder.
const pad = (n, width = 2) => String(n).padStart(width, "0");

export const formatVersion = (date) =>
  `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;

const parseVersion = (version) =>
  new Date(Date.UTC(+version.slice(0, 4), +version.slice(4, 6) - 1, +version.slice(6, 8), +version.slice(8, 10), +version.slice(10, 12), +version.slice(12, 14)));

/** @param {string[]} fileNames names in supabase/migrations @param {Date} now */
export const nextMigrationVersion = (fileNames, now) => {
  const versions = fileNames.map((name) => name.match(/^(\d{14})_/)?.[1]).filter(Boolean);
  const newest = versions.sort().at(-1);
  const clock = formatVersion(now);
  if (!newest || clock > newest) return clock;
  return formatVersion(new Date(parseVersion(newest).getTime() + 60_000));
};

export const migrationFileName = (version, catalogId) =>
  `${version}_location_sync_${catalogId.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "")}.sql`;
