<script lang="ts" setup>
import { useFileDialog } from "@vueuse/core";
import { Eye, PlusCircle, Trash } from "lucide-vue-next";
import { computed, ref, toRaw, watch } from "vue";
import { storeToRefs } from "pinia";
import { supabaseClient } from "@/lib/supabase";
import { useAuthStore } from "@/stores";
import { deleteImage, pathFromPublicUrl, uploadImage, validateImage } from "@/repositories/storage";
import { DialogConfirm, LoadingSpin } from "@/components/common";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { ExclamationTriangleIcon } from "@radix-icons/vue";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import Zooming from "./Zooming.vue";

const { session } = storeToRefs(useAuthStore());
const { open, onChange } = useFileDialog();

const props = defineProps<{
  folderName: string;
  limit: number;
  showControl:boolean
  /** Images already saved (for an edit form); kept in sync when the parent changes them. */
  modelValue?: string[];
  /** "sm" draws small boxes, for a table cell. */
  size?: "sm" | "md";
  /** Removing only unlinks the image; the file stays (the form may still be cancelled). */
  keepFiles?: boolean;
}>();

const errors = ref<string | null>(null);

const images = ref<string[]>([]);
watch(
  () => props.modelValue,
  (value) => {
    if (value) images.value = [...value];
  },
  { immediate: true }
);
const boxClass = computed(() => (props.size === "sm" ? "w-16 h-16" : "w-24 h-24"));

const emit = defineEmits(["setImages"]);
const zoom = ref(false); // State for zoom
const selectedImg = ref("");
const newFiles = ref();
const progress = ref<boolean>(false);

onChange(async (files: any) => {
  errors.value = null;
  newFiles.value = [...(files ?? [])];
  if (newFiles.value.length > props.limit) {
    errors.value = `Upload max ${props.limit} item!`;
  }

  for (let file of newFiles.value.slice(0, props.limit)) {
    await uploadFile(file);
  }
});

const uploadFile = async (file: File) => {
  const invalid = validateImage(file);
  if (invalid) {
    errors.value = invalid;
    return;
  }
  if (!session.value) {
    errors.value = "Please sign in to upload images.";
    return;
  }

  // Supabase uploads report no per-chunk progress, so this is a plain busy flag.
  progress.value = true;
  try {
    const { url } = await uploadImage(supabaseClient(), {
      userId: session.value.user.id,
      folder: props.folderName,
      file,
    });
    images.value = [...images.value, url];
    emit("setImages", images.value);
  } catch (error: any) {
    errors.value = error?.message ?? "Upload failed.";
  } finally {
    progress.value = false;
  }
};

const delImg = ref("");
const handleDelete = async (img: string) => {
  if (!img) return;
  // A link from elsewhere (not in our bucket) is only taken off the list.
  const path = pathFromPublicUrl(img);

  try {
    if (path && !props.keepFiles) await deleteImage(supabaseClient(), path);
    const newData = images.value.filter((i) => i !== img);
    images.value = newData;
    emit("setImages", newData);
    delImg.value = "";
  } catch (error: any) {
    errors.value = error?.message ?? "Delete failed.";
  }
};
</script>

<template>
  <div v-if="errors">
    <Alert variant="destructive">
      <ExclamationTriangleIcon class="w-4 h-4" />
      <AlertTitle>Notify</AlertTitle>
      <AlertDescription>
        {{ errors }}
      </AlertDescription>
    </Alert>
  </div>
  <div class="flex gap-3">
    <div
      v-for="(i, j) in limit"
      :key="j"
      class="rounded-lg border border-custom-primary border-dashed relative"
      :class="boxClass"
      @click="
        () => {
          if (!images[i - 1]) {
            open();
          }
        }
      "
    >
      <div class="relative grid place-items-center w-full h-full">
        <template v-if="!images[i - 1]">
          <template v-if="!progress">
            <PlusCircle class="w-4 h-4" color="orange" />
          </template>
          <template v-else>
            <LoadingSpin />
          </template>
        </template>
        <div class="relative" :class="boxClass" v-else>
          <div id="media" class="relative w-full h-full">
            <img
              :src="images[i - 1]"
              alt="image"
              class="w-full p-1 rounded-sm h-full object-cover"
            />
          </div>
          <div
            class="absolute bottom-[3px]   rounded-sm  backdrop-blur-sm bg-white/40 w-[97%] py-1 px-1"
          >
            <div class="flex items-center justify-between">
              <div @click="delImg = images[i - 1]">
                <Trash
                  class="size-5 cursor-pointer"
                  color="red"
                  type="button"
                />
              </div>
              <!-- Zoom button -->
              <div
                id="zoom_button"
                @click="
                  () => {
                    zoom = !zoom;
                    selectedImg = images[i - 1];
                  }
                "
              >
                <Eye class="size-5 cursor-pointer" color="white" type="button" />
              </div>

              <Dialog
                :open="zoom"
                @update:open="
                  () => {
                    zoom = !zoom;
                    selectedImg = '';
                  }
                "
                v-if="selectedImg"
              >
                <DialogContent class="h-screen w-screen max-w-none gap-0 rounded-none border-0 p-0 sm:rounded-none">
                  <Zooming :image="selectedImg" :showControl="props.showControl" />
                </DialogContent>
              </Dialog>

              <DialogConfirm
                :open="delImg ? true : false"
                danger
                :ok-btn="$t('common.delete')"
                :desc="$t('common.deleteFileDesc')"
                :title="$t('common.deleteFileTitle')"
                @cancel="delImg = ''"
                @open-change="delImg = ''"
                @handle-ok="handleDelete(toRaw(delImg))"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
