import { describe, expect, it } from "vitest";
import {
  emptyPickerState,
  filterOptions,
  fromValue,
  isComplete,
  pickProvince,
  pickWard,
  searchKey,
  toOptions,
  toValue,
} from "../../src/features/shared/locations/helpers/pickerState";
import { locationKeys } from "../../src/features/shared/locations/queries/locationKeys";

const hanoi = { code: "vn_a", fullName: "Thành phố Hà Nội" };
const hue = { code: "vn_b", fullName: "Thành phố Huế" };
const ward = { code: "vn_w", fullName: "Phường Ba Đình" };

describe("pickerState", () => {
  it("clears the ward when another province is picked", () => {
    const state = pickWard(pickProvince(emptyPickerState(), hanoi), ward);
    expect(isComplete(state)).toBe(true);
    const next = pickProvince(state, hue);
    expect(next.ward).toBeNull();
    expect(toValue(next)).toBeNull();
  });

  it("keeps the ward when the same province is picked again", () => {
    const state = pickWard(pickProvince(emptyPickerState(), hanoi), ward);
    expect(pickProvince(state, hanoi)).toBe(state);
  });

  it("is not complete without a ward, and a ward needs a province", () => {
    expect(isComplete(pickProvince(emptyPickerState(), hanoi))).toBe(false);
    expect(pickWard(emptyPickerState(), ward).ward).toBeNull();
  });

  it("round-trips a value", () => {
    const value = { provinceCode: "vn_a", provinceName: hanoi.fullName, wardCode: "vn_w", wardName: ward.fullName };
    expect(toValue(fromValue(value))).toEqual(value);
    expect(fromValue(null)).toEqual(emptyPickerState());
  });

  it("filters without accents and with đ as d", () => {
    expect(searchKey("Phường Ba Đình")).toBe("phuong ba dinh");
    const options = toOptions([
      { code: "1", officialCode: null, name: "Ba Đình", fullName: "Phường Ba Đình", unitType: "ward" },
      { code: "2", officialCode: null, name: "Cầu Giấy", fullName: "Phường Cầu Giấy", unitType: "ward" },
    ]);
    expect(filterOptions(options, "ba dinh").map((o) => o.value)).toEqual(["1"]);
    expect(filterOptions(options, "  ").length).toBe(2);
    expect(filterOptions(options, "zzz")).toEqual([]);
  });

  it("shows the unit type only where two units read the same", () => {
    const options = toOptions([
      { code: "1", officialCode: null, name: "A", fullName: "Xã A", unitType: "commune" },
      { code: "2", officialCode: null, name: "A", fullName: "Xã A", unitType: "special_zone" },
      { code: "3", officialCode: null, name: "B", fullName: "Xã B", unitType: "commune" },
    ]);
    expect(options.map((o) => o.hint)).toEqual(["commune", "special_zone", undefined]);
  });
});

describe("locationKeys", () => {
  it("changes with the catalog id", () => {
    expect(locationKeys.communes("c1", "vn_a")).not.toEqual(locationKeys.communes("c2", "vn_a"));
    expect(locationKeys.provinces("c1")).not.toEqual(locationKeys.provinces("c2"));
  });
});
