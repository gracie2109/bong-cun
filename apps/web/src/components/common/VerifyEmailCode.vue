<template>
  <section class="mx-auto grid gap-6 w-full">
    <div class="grid gap-2 text-center">
      <h1 class="text-3xl font-bold">
        {{ $t("pageFields.authen.verifyTitle") }}
      </h1>
      <p class="text-balance text-muted-foreground">
        {{ $t("pageFields.authen.verifyDesc", { email: pendingVerificationEmail }) }}
      </p>
    </div>
    <form class="grid gap-4" @submit.prevent="submit">
      <div class="grid gap-1">
        <Label for="otp-code">{{ $t("pageFields.authen.codeLabel") }}</Label>
        <Input
          id="otp-code"
          v-model="code"
          type="text"
          inputmode="numeric"
          autocomplete="one-time-code"
          maxlength="10"
          placeholder="123456"
          class="text-center text-lg tracking-[0.4em]"
          :class="{ 'p-invalid': !!error }"
        />
        <div class="error">{{ error }}</div>
      </div>
      <Button type="submit" class="w-full h-[50px]" :disabled="loading">
        {{ $t("pageFields.authen.verify") }}
      </Button>
      <Button
        type="button"
        variant="outline"
        class="w-full h-[50px]"
        :disabled="loading || secondsLeft > 0"
        @click="resend"
      >
        {{
          secondsLeft > 0
            ? $t("pageFields.authen.resendIn", { s: secondsLeft })
            : $t("pageFields.authen.resend")
        }}
      </Button>
      <p class="text-center text-sm underline cursor-pointer" @click="cancel">
        {{ $t("pageFields.authen.back") }}
      </p>
    </form>
  </section>
  <div v-if="loading">
    <LoadingIndicator />
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { onBeforeUnmount, ref } from "vue";
import { storeToRefs } from "pinia";
import { useI18n } from "vue-i18n";
import { OTP_CODE_PATTERN, OTP_RESEND_COOLDOWN_SECONDS } from "@/config/auth";
import { useAuthStore } from "@/stores";
import LoadingIndicator from "./LoadingIndicator.vue";

const emit = defineEmits<{ verified: []; cancel: [] }>();
const { t } = useI18n();
const store = useAuthStore();
const { loading, isSuccess, pendingVerificationEmail } = storeToRefs(store);

const code = ref("");
const error = ref("");
// A code was sent a moment ago (sign-up or login), so resending starts locked.
const secondsLeft = ref(OTP_RESEND_COOLDOWN_SECONDS);

let timer: ReturnType<typeof setInterval> | null = null;
const startCooldown = () => {
  if (timer) clearInterval(timer);
  secondsLeft.value = OTP_RESEND_COOLDOWN_SECONDS;
  timer = setInterval(() => {
    secondsLeft.value -= 1;
    if (secondsLeft.value <= 0 && timer) clearInterval(timer);
  }, 1000);
};
startCooldown();
onBeforeUnmount(() => timer && clearInterval(timer));

async function submit() {
  error.value = "";
  if (!OTP_CODE_PATTERN.test(code.value.trim())) {
    error.value = t("pageFields.authen.codeInvalid");
    return;
  }
  await store.verifyEmailCode(code.value);
  if (isSuccess.value) emit("verified");
}

async function resend() {
  await store.resendVerificationCode();
  startCooldown();
}

function cancel() {
  store.cancelVerification();
  emit("cancel");
}
</script>

<style scoped>
.error {
  font-size: 14px;
  color: red;
}
</style>
