import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { POS_ERROR_HINTS } from "@bongcun/core/pos";
import { SHOP_ERROR_HINTS } from "@bongcun/core/shop";
import { INVENTORY_ERROR_HINTS } from "@bongcun/core/inventory";
import { SPA_ERROR_HINTS } from "@bongcun/core/spa";
import { BOARDING_ERROR_HINTS } from "@bongcun/core/boarding";
import { MEDICAL_ERROR_HINTS } from "@bongcun/core/medical";

const supabaseSrc = fileURLToPath(new URL("../../../../packages/supabase/src/", import.meta.url));

const sourceFiles = (dir: string): string[] =>
  readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return path.endsWith(".ts") && !path.endsWith(".test.ts") ? [path] : [];
  });

/** Every RPC a repository module calls, read from its `.rpc("name")` calls so a new RPC is covered at once. */
export const rpcsCalledBy = (moduleDir: string): string[] => {
  const names = sourceFiles(join(supabaseSrc, moduleDir)).flatMap((file) =>
    [...readFileSync(file, "utf8").matchAll(/\.rpc(?:<[^>]*>)?\(\s*"([a-z_0-9]+)"/g)].map((match) => match[1]!)
  );
  return [...new Set(names)].sort();
};

export type HintModule = { module: string; hints: readonly string[]; functions: string[] };

// The money flows (POS, shop) list their functions by hand: they also call helpers outside a repository.
const MONEY_FUNCTIONS = [
  "create_invoice", "cancel_invoice", "create_sales_return", "open_cash_shift", "close_cash_shift",
  "place_shop_order", "confirm_shop_order", "pack_shop_order", "ship_shop_order", "deliver_shop_order",
  "return_shop_order", "cancel_shop_order", "cancel_my_shop_order", "pay_pickup_shop_order",
  "shop_order_for_update", "take_stock_fefo",
];

// Called from the spa folder but owned by the product catalog (it has its own error hints).
const NOT_SPA = new Set(["set_product_branch_prices"]);

export const HINT_MODULES: HintModule[] = [
  { module: "money flows", hints: [...POS_ERROR_HINTS, ...SHOP_ERROR_HINTS], functions: MONEY_FUNCTIONS },
  { module: "inventory", hints: INVENTORY_ERROR_HINTS, functions: rpcsCalledBy("inventory") },
  { module: "spa", hints: SPA_ERROR_HINTS, functions: rpcsCalledBy("spa").filter((fn) => !NOT_SPA.has(fn)) },
  { module: "boarding", hints: BOARDING_ERROR_HINTS, functions: rpcsCalledBy("boarding") },
  { module: "medical", hints: MEDICAL_ERROR_HINTS, functions: rpcsCalledBy("medical") },
];

// Generic hints every module shares; they have no business code of their own.
export const GENERIC_HINTS = new Set(["not_found", "bad_input", "not_signed_in", "not_editable", "forbidden"]);

// Names the screens still translate but no SQL function raises any more.
export const KNOWN_UNRAISED = new Set(["inpatient_unavailable", "paid"]);
