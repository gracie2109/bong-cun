<template>
  <Dialog :open="open" @update:open="emit('update:open', $event)">
    <DialogContent class="sm:max-w-md">
      <DialogHeader>
        <DialogTitle>{{ $t("pos.shift.openTitle") }}</DialogTitle>
        <DialogDescription>{{ $t("pos.shift.openSubtitle", { branch: branchName }) }}</DialogDescription>
      </DialogHeader>
      <form id="open-shift-form" class="space-y-4" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="opening-cash">{{ $t("pos.shift.openingCash") }}</Label>
          <Input id="opening-cash" v-model="openingCash" inputmode="numeric" placeholder="0" />
          <p class="text-xs text-muted-foreground">{{ money(parseAmount(openingCash)) }}</p>
        </div>
        <div class="space-y-2">
          <Label for="open-note">{{ $t("pos.shift.note") }}</Label>
          <Input id="open-note" v-model="note" />
        </div>
      </form>
      <DialogFooter class="gap-2">
        <Button variant="outline" @click="emit('update:open', false)">{{ $t("petCare.common.cancel") }}</Button>
        <Button type="submit" form="open-shift-form" :disabled="mutation.isPending.value">
          {{ $t("pos.shift.open") }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useOpenShift } from "@/queries/pos";
import { money, parseAmount } from "../format";

const props = defineProps<{ open: boolean; branchId: string; branchName: string }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const openingCash = ref("");
const note = ref("");
const mutation = useOpenShift();

watch(
  () => props.open,
  (open) => {
    if (open) {
      openingCash.value = "";
      note.value = "";
    }
  }
);

const submit = async () => {
  try {
    await mutation.mutateAsync({
      branchId: props.branchId,
      openingCash: parseAmount(openingCash.value),
      note: note.value.trim(),
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
