<template>
  <li class="flex gap-3 rounded-xl border bg-white p-3 sm:gap-4 sm:p-4" :class="{ 'opacity-60': !line.isSellable }">
    <div class="size-20 shrink-0 overflow-hidden rounded-lg bg-muted/40 sm:size-24">
      <img v-if="line.imageUrl" :src="line.imageUrl" alt="" class="size-full object-cover" loading="lazy" />
      <div v-else class="grid size-full place-content-center"><ImageIcon class="size-8 text-muted-foreground" /></div>
    </div>

    <div class="flex min-w-0 flex-1 flex-col gap-2">
      <div class="flex items-start justify-between gap-2">
        <div class="min-w-0">
          <p class="line-clamp-2 font-semibold">{{ line.name }}</p>
          <p v-if="line.variant || showUnit" class="text-xs text-muted-foreground">
            {{ [line.variant, showUnit ? line.unitName : null].filter(Boolean).join(" · ") }}
          </p>
        </div>
        <button
          type="button"
          class="shrink-0 rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-red-600"
          :aria-label="$t('shop.cart.remove')"
          @click="$emit('remove')"
        >
          <Trash2 class="size-4" />
        </button>
      </div>

      <p v-if="issue?.kind === 'unavailable'" class="text-sm font-medium text-red-600">{{ $t("shop.cart.unavailable") }}</p>
      <p v-else-if="issue?.kind === 'over_stock'" class="text-sm font-medium text-red-600">
        {{ $t("shop.cart.onlyLeft", { n: issue.available }) }}
      </p>
      <p v-else-if="line.shipPolicy === 'in_store_only'" class="text-xs text-amber-700">{{ $t("shop.cart.inStoreOnly") }}</p>

      <div class="mt-auto flex flex-wrap items-center justify-between gap-2">
        <div v-if="line.isSellable" class="flex items-center rounded-md border">
          <button type="button" class="grid size-8 place-content-center" :aria-label="$t('shop.less')" @click="set(draft - 1)">
            <Minus class="size-4" />
          </button>
          <input
            :value="draft"
            inputmode="numeric"
            class="w-10 border-x bg-transparent text-center text-sm tabular-nums outline-none"
            @change="set(Number(($event.target as HTMLInputElement).value))"
          />
          <button type="button" class="grid size-8 place-content-center" :aria-label="$t('shop.more')" @click="set(draft + 1)">
            <Plus class="size-4" />
          </button>
        </div>
        <span v-else />
        <div class="text-right">
          <p class="font-bold text-primary">{{ formatPrice(lineAmount(line)) }}</p>
          <p v-if="line.unitPrice !== null && line.qty > 1" class="text-xs text-muted-foreground">
            {{ formatPrice(line.unitPrice) }} × {{ line.qty }}
          </p>
        </div>
      </div>
    </div>
  </li>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import { Image as ImageIcon, Minus, Plus, Trash2 } from "lucide-vue-next";
import { useQtyInput } from "@/composables/shop/useQtyInput";
import { formatPrice } from "@/lib/utils";
import type { CartLineView } from "@/types/shop";
import { lineAmount, lineIssue } from "@/utils/shop/cart";

const props = defineProps<{ line: CartLineView }>();
const emit = defineEmits<{ qty: [qty: number]; remove: [] }>();

const issue = computed(() => lineIssue(props.line));
// The unit is worth showing only when it is not the product's own (thùng, hộp...).
const showUnit = computed(() => props.line.unitId !== null);
const { draft, set } = useQtyInput(toRef(() => props.line.qty), (qty) => emit("qty", qty));
</script>
