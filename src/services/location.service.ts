import type { GHNDistrict, GHNProvince, GHNWard } from "@/types/location.type";

// GHN is called through our server routes (server/api/ghn), which hold the token.
type GhnResponse<T> = { code?: number; message?: string; data?: T };

export async function getProvince() {
  try {
    const response = (await $fetch<GhnResponse<any[]>>("/api/ghn/provinces")).data;
    const responseMap = response?.map((i: any) => {
      return {
        ...i,
        ProvinceID: String(i.ProvinceID),
      };
    });

    return responseMap ? (responseMap as GHNProvince[]) : null;
  } catch (e: any) {
    console.log(new Error(e));
  }
}

export async function getDistrict(provinceId: number | string) {
  try {
    if (!provinceId) return null;
    const response = (
      await $fetch<GhnResponse<any[]>>("/api/ghn/districts", {
        query: { provinceId },
      })
    ).data;
    const responseMap = response?.map((i: any) => {
      return {
        ...i,
        DistrictID: String(i.DistrictID),
      };
    });
    return responseMap ? (responseMap as GHNDistrict[]) : null;
  } catch (e: any) {
    console.log(new Error(e));
  }
}

export async function getWard(districtId: number | string) {
  try {
    if (!districtId) return null;
    const response = (
      await $fetch<GhnResponse<GHNWard[]>>("/api/ghn/wards", {
        query: { districtId },
      })
    ).data;

    return response ? response : null;
  } catch (e: any) {
    console.log(new Error(e));
  }
}
