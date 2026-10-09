// Stock by lot and expiry, per branch. Stock only changes through documents (receipts, write-offs,
// counts) and sales; every write is an RPC, and the database takes sold stock FEFO.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { filterSafe, pageRange, searchOr, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;

const num = (value: unknown): number => Number(value ?? 0);

// --------------------------------------------------------------------- stock
export const STOCK_STATUSES = ["all", "low", "out", "expiring", "expired"] as const;
export type StockStatus = (typeof STOCK_STATUSES)[number];
export type StockAlertStatus = Exclude<StockStatus, "all">;

/** Days ahead that count as "expiring soon". */
export const EXPIRY_WINDOWS = [30, 60, 90] as const;

export type StockRow = {
  productId: string;
  name: string;
  sku: string | null;
  barcode: string | null;
  unit: string;
  isActive: boolean;
  onHand: number;
  /** Unexpired stock: what a sale can take. */
  sellable: number;
  expired: number;
  expiring: number;
  nextExpiry: string | null;
  stockValue: number;
  minQty: number | null;
};

export type StockFilter = {
  branchId: string;
  search?: string;
  status?: StockStatus;
  expiryDays?: number;
};

export type StockAlertCounts = Record<StockAlertStatus, number>;

export const getStockSummary = async (
  client: Client,
  page: PageParams,
  filter: StockFilter
): Promise<Page<StockRow>> => {
  const { from } = pageRange(page);
  const rows = unwrap(
    await client.rpc("stock_summary", {
      p_branch: filter.branchId,
      p_search: filter.search?.trim() || undefined,
      p_status: filter.status ?? "all",
      p_expiry_days: filter.expiryDays,
      p_limit: page.pageSize,
      p_offset: from,
    })
  );
  return {
    rows: rows.map((row) => ({
      productId: row.product_id,
      name: row.name,
      sku: row.sku,
      barcode: row.barcode,
      unit: row.unit,
      isActive: row.is_active,
      onHand: num(row.on_hand),
      sellable: num(row.sellable),
      expired: num(row.expired),
      expiring: num(row.expiring),
      nextExpiry: row.next_expiry,
      stockValue: num(row.stock_value),
      minQty: row.min_qty === null ? null : num(row.min_qty),
    })),
    total: rows.length ? num(rows[0].total_count) : 0,
  };
};

export const getStockAlertCounts = async (
  client: Client,
  branchId: string,
  expiryDays: number
): Promise<StockAlertCounts> => {
  const raw = (unwrap(await client.rpc("stock_alert_counts", { p_branch: branchId, p_expiry_days: expiryDays })) ??
    {}) as Record<string, unknown>;
  return { low: num(raw.low), out: num(raw.out), expiring: num(raw.expiring), expired: num(raw.expired) };
};

/** Unexpired stock per product at a branch, for the counter. Products that do not track stock are absent. */
export const getSellableStock = async (
  client: Client,
  branchId: string,
  productIds: string[]
): Promise<Record<string, number>> => {
  if (productIds.length === 0) return {};
  const rows = unwrap(await client.rpc("sellable_stock", { p_branch: branchId, p_products: productIds }));
  return Object.fromEntries(rows.map((row) => [row.product_id, num(row.qty)]));
};

export const setMinStock = async (
  client: Client,
  branchId: string,
  productId: string,
  minQty: number | null
): Promise<void> => {
  const { error } = await client.rpc("set_min_stock", { p_branch: branchId, p_product: productId, p_min: minQty });
  if (error) throw error;
};

// ---------------------------------------------------------------------- lots
export type StockLot = {
  id: string;
  productId: string;
  lotNo: string;
  expiryDate: string | null;
  unitCost: number;
  qtyOnHand: number;
  receivedAt: string;
};

const toLot = (row: Tables<"stock_lots">): StockLot => ({
  id: row.id,
  productId: row.product_id,
  lotNo: row.lot_no,
  expiryDate: row.expiry_date,
  unitCost: num(row.unit_cost),
  qtyOnHand: num(row.qty_on_hand),
  receivedAt: row.received_at,
});

