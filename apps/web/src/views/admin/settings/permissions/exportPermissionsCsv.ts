import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { CUSTOMER_ROLE, methodsOf, roleMethods } from "../rbac";

const CSV_FILE_NAME = "permissions.csv";
/** Makes Excel read the file as UTF-8, so Vietnamese text survives. */
const UTF8_BOM = "\uFEFF";

type Translate = (key: string) => string;

const csvCell = (value: string): string => `"${value.replace(/"/g, '""')}"`;

/** Downloads the permissions as a CSV file with the roles that hold each one. */
export const exportPermissionsCsv = (permissions: readonly Permission[], roles: readonly Role[], t: Translate) => {
  const header = [
    t("rbac.permissions.col.code"),
    t("rbac.permissions.col.desc"),
    t("rbac.permissions.col.module"),
    t("rbac.permissions.col.methods"),
    t("rbac.permissions.col.roles"),
  ];
  const rows = permissions.map((permission) => [
    permission.name,
    permission.description ?? "",
    permission.module ?? "",
    methodsOf(permission).map((method) => t(`rbac.methods.${method}`)).join(", "),
    roles
      .filter((role) => roleMethods(role, permission).length > 0 && role.name !== CUSTOMER_ROLE)
      .map((role) => role.description || role.name)
      .join(", "),
  ]);
  const csv = [header, ...rows].map((row) => row.map(csvCell).join(",")).join("\r\n");
  const url = URL.createObjectURL(new Blob([UTF8_BOM, csv], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = CSV_FILE_NAME;
  link.click();
  URL.revokeObjectURL(url);
};
