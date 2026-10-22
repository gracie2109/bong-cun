// Reads of the location cache (public.location_* functions). Readable without signing in.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  catalogSchema,
  communePageSchema,
  locationDetailSchema,
  provincesSchema,
  searchPageSchema,
  toLocationCatalog,
  toLocationDetail,
  toLocationSearchPage,
  toLocationUnit,
  toLocationUnitPage,
} from "@bongcun/core/locations";
import type { LocationCatalog, LocationDetail, LocationPage, LocationSearchHit, LocationUnit } from "@bongcun/core/locations";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export const getProvinces = async (client: Client): Promise<LocationUnit[]> =>
  parseRpc("location_provinces", provincesSchema, unwrap(await client.rpc("location_provinces"))).map(toLocationUnit);

/** The communes of a province; the default page size returns the whole province. */
export const getCommunes = async (
  client: Client,
  provinceCode: string,
  options: { search?: string; page?: number; pageSize?: number } = {}
): Promise<LocationPage<LocationUnit>> => {
  const raw = unwrap(
    await client.rpc("location_communes", {
      p_province: provinceCode,
      p_search: options.search ?? undefined,
      p_page: options.page,
      p_page_size: options.pageSize,
    })
  );
  return toLocationUnitPage(parseRpc("location_communes", communePageSchema, raw));
};

export const getLocation = async (client: Client, code: string): Promise<LocationDetail> =>
  toLocationDetail(parseRpc("location_unit", locationDetailSchema, unwrap(await client.rpc("location_unit", { p_code: code }))));

export const searchLocations = async (client: Client, search: string, page = 1, pageSize = 20): Promise<LocationPage<LocationSearchHit>> => {
  const raw = unwrap(await client.rpc("location_search", { p_search: search, p_page: page, p_page_size: pageSize }));
  return toLocationSearchPage(parseRpc("location_search", searchPageSchema, raw));
};

export const getLocationCatalog = async (client: Client): Promise<LocationCatalog | null> =>
  toLocationCatalog(parseRpc("location_catalog", catalogSchema, unwrap(await client.rpc("location_catalog"))));
