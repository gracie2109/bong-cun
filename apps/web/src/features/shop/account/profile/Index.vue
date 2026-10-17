<template>
  <div class="max-w-2xl space-y-4">
    <p v-if="profile.loading.value" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="profile.failed.value" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.account.profile.loadFailed") }}</p>
      <Button variant="outline" @click="profile.retry">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <template v-else>
      <ProfileForm
        :form="profile.form"
        :errors="profile.errors.value"
        :submitted="profile.submitted.value"
        :saving="profile.saving.value"
        :changed="profile.changed.value"
        :email="profile.email.value"
        @submit="profile.submit"
      />
      <GoogleLink />
    </template>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { useProfileForm } from "@/features/shop/account/composables/useProfileForm";
import GoogleLink from "./components/GoogleLink.vue";
import ProfileForm from "./components/ProfileForm.vue";

const profile = useProfileForm();
</script>
