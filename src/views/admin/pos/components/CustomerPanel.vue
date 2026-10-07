<template>
  <div class="space-y-2">
    <div v-if="modelValue" class="flex items-center justify-between gap-3 rounded-lg border bg-primary/5 px-3 py-2">
      <div class="flex min-w-0 items-center gap-2">
        <UserRound class="size-4 shrink-0 text-primary" />
        <div class="min-w-0">
          <p class="truncate text-sm font-semibold">
            {{ modelValue.fullName }}
            <span v-if="modelValue.isNew" class="ml-1 rounded-full bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold text-amber-700">
              {{ $t("pos.customer.newBadge") }}
            </span>
          </p>
          <p class="text-xs text-muted-foreground">{{ modelValue.phone }}</p>
        </div>
      </div>
      <Button type="button" size="sm" variant="ghost" @click="clear">{{ $t("pos.customer.change") }}</Button>
    </div>

    <template v-else>
      <div class="relative">
        <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input v-model="searchInput" class="pl-9" :placeholder="$t('pos.customer.searchPlaceholder')" />
      </div>
      <p class="text-xs text-muted-foreground">{{ $t("pos.customer.walkInHint") }}</p>

      <ul v-if="matches.length" class="divide-y rounded-lg border">
        <li v-for="match in matches" :key="matchKey(match)">
          <button
            type="button"
            class="flex w-full items-center justify-between gap-3 px-3 py-2 text-left hover:bg-muted/50"
            @click="pick(match)"
          >
            <span class="min-w-0">
              <span class="block truncate text-sm font-semibold">{{ match.fullName }}</span>
              <span class="block text-xs text-muted-foreground">
                {{ match.phone }} · {{ $t("pos.customer.pets", { n: match.petCount }) }}
              </span>
            </span>
            <span class="text-xs font-semibold text-primary">{{ $t("pos.customer.choose") }}</span>
          </button>
        </li>
      </ul>

      <div
        v-else-if="searchText.trim().length >= 2 && !matchesQuery.isFetching.value"
        class="space-y-2 rounded-lg border border-dashed p-3"
      >
        <p class="text-xs text-muted-foreground">{{ $t("pos.customer.notFound") }}</p>
        <div class="grid gap-2 sm:grid-cols-2">
          <Input v-model="newName" :placeholder="$t('pos.customer.fullName')" />
          <Input v-model="newPhone" inputmode="tel" :placeholder="$t('pos.customer.phone')" />
        </div>
        <Button type="button" size="sm" variant="outline" :disabled="!newValid" @click="useNew">
          <UserPlus class="mr-2 size-4" />
          {{ $t("pos.customer.useNew") }}
        </Button>
      </div>
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { Search, UserPlus, UserRound } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCustomerSearch } from "@/queries/customers";
import { digitsOf, matchKey, type CustomerMatch } from "@/repositories/customers";

/** The buyer picked at the counter; null = anonymous walk-in. */
export type Buyer = {
  customerId: string | null;
  userId: string | null;
  fullName: string;
  phone: string;
  /** Typed at the counter; created with the invoice. */
  isNew: boolean;
};

const SEARCH_DEBOUNCE_MS = 500;
const MIN_PHONE_DIGITS = 8;
const MAX_PHONE_DIGITS = 15;

defineProps<{ modelValue: Buyer | null }>();
const emit = defineEmits<{ "update:modelValue": [value: Buyer | null] }>();

const searchInput = ref("");
const searchText = refDebounced(searchInput, SEARCH_DEBOUNCE_MS);
const matchesQuery = useCustomerSearch(searchText);
const matches = computed(() => (searchText.value.trim().length >= 2 ? matchesQuery.data.value ?? [] : []));

const newName = ref("");
const newPhone = ref("");
const newValid = computed(() => {
  const digits = digitsOf(newPhone.value).length;
  return !!newName.value.trim() && digits >= MIN_PHONE_DIGITS && digits <= MAX_PHONE_DIGITS;
});

// What was typed in the search box is usually the phone or the name of the new customer.
watch(searchText, (text) => {
  const value = text.trim();
  if (digitsOf(value).length >= MIN_PHONE_DIGITS && /^[\d\s.+-]+$/.test(value)) newPhone.value = value;
  else if (value) newName.value = value;
});

const pick = (match: CustomerMatch) =>
  emit("update:modelValue", {
    customerId: match.customerId,
    userId: match.userId,
    fullName: match.fullName,
    phone: match.phone,
    isNew: false,
  });

const useNew = () =>
  emit("update:modelValue", {
    customerId: null,
    userId: null,
    fullName: newName.value.trim(),
    phone: newPhone.value.trim(),
    isNew: true,
  });

const clear = () => {
  searchInput.value = "";
  newName.value = "";
  newPhone.value = "";
  emit("update:modelValue", null);
};
</script>
