import type { ExportColumn } from "@/lib/data-io/columns";
import type { MedicalVisit } from "@/types/medicalVisit";

const STATUS_TEXT: Record<string, string> = {
  scheduled: "Đã hẹn",
  waiting: "Chờ khám",
  in_progress: "Đang khám",
  done: "Chờ thanh toán",
  paid: "Đã thanh toán",
  cancelled: "Đã hủy",
  no_show: "Không đến",
};

const OUTCOME_TEXT: Record<string, string> = {
  home: "Về nhà",
  recheck: "Tái khám",
  inpatient: "Nội trú",
  referred: "Chuyển tuyến",
  deceased: "Đã mất",
};

/** Columns of the medical visit export: one row per visit. */
export const visitsExportColumns = (): ExportColumn<MedicalVisit>[] => [
  { header: "Mã lượt khám", value: (row) => row.code, width: 18 },
  { header: "Thời gian", value: (row) => row.checkedInAt ?? row.scheduledAt ?? row.createdAt, kind: "datetime", width: 18 },
  { header: "Thú cưng", value: (row) => row.petName, width: 18 },
  { header: "Loài", value: (row) => row.speciesName, width: 12 },
  { header: "Khách hàng", value: (row) => row.customerName, width: 24 },
  { header: "Số điện thoại", value: (row) => row.customerPhone },
  { header: "Bác sĩ", value: (row) => row.vetName, width: 20 },
  { header: "Lý do khám", value: (row) => row.reason, width: 28 },
  { header: "Chẩn đoán", value: (row) => row.diagnosesText, width: 28 },
  { header: "Kết luận", value: (row) => (row.outcome ? OUTCOME_TEXT[row.outcome] : null) },
  { header: "Tạm tính", value: (row) => row.estTotal, kind: "money" },
  { header: "Trạng thái", value: (row) => STATUS_TEXT[row.status] ?? row.status },
];
