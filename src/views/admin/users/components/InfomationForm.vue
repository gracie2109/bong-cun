<template>
  <form class="flex h-full min-h-0 flex-col" @submit.prevent="submitHandle">
    <header class="space-y-1 border-b px-6 py-5">
      <div class="flex items-center gap-2">
        <h2 class="text-xl font-bold">{{ $t("pageFields.customers.form.title") }}</h2>
        <span class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-semibold text-primary">
          {{ $t("pageFields.customers.form.new") }}
        </span>
      </div>
      <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.form.subtitle") }}</p>
    </header>

    <Tabs :model-value="step" class="flex min-h-0 flex-1 flex-col" @update:model-value="goTo">
      <TabsList class="h-11 w-full justify-start gap-4 rounded-none border-b bg-transparent p-0 px-6">
        <TabsTrigger
          v-for="(s, i) in STEPS"
          :key="s.id"
          :value="s.id"
          class="h-full rounded-none border-b-2 border-transparent px-1 text-muted-foreground data-[state=active]:border-primary data-[state=active]:text-primary"
        >
          <span class="flex items-center gap-1.5 whitespace-nowrap">
            <Check v-if="i < stepIndex" class="size-3.5 text-green-600" />
            <component :is="s.icon" v-else class="size-3.5" />
            {{ i + 1 }}. {{ $t(`pageFields.customers.form.step.${s.id}`) }}
            <span
              v-if="s.id === 'address' && addressHasError"
              class="size-2 rounded-full bg-destructive"
            />
          </span>
        </TabsTrigger>
      </TabsList>

      <div class="min-h-0 flex-1 overflow-y-auto px-6 py-5">
        <TabsContent :value="STEP.INFO" force-mount :hidden="step !== STEP.INFO" class="mt-0">
          <CustomerInfoStep :form="props.form" />
        </TabsContent>

        <TabsContent :value="STEP.GROUPS" force-mount :hidden="step !== STEP.GROUPS" class="mt-0">
          <CustomerGroupsStep :form="props.form" :group-options="props.listUserGroup" />
        </TabsContent>

        <TabsContent :value="STEP.ADDRESS" force-mount :hidden="step !== STEP.ADDRESS" class="mt-0 space-y-4">
          <div>
            <h3 class="flex items-center gap-2 font-semibold">
              <Truck class="size-4 text-primary" />
              {{ $t("pageFields.customers.form.addressTitle") }}
            </h3>
            <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.form.addressDesc") }}</p>
          </div>
          <ProvinceAddress :address-model="props.addressModel" :form="props.form" field-name="province" />
        </TabsContent>
      </div>
    </Tabs>

    <footer class="flex items-center justify-between gap-3 border-t px-6 py-4">
      <Button type="button" variant="ghost" :disabled="props.loading" @click="emit('closeDialog')">
        {{ $t("pageFields.customers.form.cancel") }}
      </Button>
      <div class="flex gap-2">
        <Button v-if="stepIndex > 0" type="button" variant="outline" @click="goBack">
          <ArrowLeft class="mr-1 size-4" />
          {{ $t("pageFields.customers.form.back") }}
        </Button>
        <Button v-if="!isLastStep" type="button" @click="goNext">
          {{ $t("pageFields.customers.form.next") }}
          <ArrowRight class="ml-1 size-4" />
        </Button>
        <Button v-else type="submit" :disabled="props.loading">
          <Loader2 v-if="props.loading" class="mr-2 size-4 animate-spin" />
          {{ $t(props.loading ? "pageFields.customers.form.saving" : "pageFields.customers.form.save") }}
        </Button>
      </div>
    </footer>
  </form>
</template>

<script lang="ts" setup>
import type { FormContext } from "vee-validate";
import { ArrowLeft, ArrowRight, Check, Loader2, Truck } from "lucide-vue-next";
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ProvinceAddress } from "@/components/common/";
import type { IAddress } from "@/types/location.type";
import type { IUser } from "@/types/user.type";
import CustomerGroupsStep from "./CustomerGroupsStep.vue";
import CustomerInfoStep from "./CustomerInfoStep.vue";
import { STEP, STEPS, useCustomerSteps } from "./useCustomerSteps";

const props = defineProps<{
  form: FormContext<IUser>;
  loading: boolean;
  listUserGroup: any[];
  addressModel: IAddress;
}>();
const emit = defineEmits(["onSubmit", "closeDialog"]);

const { step, stepIndex, isLastStep, validateInfo, goTo, goNext, goBack } = useCustomerSteps(props.form);

const addressHasError = computed(() => Boolean(props.form.errors.value.province));

const submitHandle = async () => {
  if (!(await validateInfo())) {
    step.value = STEP.INFO;
    return;
  }
  emit("onSubmit");
};
</script>
