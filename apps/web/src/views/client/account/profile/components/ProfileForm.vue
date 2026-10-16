<template>
  <form class="space-y-4 rounded-xl border bg-white p-5" @submit.prevent="emit('submit')">
    <h2 class="font-semibold">{{ $t("client.account.profile.info") }}</h2>

    <div class="space-y-1.5">
      <Label for="profile-name">{{ $t("client.account.profile.fullName") }}</Label>
      <Input id="profile-name" v-model="form.fullName" autocomplete="name" :class="invalid('fullName')" />
      <p v-if="submitted && errors.fullName" class="text-xs text-red-600">{{ $t("client.account.errors.invalid_name") }}</p>
    </div>

    <div class="space-y-1.5">
      <Label for="profile-phone">{{ $t("client.account.profile.phone") }}</Label>
      <Input id="profile-phone" v-model="form.phone" type="tel" autocomplete="tel" :class="invalid('phone')" />
      <p v-if="submitted && errors.phone" class="text-xs text-red-600">{{ $t("client.account.errors.invalid_phone") }}</p>
    </div>

    <div class="space-y-1.5">
      <Label for="profile-email">{{ $t("client.account.profile.email") }}</Label>
      <Input id="profile-email" :model-value="email" disabled />
      <p class="text-xs text-muted-foreground">{{ $t("client.account.profile.emailHint") }}</p>
    </div>

    <div class="space-y-1.5">
      <Label for="profile-birth">{{ $t("client.account.profile.birthDate") }}</Label>
      <Input id="profile-birth" v-model="form.birthDate" type="date" :max="today" :class="invalid('birthDate')" />
      <p v-if="submitted && errors.birthDate" class="text-xs text-red-600">{{ $t("client.account.errors.invalid_birth_date") }}</p>
    </div>

    <Button type="submit" :disabled="saving || !changed">
      {{ $t("client.account.profile.save") }}
    </Button>
  </form>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ProfileErrors, ProfileForm } from "@bongcun/core/account";

const props = defineProps<{
  form: ProfileForm;
  errors: ProfileErrors;
  submitted: boolean;
  saving: boolean;
  changed: boolean;
  email: string;
}>();
const emit = defineEmits<{ submit: [] }>();

const today = new Date().toISOString().slice(0, 10);
const invalid = (field: keyof ProfileErrors) => (props.submitted && props.errors[field] ? "border-red-500" : "");
</script>
