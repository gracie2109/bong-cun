<template>
  <section class="space-y-3 rounded-xl border bg-white p-5">
    <h2 class="font-semibold">{{ $t("client.account.google.title") }}</h2>
    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <img :src="GOOGLE_ICON" alt="" class="size-8" />
        <div>
          <p class="text-sm font-medium">Google</p>
          <p class="text-xs text-muted-foreground">
            {{ $t(linked ? "client.account.google.linked" : "client.account.google.notLinked") }}
          </p>
        </div>
      </div>
      <Button v-if="!linked" variant="outline" size="sm" @click="store.linkGoogleIdentity()">
        {{ $t("client.account.google.link") }}
      </Button>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/stores";

const GOOGLE_ICON = "https://cdn-icons-png.flaticon.com/512/300/300221.png";

const store = useAuthStore();
const { session } = storeToRefs(store);
const linked = computed(() => session.value?.user?.identities?.some((identity) => identity.provider === "google") ?? false);
</script>