/** A product's lots at a branch in FEFO order; empty lots only when asked. */
export const listProductLots = async (
  client: Client,
  branchId: string,
  productId: string,
  includeEmpty = false
): Promise<StockLot[]> => {
  let query = client
    .from("stock_lots")
    .select("*")
    .eq("branch_id", branchId)
    .eq("product_id", productId)
    .order("expiry_date", { ascending: true, nullsFirst: false })
    .order("received_at");
  if (!includeEmpty) query = query.gt("qty_on_hand", 0);
  return unwrap(await query).map(toLot);
};

/** Today in Vietnam as YYYY-MM-DD, the day the database judges expiry by. */
export const businessDate = (): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Ho_Chi_Minh" }).format(new Date());

export const isExpired = (expiryDate: string | null): boolean => !!expiryDate && expiryDate < businessDate();

// ----------------------------------------------------------------- movements
export const MOVEMENT_REASONS = [
  "receipt",
  "receipt_cancel",
  "sale",
  "sale_cancel",
  "return",
  "writeoff",
  "count",
] as const;
export type MovementReason = (typeof MOVEMENT_REASONS)[number];

export type StockMovement = {
  id: string;
  createdAt: string;
  reason: MovementReason;
  qty: number;
  balanceAfter: number;
  unitCost: number;
  lotNo: string;
  expiryDate: string | null;
  /** The document, invoice or return code it came from. */
  ref: string | null;
};

type MovementRow = Tables<"stock_movements"> & {
  stock_lots: { lot_no: string; expiry_date: string | null } | null;
  stock_documents: { code: string } | null;
  invoices: { code: string } | null;
  sales_returns: { code: string } | null;
};

/** The stock card of a product at a branch, newest first. */
export const listProductMovements = async (
  client: Client,
  branchId: string,
  productId: string,
  limit = 50
): Promise<StockMovement[]> => {
  const rows = unwrap(
    await client
      .from("stock_movements")
      .select(
        "*, stock_lots(lot_no, expiry_date), stock_documents(code), invoices(code), sales_returns(code)"
      )
      .eq("branch_id", branchId)
      .eq("product_id", productId)
      .order("created_at", { ascending: false })
      .limit(limit)
  ) as unknown as MovementRow[];
  return rows.map((row) => ({
    id: row.id,
    createdAt: row.created_at,
    reason: MOVEMENT_REASONS.find((reason) => reason === row.reason) ?? "count",
    qty: num(row.qty),
    balanceAfter: num(row.balance_after),
    unitCost: num(row.unit_cost),
    lotNo: row.stock_lots?.lot_no ?? "",
    expiryDate: row.stock_lots?.expiry_date ?? null,
    ref: row.sales_returns?.code ?? row.stock_documents?.code ?? row.invoices?.code ?? null,
  }));
};

// ----------------------------------------------------------------- documents
export const DOC_TYPES = ["receipt", "writeoff", "count"] as const;
export type DocType = (typeof DOC_TYPES)[number];
export const DOC_STATUSES = ["draft", "posted", "cancelled"] as const;
export type DocStatus = (typeof DOC_STATUSES)[number];

export type StockDocument = {
  id: string;
  code: string;
  branchId: string;
  docType: DocType;
  status: DocStatus;
  supplierId: string | null;
  supplierName: string | null;
  supplierRef: string | null;
  note: string | null;
  totalCost: number;
  createdAt: string;
  createdByName: string | null;
  postedAt: string | null;
  postedByName: string | null;
  cancelledAt: string | null;
  cancelledByName: string | null;
  cancelReason: string | null;
};

export type StockDocumentLine = {
  id: string;
  lineNo: number;
  productId: string;
  productName: string;
  unit: string;
  lotId: string | null;
  lotNo: string;
  expiryDate: string | null;
  qty: number;
  unitCost: number;
  systemQty: number | null;
  countedQty: number | null;
  note: string | null;
};

export type StockDocumentDetail = StockDocument & { lines: StockDocumentLine[] };

