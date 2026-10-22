// Pure rules of the two-level picker: no Vue, no network.
import type { LocationUnit, LocationValue } from "@bongcun/core/locations";
import type { PickerOption, PickerState } from "../types";

export const emptyPickerState = (): PickerState => ({ province: null, ward: null });

/** Lower case, no accents, "đ" as "d": what the search box and the option labels are compared as. */
export const searchKey = (text: string): string =>
  text
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/gi, "d")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();

/** Picking a province clears the ward, which belonged to the old one. */
export const pickProvince = (state: PickerState, province: { code: string; fullName: string }): PickerState =>
  state.province?.code === province.code ? state : { province: { code: province.code, fullName: province.fullName }, ward: null };

export const pickWard = (state: PickerState, ward: { code: string; fullName: string }): PickerState =>
  state.province ? { ...state, ward: { code: ward.code, fullName: ward.fullName } } : state;

export const isComplete = (state: PickerState): boolean => state.province !== null && state.ward !== null;

/** The value to emit: only a complete choice, taken from the server's lists. */
export const toValue = (state: PickerState): LocationValue | null =>
  state.province && state.ward
    ? { provinceCode: state.province.code, provinceName: state.province.fullName, wardCode: state.ward.code, wardName: state.ward.fullName }
    : null;

export const fromValue = (value: LocationValue | null): PickerState =>
  value
    ? {
        province: { code: value.provinceCode, fullName: value.provinceName },
        ward: { code: value.wardCode, fullName: value.wardName },
      }
    : emptyPickerState();

export const filterOptions = (options: PickerOption[], query: string): PickerOption[] => {
  const key = searchKey(query);
  return key === "" ? options : options.filter((option) => searchKey(option.label).includes(key));
};

/** Options for a list of units; a unit type is shown only where two units would read the same. */
export const toOptions = (units: LocationUnit[]): PickerOption[] => {
  const seen = new Map<string, number>();
  for (const unit of units) seen.set(unit.fullName, (seen.get(unit.fullName) ?? 0) + 1);
  return units.map((unit) => ({
    value: unit.code,
    label: unit.fullName,
    hint: (seen.get(unit.fullName) ?? 0) > 1 ? unit.unitType : undefined,
  }));
};
