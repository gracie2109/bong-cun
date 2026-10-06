import type { GHNDistrict, GHNProvince, GHNWard } from "@/types/location.type";

import { env } from "@/config/env";

const token = env.ghnToken;

export async function getProvince() {
  try {
    const url =
      "https://online-gateway.ghn.vn/shiip/public-api/master-data/province";

    const controller = new AbortController();
    const signal = controller.signal;
    if (token) {
      const response = (
        await (
          await fetch(url, {
            method: "GET",
            headers: {
              "Content-Type": "application/json",
              Token: "51f94fe2-e02f-11ee-a2c1-ca2feb4b63fa",
            },
            signal,
          })
        ).json()
      ).data;
      const responseMap = response.map((i: any) => {
        return {
          ...i,
          ProvinceID: String(i.ProvinceID),
        };
      });

      return responseMap ? (responseMap as GHNProvince[]) : null;
    }
  } catch (e: any) {
    console.log(new Error(e));
  }
}

export async function getDistrict(provinceId: number | string) {
  try {
    if (!provinceId) return null;
    else {
      const url =
        "https://online-gateway.ghn.vn/shiip/public-api/master-data/district";

      const controller = new AbortController();
      const signal = controller.signal;

      const response = (
        await (
          await fetch(url, {
            method: "GET",
            //@ts-ignore
            headers: {
              "Content-Type": "application/json",
              token: "51f94fe2-e02f-11ee-a2c1-ca2feb4b63fa",
              province_id: +provinceId,
            },
            signal,
          })
        ).json()
      ).data;
      const responseMap = response.map((i: any) => {
        return {
          ...i,
          DistrictID: String(i.DistrictID),
        };
      });
      return responseMap ? (responseMap as GHNDistrict[]) : null;
    }
  } catch (e: any) {
    console.log(new Error(e));
  }
}

export async function getWard(districtId: number | string) {
  try {
    if (!districtId) return null;
    else {
      const url = `https://online-gateway.ghn.vn/shiip/public-api/master-data/ward?district_id=${districtId}`;

      const controller = new AbortController();
      const signal = controller.signal;

      const response = (
        await (
          await fetch(url, {
            method: "GET",
            headers: {
              "Content-Type": "application/json",
              token: "51f94fe2-e02f-11ee-a2c1-ca2feb4b63fa",
            },
            signal,
          })
        ).json()
      ).data;

      return response ? (response as GHNWard[]) : null;
    }
  } catch (e: any) {
    console.log(new Error(e));
  }
}
