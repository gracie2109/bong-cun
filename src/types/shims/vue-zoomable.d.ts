// vue-zoomable ships types in dist/types, but its package.json "exports" does not point to them.
declare module "vue-zoomable" {
  import type { DefineComponent } from "vue";

  const VueZoomable: DefineComponent<Record<string, unknown>>;
  export default VueZoomable;
}
