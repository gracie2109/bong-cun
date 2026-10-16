// The signed-in shopper's delivery addresses.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { Address, AddressInput } from "@bongcun/core/shop";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

type AddressJson = {
  id: string;
  receiver_name: string;
  phone: string;
  street: string;
  province_name: string;
  district_name: string;
  ward_name: string;
  ghn_province_id: number;
  ghn_district_id: number;
  ghn_ward_code: string;
  is_default: boolean;
};

export const toAddress = (row: AddressJson): Address => ({
  id: row.id,
  receiverName: row.receiver_name,
  phone: row.phone,
  street: row.street,
  provinceName: row.province_name,
  districtName: row.district_name,
  wardName: row.ward_name,
  ghnProvinceId: Number(row.ghn_province_id),
  ghnDistrictId: Number(row.ghn_district_id),
  ghnWardCode: String(row.ghn_ward_code),
  isDefault: row.is_default,
});

/** The default address first. */
export const listMyAddresses = async (client: Client): Promise<Address[]> =>
  ((unwrap(await client.rpc("my_addresses")) as AddressJson[] | null) ?? []).map(toAddress);

export const saveMyAddress = async (client: Client, input: AddressInput): Promise<Address> =>
  toAddress(
    unwrap(
      await client.rpc("save_my_address", {
        p: {
          id: input.id ?? null,
          receiver_name: input.receiverName,
          phone: input.phone,
          street: input.street,
          province_name: input.provinceName,
          district_name: input.districtName,
          ward_name: input.wardName,
          ghn_province_id: input.ghnProvinceId,
          ghn_district_id: input.ghnDistrictId,
          ghn_ward_code: input.ghnWardCode,
          is_default: input.isDefault ?? false,
        },
      })
    ) as AddressJson
  );

export const deleteMyAddress = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("delete_my_address", { p_id: id }));
};

export const setDefaultMyAddress = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("set_default_my_address", { p_id: id }));
};

/** Error hints raised by the address calls, for readable messages. */
export const ADDRESS_ERROR_HINTS = [
  "address_required",
  "invalid_phone",
  "address_location",
  "address_limit",
  "address_not_found",
] as const;
export type AddressErrorHint = (typeof ADDRESS_ERROR_HINTS)[number];

export const addressErrorHint = (error: unknown): AddressErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return ADDRESS_ERROR_HINTS.find((item) => item === hint) ?? null;
};
