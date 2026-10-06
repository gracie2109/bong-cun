<template>
  <div id="service_combo_form">
    <Dialog :open="props.open" @update:open="$emit('changeOpen')">
      <DialogContent
        class="sm:max-w-[425px] lg:max-w-[950px] grid-rows-[auto_minmax(0,1fr)_auto] p-0 h-auto max-h-[90dvh]">
        <DialogHeader class="p-6 pb-0">
          <DialogTitle> {{ $t("common.addNew") }}</DialogTitle>
          <DialogDescription>
            {{ $t("pageFields.serviceProvider.desc") }}
          </DialogDescription>
        </DialogHeader>
        <div class="grid gap-4 py-4 px-6 overflow-y-auto">
          <form class="space-y-6" @submit="onSubmit">
            <FormField v-slot="{ componentField }" name="name">
              <FormItem>
                <FormLabel>{{ $t("common.name") }}</FormLabel>
                <FormControl>
                  <Input type="text" placeholder="shadcn" v-bind="componentField" size="lg" />
                </FormControl>
                <FormMessage />
              </FormItem>
            </FormField>
            <FormField v-slot="{ componentField }" name="petIds">
              <FormItem>
                <FormLabel>{{ $t("pageFields.pets.choosePet") }}</FormLabel>
                <FormControl>
                  <Multiselect v-bind="componentField" v-model="petSelected" :options="listPet" :multiple="true"
                    :close-on-select="false" :clear-on-select="false" :preserve-search="true"
                    :placeholder="$t('pageFields.pets.choosePet')" label="name" track-by="name" :taggable="true"
                    @update:modelValue="(value: any) => {
                      props.form.setFieldValue('petIds', value?.map((i: any) => i.id));
                      props.form.setFieldValue('petProfiles', value?.map((i: any) => i))

                    }">
                  </Multiselect>
                </FormControl>
                <FormMessage />
              </FormItem>
            </FormField>
            <FormField v-slot="{ componentField }" name="serviceIds">
              <FormItem>
                <FormLabel>
                  {{ $t("pageFields.pets.chooseService") }}
                </FormLabel>
                <FormControl>
                  <Multiselect v-bind="componentField" v-model="serviceSelected" :options="listServices"
                    :multiple="true" :close-on-select="false" :clear-on-select="false" :preserve-search="true"
                    :placeholder="$t('pageFields.pets.chooseService')" label="name" track-by="name" :taggable="true"
                    @update:modelValue="(value: any) => {
                      props.form.setFieldValue('serviceIds', value?.map((i: any) => i.id));
                      props.form.setFieldValue('serviceProfiles', value?.map((i: any) => i))
                    }">
                  </Multiselect>
                </FormControl>
                <FormMessage />
              </FormItem>
            </FormField>
            <div class="grid grid-cols-2 gap-3">
        
              <FormField v-slot="{ componentField }" name="origin_price">
                <FormItem>
                  <FormLabel>{{ $t("pageFields.pets.originPrice") }}</FormLabel>
                  <FormControl>
                    <InputContent v-bind="componentField" :placeholder="$t('pageFields.pets.originPrice')"
                      :contentValue="formatPrice(origin_price)" :form="props.form" name="origin_price" disabled />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              </FormField>
              <FormField v-slot="{ componentField }" name="price">
                <FormItem>
                  <FormLabel>{{ $t("common.price") }}</FormLabel>
                  <FormControl>
                    <InputContent v-bind="componentField" placeholder="price" @update-value="(vl) => (price = vl)"
                      :contentValue="formatPrice(price)" :form="props.form" name="price" />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              </FormField>

              <FormField v-slot="{ componentField, value }" name="duration">
                <FormItem>
                  <FormLabel>
                    {{ $t("pageFields.pets.duration") }}
                  </FormLabel>
                  <FormControl>
                    <Slider v-bind="componentField" :default-value="[0]" :max="1439" :min="0" :step="5" />
                    <FormDescription class="flex justify-between">
                      <span>{{ convertNumberToTime(value?.[0] || 0) }} m</span>
                    </FormDescription>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              </FormField>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <FormField v-slot="{ componentField }" name="markAsId">
                <FormItem>
                  <FormLabel>
                    {{ $t("pageFields.pets.display") }}
                  </FormLabel>

                  <Select v-bind="componentField">
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue :placeholder="$t('pageFields.pets.displayPlaceholder')
                          " />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectGroup>
                        <SelectItem :value="String(i.id)" :key="ii" v-for="(i, ii) in status">
                          <span>
                            {{ (i.name as any)[locale] }}
                          </span>
                        </SelectItem>
                      </SelectGroup>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              </FormField>
              <FormField v-slot="{ componentField }" name="markTime">
                <FormItem>
                  <FormLabel>{{ $t("pageFields.pets.comboTime") }}</FormLabel>
                  <VueDatePicker v-bind="componentField" v-model="date" range :preset-dates="presetDates"
                    :readonly="props.form.values['markAsId'] === '4'">
                    <template #preset-date-range-button="{ label, value, presetDate }">
                      <span role="button" :tabindex="0" @click="presetDate(value)"
                        @keyup.enter.prevent="presetDate(value)" @keyup.space.prevent="presetDate(value)">
                        {{ label }}
                      </span>
                    </template>
                  </VueDatePicker>
                  <FormMessage />
                </FormItem>
              </FormField>
            </div>

            <FormField v-slot="{ componentField }" name="desc">
              <FormItem>
                <FormLabel>{{ $t("common.description") }}</FormLabel>
                <FormControl>
                  <Textarea placeholder="Tell us a little bit about yourself" class="resize-none"
                    v-bind="componentField" />
                </FormControl>
                <FormMessage />
              </FormItem>
            </FormField>
            <DialogFooter class="p-6 pt-0">
              <Button type="button" variant="outline" @click="$emit('changeOpen')">
                Cancel
              </Button>
              <Button type="submit"> Save changes </Button>
            </DialogFooter>
          </form>
        </div>
      </DialogContent>
    </Dialog>
  </div>
