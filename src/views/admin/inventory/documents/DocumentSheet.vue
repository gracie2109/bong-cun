<template>
  <Sheet :open="open" @update:open="(value) => !value && emit('close')">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-4xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle class="flex flex-wrap items-center gap-2">
          {{ doc?.code ?? $t(`inventory.documents.newTitle.${type}`) }}
          <span v-if="doc" class="rounded-full px-2 py-0.5 text-[11px] font-semibold" :class="STATUS_TONE[doc.status]">
            {{ $t(`inventory.documents.status.${doc.status}`) }}
          </span>
        </SheetTitle>
        <SheetDescription>
          {{ $t(`inventory.documents.typeHint.${type}`) }}
        </SheetDescription>
      </SheetHeader>

      <div class="flex-1 space-y-5 overflow-y-auto px-6 py-5">
        <Skeleton v-if="documentId && docQuery.isPending.value" class="h-60 w-full" />
        <template v-else>
          <dl v-if="doc" class="grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
            <div class="flex justify-between gap-3">
              <dt class="text-muted-foreground">{{ $t("inventory.documents.createdBy") }}</dt>
              <dd>{{ doc.createdByName }} · {{ dateTime(doc.createdAt) }}</dd>
            </div>
            <div v-if="doc.postedAt" class="flex justify-between gap-3">
              <dt class="text-muted-foreground">{{ $t("inventory.documents.postedBy") }}</dt>
              <dd>{{ doc.postedByName }} · {{ dateTime(doc.postedAt) }}</dd>
            </div>
            <div v-if="doc.cancelledAt" class="flex justify-between gap-3 text-red-600 sm:col-span-2">
              <dt>{{ $t("inventory.documents.cancelledBy") }}</dt>
              <dd>{{ doc.cancelledByName }} · {{ dateTime(doc.cancelledAt) }}<template v-if="doc.cancelReason"> · {{ doc.cancelReason }}</template></dd>
            </div>
          </dl>

          <div class="grid gap-4 sm:grid-cols-2">
            <template v-if="type === 'receipt'">
              <div class="space-y-2">
                <Label>{{ $t("inventory.documents.supplier") }}</Label>
                <Select v-model="form.supplierId" :disabled="!editable">
                  <SelectTrigger><SelectValue :placeholder="$t('inventory.documents.noSupplier')" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem :value="NONE">{{ $t("inventory.documents.noSupplier") }}</SelectItem>
                    <SelectItem v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div class="space-y-2">
                <Label for="supplier-ref">{{ $t("inventory.documents.supplierRef") }}</Label>
                <Input id="supplier-ref" v-model="form.supplierRef" :disabled="!editable" />
              </div>
            </template>
            <div class="space-y-2 sm:col-span-2">
              <Label for="doc-note">{{ $t("inventory.documents.note") }}</Label>
              <Input id="doc-note" v-model="form.note" :disabled="!editable" :placeholder="$t(`inventory.documents.notePlaceholder.${type}`)" />
            </div>
          </div>

          <ProductPicker v-if="editable" @pick="addProduct" />

          <p v-if="lines.length === 0" class="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">
            {{ $t("inventory.documents.noLines") }}
          </p>
          <div v-else class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
                  <th class="py-2 pr-2 font-semibold">{{ $t("products.col.product") }}</th>
                  <th class="py-2 pr-2 font-semibold">{{ $t("inventory.lots.lotNo") }}</th>
                  <th class="py-2 pr-2 font-semibold">{{ $t("inventory.lots.expiry") }}</th>
                  <template v-if="type === 'count'">
                    <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.documents.systemQty") }}</th>
                    <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.documents.countedQty") }}</th>
                    <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.documents.difference") }}</th>
                  </template>
                  <template v-else>
                    <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.movements.qty") }}</th>
                    <th class="py-2 pr-2 text-right font-semibold">{{ $t("inventory.lots.unitCost") }}</th>
                    <th class="py-2 pr-2 text-right font-semibold">{{ $t("pos.invoices.amount") }}</th>
                  </template>
                  <th v-if="editable" class="py-2" />
                </tr>
              </thead>
              <tbody>
                <tr v-for="line in lines" :key="line.key" class="border-b align-top last:border-0">
                  <td class="py-2 pr-2">
                    <p class="font-medium">{{ line.productName }}</p>
                    <p class="text-xs text-muted-foreground">{{ line.unit }}</p>
                  </td>

                  <!-- lot -->
                  <td class="py-2 pr-2">
                    <Input v-if="editable && type === 'receipt'" v-model="line.lotNo" class="h-8 w-32" :placeholder="$t('inventory.lots.noLot')" />
                    <Select
                      v-else-if="editable && type === 'writeoff'"
                      :model-value="line.lotId ?? undefined"
                      @update:model-value="(value) => pickLot(line, String(value))"
                    >
                      <SelectTrigger class="h-8 w-44" :class="submitted && !line.lotId ? 'border-red-500' : ''">
                        <SelectValue :placeholder="$t('inventory.documents.pickLot')" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem v-for="lot in line.lotOptions" :key="lot.id" :value="lot.id">
                          {{ lot.lotNo || $t("inventory.lots.noLot") }} · {{ lot.expiryDate ? day(lot.expiryDate) : $t("inventory.lots.noExpiry") }} · {{ qty(lot.qtyOnHand) }}
                        </SelectItem>
                      </SelectContent>
                    </Select>
                    <span v-else>{{ line.lotNo || $t("inventory.lots.noLot") }}</span>
                  </td>

                  <!-- expiry -->
                  <td class="py-2 pr-2">
                    <Input v-if="editable && type === 'receipt'" v-model="line.expiryDate" type="date" class="h-8 w-40" />
                    <span v-else-if="line.expiryDate" :class="isExpired(line.expiryDate) ? 'font-semibold text-red-600' : ''">{{ day(line.expiryDate) }}</span>
                    <span v-else class="text-muted-foreground">{{ $t("inventory.lots.noExpiry") }}</span>
                  </td>

                  <template v-if="type === 'count'">
                    <td class="py-2 pr-2 text-right text-muted-foreground">{{ line.systemQty === null ? "—" : qty(line.systemQty) }}</td>
                    <td class="py-2 pr-2 text-right">
                      <Input
                        v-if="editable"
                        v-model="line.countedQty"
                        inputmode="decimal"
                        class="ml-auto h-8 w-24 text-right"
                        :class="submitted && !validCounted(line) ? 'border-red-500' : ''"
                      />
                      <span v-else class="font-semibold">{{ line.countedQty }}</span>
                    </td>
                    <td class="py-2 pr-2 text-right font-semibold" :class="diffTone(countDiff(line))">
                      {{ countDiff(line) === null ? "—" : (countDiff(line) ?? 0) > 0 ? `+${qty(countDiff(line))}` : qty(countDiff(line)) }}
                    </td>
                  </template>
                  <template v-else>
                    <td class="py-2 pr-2 text-right">
                      <Input
                        v-if="editable"
                        v-model="line.qty"
                        inputmode="decimal"
                        class="ml-auto h-8 w-24 text-right"
                        :class="submitted && !validQty(line) ? 'border-red-500' : ''"
                      />
                      <span v-else class="font-semibold">{{ line.qty }}</span>
                      <p v-if="editable && type === 'writeoff' && selectedLot(line)" class="mt-1 text-[11px] text-muted-foreground">
                        {{ $t("inventory.documents.lotHolds", { n: qty(selectedLot(line)?.qtyOnHand) }) }}
                      </p>
                    </td>
                    <td class="py-2 pr-2 text-right">
                      <Input
                        v-if="editable && type === 'receipt'"
                        v-model="line.unitCost"
                        inputmode="numeric"
                        class="ml-auto h-8 w-28 text-right"
                      />
                      <span v-else class="text-muted-foreground">{{ money(lineCost(line)) }}</span>
                    </td>
                    <td class="whitespace-nowrap py-2 pr-2 text-right font-medium">{{ money(lineAmount(line)) }}</td>
                  </template>

                  <td v-if="editable" class="py-2 text-right">
                    <Button variant="ghost" size="icon" class="size-8 text-muted-foreground" :aria-label="$t('pos.cart.remove')" @click="removeLine(line.key)">
                      <X class="size-4" />
                    </Button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div v-if="lines.length" class="flex justify-end">
            <dl class="min-w-64 space-y-1 rounded-xl bg-muted/50 p-4 text-sm">
              <div class="flex justify-between gap-6 text-base font-bold">
                <dt>{{ $t(`inventory.documents.totalLabel.${type}`) }}</dt>
                <dd :class="type === 'count' ? diffTone(totalValue) : 'text-primary'">{{ money(totalValue) }}</dd>
              </div>
            </dl>
          </div>

          <p v-if="editable && !canPost" class="rounded-lg bg-amber-50 p-3 text-sm text-amber-800">
            {{ $t("inventory.documents.needsManager") }}
          </p>

          <div v-if="cancelling" class="space-y-2 rounded-lg border border-red-200 p-3">
            <Label for="cancel-reason">{{ $t("inventory.documents.cancelReason") }}</Label>
            <Textarea id="cancel-reason" v-model="cancelReason" rows="2" class="resize-none" />
            <div class="flex justify-end gap-2">
              <Button variant="outline" size="sm" @click="cancelling = false">{{ $t("petCare.common.cancel") }}</Button>
              <Button
                variant="destructive"
                size="sm"
                :disabled="(doc?.status === 'posted' && !cancelReason.trim()) || cancelMutation.isPending.value"
                @click="cancelDocument"
              >
                {{ $t("inventory.documents.confirmCancel") }}
              </Button>
            </div>
          </div>
        </template>
      </div>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button v-if="canCancel && !cancelling" variant="outline" class="text-red-600" @click="cancelling = true">
          {{ $t(doc?.status === "posted" ? "inventory.documents.cancelPosted" : "inventory.documents.cancelDraft") }}
        </Button>
        <template v-if="editable">
          <Button variant="outline" :disabled="busy" @click="save(false)">
            {{ $t("inventory.documents.saveDraft") }}
          </Button>
          <Button v-if="canPost" :disabled="busy" @click="save(true)">
            <BookCheck class="mr-2 size-4" />
            {{ $t("inventory.documents.post") }}
          </Button>
        </template>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from "vue";
