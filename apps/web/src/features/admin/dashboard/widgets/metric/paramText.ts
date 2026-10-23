import type { MetricParams } from "../../metrics/types";

type Translate = (key: string, named?: Record<string, unknown>) => string;
type Exists = (key: string) => boolean;

/** The parameters of a metric as words ("Spa · Theo doanh thu"), skipping any without a label. */
export const paramText = (params: MetricParams, t: Translate, te: Exists): string =>
  Object.entries(params)
    .map(([name, value]) => {
      if (typeof value === "number") return te(`dashboard.param.${name}`) ? t(`dashboard.param.${name}`, { n: value }) : "";
      const key = `dashboard.param.${name}.${value}`;
      return te(key) ? t(key) : "";
    })
    .filter(Boolean)
    .join(" · ");
