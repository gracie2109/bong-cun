<template>

    <Popover class="pr-20 relative" >
        <PopoverTrigger as-child>
            <div id="notification">
                <div class="relative cursor-pointer ">
                    <Bell class="w-6 h-6 relative" />
                    <div class="absolute -top-2 -right-1 w-4 h-4 bg-red-600 rounded-full text-white">
                        <div class="grid place-items-center font-semibold  ">
                            <span class="text-xs " v-if="!showPlus">{{ notif }}</span>
                            <span class="text-[10px]" v-else>9+</span>
                        </div>

                    </div>
                </div>
            </div>

        </PopoverTrigger>
        <PopoverContent class="w-full min-w-[360px] absolute -right-[8rem]">
            <div>
                <div class="border-b ">
                    <div class="pb-4">
                        <h1 class="font-bold leading-none text-lg">
                            Notification
                        </h1>
                       
                    </div>

                </div>

                <ScrollArea class=" space-y-3 h-96 w-full mt-2">
                    
                    <div class="">
                        asdada
                    </div>

                </ScrollArea>
            </div>
            <PopoverArrow class=" absolute right-12 " />
        </PopoverContent>
    </Popover>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { Bell } from "lucide-vue-next";

import { ScrollArea } from "@/components/ui/scroll-area"
import {
    Popover,
    PopoverContent,
    PopoverTrigger,
    PopoverArrow
} from '@/components/ui/popover';
const notif = ref<number>(4);
const showNotif = ref(false);






const showPlus = computed(() => { return notif.value >= 10 ? true : false });

</script>