/** One file row as `import_suppliers` reads it. An empty value means "keep what is saved". */
export type SupplierImportRow = {
  row: string;
  name: string;
  phone: string;
  email: string;
  address: string;
  tax_code: string;
  note: string;
  is_active: boolean | null;
};