type DocumentRow = Tables<"stock_documents"> & { suppliers: { name: string } | null };
type DocumentLineRow = Tables<"stock_document_lines"> & { products: { name: string; unit: string } | null };

const toDocType = (value: string): DocType => DOC_TYPES.find((type) => type === value) ?? "receipt";
const toDocStatus = (value: string): DocStatus => DOC_STATUSES.find((status) => status === value) ?? "draft";

const toDocument = (row: DocumentRow): StockDocument => ({
  id: row.id,
  code: row.code,
  branchId: row.branch_id,
  docType: toDocType(row.doc_type),
  status: toDocStatus(row.status),
  supplierId: row.supplier_id,
  supplierName: row.suppliers?.name ?? null,
  supplierRef: row.supplier_ref,
  note: row.note,
  totalCost: num(row.total_cost),
  createdAt: row.created_at,
  createdByName: row.created_by_name,
  postedAt: row.posted_at,
  postedByName: row.posted_by_name,
  cancelledAt: row.cancelled_at,
  cancelledByName: row.cancelled_by_name,
  cancelReason: row.cancel_reason,
});

export type StockDocumentFilter = {
  branchId: string;
  docType?: DocType;
  status?: DocStatus;
  /** Document code, supplier reference or note. */
  search?: string;
};

export const listStockDocuments = async (
  client: Client,
  page: PageParams,
  filter: StockDocumentFilter
): Promise<Page<StockDocument>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("stock_documents")
    .select("*, suppliers(name)", { count: "exact" })
    .eq("branch_id", filter.branchId)
    .order("created_at", { ascending: false })
    .range(from, to);
  if (filter.docType) query = query.eq("doc_type", filter.docType);
  if (filter.status) query = query.eq("status", filter.status);
  const term = filterSafe(filter.search ?? "");
  if (term) query = query.or([`code.ilike.%${term}%`, `supplier_ref.ilike.%${term}%`, `note.ilike.%${term}%`].join(","));

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: ((data ?? []) as unknown as DocumentRow[]).map(toDocument), total: count ?? 0 };
};

export const getStockDocument = async (client: Client, id: string): Promise<StockDocumentDetail | null> => {
  const row = unwrap(
    await client
      .from("stock_documents")
      .select("*, suppliers(name), stock_document_lines(*, products(name, unit))")
      .eq("id", id)
      .maybeSingle()
  ) as unknown as (DocumentRow & { stock_document_lines: DocumentLineRow[] }) | null;
  if (!row) return null;
  return {
    ...toDocument(row),
    lines: [...row.stock_document_lines]
      .sort((a, b) => a.line_no - b.line_no)
      .map((line) => ({
        id: line.id,
        lineNo: line.line_no,
        productId: line.product_id,
        productName: line.products?.name ?? "",
        unit: line.products?.unit ?? "",
        lotId: line.lot_id,
        lotNo: line.lot_no,
        expiryDate: line.expiry_date,
        qty: num(line.qty),
        unitCost: num(line.unit_cost),
        systemQty: line.system_qty === null ? null : num(line.system_qty),
        countedQty: line.counted_qty === null ? null : num(line.counted_qty),
        note: line.note,
      })),
  };
};

/** Receipt lines name a lot; write-off and count lines point at an existing one. */
export type StockDocumentLineInput =
  | { productId: string; lotNo: string; expiryDate: string | null; qty: number; unitCost: number; note?: string | null }
  | { lotId: string; qty: number; note?: string | null }
  | { lotId: string; countedQty: number; note?: string | null };

export type StockDocumentInput = {
  id?: string;
  branchId: string;
  docType: DocType;
  supplierId?: string | null;
  supplierRef?: string | null;
  note?: string | null;
  lines: StockDocumentLineInput[];
};

