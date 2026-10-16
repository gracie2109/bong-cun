<template>
    <div>
        <div class="mt-5 space-y-8" v-if="currentUser">
            <div class="flex gap-3 items-center">
                <img :src="avatar" alt="user photo" class="w-12 h-12 rounded-full inline-block">
                <div>
                    <small>@{{ currentUser.displayName }}</small>
                    <p>{{ currentUser.email }}</p>
                </div>
            </div>

        </div>
    </div>
</template>


<script lang="ts" setup>
import { placeholderImg } from "@/setting";
import { useAuthStore } from "@/stores";
import { storeToRefs } from "pinia";
import { computed } from "vue";

const store = useAuthStore();
const { currentUser } = storeToRefs(store);
const avatar = computed(() => (currentUser.value && currentUser.value.photoURL && currentUser.value.photoURL !== null && currentUser.value.photoURL !== "")
    ? currentUser.value.photoURL : placeholderImg
)
</script>