import { BookCheck, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Textarea } from "@/components/ui/textarea";
import { usePermission } from "@/composables/usePermission";
import {
  useCancelStockDocument,
  useFetchProductLots,
  usePostStockDocument,
  useSaveStockDocument,
  useStockDocument,
  useSupplierOptions,
} from "@/queries/inventory";
import {
  isExpired,
  type DocStatus,
  type DocType,
  type StockDocumentDetail,
  type StockDocumentLineInput,
  type StockLot,
} from "@/repositories/inventory";
import type { Product } from "@/repositories/products";
import { dateTime, money, parseAmount } from "@/views/admin/pos/format";
import { day, parseQty, qty } from "../format";
import ProductPicker from "./ProductPicker.vue";

const NONE = "none";
const STATUS_TONE: Record<DocStatus, string> = {
  draft: "bg-amber-50 text-amber-700",
  posted: "bg-primary/10 text-primary",
  cancelled: "bg-red-50 text-red-600",
};

/** One editable row. Text fields hold what was typed; numbers are parsed on save. */
type EditLine = {
  key: string;
  productId: string;
  productName: string;
  unit: string;
  lotId: string | null;
  lotNo: string;
  expiryDate: string;
  qty: string;
  unitCost: string;
  countedQty: string;
  systemQty: number | null;
  lotOptions: StockLot[];
};

