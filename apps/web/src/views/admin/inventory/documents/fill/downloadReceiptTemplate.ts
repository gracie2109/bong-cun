import { templateRows } from "@/lib/data-io/importSchema";
import { downloadTemplate } from "@/lib/data-io/templateFile";
import { RECEIPT_COLUMNS, RECEIPT_TEMPLATE_BASE, RECEIPT_TEMPLATE_SAMPLES } from "./receiptFileSchema";

export const downloadReceiptTemplate = (format: "xlsx" | "csv") =>
  downloadTemplate(templateRows(RECEIPT_COLUMNS, RECEIPT_TEMPLATE_SAMPLES), RECEIPT_TEMPLATE_BASE, format);
