// Same fixed request the client used to send directly to GHN (test data).
export default defineEventHandler((event) => {
  const { ghn } = useRuntimeConfig(event);
  return ghnFetch(event, "/v2/shipping-order/leadtime", {
    method: "POST",
    withShop: true,
    body: {
      from_district_id: 1750,
      from_ward_code: "511110",
      to_district_id: 1750,
      to_ward_code: "511110",
      service_id: ghn.lightGoodsServiceId,
    },
  });
});
