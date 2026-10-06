<template>
  <div class="space-y-6" v-if="props.services.length > 0">
    
    <div v-if="serviceTypeAll.length > 0">
      <table id="service_apply_for_all" class="w-[550px]">
        <thead>
          <tr>
            <th>Service</th>
            <th>Price</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(i, ii) in serviceTypeAll" :key="ii" :class="{
            'bg-[#dcdcdc]': props.isMouseId === i.id,
          }">
            <td @mouseenter="() => onMouseOver(String(i.id))" @mouseleave="() => onMouseLeave()">
              {{ i.name }}
            </td>
            <td>{{ formatPrice(i.generalPrice || "") }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="table-container">
      <table id="table_full" class="w-full">
        <thead>
          <tr>
            <th class="fixed-column">Weight</th>
            <th v-for="(i, ii) in serviceTypeWeight" :key="ii" @mouseenter="() => onMouseOver(String(i.id))"
              @mouseleave="() => onMouseLeave()" :class="{
                'bg-[#dcdcdc]': props.isMouseId === i.id,
              }">
              {{ i.name }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(i, ii) in contents" :key="ii">
            <td class="fixed-column">
              {{ (contents[ii].lang as any)[String(locale)] }}
            </td>
            <template v-for="(k, kk) in serviceTypeWeight" :key="kk">
              <td v-if="
                data &&
                data[k.id] &&
                data[k.id].some((m: any) => m.weightId === i.id)
              " class="font-semibold text-left pl-3" :class="{
                'bg-[#dcdcdc]': props.isMouseId === k.id,
              }">
                {{
                  formatPrice(
                    data[k.id].find((m: any) => m.weightId === i.id)?.price ?? ''
                  )
                }}
              </td>
              <td v-else :class="{
                'bg-[#dcdcdc]': props.isMouseId === k.id,
              }"></td>
            </template>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <div v-else>
    No data
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { groupPricesByService, useServicePrices } from "@/queries/servicePrices";
import { useRoute } from "vue-router";
import { contents } from "@/data/pet-weights.json";
import { useI18n } from "vue-i18n";
import { formatPrice } from "@/lib/utils";

const route = useRoute();
const props = defineProps<{
  services: any[];
  isMouseId: string;
}>();
const emits = defineEmits(["setMouseEl"]);
console.log('pops', props.services)
const { locale } = useI18n();
// Prices for this pet, grouped by service id (the shape the table renders).
const pricesQuery = useServicePrices({ petId: String(route.params.petId) });
const data = computed(() =>
  pricesQuery.data.value ? groupPricesByService(pricesQuery.data.value) : undefined
);
const serviceTypeWeight = computed(() =>
  props.services.filter((i) => i.type !== "all")
);
const serviceTypeAll = computed(() =>
  props.services.filter((i) => i.type === "all")
);

function onMouseOver(id: string) {
  emits("setMouseEl", id);
}

function onMouseLeave() {
  emits("setMouseEl", "");
}
</script>

<style scoped>
th,
td,
tr {
  border: 1px solid hsl(var(--primary));
}

.table-container {
  overflow-y: auto;
  width: 100%;
  height: 100%;
}

#table_full {
  width: 100%;
  border-collapse: collapse;
}

th,
td {
  padding: 8px;
  text-align: left;
}

.fixed-column {
  position: sticky;
  left: 0;
  background: white;
  z-index: 1;
}
</style>
