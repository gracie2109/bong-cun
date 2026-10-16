<template>
  
  <div>
    <div class="flex gap-2 items-center  cursor-pointer">

      <div :class="{ 'disable': locale !== 'en' }" @click="switchLanguage('en')">
        <img alt="" class="w-6 h-6 object-cover inline-block " src="~/assets/flags/uk.png">
      </div>
      <div :class="{ 'disable': locale !== 'vi' }" @click="switchLanguage('vi')">
        <img alt="" class="w-6 h-6  object-cover inline-block " src="~/assets/flags/vietnam.png">
      </div>
    </div>
  </div>
 

</template>


<script lang="ts" setup>
import { useI18n } from "vue-i18n";

// @nuxtjs/i18n persists the choice in the `user-locale` cookie and sets <html lang>.
const { locale, setLocale } = useI18n();

const switchLanguage = (newLocale: "vi" | "en") => setLocale(newLocale);
</script>
<style scoped>
.disable>img {
  filter: grayscale(100%);
}
</style>
