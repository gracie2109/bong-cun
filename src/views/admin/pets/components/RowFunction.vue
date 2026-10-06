<template>
  <ActionRow :type="type" :row="props.row" @click="handleEmit">
    <Tooltip v-if="$route.name === 'pets'">
      <TooltipTrigger as-child>
        <Button
          variant="ghost"
          @click="
            $router.push({
              name: 'settingPetServicePrice',
              params: { petId: row.original.id },
            })
          "
        >
          <Settings class="size-6 text-primary" />
        </Button>
      </TooltipTrigger>
      <TooltipContent>
        {{ $t("pageMeta.settingPetServicePrice") }}
      </TooltipContent>
    </Tooltip>

    <DropdownMenu v-if="showSettingPrice">
      <DropdownMenuTrigger>
        <EllipsisVertical class="text-primary-subb" />
      </DropdownMenuTrigger>
      <DropdownMenuContent>
        <DropdownMenuLabel>Setting price</DropdownMenuLabel>
        <DropdownMenuSeparator />

        <DropdownMenuItem v-for="(i, ii) in pets" :key="ii">
          <div
            class="flex items-center gap-3 hover:text-primary"
            @click="
              $router.push({
                name: 'settingPetServicePrice',
                params: { petId: i.id },
              })
            "
          >
            <Icon :icon="i.icon ?? ''" />
            <span class="font-bold capitalize cursor-pointer">
              {{ i.name }}
            </span>
          </div>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  </ActionRow>
</template>

<script lang="ts" setup>
import { ActionRow } from "@/components/common";
import { Tooltip, TooltipTrigger, TooltipContent } from "@/components/ui/tooltip";
import { Button } from "@/components/ui/button";

import type { T_ROW_FUNCTION } from "@/types";
import type { Row } from "@tanstack/vue-table";
import { computed, reactive } from "vue";
import { EllipsisVertical, Settings } from "lucide-vue-next";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useRoute } from "vue-router";
import { useAllPets } from "@/queries/pets";
import { Icon } from "@iconify/vue";
const props = defineProps<{
  row: Row<any>;
}>();
const emits = defineEmits(["click"]);
const { data: pets } = useAllPets();

const type = reactive<T_ROW_FUNCTION[]>([
  {
    id: "DELETE",
    isShow: true,
  },
  {
    id: "EDIT",
    isShow: true,
  },
]);

const route = useRoute();
const showSettingPrice = computed(() => route.name !== "pets")
function handleEmit({ action, row }: { action: T_ROW_FUNCTION; row: any }) {
  emits("click", { action, row });
}
</script>
