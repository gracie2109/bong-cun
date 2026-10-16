import { templateRows } from "@/lib/data-io/importSchema";
import { downloadTemplate } from "@/lib/data-io/templateFile";
import { PETS_TEMPLATE_BASE, PETS_TEMPLATE_SAMPLES, PET_COLUMNS } from "./petsImportSchema";

export const downloadPetsTemplate = (format: "xlsx" | "csv") =>
  downloadTemplate(templateRows(PET_COLUMNS, PETS_TEMPLATE_SAMPLES), PETS_TEMPLATE_BASE, format);
