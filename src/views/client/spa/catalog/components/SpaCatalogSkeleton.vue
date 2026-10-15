<template>
  <div class="space-y-6" aria-hidden="true">
    <div class="shop-skeleton h-10 w-56 rounded-full" />
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <div v-for="n in 3" :key="n" class="shop-skeleton h-56 rounded-3xl" />
    </div>
  </div>
</template>
