// Online shop settings: the public subset for the checkout and the staff view / editor.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { ShopPublicSettings, ShopSettings } from "@/types/shop";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

type SettingsJson = Record<string, unknown>;

const num = (value: unknown, fallback = 0): number => (value === null || value === undefined ? fallback : Number(value));
const numOrNull = (value: unknown): number | null => (value === null || value === undefined ? null : Number(value));
const textOrNull = (value: unknown): string | null => (typeof value === "string" && value ? value : null);

export const toPublicSettings = (json: SettingsJson): ShopPublicSettings => ({
  onlineBranchId: String(json.online_branch_id ?? ""),
  allowCod: json.allow_cod !== false,
  allowPickup: json.allow_pickup !== false,
  codMax: num(json.cod_max, 10000000),
  defaultWeightG: num(json.default_weight_g, 500),
  flatShippingFee: num(json.flat_shipping_fee, 30000),
  freeShipFrom: numOrNull(json.free_ship_from),
  ghnFromDistrictId: numOrNull(json.ghn_from_district_id),
  ghnFromWardCode: textOrNull(json.ghn_from_ward_code),
  pickupAddress: textOrNull(json.pickup_address),
  pickupNote: textOrNull(json.pickup_note),
});

export const toSettings = (json: SettingsJson): ShopSettings => ({
  ...toPublicSettings(json),
  ghnFromProvinceId: numOrNull(json.ghn_from_province_id),
  fromAddressText: textOrNull(json.from_address_text),
});

export const getPublicSettings = async (client: Client): Promise<ShopPublicSettings> =>
  toPublicSettings(unwrap(await client.rpc("shop_public_settings")) as SettingsJson);

export const getAdminSettings = async (client: Client): Promise<ShopSettings> =>
  toSettings(unwrap(await client.rpc("shop_admin_settings")) as SettingsJson);

export const saveSettings = async (client: Client, input: ShopSettings): Promise<ShopSettings> =>
  toSettings(
    unwrap(
      await client.rpc("save_shop_settings", {
        p: {
          online_branch_id: input.onlineBranchId,
          allow_cod: input.allowCod,
          allow_pickup: input.allowPickup,
          cod_max: input.codMax,
          default_weight_g: input.defaultWeightG,
          flat_shipping_fee: input.flatShippingFee,
          free_ship_from: input.freeShipFrom,
          ghn_from_province_id: input.ghnFromProvinceId,
          ghn_from_district_id: input.ghnFromDistrictId,
          ghn_from_ward_code: input.ghnFromWardCode,
          from_address_text: input.fromAddressText,
          pickup_address: input.pickupAddress,
          pickup_note: input.pickupNote,
        },
      })
    ) as SettingsJson
  );
