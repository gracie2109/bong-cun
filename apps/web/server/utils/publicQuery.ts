// Query string shapes of the /api/public routes. Pages are capped so one request cannot pull a whole table.
import { z } from "zod";
import { CATALOG_SORTS } from "@bongcun/core/shop";

const MAX_PAGE_SIZE = 200;

const optionalId = z.string().uuid().optional();

export const pageQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(MAX_PAGE_SIZE).default(24),
});

export const categoriesQuerySchema = pageQuerySchema.extend({
  rootsOnly: z.enum(["true", "false"]).optional().transform((value) => value === "true"),
});

export const productsQuerySchema = pageQuerySchema.extend({
  search: z.string().trim().max(100).optional(),
  category: optionalId,
  brand: optionalId,
  sort: z.enum(CATALOG_SORTS).default("newest"),
});

export const branchQuerySchema = z.object({ branch: optionalId });

export const idParamSchema = z.object({ id: z.string().uuid() });
