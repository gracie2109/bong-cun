<template>
  <div class="space-y-5">
    <p v-if="visit.signedAt" class="flex items-center gap-2 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
      <Lock class="size-4" />
      {{ $t("medical.record.signedBy", { name: visit.signedByName ?? "-", time: dateTime(visit.signedAt) }) }}
    </p>
    <p v-else-if="!canEdit" class="rounded-lg border border-dashed px-3 py-2 text-sm text-muted-foreground">
      {{ $t(visit.status === "in_progress" ? "medical.record.readOnly" : "medical.record.notStarted") }}
    </p>

    <section class="space-y-2">
      <h3 class="text-sm font-semibold">{{ $t("medical.record.vitals") }}</h3>
      <VitalsFields v-model:draft="draft" :readonly="readonly" />
    </section>

    <section class="space-y-2">
      <h3 class="text-sm font-semibold">{{ $t("medical.record.soap") }}</h3>
      <SoapFields v-model:draft="draft" :readonly="readonly" />
    </section>

    <DiagnosisPicker v-model:draft="draft" :readonly="readonly" />
    <OutcomeFields v-model:draft="draft" :readonly="readonly" />

    <div v-if="canEdit" class="flex flex-wrap justify-end gap-2 border-t pt-4">
      <Button variant="outline" :disabled="busy" @click="save">
        <Save class="mr-2 size-4" />
        {{ $t("petCare.common.save") }}
      </Button>
      <Button :disabled="busy || !signable" @click="sign">
        <Loader2 v-if="busy" class="mr-2 size-4 animate-spin" />
        <FileSignature v-else class="mr-2 size-4" />
        {{ $t("medical.record.sign") }}
      </Button>
    </div>
    <p v-if="canEdit && !signable" class="text-right text-xs text-muted-foreground">{{ $t("medical.record.signHint") }}</p>

    <AddendaList v-if="visit.signedAt" :visit-id="visit.id" :addenda="visit.addenda" :can-add="canAddAddendum" />
  </div>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { FileSignature, Loader2, Lock, Save } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import type { MedicalVisitDetail } from "@bongcun/core/medical";
import { dateTime } from "../../format";
import AddendaList from "./AddendaList.vue";
import DiagnosisPicker from "./DiagnosisPicker.vue";
import OutcomeFields from "./OutcomeFields.vue";
import SoapFields from "./SoapFields.vue";
import { useRecordDraft } from "./useRecordDraft";
import VitalsFields from "./VitalsFields.vue";

const props = defineProps<{ visit: MedicalVisitDetail; canEdit: boolean; canAddAddendum: boolean }>();

const { draft, readonly, signable, busy, save, sign } = useRecordDraft(toRef(props, "visit"), toRef(props, "canEdit"));
</script>
