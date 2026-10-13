// Estimated delivery time from GHN for the same places the fee was priced for.
export default defineEventHandler(async (event) => {
  const request = await readValidatedBody(event, leadtimeRequestSchema.parse);

  const { ghn } = useRuntimeConfig(event);
  const serviceId = Number(request.weightG >= HEAVY_FROM_G ? ghn.heavyGoodsServiceId : ghn.lightGoodsServiceId);
  if (!Number.isInteger(serviceId) || serviceId <= 0) {
    throw createError({ statusCode: 503, statusMessage: "GHN service is not configured" });
  }

  return ghnFetch(event, "/v2/shipping-order/leadtime", {
    method: "POST",
    withShop: true,
    body: leadtimeBody(request, serviceId),
  });
});
