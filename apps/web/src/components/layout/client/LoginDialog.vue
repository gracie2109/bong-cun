<template>
  <Dialog :open="open" @update:open="emit('update:open', $event)">
    <DialogContent class="max-h-[90dvh] w-[calc(100%-2rem)] overflow-y-auto rounded-2xl sm:max-w-[520px]">
      <LoginView v-if="view === 'login'" @direct-path="switchView" @close-dialog="emit('update:open', false)" />
      <RegisterView v-else-if="view === 'register'" @direct-path="switchView" @close-dialog="emit('update:open', false)" />
      <ForgotPassView v-else @direct-path="switchView" @close-dialog="emit('update:open', false)" />
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import ForgotPassView from "@/features/auth/ForgotPassView.vue";
import LoginView from "@/features/auth/LoginView.vue";
import RegisterView from "@/features/auth/RegisterView.vue";

type AuthView = "login" | "register" | "forgot";

const props = defineProps<{ open: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const view = ref<AuthView>("login");
// The auth views ask for another view by a path-like name ("register", "forgotPw").
const switchView = (target: unknown) => {
  const name = String(target ?? "");
  view.value = name.includes("register") ? "register" : name.includes("login") || !name ? "login" : "forgot";
};
watch(
  () => props.open,
  (open) => {
    if (open) view.value = "login";
  }
);
</script>
