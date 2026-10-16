<template>
  <section
    v-if="!pendingRecoveryEmail"
    class="mx-auto grid gap-6 w-full"
    :class="{
      'mt-5 p-5': !isExactPath,
    }"
  >
    <div class="grid gap-2 text-center">
      <h1 class="text-3xl font-bold">
        {{ $t("pageMeta.forgotPw") }}
      </h1>
      <p class="text-balance text-muted-foreground">
        {{ $t("pageFields.authen.prefForgotPw") }}
      </p>
    </div>
    <div>
      <div class="grid gap-4">
        <form @submit.prevent="submitHdl">
          <div class="grid gap-2">
            <Label for="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="m@example.com"
              required
              name="email"
              v-model:model-value="formVl.email"
              :class="{ 'p-invalid': !!getError('email') }"
            />
            <div class="error">{{ getError("email") }}</div>
          </div>
          <Button type="submit" class="w-full h-[50px]" @click="submitHdl()">
            {{ $t("common.submit") }}
          </Button>
          <Button
            variant="outline"
            class="w-full h-[50px] mt-3"
            @click="redirectPath()"
          >
            Back
          </Button>
        </form>
      </div>
    </div>
  </section>
  <ResetPasswordWithCode v-else @done="finishRecovery" />
  <div v-if="loading">
    <LoadingIndicator />
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ref } from "vue";
import { useAuthStore } from "@/stores";
import { useRoute, useRouter } from "vue-router";
import { storeToRefs } from "pinia";
import { LoadingIndicator, ResetPasswordWithCode } from "@/components/common";
import useValidation from "@/composables/useValidation";
import { EmailSChema } from "@/validations";

const formVl = ref({
  email: "",
});
const store = useAuthStore();
const { loading, pendingRecoveryEmail } = storeToRefs(store);
const emit = defineEmits(["directPath", "closeDialog"]);
const route = useRoute();
const router = useRouter();
const isExactPath = route.fullPath?.toString()?.split("/")[1] === "";

function redirectPath() {
  if (route.fullPath?.includes("forgot-password")) {
    router.push({ name: "login" });
  } else {
    emit("directPath", "login");
  }
}

const { validate, isValid, getError, scrolltoError, errors } = useValidation(
  EmailSChema,
  formVl,
  {
    mode: "lazy",
  }
);

// After the code is accepted the user is signed in with the new password.
function finishRecovery() {
  if (route.fullPath?.includes("forgot-password")) {
    router.push({ name: "home" });
  } else {
    emit("closeDialog");
  }
}

async function submitHdl() {
  await validate();
  if (isValid.value) {
    // On success the store switches to the code form (pendingRecoveryEmail).
    await store.sendResetPassMail(formVl.value.email.trim());
  } else {
    scrolltoError(".p-invalid", { offset: 24 });
  }
}
</script>
<style scoped>
.error {
  font-size: 14px;
  color: red;
  margin-top: 4px;
}
</style>
