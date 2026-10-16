<template>
  <div class="mt-2 w-full space-y-4">
    <div class="grid grid-cols-2 items-start gap-3 w-full">
      <div class="space-y-2">
        <Label for="province">Province</Label>
        <Select
          :model-value="props.addressModel.province.ProvinceID"
          id="province"
          @update:modelValue="
            (v) =>
              currySelected(
                'province',
                v,
                'string',
                mapProvince,
                'ProvinceID',
                'ProvinceName'
              )
          "
        >
          <SelectTrigger>
            <SelectValue
              :placeholder="props.addressModel.province.ProvinceName"
            />
          </SelectTrigger>
          <SelectContent side="bottom">
            <template
              v-for="i in listProvince"
              v-if="listProvince"
              :key="i.ProvinceID"
            >
              <SelectItem :value="i.ProvinceID.toString()">
                {{ i.ProvinceName }}
              </SelectItem>
            </template>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-2">
        <Label for="district">District</Label>
        <Select
          :model-value="props.addressModel.district.DistrictID"
          id="district"
          @update:modelValue="
            (v) =>
              currySelected(
                'district',
                v,
                'string',
                mapDistricts,
                'DistrictID',
                'DistrictName'
              )
          "
        >
          <SelectTrigger>
            <SelectValue
              :placeholder="props.addressModel.district.DistrictName"
            />
          </SelectTrigger>
          <SelectContent side="bottom">
            <template
              v-for="i in listDistricts"
              v-if="listDistricts"
              :key="i.DistrictID"
            >
              <SelectItem :value="i.DistrictID.toString()">
                {{ i.DistrictName }}
              </SelectItem>
            </template>
          </SelectContent>
        </Select>
      </div>
    </div>

    <div class="space-y-2">
      <Label for="ward">Ward</Label>
      <Select
        :model-value="props.addressModel.ward.WardCode"
        id="ward"
        @update:modelValue="
          (v) =>
            currySelected('ward', v, 'string', mapWards, 'WardCode', 'WardName')
        "
      >
        <SelectTrigger>
          <SelectValue :placeholder="props.addressModel.ward.WardCode" />
        </SelectTrigger>
        <SelectContent side="bottom">
          <template v-for="i in listWards" v-if="listWards" :key="i.WardCode">
            <SelectItem :value="i.WardCode.toString()">
              {{ i.WardName }}
            </SelectItem>
          </template>
        </SelectContent>
      </Select>
    </div>

    <div class="gap-2" v-if="props.addressModel">
      <Label for="address">Address</Label>
      <Textarea
        id="address"
        v-model="props.addressModel.address"
        placeholder="Type your exactly address."
        @update:modelValue="
          (v:any) =>
            updateAddress(v)
        "
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { onMounted, reactive, ref, watchEffect } from "vue";
import type {
  GHNDistrict,
  GHNProvince,
  GHNWard,
  IAddress,
} from "@bongcun/core/users";
import { getDistrict, getProvince, getWard } from "@/services/location.service";
import type { FormContext } from "vee-validate";

const listProvince = ref<GHNProvince[] | null | undefined>(null);
const mapProvince = reactive(new Map());

const listDistricts = ref<GHNDistrict[] | null | undefined>(null);
const mapDistricts = reactive(new Map());

const listWards = ref<GHNWard[] | null | undefined>(null);
const mapWards = reactive(new Map());
const address = ref();
const props = defineProps<{
  addressModel: any;
  form: FormContext<any>;
  fieldName: string;
}>();
const updateAddress = (vl: string) => {
  if (props.form) {
    const field = props.fieldName;
    props.form.setValues({
      [field]: {
        address: vl,
      },
    });
  }
};
const currySelected = (
  modelName: keyof IAddress,
  selectedId: unknown,
  selectedIdType: "string" | "number",
  listMapName: Map<string | number, any>,
  codeField: any,
  nameField: any
) => {
  const select =
    selectedIdType === "number"
      ? listMapName.get(Number(selectedId))
      : listMapName.get(String(selectedId));
  if (select && props.addressModel) {
    //@ts-ignore
    props.addressModel[modelName][codeField] = select[codeField];
    //@ts-ignore
    props.addressModel[modelName][nameField] = select[nameField];

    const payload = {
      [modelName]: {
        [codeField]: select[codeField],
        [nameField]: select[nameField],
      },
    };

    props.form.setValues({ [props.fieldName]: { ...payload } });
  }
};

onMounted(async () => {
  const province = (await getProvince()) as any;
  listProvince.value = province;
  if (province) {
    province.map((i: GHNProvince) => mapProvince.set(i.ProvinceID, i));
  }
});

watchEffect(async () => {
  if (props.addressModel?.province?.ProvinceID !== 0) {
    const districts = await getDistrict(
      props.addressModel?.province?.ProvinceID
    );
    listDistricts.value = districts;
    if (districts) {
      districts.map((i: GHNDistrict) => mapDistricts.set(i.DistrictID, i));
    }
  }
});
watchEffect(async () => {
  if (props.addressModel?.district?.DistrictID !== 0) {
    const wards = await getWard(props.addressModel?.district?.DistrictID);
    listWards.value = wards;
    if (wards) {
      wards.map((i: GHNWard) => mapWards.set(i.WardCode, i));
    }
  }
});
</script>
