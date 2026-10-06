<template>
  <div class="space-y-3 w-full h-full">
    <div class="flex flex-end justify-end gap-x-3">
      <Button
        variant="outline"
        @click="clearData"
        :disabled="!props.isHandleForm || loading"
      >
        <RotateCcw class="size-4 mr-2" :class="{'animate-spin': loading}"/>
        Clear
      </Button>
      <Button @click="handleSubmit" :disabled="!props.isHandleForm || loading" >
        <Save class="size-4 mr-2"  />
        Save
      </Button>
    </div>
    <table class="w-full">
      <thead>
        <tr>
          <th>Weights</th>
          <th>Price</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(item, index) in data2" :key="item.weightId" class="p-3">
          <td>{{ (contents[index].lang as any)[String(locale)] }}</td>
          <td class="p-1">
            <Input
              :readonly="loading"
              type="number"
              :placeholder="`Enter price of ${(contents[index].lang as any)[String(locale)]}`"
              v-model:model-value="item.price"
            />
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { contents } from "@/data/pet-weights.json";
import Input from "@/components/ui/input/Input.vue";
import { useRoute } from "vue-router";
import Button from "@/components/ui/button/Button.vue";
import { Save, RotateCcw } from "lucide-vue-next";
import { useSaveServicePrices, useServicePrices } from "@/queries/servicePrices";
import type { ServicePrice } from "@/repositories/servicePrices";

type IPrice = {
  [key: string]: string | number;
};

const props = defineProps<{
  isHandleForm: boolean;
}>();

const { locale } = useI18n();
const route = useRoute();
const petId = String(route.params.petId);
const serviceId = String(route.params.serviceId);

const data2 = ref<IPrice[]>(
  contents.map((i) => {
    return {
      id: "",
      petId,
      serviceId,
      weightId: String(i.id),
      price: "",
    };
  })
);

const pricesQuery = useServicePrices({ petId, serviceId });
const savePrices = useSaveServicePrices();
const loading = computed(() => pricesQuery.isFetching.value || savePrices.isPending.value);

// Fill the inputs from the saved prices; a weight with no saved price is blank.
function applyPrices(prices: ServicePrice[] | undefined) {
  data2.value.forEach((row) => {
    const saved = prices?.find((price) => price.weightId === row.weightId);
    row.id = saved?.id ?? "";
    row.price = saved ? saved.price : "";
  });
}

watch(() => pricesQuery.data.value, applyPrices, { immediate: true });

/** Discards unsaved edits and shows the saved prices again. */
function clearData() {
  applyPrices(pricesQuery.data.value);
}

async function handleSubmit() {
  try {
    await savePrices.mutateAsync({
      petId,
      serviceId,
      rows: data2.value.map((row) => ({
        weightId: String(row.weightId),
        price: row.price === "" ? null : row.price,
      })),
    });
  } catch {
    // the mutation already showed the failure toast
  }
}
</script>

<style scoped>
th,
td,
tr {
  border: 1px solid hsl(var(--primary));
}
</style>
