import { downloadTemplate as saveGrid } from "@/lib/data-io/templateFile";
import { downloadTemplate } from "./exportProducts";
import { PRODUCT_TEMPLATE_GRID, TEMPLATE_BASE_NAME } from "./importTemplate";

/** Excel: the template with both sheets. CSV: the product sheet only. */
export const downloadProductTemplate = (format: "xlsx" | "csv") =>
  format === "xlsx" ? downloadTemplate() : saveGrid(PRODUCT_TEMPLATE_GRID, TEMPLATE_BASE_NAME, "csv");
