<template>
  <section v-if="!pendingVerificationEmail" class="mx-auto  w-full" 
  
  :class="{
      'mt-5 p-5': !isExactPath
    }"
  >
    <div class="grid gap-2 text-center">
      <h1 class="text-3xl font-bold">
        {{ $t("pageMeta.register") }}
      </h1>
      <p class="text-balance text-muted-foreground">
        {{ $t("pageFields.authen.prefSignup") }}
      </p>
    </div>
    <div class="h-full">
      <div class="mt-5">
        <form @submit.prevent="handleSubmit">
          <div class="grid gap-4">
            <div class="grid gap-1">
              <Label for="email">Email</Label>
              <Input
                id="email"
                type="email"
                name="email"
                placeholder="m@example.com"
                required
                v-model:model-value="formSchema.email"
                :disabled="isCheckStt"
                :class="{ 'p-invalid': !!getError('email') }"
              />
              <div class="error">{{ getError("email") }}</div>
            </div>
            <div class="grid gap-1">
              <Label for="password">Display Name</Label>
              <Input
                id="password"
                type="text"
                required
                placeholder="Robinson"
                :disabled="isCheckStt"
                name="displayName"
                v-model:model-value="formSchema.displayName"
                :class="{ 'p-invalid': !!getError('displayName') }"
              />
              <div class="error">{{ getError("displayName") }}</div>
            </div>

            <div class="grid grid-cols-2 gap-x-3 gap-y-0">
              <div class="grid gap-1">
                <Label for="password">Password</Label>
                <InputPassword
                  id="password"
                  name="password"
                  placeholder="********"
                  @update-value="(vl) => (formSchema.password = vl)"
                  :class="{ 'p-invalid': !!getError('password') }"
                />
              </div>
              <div class="grid">
                <Label for="password">Reset Password</Label>
                <InputPassword
                  id="password"
                  name="password"
                  @update-value="(vl) => (formSchema.confirm = vl)"
                  placeholder="********"
                  :class="{ 'p-invalid': !!getError('confirm') }"
                />
              </div>
            </div>
            <div class="grid gap-y-1">
              <div class="error">{{ getError("password") }}</div>
              <div class="error">{{ getError("confirm") }}</div>
            </div>
            <Button
              type="submit"
              class="w-full h-[50px]"
              @click="handleSubmit()"
              :disabled="loading"
            >
              {{ $t("pageFields.authen.createAcc") }}
            </Button>
            <Button variant="outline" class="w-full  h-[50px]" :disabled="loading">
              Login with Google
            </Button>
          </div>
        </form>
        <div class="mt-4 text-center text-sm flex justify-center items-center gap-3">
          {{ $t("pageFields.authen.alreadyHasAccount") }}
          <p @click="redirectPath" class="underline cursor-pointer">
            {{ $t("pageMeta.login") }}
          </p>
        </div>
      </div>
    </div>
  </section>
  <VerifyEmailCode v-else @verified="finishRegister" />
  <div v-if="loading">
    <LoadingIndicator />
  </div>
</template>

<script setup lang="ts">
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { onMounted, ref } from "vue";
import { useAuthStore } from "@/stores";
import { storeToRefs } from "pinia";
import LoadingIndicator from "@/components/common/LoadingIndicator.vue";
import type { IRegisterPayload } from "@/types/user.type";
import { InputPassword, VerifyEmailCode } from "@/components/common";
import { useRoute, useRouter } from "vue-router";
import useValidation from "@/composables/useValidation";
import { registerSchema } from "@/validations/auth";
const route = useRoute();
const router = useRouter();
const emits = defineEmits(["directPath", "closeDialog"]);
const isExactPath = route.fullPath?.toString()?.split('/')[1] === ""

const isCheckStt = ref(false);
const authStore = useAuthStore();
const { loading, isSuccess, pendingVerificationEmail } = storeToRefs(authStore);

const formSchema = ref<IRegisterPayload>({
  email: "",
  displayName: "",
  password: "",
  confirm: "",
});

const { validate, isValid, getError, scrolltoError, errors } = useValidation(
  registerSchema,
  formSchema,
  {
    mode: "lazy",
  }
);

function redirectPath() {
  if (route.fullPath?.includes("register")) {
    router.push({ name: "login" });
  } else {
    emits("directPath", "login");
  }
}

// The account is verified and signed in after the emailed code is accepted.
function finishRegister() {
  if (route.fullPath?.includes("register")) {
    router.push({ name: "home" });
  } else {
    emits("closeDialog");
  }
}

async function handleSubmit() {
  await validate();
  if (isValid.value) {
    await authStore.signUp(formSchema.value);
    if (isSuccess.value) {
      redirectPath();
      if (route.fullPath?.includes("login")) {
        router.resolve({ name: "login" });
      } else {
        redirectPath();
      }
    }
  } else {
    scrolltoError(".p-invalid", { offset: 24 });
  }
}

onMounted(async () => {
  await authStore.getListUsers();
});
</script>

<style scoped>
.error {
  font-size: 14px;
  color: red;
}
</style>
