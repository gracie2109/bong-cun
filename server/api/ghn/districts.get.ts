import { z } from "zod";

const querySchema = z.object({ provinceId: z.coerce.number().int().positive() });

export default defineEventHandler(async (event) => {
  const { provinceId } = await getValidatedQuery(event, querySchema.parse);
  return ghnFetch(event, "/master-data/district", {
    headers: { province_id: String(provinceId) },
  });
});