const toLinePayload = (line: StockDocumentLineInput) => {
  if ("productId" in line) {
    return {
      product_id: line.productId,
      lot_no: line.lotNo,
      expiry_date: line.expiryDate,
      qty: line.qty,
      unit_cost: line.unitCost,
      note: line.note ?? null,
    };
  }
  if ("countedQty" in line) return { lot_id: line.lotId, counted_qty: line.countedQty, note: line.note ?? null };
  return { lot_id: line.lotId, qty: line.qty, note: line.note ?? null };
};

/** Creates or replaces a draft; returns its id. */
export const saveStockDocument = async (client: Client, input: StockDocumentInput): Promise<string> =>
  unwrap(
    await client.rpc("save_stock_document", {
      p: {
        id: input.id ?? null,
        branch_id: input.branchId,
        doc_type: input.docType,
        supplier_id: input.supplierId ?? null,
        supplier_ref: input.supplierRef ?? null,
        note: input.note ?? null,
        lines: input.lines.map(toLinePayload),
      },
    })
  );

export const postStockDocument = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.rpc("post_stock_document", { p_id: id });
  if (error) throw error;
};

export const cancelStockDocument = async (client: Client, id: string, reason?: string): Promise<void> => {
  const { error } = await client.rpc("cancel_stock_document", { p_id: id, p_reason: reason || undefined });
  if (error) throw error;
};

// ----------------------------------------------------------------- suppliers
export type Supplier = {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  taxCode: string | null;
  note: string | null;
  isActive: boolean;
};

export type SupplierInput = Omit<Supplier, "id" | "isActive"> & { isActive?: boolean };

const toSupplier = (row: Tables<"suppliers">): Supplier => ({
  id: row.id,
  name: row.name,
  phone: row.phone,
  email: row.email,
  address: row.address,
  taxCode: row.tax_code,
  note: row.note,
  isActive: row.is_active,
});

const blankToNull = (value: string | null | undefined): string | null => value?.trim() || null;

const toSupplierRow = (input: SupplierInput) => ({
  name: input.name.trim(),
  phone: blankToNull(input.phone),
  email: blankToNull(input.email),
  address: blankToNull(input.address),
  tax_code: blankToNull(input.taxCode),
  note: blankToNull(input.note),
  is_active: input.isActive ?? true,
});

export type SupplierFilter = { search?: string; includeArchived?: boolean };

export const listSuppliers = async (
  client: Client,
  page: PageParams,
  filter: SupplierFilter = {}
): Promise<Page<Supplier>> => {
  const { from, to } = pageRange(page);
  let query = client.from("suppliers").select("*", { count: "exact" }).order("name").range(from, to);
  if (!filter.includeArchived) query = query.eq("is_active", true);
  const term = filterSafe(filter.search ?? "");
  if (term) query = query.or([`name.ilike.%${term}%`, `phone.ilike.%${term}%`, `tax_code.ilike.%${term}%`].join(","));
  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data ?? []).map(toSupplier), total: count ?? 0 };
};

/** Active suppliers for the receipt picker, a page at a time and searchable by name or phone. */
export const listSupplierOptions = async (
  client: Client,
  page: PageParams,
  search = ""
): Promise<Page<Supplier>> => listSuppliers(client, page, { search });

export const createSupplier = async (client: Client, input: SupplierInput): Promise<void> => {
  const { error } = await client.from("suppliers").insert(toSupplierRow(input));
  if (error) throw error;
};

export const updateSupplier = async (client: Client, id: string, input: SupplierInput): Promise<void> => {
  const { error } = await client.from("suppliers").update(toSupplierRow(input)).eq("id", id);
  if (error) throw error;
};

// -------------------------------------------------------------------- errors
/** Error hints raised by the inventory functions, for readable messages. */
export const INVENTORY_ERROR_HINTS = [
  "lot_short",
  "needs_manager",
  "not_draft",
  "no_lines",
  "posted_not_receipt",
  "reason_required",
  "untracked_product",
] as const;
export type InventoryErrorHint = (typeof INVENTORY_ERROR_HINTS)[number];

export const inventoryErrorHint = (error: unknown): InventoryErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return INVENTORY_ERROR_HINTS.find((item) => item === hint) ?? null;
};
