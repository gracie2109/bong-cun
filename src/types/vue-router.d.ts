import "vue-router";
import type { AccessMeta } from "@/lib/access";

declare module "vue-router" {
  interface RouteMeta extends AccessMeta {
    key?: string;
    layout?: string;
  }
}
