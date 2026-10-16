import { computed, type Ref } from "vue";
import { useGhnDistricts, useGhnProvinces, useGhnWards } from "@/queries/ghnLocations";
import type { GhnLocation } from "@bongcun/core/shop";

/**
 * Province -> district -> ward choice for GHN. Picking a higher level clears the lower ones;
 * names are copied next to the ids because ids price the parcel and names print on the label.
 */
export const useGhnLocationPicker = (model: Ref<GhnLocation>) => {
  const provinces = useGhnProvinces();
  const districts = useGhnDistricts(computed(() => model.value.provinceId));
  const wards = useGhnWards(computed(() => model.value.districtId));

  const provinceOptions = computed(() =>
    (provinces.data.value ?? []).map((item) => ({ value: String(item.ProvinceID), label: item.ProvinceName }))
  );
  const districtOptions = computed(() =>
    (districts.data.value ?? []).map((item) => ({ value: String(item.DistrictID), label: item.DistrictName }))
  );
  const wardOptions = computed(() =>
    (wards.data.value ?? []).map((item) => ({ value: String(item.WardCode), label: item.WardName }))
  );

  const pickProvince = (value: string) => {
    const option = provinceOptions.value.find((item) => item.value === value);
    if (!option) return;
    model.value = {
      provinceId: Number(value),
      provinceName: option.label,
      districtId: null,
      districtName: "",
      wardCode: null,
      wardName: "",
    };
  };

  const pickDistrict = (value: string) => {
    const option = districtOptions.value.find((item) => item.value === value);
    if (!option) return;
    model.value = { ...model.value, districtId: Number(value), districtName: option.label, wardCode: null, wardName: "" };
  };

  const pickWard = (value: string) => {
    const option = wardOptions.value.find((item) => item.value === value);
    if (!option) return;
    model.value = { ...model.value, wardCode: value, wardName: option.label };
  };

  return {
    provinceOptions,
    districtOptions,
    wardOptions,
    loading: computed(() => provinces.isLoading.value || districts.isFetching.value || wards.isFetching.value),
    pickProvince,
    pickDistrict,
    pickWard,
  };
};
