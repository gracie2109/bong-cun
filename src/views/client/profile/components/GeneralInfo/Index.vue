<template>
    {{ currentUser }}
    <div class="flex flex-col md:flex-row gap-3 w-full">
        <div v-if="currentUser" class="space-y-8 flex-1 md:w-2/3">
            <UserAvatar />
            <div class="md:grid-cols-3">
                <div class="space-y-3 col-span-1 md:col-span-2">
                    <div>
                        <Label>User name</Label>
                        <Input v-model="profileModel.userName" type="text" />
                    </div>
                    <div>
                        <Label>Email</Label>
                        <Input v-model="profileModel.email" type="text" />
                    </div>
                    <div>
                        <Label>Phone number</Label>
                        <Input v-model="profileModel.phoneNumber" type="text" />
                    </div>
                </div>
            </div>

            <Button class="w-full md:w-auto">Update profile</Button>
        </div>
        {{ providers }}
        <div class="grid grid-cols-3 sm:grid-cols-3 md:w-1/3 md:grid-cols-4 gap-4 md:gap-6 p-4 md:p-6">
            <div v-for="social in socialIcons" :key="social.key"
                :class="providers.includes(social.key) ? 'grayscale-0' : 'grayscale'"
                class="flex flex-col items-center transition-all duration-300 cursor-pointer"
                @click="linkProvider(social.key)">
                <img :src="social.src" :alt="social.key" class="w-10 md:w-14 h-10 md:h-14 object-contain" />
                <span class="text-xs md:text-sm mt-2">{{ social.name }}</span>
            </div>
        </div>
    </div>
</template>

<script lang="ts" setup>
import UserAvatar from "@/components/common/UserAvatar.vue";
import { ref } from "vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import Button from "@/components/ui/button/Button.vue";
import { useAuthStore } from "@/stores";
import { storeToRefs } from "pinia";



const store = useAuthStore();
const { currentUser } = storeToRefs(store);

const profileModel = ref({
    userName: currentUser.value?.displayName ?? "",
    email: currentUser.value?.email ?? "",
    phoneNumber: currentUser.value?.phoneNumber ?? "",
});

const socialIcons = ref([
    { key: "google", name: "Google", src: "https://cdn-icons-png.flaticon.com/512/300/300221.png" },
    { key: "facebook", name: "Facebook", src: "https://cdn-icons-png.flaticon.com/512/5968/5968764.png" },
    { key: "apple", name: "Apple", src: "https://cdn-icons-png.flaticon.com/512/831/831276.png" },
    { key: "github", name: "GitHub", src: "https://cdn-icons-png.flaticon.com/512/733/733609.png" },
    { key: "gitlab", name: "GitLab", src: "https://cdn-icons-png.flaticon.com/512/5968/5968853.png" },
    { key: "twitter", name: "Twitter", src: "https://cdn-icons-png.flaticon.com/512/733/733579.png" },
    { key: "discord", name: "Discord", src: "https://cdn-icons-png.flaticon.com/512/3670/3670157.png" },
    { key: "twitch", name: "Twitch", src: "https://cdn-icons-png.flaticon.com/512/733/733641.png" },
    { key: "hubspot", name: "HubSpot", src: "https://cdn-icons-png.flaticon.com/512/5968/5968829.png" }
]);

const providers = ref<string[]>([]);

const linkProvider = async (providerKey: string) => {
    if (providerKey !== "google") {
        console.error("Provider không hợp lệ:", providerKey);
        return;
    }
    // Needs "Manual linking" enabled in the Supabase dashboard.
    await store.linkGoogleIdentity();
};
</script>

<style scoped>
.grayscale {
    filter: grayscale(100%);
    cursor: pointer;
    transition: filter 0.3s;
}

.grayscale-0 {
    filter: grayscale(0%);
}
</style>
