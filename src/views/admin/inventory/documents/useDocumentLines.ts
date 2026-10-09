import { computed, ref, type Ref } from "vue";
import { useFetchProductLots } from "@/queries/inventory";
import { isExpired, type DocType, type StockDocumentDetail } from "@/repositories/inventory";
import type { Product } from "@/repositories/products";
import { blankLine, draftTotal, pickLot, toInput, validLine, type EditLine } from "./documentLines";

/** The editable lines of a stock document, loaded from a saved one or built by picking products. */
export const useDocumentLines = (type: Ref<DocType>, branchId: () => string | undefined) => {
  const fetchLots = useFetchProductLots();
  const lines = ref<EditLine[]>([]);
  // Bumped on every load, so a lot lookup that resolves after the sheet moved on is dropped.
  let loadSeq = 0;

  const draftValue = computed(() => draftTotal(type.value, lines.value));

  const load = async (detail: StockDocumentDetail | null) => {
    loadSeq++;
    lines.value = (detail?.lines ?? []).map((line) => ({
      ...blankLine({ id: line.productId, name: line.productName, unit: line.unit }),
      lotId: line.lotId,
      lotNo: line.lotNo,
      expiryDate: line.expiryDate ?? "",
      qty: detail?.docType === "count" ? "" : String(line.qty),
      // A receipt's cost field takes whole dong only (parseAmount keeps digits), so drop any decimals.
      unitCost: String(detail?.docType === "receipt" ? Math.round(line.unitCost) : line.unitCost),
      countedQty: line.countedQty === null ? "" : String(line.countedQty),
      systemQty: line.systemQty,
    }));
    // A draft write-off needs each product's lots for its lot picker.
    const branch = branchId();
    if (detail?.status === "draft" && detail.docType === "writeoff" && branch) {
      await Promise.all(lines.value.map(async (line) => (line.lotOptions = await fetchLots(branch, line.productId))));
    }
  };

  const addProduct = async (product: Product) => {
    const branch = branchId();
    if (!branch) return;
    if (type.value === "receipt") {
      lines.value.push(blankLine(product));
      return;
    }
    const seq = loadSeq;
    const docType = type.value;
    const lots = await fetchLots(branch, product.id);
    if (seq !== loadSeq || docType !== type.value) return;
    if (type.value === "writeoff") {
      // Expired lots first: they are what usually gets written off.
      const line = { ...blankLine(product), lotOptions: lots };
      const preset = lots.find((lot) => isExpired(lot.expiryDate)) ?? (lots.length === 1 ? lots[0] : undefined);
      if (preset) pickLot(line, preset.id);
      lines.value.push(line);
      return;
    }
    // A count lists every lot holding stock that is not on the sheet yet.
    const listed = new Set(lines.value.map((line) => line.lotId));
    for (const lot of lots.filter((item) => !listed.has(item.id))) {
      lines.value.push({
        ...blankLine(product),
        lotId: lot.id,
        lotNo: lot.lotNo,
        expiryDate: lot.expiryDate ?? "",
        unitCost: String(lot.unitCost),
        systemQty: lot.qtyOnHand,
      });
    }
  };

  const isValid = (): boolean => lines.value.length > 0 && lines.value.every((line) => validLine(type.value, line));

  const inputs = () => lines.value.map((line) => toInput(type.value, line));

  return { lines, draftValue, load, addProduct, isValid, inputs };
};