const props = defineProps<{ documentId: string | undefined; newType: DocType | undefined; branchId: string | undefined }>();
const emit = defineEmits<{ close: []; saved: [id: string] }>();

const { canCreate, canUpdate, canDelete } = usePermission("inventory");
const docQuery = useStockDocument(computed(() => props.documentId));
const doc = computed<StockDocumentDetail | null>(() => (props.documentId ? docQuery.data.value ?? null : null));
const suppliersQuery = useSupplierOptions();
const suppliers = computed(() => suppliersQuery.data.value ?? []);
const fetchLots = useFetchProductLots();
const saveMutation = useSaveStockDocument();
const postMutation = usePostStockDocument();
const busy = computed(() => saveMutation.isPending.value || postMutation.isPending.value);
const cancelMutation = useCancelStockDocument();

const open = computed(() => !!props.documentId || !!props.newType);
const type = computed<DocType>(() => doc.value?.docType ?? props.newType ?? "receipt");
const form = reactive({ supplierId: NONE, supplierRef: "", note: "" });
const lines = ref<EditLine[]>([]);
const submitted = ref(false);
const cancelling = ref(false);
const cancelReason = ref("");
let keySeq = 0;

const editable = computed(() => canCreate.value && (!props.documentId || doc.value?.status === "draft"));
// Receipts post with CREATE; write-offs and counts change stock without goods arriving, so a manager posts them.
const canPost = computed(() => (type.value === "receipt" ? canCreate.value : canUpdate.value));
const canCancel = computed(() => {
  if (!doc.value) return false;
  if (doc.value.status === "draft") return canCreate.value;
  return doc.value.status === "posted" && doc.value.docType === "receipt" && canDelete.value;
});

const blankLine = (product: { id: string; name: string; unit: string }): EditLine => ({
  key: `line-${++keySeq}`,
  productId: product.id,
  productName: product.name,
  unit: product.unit,
  lotId: null,
  lotNo: "",
  expiryDate: "",
  qty: "",
  unitCost: "",
  countedQty: "",
  systemQty: null,
  lotOptions: [],
});

