<template>
  <section class="space-y-3 rounded-xl border bg-muted/30 p-4">
    <h3 class="text-sm font-semibold">{{ $t("medical.addenda.title") }}</h3>
    <p v-if="addenda.length === 0" class="text-sm text-muted-foreground">{{ $t("medical.addenda.empty") }}</p>
    <ul class="space-y-2">
      <li v-for="item in addenda" :key="item.id" class="rounded-lg border bg-white p-3 text-sm">
        <p class="whitespace-pre-line">{{ item.content }}</p>
        <p class="mt-1 text-xs text-muted-foreground">{{ item.createdByName ?? "-" }} · {{ dateTime(item.createdAt) }}</p>
      </li>
    </ul>
    <form v-if="canAdd" class="space-y-2" @submit.prevent="submit">
      <Textarea v-model="content" rows="2" :placeholder="$t('medical.addenda.placeholder')" />
      <Button type="submit" size="sm" :disabled="!content.trim() || adding.isPending.value">{{ $t("medical.addenda.add") }}</Button>
    </form>
  </section>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { useAddAddendum } from "@/features/admin/medical/queries/medicalVisits";
import type { VisitAddendum } from "@bongcun/core/medical";
import { dateTime } from "../../format";

const props = defineProps<{ visitId: string; addenda: VisitAddendum[]; canAdd: boolean }>();

const content = ref("");
const adding = useAddAddendum();

const submit = async () => {
  try {
    await adding.mutateAsync({ id: props.visitId, content: content.value.trim() });
    content.value = "";
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
