import type { SelectOptionValue } from "@/types";

type CustomerGroup = { id: string; name: string };

export const toGroupOptions = (groups: CustomerGroup[]): SelectOptionValue[] =>
  groups.map((group) => ({ label: group.name, value: group.id }));

export const pickGroups = (groups: CustomerGroup[], ids: string[]): CustomerGroup[] =>
  groups.filter((group) => ids.includes(group.id));
