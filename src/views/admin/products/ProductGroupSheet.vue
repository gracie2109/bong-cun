<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-5xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ groupId ? $t("products.edit") : $t("products.add") }}</SheetTitle>
        <SheetDescription>{{ $t("products.subtitle") }}</SheetDescription>
      </SheetHeader>

      <div v-if="loading" class="space-y-3 p-6">
        <Skeleton v-for="i in 4" :key="i" class="h-10 w-full" />
      </div>

      <form v-else id="product-group-form" class="flex min-h-0 flex-1 flex-col" @submit.prevent="submit">
        <Tabs v-model="tab" class="flex min-h-0 flex-1 flex-col">
          <TabsList class="shrink-0 justify-start border-b px-6">
            <TabsTrigger v-for="item in tabs" :key="item" :value="item">
              {{ item === "images" ? $t("products.tabs.images", { n: gallery.images.value.length }) : $t(`products.tabs.${item}`) }}
              <span v-if="tabErrors[item]" class="ml-1.5 size-2 rounded-full bg-red-500" />
            </TabsTrigger>
          </TabsList>
          <div class="min-h-0 flex-1 overflow-y-auto px-6 py-5">
            <TabsContent value="general" class="mt-0">
              <GeneralTab :form="form" :submitted="submitted" />
            </TabsContent>
            <TabsContent value="images" class="mt-0">
              <ImagesTab
                :images="gallery.images.value"
                :uploading="gallery.uploading.value"
                :error="gallery.error.value"
                @add="gallery.add"
                @remove="gallery.remove"
                @move="gallery.move"
                @make-cover="gallery.makeCover"
              />
            </TabsContent>
            <TabsContent value="variants" class="mt-0">
              <VariantsTab
                v-model:attributes="attributes"
                v-model:rows="rows"
                v-model:bulk="bulk"
                :known-attributes="knownAttributes"
                :images="gallery.images.value"
                :submitted="submitted"
              />
            </TabsContent>
            <TabsContent value="units" class="mt-0">
              <UnitsTab v-model:rows="rows" :submitted="submitted" />
            </TabsContent>
            <TabsContent v-if="priceGrid.visible.value" value="branchPrices" class="mt-0">
              <BranchPricesTab
                :rows="rows"
                :branches="priceGrid.branches.value"
                :cells="priceGrid.cells"
                :can-edit="priceGrid.canEdit"
              />
            </TabsContent>
          </div>
        </Tabs>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">{{ $t("petCare.common.cancel") }}</Button>
        <Button type="submit" form="product-group-form" :disabled="saving || loading">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import BranchPricesTab from "./tabs/BranchPricesTab.vue";
import GeneralTab from "./tabs/GeneralTab.vue";
import UnitsTab from "./tabs/UnitsTab.vue";
import ImagesTab from "./tabs/ImagesTab.vue";
import VariantsTab from "./tabs/VariantsTab.vue";
import { useProductGroupForm, type ProductTab } from "./useProductGroupForm";

const BASE_TABS: ProductTab[] = ["general", "images", "variants", "units"];

const props = defineProps<{ open: boolean; groupId: string | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const { form, attributes, rows, bulk, knownAttributes, gallery, priceGrid, submitted, tab, tabErrors, loading, saving, submit } =
  useProductGroupForm(toRef(props, "open"), toRef(props, "groupId"), () => emit("update:open", false));

// The price grid only makes sense with more than one branch.
const tabs = computed<ProductTab[]>(() => (priceGrid.visible.value ? [...BASE_TABS, "branchPrices"] : BASE_TABS));
</script>
