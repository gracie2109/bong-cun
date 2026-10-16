<template>
    <div class="input_pw flex relative">
        <Input class="relative" :type="showPass ? 'text' : 'password'" v-model:model-value="value"
            @update:model-value="updateValue" :placeholder="props.placeholder" />
        <div @click="updateState" class="absolute right-3 h-full grid place-items-center cursor-pointer"
            v-if="value.trim().length > 0">
            <EyeOff v-if="!showPass" class="w-4 h-4" />
            <Eye v-else class="w-4 h-4" />
        </div>
    </div>
</template>


<script lang="ts" setup>
import { ref } from "vue";
import { Input } from "@/components/ui/input";
import { Eye, EyeOff } from "lucide-vue-next";


const props = defineProps<{
    placeholder: string,
}>()

const emits = defineEmits(['updateValue'])


const showPass = ref(false)

const value = ref('');
function updateState() {
    showPass.value = !showPass.value
}

function updateValue() {
    emits('updateValue', value.value)
}
</script>