import type { ExportColumn } from "@/lib/data-io/columns";
import type { PetService } from "@/repositories/petServices";

/** Columns of the service export (Excel and CSV). */
export const servicesExportColumns = (): ExportColumn<PetService>[] => [
  { header: "Tên dịch vụ", value: (row) => row.name, width: 28 },
  { header: "Mô tả", value: (row) => row.desc, width: 36 },
  { header: "Cách tính giá", value: (row) => (row.type === "by_weight" ? "Theo cân nặng" : "Giá chung"), width: 16 },
  { header: "Giá chung", value: (row) => row.generalPrice, kind: "money" },
  { header: "Thời lượng (phút)", value: (row) => row.duration[0], kind: "number" },
  { header: "Loài áp dụng", value: (row) => row.species.map((item) => item.name).join(", "), width: 22 },
  { header: "Hiển thị ở shop", value: (row) => row.isShow, kind: "flag" },
  { header: "Đang dùng", value: (row) => row.isActive, kind: "flag" },
];
