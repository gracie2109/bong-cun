import { apiUrl } from "@/utils/apiUrl";

/** `/api/...` path to the URL the build should call: relative on the web, absolute in the app. */
export const resolveApiUrl = (path: string): string =>
  apiUrl(useRuntimeConfig().public.apiBase as string | undefined, path);
