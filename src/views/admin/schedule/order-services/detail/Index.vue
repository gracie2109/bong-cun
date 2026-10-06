<template>
    <div>
        <Header>
            <div class="flex gap-3 items-center">
                <h1 class="font-semibold flex items-center gap-2 cursor-pointer"
                    @click="() => $router.push({ name: 'listOrderSchedule' })">
                    <CalendarDays class="size-4 text-primary" />
                    List Order &gt;
                </h1>
                <h1 class="font-semibold">Order Service Detail</h1>
            </div>
        </Header>

        <ContentWrap>
            <div class="relative top-20 min-h-dvh">
                <div class="grid grid-cols-4 gap-8 wrap">
                    <div class="col-span-3 border bg-white rounded-md h-auto min-h-[650px] p-5">
                        <Calendar />


                    </div>
                    <div class="col-span-1 border bg-white rounded-md p-5 overflow-y-auto h-[650px] ">

                        <div class="block  " v-if="orderSelected && orderSelected.services.length > 0"
                            v-for="(i, ii) in orderSelected.services" :key="ii">
                            <div class="space-y-6 border border-solid border-red-300 rounded-md h-20 mb-3 cursor-move"
                                draggable="true"
                                @dragstart="handleDragStart"
                                
                                >
                                <div class="h-full w-full p-3 ">
                                    <h3 class="font-semibold flex items-center justify-start gap-x-6"
                                        id="service_title">
                                        {{ i.name || "" }}

                                        <span class="font-normal" v-if="i.type === 'combo' || i.serviceProfiles">
                                            (<span v-for="(c, cc) in i.serviceProfiles" :key="cc">
                                                {{ c.name }}
                                            </span>)
                                        </span>
                                    </h3>
                                    <div class="flex justify-between">
                                        <p>{{ convertNumberToTime(i.duration?.[0] || 0) }}m</p>
                                        <p>{{ formatPrice(i.price ?? i.generalPrice ?? 0) }}</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div v-else>
                            Service not found
                        </div>
                    </div>
                </div>
            </div>
        </ContentWrap>
    </div>
</template>

<script lang="ts" setup>
import Header from "@/views/admin/components/Header.vue";
import ContentWrap from "@/views/admin/components/ContentWrap.vue";
import { CalendarDays } from "lucide-vue-next";
import Calendar from "@/views/admin/schedule/order-services/detail/components/Calendar.vue";
import { useOrderDetail } from "@/queries/orders";
import { useRoute } from "vue-router";
import { convertNumberToTime, formatPrice } from "@/lib/utils";

const { params } = useRoute();
const { data: orderSelected } = useOrderDetail(String(params.id));

const handleDragStart = () => {
    
}
</script>
