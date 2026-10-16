<template>
  <li class="flex gap-4 py-5" :class="{ 'opacity-60': !line.isSellable }">
    <RouterLink
      :to="productLink"
      class="size-20 shrink-0 overflow-hidden rounded-2xl bg-white ring-1 ring-border/70 sm:size-24"
      tabindex="-1"
      aria-hidden="true"
    >
      <img v-if="line.imageUrl" :src="line.imageUrl" alt="" class="size-full object-contain p-1.5" loading="lazy" />
      <span v-else class="grid size-full place-content-center bg-muted text-muted-foreground/40"><PawMark class="size-8" /></span>
    </RouterLink>

    <div class="flex min-w-0 flex-1 flex-col gap-2">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <RouterLink :to="productLink" class="line-clamp-2 font-semibold leading-snug hover:text-primary">{{ line.name }}</RouterLink>
          <p v-if="line.variant || showUnit" class="mt-0.5 text-sm text-muted-foreground">
            {{ [line.variant, showUnit ? line.unitName : null].filter(Boolean).join(" · ") }}
          </p>
        </div>
        <p class="shrink-0 text-right font-bold tabular-nums">{{ formatPrice(lineAmount(line)) }}</p>
      </div>

      <p v-if="issue?.kind === 'unavailable'" class="text-sm font-medium text-destructive">{{ $t("shop.cart.unavailable") }}</p>
      <p v-else-if="issue?.kind === 'over_stock'" class="text-sm font-medium text-destructive">
        {{ $t("shop.cart.onlyLeft", { n: issue.available }) }}
      </p>
      <p v-else-if="line.shipPolicy === 'in_store_only'" class="text-xs font-medium text-amber-800">{{ $t("shop.cart.inStoreOnly") }}</p>

      <div class="mt-auto flex flex-wrap items-center justify-between gap-2">
        <div v-if="line.isSellable" class="inline-flex h-10 items-center rounded-full border bg-white">
          <button type="button" class="grid size-10 place-content-center rounded-full hover:bg-muted" :aria-label="$t('shop.less')" @click="set(draft - 1)">
            <Minus class="size-4" />
          </button>
          <input
            :value="draft"
            inputmode="numeric"
            :aria-label="$t('shop.quantity')"
            class="w-9 bg-transparent text-center text-sm font-semibold tabular-nums outline-none"
            @change="set(Number(($event.target as HTMLInputElement).value))"
          />
          <button type="button" class="grid size-10 place-content-center rounded-full hover:bg-muted" :aria-label="$t('shop.more')" @click="set(draft + 1)">
            <Plus class="size-4" />
          </button>
        </div>
        <span v-else />
        <div class="flex items-center gap-3">
          <span v-if="line.unitPrice !== null && line.qty > 1" class="text-xs text-muted-foreground tabular-nums">
            {{ formatPrice(line.unitPrice) }} × {{ line.qty }}
          </span>
          <button
            type="button"
            class="grid size-10 place-content-center rounded-full text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
            :aria-label="$t('shop.cart.remove')"
            @click="emit('remove')"
          >
            <Trash2 class="size-[18px]" />
          </button>
        </div>
      </div>
    </div>
  </li>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import { Minus, Plus, Trash2 } from "lucide-vue-next";
import PawMark from "@/components/shop/PawMark.vue";
import { useQtyInput } from "@/composables/shop/useQtyInput";
import { formatPrice } from "@/lib/utils";
import type { CartLineView } from "@bongcun/core/shop";
import { lineAmount, lineIssue } from "@/utils/shop/cart";

const props = defineProps<{ line: CartLineView }>();
const emit = defineEmits<{ qty: [qty: number]; remove: [] }>();

const issue = computed(() => lineIssue(props.line));
// The unit is worth showing only when it is not the product's own (thùng, hộp...).
const showUnit = computed(() => props.line.unitId !== null);
const productLink = computed(() => (props.line.groupId ? { name: "product-detail", params: { id: props.line.groupId } } : { name: "products" }));
const { draft, set } = useQtyInput(toRef(() => props.line.qty), (qty) => emit("qty", qty));
</script>
