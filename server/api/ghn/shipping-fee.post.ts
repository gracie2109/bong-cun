// Same fixed request the client used to send directly to GHN. It is still test
// data (the order details are not passed through yet).
export default defineEventHandler((event) =>
  ghnFetch(event, "/v2/shipping-order/fee", {
    method: "POST",
    withShop: true,
    body: {
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
    },
  })
);
