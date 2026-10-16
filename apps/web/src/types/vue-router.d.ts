import "vue-router";
import type { AccessMeta } from "@bongcun/core/auth";

declare module "vue-router" {
  interface RouteMeta extends AccessMeta {
    key?: string;
    layout?: string;
  }
}
