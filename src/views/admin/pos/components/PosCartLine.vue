<template>
  <li class="space-y-2 px-3 py-3">
    <div class="flex items-start justify-between gap-2">
      <div class="min-w-0">
        <p class="text-sm font-semibold leading-snug">{{ line.item.name }}</p>
        <p class="text-xs text-muted-foreground">
          {{ $t(`pos.lineType.${line.item.type}`) }}
          <template v-if="price !== null"> · {{ money(price) }}</template>
          <template v-if="line.item.unit"> / {{ line.item.unit }}</template>
        </p>
      </div>
      <div class="flex items-center gap-1">
        <span class="whitespace-nowrap text-sm font-bold">
          {{ price === null ? "—" : money(price * line.qty) }}
        </span>
        <Button variant="ghost" size="icon" class="size-7 text-muted-foreground" :aria-label="$t('pos.cart.remove')" @click="emit('remove')">
          <X class="size-4" />
        </Button>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <div class="flex items-center rounded-lg border">
        <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('pos.cart.less')" @click="emit('changeQty', -1)">
          <Minus class="size-3.5" />
        </Button>
        <span class="w-8 text-center text-sm font-semibold">{{ line.qty }}</span>
        <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('pos.cart.more')" @click="emit('changeQty', 1)">
          <Plus class="size-3.5" />
        </Button>
      </div>

      <Select
        v-if="line.item.type !== 'product' && pets.length"
        :model-value="line.petId ?? NO_PET"
        @update:model-value="(value) => emit('setPet', value === NO_PET ? null : String(value))"
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

    <p v-if="problem" class="text-xs text-red-600">{{ problem }}</p>
  </li>
</template>

<script lang="ts" setup>
import { Minus, PawPrint, Plus, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { CustomerPet } from "@/repositories/pos";
import { money } from "../format";
import type { CartLine } from "../usePosCart";

const NO_PET = "none";

defineProps<{
  line: CartLine;
  /** Pets of the buyer, offered for service lines. */
  pets: CustomerPet[];
  /** Price of one unit; null while a by-weight service cannot be priced yet. */
  price: number | null;
  /** Why the line cannot be sold yet, empty when it can. */
  problem: string;
}>();

const emit = defineEmits<{ remove: []; changeQty: [delta: number]; setPet: [petId: string | null] }>();
</script>
