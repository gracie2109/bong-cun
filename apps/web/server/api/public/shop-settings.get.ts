import { getPublicSettings } from "@bongcun/supabase/shop";

// What the product page, cart and checkout read about delivery and payment.
export default defineEventHandler((event) => publicRead(event, () => getPublicSettings(publicSupabase(event))));
