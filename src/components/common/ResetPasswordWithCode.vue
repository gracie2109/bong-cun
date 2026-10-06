<template>
  <section class="mx-auto grid gap-6 w-full">
    <div class="grid gap-2 text-center">
      <h1 class="text-3xl font-bold">
        {{ $t("pageMeta.resetPw") }}
      </h1>
      <p class="text-balance text-muted-foreground">
        {{ $t("pageFields.authen.verifyDesc", { email: pendingRecoveryEmail }) }}
      </p>
    </div>
    <form class="grid gap-4" @submit.prevent="submit">
      <div class="grid gap-1">
        <Label for="recovery-code">{{ $t("pageFields.authen.codeLabel") }}</Label>
        <Input
          id="recovery-code"
          v-model="formVl.code"
          type="text"
          inputmode="numeric"
          autocomplete="one-time-code"
          maxlength="10"
          placeholder="123456"
          class="text-center text-lg tracking-[0.4em]"
          :class="{ 'p-invalid': !!getError('code') }"
        />
        <div class="error">{{ getError("code") }}</div>
      </div>
      <div class="grid gap-1">
        <Label for="recovery-password">Password</Label>
        <InputPassword
          id="recovery-password"
          name="password"
          placeholder="********"
          @update-value="(vl) => (formVl.password = vl)"
          :class="{ 'p-invalid': !!getError('password') }"
        />
        <div class="error">{{ getError("password") }}</div>
      </div>
      <div class="grid gap-1">
        <Label for="recovery-confirm">Confirm password</Label>
        <InputPassword
          id="recovery-confirm"
          name="confirm"
          placeholder="********"
          @update-value="(vl) => (formVl.confirm = vl)"
          :class="{ 'p-invalid': !!getError('confirm') }"
        />
        <div class="error">{{ getError("confirm") }}</div>
      </div>
      <Button type="submit" class="w-full h-[50px]" :disabled="loading">
        {{ $t("common.submit") }}
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
import { OTP_RESEND_COOLDOWN_SECONDS } from "@/config/auth";
import useValidation from "@/composables/useValidation";
import { resetPasswordWithCodeSchema } from "@/validations/auth";
import { useAuthStore } from "@/stores";
import InputPassword from "./InputPassword.vue";
import LoadingIndicator from "./LoadingIndicator.vue";

const emit = defineEmits<{ done: []; cancel: [] }>();
const store = useAuthStore();
const { loading, isSuccess, pendingRecoveryEmail } = storeToRefs(store);

const formVl = ref({ code: "", password: "", confirm: "" });
const { validate, isValid, getError, scrolltoError } = useValidation(
  resetPasswordWithCodeSchema,
  formVl,
  { mode: "lazy" }
);

// A code was sent a moment ago, so resending starts locked.
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
  await validate();
  if (!isValid.value) {
    scrolltoError(".p-invalid", { offset: 24 });
    return;
  }
  await store.resetPasswordWithCode({
    code: formVl.value.code,
    password: formVl.value.password,
  });
  if (isSuccess.value) emit("done");
}

async function resend() {
  await store.resendRecoveryCode();
  startCooldown();
}

function cancel() {
  store.cancelRecovery();
  emit("cancel");
}
</script>

<style scoped>
.error {
  font-size: 14px;
  color: red;
}
</style>
