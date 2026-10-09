<template>
  <Sheet :open="open" @update:open="(value) => !value && emit('close')">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-4xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle class="flex flex-wrap items-center gap-2">
          {{ doc?.code ?? $t(`inventory.documents.newTitle.${type}`) }}
          <span v-if="doc" class="rounded-full px-2 py-0.5 text-[11px] font-semibold" :class="DOC_STATUS_TONE[doc.status]">
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
                <InfiniteSelect
                  :model-value="form.supplierId === NONE ? '' : form.supplierId"
                  :options="supplierOptions"
                  :placeholder="$t('inventory.documents.noSupplier')"
                  :none-label="$t('inventory.documents.noSupplier')"
                  :selected-fallback="doc?.supplierName ?? undefined"
                  :has-more="suppliersMore"
                  :loading="suppliersLoading"
                  :loading-more="suppliersLoadingMore"
                  :disabled="!editable"
                  @update:model-value="(id) => (form.supplierId = id || NONE)"
                  @update:search="supplierSearch = $event"
                  @load-more="loadMoreSuppliers"
                />
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
          <DocumentLinesTable v-else v-model:lines="lines" :type="type" :editable="editable" :submitted="submitted" />

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
import { BookCheck } from "lucide-vue-next";
import InfiniteSelect from "@/components/common/InfiniteSelect.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
  usePostStockDocument,
  useSaveStockDocument,
  useStockDocument,
  useSupplierOptions,
} from "@/queries/inventory";
import type { DocType, StockDocumentDetail } from "@/repositories/inventory";
import { dateTime, money } from "@/views/admin/pos/format";
import { diffTone } from "./documentLines";
import { DOC_STATUS_TONE } from "./documentStatus";
import DocumentLinesTable from "./DocumentLinesTable.vue";
import ProductPicker from "./ProductPicker.vue";
import { useDocumentLines } from "./useDocumentLines";

const NONE = "none";

const props = defineProps<{ documentId: string | undefined; newType: DocType | undefined; branchId: string | undefined }>();
const emit = defineEmits<{ close: []; saved: [id: string] }>();

const { canCreate, canUpdate, canDelete } = usePermission("inventory");
const docQuery = useStockDocument(computed(() => props.documentId));
const doc = computed<StockDocumentDetail | null>(() => (props.documentId ? docQuery.data.value ?? null : null));
const supplierSearch = ref("");
const {
  items: suppliers,
  loadMore: loadMoreSuppliers,
  hasMore: suppliersMore,
  loading: suppliersLoading,
  loadingMore: suppliersLoadingMore,
} = useSupplierOptions(supplierSearch);
const supplierOptions = computed(() => suppliers.value.map((supplier) => ({ value: supplier.id, label: supplier.name })));
const saveMutation = useSaveStockDocument();
const postMutation = usePostStockDocument();
const busy = computed(() => saveMutation.isPending.value || postMutation.isPending.value);
const cancelMutation = useCancelStockDocument();

const open = computed(() => !!props.documentId || !!props.newType);
const type = computed<DocType>(() => doc.value?.docType ?? props.newType ?? "receipt");
const form = reactive({ supplierId: NONE, supplierRef: "", note: "" });
const { lines, draftValue, load, addProduct, isValid, inputs } = useDocumentLines(type, () => props.branchId);
const submitted = ref(false);
const cancelling = ref(false);
const cancelReason = ref("");

const editable = computed(() => canCreate.value && (!props.documentId || doc.value?.status === "draft"));
// Receipts post with CREATE; write-offs and counts change stock without goods arriving, so a manager posts them.
const canPost = computed(() => (type.value === "receipt" ? canCreate.value : canUpdate.value));
const canCancel = computed(() => {
  if (!doc.value) return false;
  if (doc.value.status === "draft") return canCreate.value;
  return doc.value.status === "posted" && doc.value.docType === "receipt" && canDelete.value;
});

const totalValue = computed(() =>
  doc.value && doc.value.status !== "draft" ? doc.value.totalCost : draftValue.value
);

const resetFrom = async (detail: StockDocumentDetail | null) => {
  submitted.value = false;
  cancelling.value = false;
  cancelReason.value = "";
  form.supplierId = detail?.supplierId ?? NONE;
  form.supplierRef = detail?.supplierRef ?? "";
  form.note = detail?.note ?? "";
  await load(detail);
};

watch(
  () => [props.documentId, props.newType, doc.value] as const,
  ([, newType, detail]) => {
    if (newType) void resetFrom(null);
    else if (detail) void resetFrom(detail);
  },
  { immediate: true }
);

const save = async (post: boolean) => {
  submitted.value = true;
  if (!props.branchId || !isValid()) return;
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
        lines: inputs(),
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
