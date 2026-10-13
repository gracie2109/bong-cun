// Prices a parcel with GHN. The client sends the places and the weight; the service type is
// chosen here from the weight, and the answer is GHN's own JSON (`{ code, message, data }`).
export default defineEventHandler(async (event) => {
  const request = await readValidatedBody(event, feeRequestSchema.parse);

  const serviceType = serviceTypeForWeight(request.weightG);
  if (serviceType === null) {
    throw createError({ statusCode: 422, statusMessage: "Parcel is too heavy to deliver" });
  }

  return ghnFetch(event, "/v2/shipping-order/fee", {
    method: "POST",
    withShop: true,
    body: feeBody(request, serviceType),
  });
});
