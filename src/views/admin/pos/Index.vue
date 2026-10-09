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
              <PosCartLine
                v-for="line in lines"
                :key="line.key"
                :line="line"
                :pets="pets"
                :price="unitPrice(line)"
                :problem="lineProblem(line)"
                @remove="removeLine(line.key)"
                @change-qty="changeQty(line, $event)"
                @set-pet="setPet(line, $event)"
              />
            </ul>
          </div>

          <PosCartFooter
            v-model:discount-text="discountText"
            v-model:note="note"
            :subtotal="subtotal"
            :discount="discount"
            :total="total"
            :discount-problem="discountProblem"
            :checkout-blocker="checkoutBlocker"
            :can-checkout="canCheckout"
            :has-lines="lines.length > 0"
            @clear="resetSale"
            @checkout="paymentOpen = true"
          />
        </section>
      </div>
    </div>

    <PaymentDialog
      v-model:open="paymentOpen"
      :total="total"
      :busy="creating"
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
import { computed, ref } from "vue";
import { LogOut, ShoppingCart, Wallet } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useMyOpenShift } from "@/queries/pos";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "./components/BranchPicker.vue";
import CatalogPanel from "./components/CatalogPanel.vue";
import CloseShiftDialog from "./components/CloseShiftDialog.vue";
import CustomerPanel from "./components/CustomerPanel.vue";
import OpenShiftDialog from "./components/OpenShiftDialog.vue";
import PaymentDialog from "./components/PaymentDialog.vue";
import PosCartFooter from "./components/PosCartFooter.vue";
import PosCartLine from "./components/PosCartLine.vue";
import PosNav from "./PosNav.vue";
import { dateTime } from "./format";
import { usePosCart } from "./usePosCart";
import { usePosCheckout } from "./usePosCheckout";

const auth = useAuthStore();
const { branches, branch, branchId, selectBranch } = useCurrentBranch();
const userId = computed(() => auth.session?.user.id);

const shiftQuery = useMyOpenShift(branchId, userId);
const shift = computed(() => shiftQuery.data.value ?? null);
const openOpen = ref(false);
const closeOpen = ref(false);

const {
  buyer,
  lines,
  pets,
  discountText,
  note,
  subtotal,
  discount,
  total,
  discountProblem,
  checkoutBlocker,
  canCheckout,
  addItem,
  removeLine,
  changeQty,
  setPet,
  unitPrice,
  lineProblem,
  resetSale,
} = usePosCart(branchId, computed(() => !!shift.value));

const { paymentOpen, result, printing, creating, pay, print } = usePosCheckout({
  branchId,
  branch,
  buyer,
  lines,
  discount,
  note,
  reset: resetSale,
});
</script>
