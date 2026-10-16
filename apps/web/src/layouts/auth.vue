<script setup lang="ts">
import { SwitchLang } from "@/components/common";
import { placeholderImg } from "@/setting";

</script>

<template>
    <div
        class="fixed left-0 top-0 z-40 w-full transition-transform duration-300 border-b bg-[rgb(255, 255, 255)] translate-y-0 py-6 bg-white  z-20 shadow-lg">
        <div class="grid h-full w-full justify-end px-6">
            <SwitchLang />
        </div>
    </div>
    <div class="w-full lg:grid lg:min-h-[600px] lg:grid-cols-2 xl:min-h-[800px] relative">
        <div class="flex items-center justify-center py-12">
            <slot />
        </div>
        <div class="hidden bg-muted lg:block">
            <img :src="placeholderImg" alt="Image" width="1920" height="1080"
                class="h-full w-full object-cover dark:brightness-[0.2] dark:grayscale">
        </div>
    </div>
</template>