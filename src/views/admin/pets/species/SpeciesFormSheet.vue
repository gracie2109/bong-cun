<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-md">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ species ? $t("petCare.species.edit") : $t("petCare.species.add") }}</SheetTitle>
        <SheetDescription class="sr-only">{{ $t("petCare.species.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="species-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="species-name">{{ $t("petCare.species.name") }}</Label>
          <Input id="species-name" v-model="name" />
          <p v-if="submitted && !name.trim()" class="text-sm text-red-600">
            {{ $t("petCare.common.required") }}
          </p>
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.species.icon") }}</Label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="option in ICONS"
              :key="option"
              type="button"
              class="flex size-10 items-center justify-center rounded-lg border transition-colors"
              :class="icon === option ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
              :aria-pressed="icon === option"
              @click="icon = icon === option ? '' : option"
            >
              <Icon :icon="option" class="size-5" />
            </button>
          </div>
        </div>

        <div class="space-y-2">
          <Label for="species-desc">{{ $t("petCare.species.desc") }}</Label>
          <Textarea id="species-desc" v-model="desc" class="resize-none" rows="3" />
        </div>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button type="submit" form="species-form" :disabled="pending">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Icon } from "@iconify/vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Textarea } from "@/components/ui/textarea";
import { useCreateSpecies, useUpdateSpecies } from "@/queries/species";
import type { Species } from "@/repositories/species";

const ICONS = ["lucide:dog", "lucide:cat", "lucide:rabbit", "lucide:bird", "lucide:fish", "lucide:squirrel"];

const props = defineProps<{ open: boolean; species: Species | null }>();
const emit = defineEmits<{ "update:open": [value: boolean]; saved: [id: string] }>();

const name = ref("");
const icon = ref("");
const desc = ref("");
const submitted = ref(false);

const create = useCreateSpecies();
const update = useUpdateSpecies();
const pending = computed(() => create.isPending.value || update.isPending.value);

// Load the species being edited (or blank values) each time the sheet opens.
watch(
  () => [props.open, props.species],
  () => {
    if (!props.open) return;
    name.value = props.species?.name ?? "";
    icon.value = props.species?.icon ?? "";
    desc.value = props.species?.desc ?? "";
    submitted.value = false;
  },
  { immediate: true }
);

const submit = async () => {
  submitted.value = true;
  if (!name.value.trim()) return;
  const input = {
    name: name.value.trim(),
    icon: icon.value || null,
    desc: desc.value.trim() || null,
    isActive: props.species?.isActive ?? true,
  };
  try {
    const id = props.species
      ? await update.mutateAsync({ id: props.species.id, input })
      : await create.mutateAsync(input);
    emit("saved", id);
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast; keep the sheet open
  }
};
</script>
