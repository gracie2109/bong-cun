import type { IGHNShippingPayload } from "@/types/shipment.type";

import { env } from "@/config/env";

const token = env.ghnToken;
const service_light_good = env.ghnLightGoodsServiceId;

export async function calcShippingFee({
  shippingInfo,
  storeInfo,
  orderInfo,
}: any) {
  try {
    const url =
      "https://online-gateway.ghn.vn/shiip/public-api/v2/shipping-order/fee";
    const controller = new AbortController();
    const signal = controller.signal;
    const response = await (
      await fetch(url, {
        method: "POST",
        //@ts-ignore
        headers: {
          "Content-Type": "application/json",
          ShopId: "4950045",
          token: "51f94fe2-e02f-11ee-a2c1-ca2feb4b63fa",
        },
        body: JSON.stringify({
          service_type_id: 5,
          from_district_id: 1442,
          from_ward_code: "21211",
          to_district_id: 1820,
          to_ward_code: "030712",
          length: 30,
          width: 40,
          height: 20,
          weight: 3000,
          insurance_value: 0,
          coupon: null,
          items: [
            {
              name: "TEST1",
              quantity: 1,
              length: 200,
              width: 200,
              height: 200,
              weight: 1000,
            },
          ],
        }),
        signal,
      })
    ).json();
    if (response) {
      if (response.code !== 200) {
        console.log("calcShippingFee fail", response?.message);
      }
      return response.data;
    }
  } catch (err: any) {
    console.log(new Error(err));
  }
}

// Tính thời gian dự kiến giao
export async function getLeadTime() {
  try {
    const production_path =
      "https://online-gateway.ghn.vn/shiip/public-api/v2/shipping-order/leadtime";

    const controller = new AbortController();
    const signal = controller.signal;

    const response = await (
      await fetch(production_path, {
        method: "POST",
        headers: {
          ShopId: "4950045",
          token: "51f94fe2-e02f-11ee-a2c1-ca2feb4b63fa",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from_district_id: 1750,
          from_ward_code: "511110",
          to_district_id: 1750,
          to_ward_code: "511110",
          service_id: service_light_good,
        }),
        signal,
      })
    ).json();

    if (response) {
      if (response.code !== 200) {
        console.log("getLeadTime fail", response?.message);
      }
      return response.data?.leadtime;
    }
  } catch (err: any) {
    console.log("getLeadTime fail", err?.message);
  }
}
