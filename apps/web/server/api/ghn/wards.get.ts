import { z } from "zod";

const querySchema = z.object({ districtId: z.coerce.number().int().positive() });

export default defineEventHandler(async (event) => {
  const { districtId } = await getValidatedQuery(event, querySchema.parse);
  return ghnFetch(event, "/master-data/ward", { query: { district_id: districtId } });
});
