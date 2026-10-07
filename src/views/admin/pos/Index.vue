<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ShoppingCart class="size-4 text-primary" />
      {{ $t("pos.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <PosNav />
        <div class="flex flex-wrap items-center gap-2">
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <template v-if="shift">
            <span class="flex items-center gap-2 rounded-lg border border-primary/30 bg-primary/5 px-3 py-1.5 text-sm">
              <span class="size-2 rounded-full bg-primary" />
              {{ $t("pos.shift.current", { code: shift.code, time: dateTime(shift.openedAt) }) }}
            </span>
            <Button variant="outline" size="sm" @click="closeOpen = true">
              <LogOut class="mr-2 size-4" />
              {{ $t("pos.shift.close") }}
            </Button>
          </template>
        </div>
      </div>

      <div
        v-if="branchId && !shiftQuery.isPending.value && !shift"
        class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-amber-200 bg-amber-50 p-4"
      >
        <div>
          <p class="font-semibold text-amber-900">{{ $t("pos.shift.noneTitle") }}</p>
          <p class="text-sm text-amber-800">{{ $t("pos.shift.noneHint") }}</p>
        </div>
        <Button @click="openOpen = true">
          <Wallet class="mr-2 size-4" />
          {{ $t("pos.shift.open") }}
        </Button>
      </div>

      <div class="grid gap-4 lg:h-[calc(100vh-12rem)] lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
        <CatalogPanel class="min-h-[420px]" :branch-id="branchId" @add="addItem" />

        <section class="flex min-h-0 flex-col rounded-xl border bg-white">
          <div class="space-y-2 border-b p-3">
            <h2 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{{ $t("pos.customer.title") }}</h2>
            <CustomerPanel v-model="buyer" />
          </div>

          <div class="min-h-0 flex-1 overflow-y-auto">
            <p v-if="lines.length === 0" class="px-4 py-12 text-center text-sm text-muted-foreground">
              {{ $t("pos.cart.empty") }}
            </p>
            <ul v-else class="divide-y">
              <li v-for="line in lines" :key="line.key" class="space-y-2 px-3 py-3">
                <div class="flex items-start justify-between gap-2">
                  <div class="min-w-0">
                    <p class="text-sm font-semibold leading-snug">{{ line.item.name }}</p>
                    <p class="text-xs text-muted-foreground">
                      {{ $t(`pos.lineType.${line.item.type}`) }}
                      <template v-if="unitPrice(line) !== null"> · {{ money(unitPrice(line)) }}</template>
                      <template v-if="line.item.unit"> / {{ line.item.unit }}</template>
                    </p>
                  </div>
                  <div class="flex items-center gap-1">
                    <span class="whitespace-nowrap text-sm font-bold">
                      {{ unitPrice(line) === null ? "—" : money((unitPrice(line) ?? 0) * line.qty) }}
                    </span>
                    <Button variant="ghost" size="icon" class="size-7 text-muted-foreground" :aria-label="$t('pos.cart.remove')" @click="removeLine(line.key)">
                      <X class="size-4" />
                    </Button>
                  </div>
                </div>

                <div class="flex flex-wrap items-center gap-2">
                  <div class="flex items-center rounded-lg border">
                    <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('pos.cart.less')" @click="changeQty(line, -1)">
                      <Minus class="size-3.5" />
                    </Button>
                    <span class="w-8 text-center text-sm font-semibold">{{ line.qty }}</span>
                    <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('pos.cart.more')" @click="changeQty(line, 1)">
                      <Plus class="size-3.5" />
                    </Button>
                  </div>

                  <Select
                    v-if="line.item.type !== 'product' && pets.length"
                    :model-value="line.petId ?? NO_PET"
                    @update:model-value="setPet(line, String($event))"
                  >
                    <SelectTrigger class="h-8 w-44 text-xs" :aria-label="$t('pos.cart.pet')">
                      <PawPrint class="mr-1 size-3.5 text-muted-foreground" />
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem :value="NO_PET">{{ $t("pos.cart.noPet") }}</SelectItem>
                      <SelectItem v-for="pet in pets" :key="pet.id" :value="pet.id">
                        {{ pet.name }}{{ pet.weightKg ? ` · ${pet.weightKg} kg` : "" }}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <p v-if="lineProblem(line)" class="text-xs text-red-600">{{ lineProblem(line) }}</p>
              </li>
            </ul>
          </div>

          <div class="space-y-3 border-t p-3">
            <div class="flex items-center justify-between gap-3 text-sm">
              <span class="text-muted-foreground">{{ $t("pos.subtotal") }}</span>
              <span class="font-semibold">{{ money(subtotal) }}</span>
            </div>
            <div class="flex items-center justify-between gap-3 text-sm">
              <Label for="pos-discount" class="text-muted-foreground">{{ $t("pos.discount") }}</Label>
              <div class="flex items-center gap-2">
                <span v-if="discount > 0 && subtotal > 0" class="text-xs text-muted-foreground">
                  {{ Math.round((discount / subtotal) * 1000) / 10 }}%
                </span>
                <Input id="pos-discount" v-model="discountText" class="h-8 w-32 text-right" inputmode="numeric" placeholder="0" />
              </div>
            </div>
            <p v-if="discountProblem" class="text-xs text-red-600">{{ discountProblem }}</p>
            <Input v-model="note" class="h-8 text-sm" :placeholder="$t('pos.cart.note')" />
            <div class="flex items-center justify-between">
              <span class="font-semibold">{{ $t("pos.total") }}</span>
              <span class="text-2xl font-bold text-primary">{{ money(total) }}</span>
            </div>
            <div class="flex gap-2">
              <Button variant="outline" :disabled="lines.length === 0" @click="resetSale">{{ $t("pos.cart.clear") }}</Button>
              <Button class="flex-1" size="lg" :disabled="!canCheckout" @click="paymentOpen = true">
                <CreditCard class="mr-2 size-4" />
                {{ $t("pos.cart.checkout") }}
              </Button>
            </div>
            <p v-if="checkoutBlocker" class="text-center text-xs text-muted-foreground">{{ checkoutBlocker }}</p>
          </div>
        </section>
      </div>
    </div>

    <PaymentDialog
      v-model:open="paymentOpen"
      :total="total"
      :busy="createMutation.isPending.value"
      :printing="printing"
      :result="result"
      @confirm="pay"
      @print="print"
    />
    <OpenShiftDialog v-if="branchId" v-model:open="openOpen" :branch-id="branchId" :branch-name="branch?.name ?? ''" />
    <CloseShiftDialog v-model:open="closeOpen" :shift="shift" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch, watchEffect } from "vue";
import { useI18n } from "vue-i18n";
import { CreditCard, LogOut, Minus, PawPrint, Plus, ShoppingCart, Wallet, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { usePermission } from "@/composables/usePermission";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { supabaseClient } from "@/lib/supabase";
import { useCreateInvoice, useCustomerPets, useFetchServicePrice, useMyOpenShift } from "@/queries/pos";
import { DISCOUNT_LIMIT, getInvoice, type SaleCustomer, type SaleResult } from "@/repositories/pos";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "./components/BranchPicker.vue";
import CatalogPanel, { type CatalogItem } from "./components/CatalogPanel.vue";
import CloseShiftDialog from "./components/CloseShiftDialog.vue";
import CustomerPanel, { type Buyer } from "./components/CustomerPanel.vue";
import OpenShiftDialog from "./components/OpenShiftDialog.vue";
import PaymentDialog, { type PaymentEntry } from "./components/PaymentDialog.vue";
import PosNav from "./PosNav.vue";
import { dateTime, money, parseAmount } from "./format";
import { printReceipt } from "./receipt";

type CartLine = { key: string; item: CatalogItem; qty: number; petId: string | null };

const NO_PET = "none";

const { t } = useI18n();
const auth = useAuthStore();
const { canUpdate: canDiscountMore } = usePermission("pos");
const { branches, branch, branchId, selectBranch } = useCurrentBranch();
const userId = computed(() => auth.session?.user.id);

const shiftQuery = useMyOpenShift(branchId, userId);
const shift = computed(() => shiftQuery.data.value ?? null);
const openOpen = ref(false);
const closeOpen = ref(false);

// ------------------------------------------------------------------ cart
const buyer = ref<Buyer | null>(null);
const lines = ref<CartLine[]>([]);
const discountText = ref("");
const note = ref("");
let nextKey = 0;

const petsQuery = useCustomerPets(computed(() => buyer.value?.customerId));
const pets = computed(() => (buyer.value?.customerId ? petsQuery.data.value ?? [] : []));

const addItem = (item: CatalogItem) => {
  // Scanning the same product again adds one more; services and combos get a line per pet.
  const existing = item.type === "product" ? lines.value.find((line) => line.item.id === item.id) : undefined;
  if (existing) {
    existing.qty += 1;
    return;
  }
  const onlyPet = pets.value.length === 1 ? pets.value[0].id : null;
  lines.value.push({ key: String(nextKey++), item, qty: 1, petId: item.type === "product" ? null : onlyPet });
};

const removeLine = (key: string) => {
  lines.value = lines.value.filter((line) => line.key !== key);
};

const changeQty = (line: CartLine, delta: number) => {
  const next = line.qty + delta;
  if (next <= 0) removeLine(line.key);
  else line.qty = next;
};

const setPet = (line: CartLine, value: string) => {
  line.petId = value === NO_PET ? null : value;
};

// A different buyer means different pets: drop pets that are no longer theirs.
watch(pets, (list) => {
  const ids = new Set(list.map((pet) => pet.id));
  const onlyPet = list.length === 1 ? list[0].id : null;
  for (const line of lines.value) {
    if (line.item.type === "product") continue;
    if (line.petId && !ids.has(line.petId)) line.petId = null;
    if (!line.petId && onlyPet) line.petId = onlyPet;
  }
});

// -------------------------------------------------- by-weight price preview
const fetchServicePrice = useFetchServicePrice();
const weightPrices = reactive<Record<string, number | null | "loading">>({});
const weightKey = (line: CartLine) => `${branchId.value ?? ""}:${line.item.id}:${line.petId ?? ""}`;

watchEffect(() => {
  const branch = branchId.value;
  if (!branch) return;
  for (const line of lines.value) {
    if (line.item.type !== "service" || line.item.price !== null || !line.petId) continue;
    const key = weightKey(line);
    if (key in weightPrices) continue;
    const pet = pets.value.find((item) => item.id === line.petId);
    if (!pet?.weightKg) {
      weightPrices[key] = null;
      continue;
    }
    weightPrices[key] = "loading";
    fetchServicePrice({ speciesId: pet.speciesId, serviceId: line.item.id, weightKg: pet.weightKg, branchId: branch })
      .then((price) => (weightPrices[key] = price))
      .catch(() => (weightPrices[key] = null));
  }
});

/** The price shown for a line; null while a by-weight service cannot be priced yet. */
const unitPrice = (line: CartLine): number | null => {
  if (line.item.price !== null) return line.item.price;
  const price = weightPrices[weightKey(line)];
  return typeof price === "number" ? price : null;
};

const lineProblem = (line: CartLine): string => {
  if (line.item.type === "product" || line.item.price !== null) return "";
  if (!buyer.value?.customerId) return t("pos.cart.needCustomerPet");
  if (!line.petId) return t("pos.cart.needPet");
  const pet = pets.value.find((item) => item.id === line.petId);
  if (!pet?.weightKg) return t("pos.cart.needWeight");
  const price = weightPrices[weightKey(line)];
  if (price === "loading") return "";
  return price === null ? t("pos.cart.noPrice") : "";
};

const subtotal = computed(() => lines.value.reduce((sum, line) => sum + (unitPrice(line) ?? 0) * line.qty, 0));
const discount = computed(() => parseAmount(discountText.value));
const total = computed(() => Math.max(0, subtotal.value - discount.value));

const discountProblem = computed(() => {
  if (discount.value > subtotal.value) return t("pos.cart.discountTooHigh");
  if (discount.value > subtotal.value * DISCOUNT_LIMIT && !canDiscountMore.value) return t("pos.errors.discount_limit");
  return "";
});

const checkoutBlocker = computed(() => {
  if (!shift.value) return t("pos.errors.no_open_shift");
  if (lines.value.length === 0) return "";
  if (lines.value.some((line) => unitPrice(line) === null)) return t("pos.cart.unpriced");
  return discountProblem.value;
});
const canCheckout = computed(() => lines.value.length > 0 && !checkoutBlocker.value);

// ---------------------------------------------------------------- payment
const paymentOpen = ref(false);
const result = ref<SaleResult | null>(null);
const printing = ref(false);
const createMutation = useCreateInvoice();

const toSaleCustomer = (value: Buyer | null): SaleCustomer => {
  if (!value) return null;
  if (value.customerId) return { id: value.customerId };
  if (value.userId) return { userId: value.userId };
  return { fullName: value.fullName, phone: value.phone };
};

const pay = async (payments: PaymentEntry[]) => {
  if (!branchId.value) return;
  try {
    result.value = await createMutation.mutateAsync({
      branchId: branchId.value,
      customer: toSaleCustomer(buyer.value),
      discountAmount: discount.value,
      note: note.value.trim() || null,
      lines: lines.value.map((line) => ({
        type: line.item.type,
        id: line.item.id,
        qty: line.qty,
        petId: line.petId,
      })),
      payments,
    });
  } catch {
    // the mutation already showed the failure toast
  }
};

const print = async () => {
  if (!result.value) return;
  printing.value = true;
  try {
    const invoice = await getInvoice(supabaseClient(), result.value.id);
    if (invoice) printReceipt(invoice, branch.value, t);
  } finally {
    printing.value = false;
  }
};

const resetSale = () => {
  buyer.value = null;
  lines.value = [];
  discountText.value = "";
  note.value = "";
};

// Closing the dialog after a sale starts the next one.
watch(paymentOpen, (open) => {
  if (open || !result.value) return;
  result.value = null;
  resetSale();
});
</script>