const resetFrom = async (detail: StockDocumentDetail | null) => {
  submitted.value = false;
  cancelling.value = false;
  cancelReason.value = "";
  form.supplierId = detail?.supplierId ?? NONE;
  form.supplierRef = detail?.supplierRef ?? "";
  form.note = detail?.note ?? "";
  lines.value = (detail?.lines ?? []).map((line) => ({
    ...blankLine({ id: line.productId, name: line.productName, unit: line.unit }),
    lotId: line.lotId,
    lotNo: line.lotNo,
    expiryDate: line.expiryDate ?? "",
    qty: detail?.docType === "count" ? "" : String(line.qty),
    unitCost: String(line.unitCost),
    countedQty: line.countedQty === null ? "" : String(line.countedQty),
    systemQty: line.systemQty,
  }));
  // A draft write-off needs each product's lots for its lot picker.
  if (detail?.status === "draft" && detail.docType === "writeoff" && props.branchId) {
    const branchId = props.branchId;
    await Promise.all(lines.value.map(async (line) => (line.lotOptions = await fetchLots(branchId, line.productId))));
  }
};

watch(
  () => [props.documentId, props.newType, doc.value] as const,
  ([, newType, detail]) => {
    if (newType) void resetFrom(null);
    else if (detail) void resetFrom(detail);
  },
  { immediate: true }
);

const addProduct = async (product: Product) => {
  if (!props.branchId) return;
  if (type.value === "receipt") {
    lines.value.push(blankLine(product));
    return;
  }
  const lots = await fetchLots(props.branchId, product.id);
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

const pickLot = (line: EditLine, lotId: string) => {
  const lot = line.lotOptions.find((item) => item.id === lotId);
  line.lotId = lotId;
  line.lotNo = lot?.lotNo ?? "";
  line.expiryDate = lot?.expiryDate ?? "";
  line.unitCost = String(lot?.unitCost ?? 0);
};

const removeLine = (key: string) => {
  lines.value = lines.value.filter((line) => line.key !== key);
};

const selectedLot = (line: EditLine) => line.lotOptions.find((lot) => lot.id === line.lotId);
const lineCost = (line: EditLine) => (type.value === "receipt" ? parseAmount(line.unitCost) : Number(line.unitCost) || 0);
const lineAmount = (line: EditLine) => {
  const value = parseQty(line.qty);
  return Number.isFinite(value) ? Math.round(value * lineCost(line)) : 0;
};
const countDiff = (line: EditLine): number | null => {
  const counted = parseQty(line.countedQty);
  return Number.isFinite(counted) && line.systemQty !== null ? Math.round((counted - line.systemQty) * 100) / 100 : null;
};
const diffTone = (value: number | null) => (!value ? "" : value > 0 ? "text-primary" : "text-red-600");

const totalValue = computed(() => {
  if (doc.value && doc.value.status !== "draft") return doc.value.totalCost;
  if (type.value === "count") {
    return lines.value.reduce((sum, line) => sum + Math.round((countDiff(line) ?? 0) * (Number(line.unitCost) || 0)), 0);
  }
  return lines.value.reduce((sum, line) => sum + lineAmount(line), 0);
});

const validQty = (line: EditLine) => {
  const value = parseQty(line.qty);
  if (!Number.isFinite(value) || value <= 0) return false;
  const lot = selectedLot(line);
  return type.value !== "writeoff" || (!!line.lotId && (!lot || value <= lot.qtyOnHand));
};
const validCounted = (line: EditLine) => {
  const value = parseQty(line.countedQty);
  return Number.isFinite(value) && value >= 0;
};
const validLine = (line: EditLine) => (type.value === "count" ? validCounted(line) : validQty(line));

const toInput = (line: EditLine): StockDocumentLineInput => {
  if (type.value === "receipt") {
    return {
      productId: line.productId,
      lotNo: line.lotNo.trim(),
      expiryDate: line.expiryDate || null,
      qty: parseQty(line.qty),
      unitCost: parseAmount(line.unitCost),
    };
  }
  if (type.value === "count") return { lotId: line.lotId as string, countedQty: parseQty(line.countedQty) };
  return { lotId: line.lotId as string, qty: parseQty(line.qty) };
};

const save = async (post: boolean) => {
  submitted.value = true;
  if (!props.branchId || lines.value.length === 0 || !lines.value.every(validLine)) return;
  try {
    const id = await saveMutation.mutateAsync({
      quiet: post,
      input: {
        id: props.documentId,
        branchId: props.branchId,
        docType: type.value,
        supplierId: form.supplierId === NONE ? null : form.supplierId,
        supplierRef: form.supplierRef,
        note: form.note,
        lines: lines.value.map(toInput),
      },
    });
    // The sheet now shows the saved draft, so a failed post leaves it open to fix and post again.
    emit("saved", id);
    if (post) await postMutation.mutateAsync(id);
  } catch {
    // the mutation already showed the failure toast
  }
};

const cancelDocument = async () => {
  if (!doc.value) return;
  try {
    await cancelMutation.mutateAsync({ id: doc.value.id, reason: cancelReason.value.trim() });
    cancelling.value = false;
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
