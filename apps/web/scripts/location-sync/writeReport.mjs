// The text of the pull request the sync workflow opens.
export const writeReport = ({ catalog, counts, diff, previous, fileName }) => {
  const first = previous.catalog === null;
  const environments = [...new Set(Object.values(diff.nextGhn).map((g) => g.provider_environment))].sort().join(", ") || "none";
  return `## Location cache sync

Catalog \`${catalog.id}\` (in force since ${catalog.effective_on}), source: ${catalog.source}${first ? " (first sync)" : ""}.
Migration: \`supabase/migrations/${fileName}\`. Merging this pull request runs it through "Supabase migrate".

| | Count |
| --- | --- |
| Active provinces | ${counts.provinces} |
| Active communes | ${counts.communes} |
| Retired units kept | ${counts.retired} |
| Active GHN codes | ${counts.ghn} (environment: ${environments}) |
| Unit rows written | ${diff.changedUnits.length} (${diff.added} new, ${diff.retired} retired) |
| GHN code rows written | ${diff.changedGhn.length} |

GHN codes of the \`test\` environment are not used for shipping fees in production; see docs/ke-hoach-noi-dia-gioi.md section 8.
`;
};
