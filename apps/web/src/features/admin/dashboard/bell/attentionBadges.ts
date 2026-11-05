import type { ActionRow, ActionRowKey } from "../widgets/actionItems/actionItems";

/** Menu item (route name) -> the to-do rows whose counts add up to its badge. Only date-driven rows: stock level and orders have their own screens. */
const BADGE_SOURCES: Record<string, readonly ActionRowKey[]> = {
  medicalReminders: ["vaccineOverdue", "vaccineDue"],
  inventoryStock: ["stockExpiring", "stockExpired"],
};

/** Badge numbers for the sidebar; items with nothing to do are left out. */
export const attentionBadges = (rows: readonly ActionRow[]): Record<string, number> => {
  const out: Record<string, number> = {};
  for (const [item, keys] of Object.entries(BADGE_SOURCES)) {
    const total = rows.filter((row) => keys.includes(row.key)).reduce((sum, row) => sum + (row.count ?? 0), 0);
    if (total > 0) out[item] = total;
  }
  return out;
};