</template>

<script lang="ts" setup>
import {
  FormControl,
  FormField,
  FormMessage,
  FormLabel,
  FormItem,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { ref, watch } from "vue";
import "@vuepic/vue-datepicker/dist/main.css";
import VueDatePicker from "@vuepic/vue-datepicker";
import { InputContent } from "@/components/common";
import { cn, convertNumberToTime, formatPrice } from "@/lib/utils";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

import { status } from "@/data/status.json";
import { useI18n } from "vue-i18n";
import type { FormContext } from "vee-validate";
import { useCreatePetCombo } from "@/queries/petCombos";
import { useFetchServicesOfPets } from "@/queries/petServices";
import Multiselect from "vue-multiselect";
import { Slider } from "@/components/ui/slider";
import { TIME_OPTIONS } from "@/lib/constants";

const props = defineProps<{
  form: FormContext<any>;
  open: boolean;
  rowEditting?: any;
  listPet: any[];
}>();

const emit = defineEmits(["onSubmitHdl", "changeOpen"]);
const { locale } = useI18n();
const dataItem = ref();
const createCombo = useCreatePetCombo();
const fetchServicesOfPets = useFetchServicesOfPets();
const date = ref();
const time = ref([0]);
const price = ref();
const serviceSelected = ref<any[]>([]);
const petSelected = ref<any[]>([]);
const listServices = ref<any[]>([]);
const origin_price = ref();

function resetAll() {
  props.form.resetForm();
  date.value = null;
  time.value = [0];
  price.value = null;
  serviceSelected.value = [];
  petSelected.value = [];
  origin_price.value = 0;
}
const onSubmit = props.form.handleSubmit(async (values: any) => {
  if (!dataItem.value) {
    const pl = { ...values, status: 1 };
    try {
      await createCombo.mutateAsync(pl);
    } catch {
      return; // the mutation already showed the failure toast; keep the dialog open
    }
    resetAll();
    emit("changeOpen");
  }
});

const presetDates = ref(TIME_OPTIONS);
watch(
  () => petSelected.value,
  async () => {
    if (!petSelected.value || petSelected.value.length === 0) {
      serviceSelected.value = [];
      listServices.value = [];
      props.form.setFieldValue("serviceIds", []);
      return;
    }

    const response = await fetchServicesOfPets(
      petSelected.value.map((i) => i?.id).filter(Boolean)
    );
    listServices.value = response || [];

    const selectedServiceIds = serviceSelected.value.map(
      (service) => service.id
    );

    const validServices = serviceSelected.value.filter((service) =>
      listServices.value.some((respService) => respService.id === service.id)
    );

    serviceSelected.value = validServices;

    if (validServices.length !== selectedServiceIds.length) {
      props.form.setFieldValue(
        "serviceIds",
        validServices.map((service) => service.id)
      );
    } else {
      props.form.setFieldValue("serviceIds", selectedServiceIds);
    }
  }
);

watch(
  () => props.rowEditting,
  (newVal) => {
    console.log("newVal", props.rowEditting);
    props.form.setValues({ ...props.rowEditting }, true);
    petSelected.value = props.rowEditting["petProfiles"] ?? [];
    price.value = props.rowEditting["price"];
    time.value = props.rowEditting["duration"];
  }
);

watch(
  () => props.open,
  () => {
    if (!props.open) {
      resetAll();
    }
  }
);

watch(
  () => serviceSelected.value,
  () => {
    if (serviceSelected.value.length > 0) {
      const data = serviceSelected.value.reduce(
        (accumulator, currentValue) =>
          accumulator + (currentValue?.generalPrice || 0),
        0
      );
      origin_price.value = data;
      const formVals = props.form?.values;
      props.form.setValues({ ...formVals, origin_price: data }, true);
    }
  }
);
</script>
