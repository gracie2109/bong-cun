<template>
  <div class="space-y-4">
    <p class="text-sm text-muted-foreground">{{ $t("medical.attachments.hint") }}</p>

    <form v-if="canEdit" class="grid gap-3 rounded-lg border p-3 sm:grid-cols-[10rem_minmax(0,1fr)_auto]" @submit.prevent="submit">
      <Select v-model="draft.kind">
        <SelectTrigger :aria-label="$t('medical.attachments.kindLabel')"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="kind in ATTACHMENT_KINDS" :key="kind" :value="kind">{{ $t(`medical.attachments.kind.${kind}`) }}</SelectItem>
        </SelectContent>
      </Select>
      <Input v-model="draft.title" :placeholder="$t('medical.attachments.titlePlaceholder')" />
      <Button type="submit" :disabled="!ready || adding.isPending.value">
        <Upload class="mr-1.5 size-4" />{{ $t("medical.attachments.upload") }}
      </Button>
      <div class="sm:col-span-3">
        <input ref="fileInput" type="file" accept="image/png,image/jpeg,image/webp,application/pdf" class="text-sm" @change="onPick" />
        <p v-if="fileError" class="mt-1 text-xs text-red-600">{{ $t(`medical.attachments.error.${fileError}`) }}</p>
      </div>
    </form>

    <p v-if="files.length === 0" class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">
      {{ $t("medical.attachments.empty") }}
    </p>
    <ul v-else class="divide-y rounded-lg border text-sm">
      <li v-for="file in files" :key="file.id" class="flex items-center justify-between gap-3 px-3 py-2">
        <button type="button" class="flex min-w-0 items-center gap-2 text-left hover:text-primary" @click="open(file.filePath)">
          <FileText class="size-4 shrink-0" />
          <span class="min-w-0 truncate font-medium">{{ file.title }}</span>
          <span class="shrink-0 rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold">{{ $t(`medical.attachments.kind.${file.kind}`) }}</span>
        </button>
        <span class="flex shrink-0 items-center gap-2 text-xs text-muted-foreground">
          {{ file.createdByName }} · {{ dateTime(file.createdAt) }}
          <Button v-if="canEdit" size="icon" variant="ghost" class="size-8 text-red-600" :aria-label="$t('medical.attachments.remove')" @click="remove.mutate(file.id)">
            <Trash2 class="size-4" />
          </Button>
        </span>
      </li>
    </ul>
  </div>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from "vue";
import { FileText, Trash2, Upload } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { openAttachment, useAddAttachment, useMedicalAttachments, useRemoveAttachment } from "@/features/admin/medical/queries/medicalAttachments";
import { validateAttachment } from "@bongcun/supabase/medical";
import { ATTACHMENT_KINDS, type AttachmentKind, type MedicalVisitDetail } from "@bongcun/core/medical";
import { dateTime } from "../../format";

const props = defineProps<{ visit: MedicalVisitDetail; canUpdate: boolean }>();

const files = computed(() => query.data.value ?? []);
const query = useMedicalAttachments(computed(() => props.visit.id));
const adding = useAddAttachment();
const remove = useRemoveAttachment();

// Files can be added once the case is open and also after it is signed (results arrive later).
const canEdit = computed(() => props.canUpdate && ["in_progress", "done", "paid"].includes(props.visit.status));

const draft = reactive<{ kind: AttachmentKind; title: string }>({ kind: "lab", title: "" });
const file = ref<File | null>(null);
const fileError = ref<"type" | "size" | null>(null);
const fileInput = ref<HTMLInputElement | null>(null);
const ready = computed(() => !!file.value && !fileError.value && draft.title.trim().length > 0);

const onPick = (event: Event) => {
  const picked = (event.target as HTMLInputElement).files?.[0] ?? null;
  file.value = picked;
  fileError.value = picked ? validateAttachment(picked) : null;
  if (picked && !draft.title.trim()) draft.title = picked.name.replace(/\.[^.]+$/, "");
};

const submit = async () => {
  if (!file.value || !ready.value) return;
  try {
    await adding.mutateAsync({ petId: props.visit.petId, visitId: props.visit.id, kind: draft.kind, title: draft.title.trim(), file: file.value });
    draft.title = "";
    file.value = null;
    if (fileInput.value) fileInput.value.value = "";
  } catch {
    // the mutation already showed the failure toast
  }
};

const open = (path: string) => openAttachment(path);
</script>
