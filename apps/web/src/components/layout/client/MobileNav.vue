<template>
  <Sheet v-model:open="open">
    <SheetTrigger as-child>
      <button
        type="button"
        class="grid size-11 place-content-center rounded-full transition-colors hover:bg-muted lg:hidden"
        :aria-label="$t('client.header.openMenu')"
      >
        <Menu class="size-6" :stroke-width="1.8" />
      </button>
    </SheetTrigger>
    <SheetContent side="left" class="flex w-[88%] max-w-sm flex-col gap-0 p-0">
      <SheetHeader class="border-b px-5 py-4 text-left">
        <SheetTitle><ShopLogo @click="open = false" /></SheetTitle>
      </SheetHeader>

      <div class="px-5 pt-4">
        <HeaderSearch @submitted="open = false" />
      </div>

      <nav class="flex-1 overflow-y-auto px-3 py-4" :aria-label="$t('client.header.menu')">
        <ul class="space-y-1">
          <li v-for="(item, index) in SHOP_NAV" :key="item.name" class="shop-reveal" :style="{ '--i': index }">
            <RouterLink
              :to="{ name: item.name }"
              class="flex h-12 items-center gap-3 rounded-xl px-3 text-base font-medium transition-colors"
              :class="isNavActive(route.name, item.name) ? 'bg-accent text-accent-foreground' : 'hover:bg-muted'"
              @click="open = false"
            >
              <component :is="item.icon" class="size-5 opacity-80" :stroke-width="1.8" />
              {{ $t(item.title) }}
              <ChevronRight class="ml-auto size-4 opacity-40" />
            </RouterLink>
          </li>
        </ul>
      </nav>

      <div class="space-y-4 border-t p-5">
        <Button as-child class="h-12 w-full rounded-full text-base">
          <RouterLink :to="{ name: 'spa' }" @click="open = false">
            <CalendarHeart class="mr-2 size-5" />{{ $t("client.header.bookSpa") }}
          </RouterLink>
        </Button>
        <div class="flex items-center justify-between text-sm">
          <a :href="`tel:${STORE_INFO.phone}`" class="inline-flex items-center gap-2 font-medium">
            <Phone class="size-4 text-primary" />{{ STORE_INFO.phone }}
          </a>
          <LangToggle />
        </div>
      </div>
    </SheetContent>
  </Sheet>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { useRoute } from "vue-router";
import { CalendarHeart, ChevronRight, Menu, Phone } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { SHOP_NAV } from "@/config/shopNav";
import { STORE_INFO } from "@/config/storeInfo";
import { isNavActive } from "@/utils/shop/nav";
import HeaderSearch from "./HeaderSearch.vue";
import LangToggle from "./LangToggle.vue";
import ShopLogo from "./ShopLogo.vue";

const route = useRoute();
const open = ref(false);
</script>
