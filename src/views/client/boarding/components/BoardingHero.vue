<template>
  <section class="bg-sage-soft">
    <div class="shop-container py-10 md:py-14">
      <p class="shop-eyebrow !text-sage">{{ $t("client.boarding.eyebrow") }}</p>
      <h1 class="shop-display mt-2 text-[34px] leading-[1.1] md:text-5xl">{{ $t("client.boarding.pageTitle") }}</h1>
      <p class="mt-4 max-w-xl text-lg text-muted-foreground">{{ $t("client.boarding.intro") }}</p>
      <div class="mt-7">
        <Button as-child class="h-12 rounded-full bg-sage px-6 text-base hover:bg-sage/90">
          <a :href="`tel:${phone}`"><Phone class="mr-2 size-4" />{{ phone }}</a>
        </Button>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Phone } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

defineProps<{ phone: string }>();
</script>
