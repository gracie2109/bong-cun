import { templateRows } from "@/lib/data-io/importSchema";
import { downloadTemplate } from "@/lib/data-io/templateFile";
import { SUPPLIER_COLUMNS, SUPPLIERS_TEMPLATE_BASE, SUPPLIERS_TEMPLATE_SAMPLES } from "./suppliersImportSchema";

export const downloadSuppliersTemplate = (format: "xlsx" | "csv") =>
  downloadTemplate(templateRows(SUPPLIER_COLUMNS, SUPPLIERS_TEMPLATE_SAMPLES), SUPPLIERS_TEMPLATE_BASE, format);
