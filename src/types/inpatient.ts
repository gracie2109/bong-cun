// In-patient care: kennels, orders and the doses of one day (see 20261021080100_inpatient_rpcs.sql).
export type InpatientKennel = { id: string; code: string; typeName: string; purpose: "medical" | "isolation"; free: boolean };

export type OrderKind = "product" | "service" | "care";

export type WardOrder = {
  id: string;
  kind: OrderKind;
  name: string;
  dose: string;
  qtyPerDose: number;
  times: string[];
  startOn: string;
  endOn: string;
  note: string;
};

export type WardDose = {
  id: string;
  orderId: string;
  dueAt: string;
  givenAt: string | null;
  givenByName: string | null;
  skippedReason: string | null;
};

export type WardRow = {
  stayId: string;
  stayCode: string;
  stayPetId: string;
  visitId: string;
  visitCode: string;
  petId: string;
  petName: string;
  customerName: string;
  customerPhone: string;
  kennelCode: string;
  purpose: "medical" | "isolation";
  since: string;
  plannedOutAt: string;
  overdue: boolean;
  allergies: string | null;
  orders: WardOrder[];
  doses: WardDose[];
  lastVitals: { content: string; loggedAt: string } | null;
};

export type Ward = { date: string; rows: WardRow[] };

export type AdmitInput = { kennelId: string; plannedOutAt: string | null; note: string };

export type OrderInput = {
  stayPetId: string;
  kind: OrderKind;
  productId: string | null;
  serviceId: string | null;
  name: string;
  dose: string;
  qtyPerDose: number;
  times: string[];
  startOn: string;
  endOn: string;
  note: string;
};

export type LogKind = "vitals" | "treatment" | "note";
