<template>
  <form @submit.prevent="onSubmit">
    <div class="grid grid-cols-2 gap-x-8">
      <div class="space-y-6">
        <FormField v-slot="{ componentField }" name="name">
          <FormItem>
            <FormLabel>{{ $t("common.name") }}</FormLabel>
            <FormControl>
              <Input
                type="text"
                placeholder="shadcn"
                v-bind="componentField"
                size="sm"
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        </FormField>
        <FormField v-slot="{ componentField, value }" name="duration">
          <FormItem>
            <FormLabel> {{ $t("pageFields.pets.duration") }}</FormLabel>
            <FormControl>
              <Slider
                v-bind="componentField"
                :default-value="[0]"
                :max="1439"
                :min="0"
                :step="5"
              />
              <FormDescription class="flex justify-between">
                <span>{{ convertNumberToTime(value?.[0] || 0) }} m</span>
              </FormDescription>
            </FormControl>
            <FormMessage />
          </FormItem>
        </FormField>

        <FormField v-slot="{ componentField }" name="type">
          <FormItem>
            <FormLabel>
              {{ $t("pageFields.pets.serviceTypeSelect") }}</FormLabel
            >
            <Select v-bind="componentField">
              <FormControl>
                <SelectTrigger>
                  <SelectValue
                    :placeholder="$t('pageFields.pets.serviceTypeSelect')"
                  />
                </SelectTrigger>
              </FormControl>
              <SelectContent>
                <SelectGroup>
                  <SelectItem v-for="(i, ii) in type" :value="i.id">
                    {{ (type[ii].lang as any)[String(locale)] }}
                  </SelectItem>
                </SelectGroup>
              </SelectContent>
            </Select>
            <FormMessage />
          </FormItem>
        </FormField>
        <FormField
          v-slot="{ componentField }"
          type="radio"
          name="unit"
          v-if="props.form.values['type'] === 'all'"
        >
          <FormItem class="space-y-3">
            <FormLabel>
              {{ $t("pageFields.pets.unit") }}
            </FormLabel>

            <FormControl>
              <RadioGroup class="flex gap-6 space-y-1" v-bind="componentField">
                <FormItem
                  class="flex items-center space-y-0 gap-x-3"
                  v-for="(i, ii) in unit"
                >
                  <FormControl>
                    <RadioGroupItem :value="i.id" />
                  </FormControl>
                  <FormLabel class="font-normal">
                    {{ (unit[ii].lang as any)[String(locale)] }}
                  </FormLabel>
                </FormItem>
              </RadioGroup>
            </FormControl>
            <FormMessage />
          </FormItem>
        </FormField>

        <FormField
          v-slot="{ componentField }"
          type="radio"
          name="generalPrice"
          v-if="props.form.values['type'] === 'all'"
        >
          <FormItem class="space-y-3">
            <FormLabel>
              {{ $t("pageFields.pets.generalPrice") }}
            </FormLabel>

            <FormControl>
              <Input
                type="number"
                v-bind="componentField"
                size="sm"
                placeholder="Enter general price"
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        </FormField>
      </div>

      <div class="space-y-6">
        <div id="choose_pets" class="space-y-1">
          <Label class="font-bold mb-3">
            {{ $t("pageFields.pets.choosePet") }}
          </Label>
          <multiselect
            v-model="petsSelected"
            :options="pets"
            :multiple="true"
            :close-on-select="false"
            :clear-on-select="false"
            :preserve-search="true"
            placeholder="choose pets"
            label="name"
            track-by="name"
            :taggable="true"
            
            @update:modelValue="(value:any) => {
                               props.form.setFieldValue('petIds', value?.map((i:any) => i.id));
                               props.form.setFieldValue('petsProfiles', value?.map((i:any) => i))
                            }"
          >
          </multiselect>
        </div>
        <FormField v-slot="{ value, handleChange }" name="isShow">
          <FormItem>
            <FormLabel>
              {{ $t("pageFields.pets.status") }}
            </FormLabel>
            <div
              class="flex flex-row items-center justify-between rounded-lg border p-4"
            >
              <div class="space-y-0.5">
                <FormDescription
                  >{{ $t("pageFields.pets.markSale") }}
                </FormDescription>
              </div>
              <FormControl>
                <Switch :checked="value" @update:checked="handleChange" />
              </FormControl>
            </div>
          </FormItem>
        </FormField>
        <FormField v-slot="{ componentField }" name="desc">
          <FormItem>
            <FormLabel>{{ $t("common.description") }}</FormLabel>
            <FormControl>
              <Textarea
                placeholder="Tell us a little bit about yourself"
                class="resize-none"
                v-bind="componentField"
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        </FormField>
      </div>
    </div>
    <div v-if="props.showBtn">
      <Button type="button" variant="outline"> Cancel </Button>
      <Button type="submit"> Save changes </Button>
    </div>
  </form>
</template>

<script lang="ts" setup>
import { FormField } from "@/components/ui/form";
import FormControl from "@/components/ui/form/FormControl.vue";
import FormItem from "@/components/ui/form/FormItem.vue";
import FormLabel from "@/components/ui/form/FormLabel.vue";
import FormMessage from "@/components/ui/form/FormMessage.vue";
import Input from "@/components/ui/input/Input.vue";
import { Textarea } from "@/components/ui/textarea";
import type { FormContext } from "vee-validate";
import { useAllPets } from "@/queries/pets";
import {
  computed,
  getCurrentInstance,
  onMounted,
  ref,
  watch,
  watchEffect,
  type Ref,
} from "vue";
import Multiselect from "vue-multiselect";
import Label from "@/components/ui/label/Label.vue";
import Button from "@/components/ui/button/Button.vue";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { contents as unit, type } from "@/data/pet-service.json";
import type { PetsServicesValid } from "@/validations/pets";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { cn, convertNumberToTime, formatPrice } from "@/lib/utils";
import { Slider } from "@/components/ui/slider";
import type { z } from "zod";
import { useI18n } from "vue-i18n";
import Switch from "@/components/ui/switch/Switch.vue";

const props = defineProps<{
  form: FormContext<any>;
  showBtn: boolean;
  elSelect?: any;
  defaultPet?:any[]
}>();
const { locale } = useI18n();
const emits = defineEmits(["onSubmit"]);
const { data: petOptions } = useAllPets();
const pets = computed(() => petOptions.value ?? []);
const petsSelected = ref<any[]>(props?.elSelect?.petsProfiles || props?.defaultPet || null);

const onFormSubmit = props.form.handleSubmit(
  async (values: z.infer<typeof PetsServicesValid>) => {}
);

const onSubmit = (values: any) => {
  if (!props.showBtn) {
    emits("onSubmit", values);
  } else {
    onFormSubmit(values);
  }
};

watchEffect(() => {
  if(props.defaultPet) {
    props.form.setFieldValue('petIds', props.defaultPet?.map((i:any) => i.id));
    props.form.setFieldValue('petsProfiles', props.defaultPet?.map((i:any) => i))
  }
})
</script>
