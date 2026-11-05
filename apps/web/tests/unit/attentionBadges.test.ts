import { describe, expect, it } from "vitest";
import { attentionBadges } from "@/features/admin/dashboard/bell/attentionBadges";
import type { ActionRow } from "@/features/admin/dashboard/widgets/actionItems/actionItems";

const row = (key: ActionRow["key"], count: number | null): ActionRow => ({ key, count, failed: false, to: { name: "x" } });

describe("attentionBadges", () => {
  it("adds overdue and due vaccines onto the reminders item", () => {
    expect(attentionBadges([row("vaccineOverdue", 2), row("vaccineDue", 3)])).toEqual({ medicalReminders: 5 });
  });
  it("adds expiring and expired lots onto the stock item and ignores stock level rows", () => {
    expect(attentionBadges([row("stockExpiring", 4), row("stockExpired", 1), row("stockLow", 9)])).toEqual({ inventoryStock: 5 });
  });
  it("leaves out items with nothing to do or still loading", () => {
    expect(attentionBadges([row("vaccineOverdue", 0), row("stockExpired", null)])).toEqual({});
  });
});
