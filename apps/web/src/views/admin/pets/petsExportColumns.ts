import type { ExportColumn } from "@/lib/data-io/columns";
import type { PetListItem, PetSex, PetStatus } from "@/repositories/pets";

const SEX_TEXT: Record<PetSex, string> = { male: "Đực", female: "Cái", unknown: "Không rõ" };
const STATUS_TEXT: Record<PetStatus, string> = { active: "Đang theo dõi", archived: "Đã lưu trữ", deceased: "Đã mất" };

/** Columns of the pet export; the headers match the "Khách và thú cưng" import template. */
export const petsExportColumns = (): ExportColumn<PetListItem>[] => [
  { header: "Số điện thoại chủ", value: (row) => row.ownerPhone, width: 18 },
  { header: "Tên chủ", value: (row) => row.ownerName, width: 24 },
  { header: "Tên thú cưng", value: (row) => row.name, width: 20 },
  { header: "Loài", value: (row) => row.speciesName },
  { header: "Giống", value: (row) => row.breed, width: 20 },
  { header: "Giới tính", value: (row) => SEX_TEXT[row.sex] },
  { header: "Đã triệt sản", value: (row) => row.neutered, kind: "flag" },
  { header: "Ngày sinh", value: (row) => row.birthDate, kind: "date" },
  { header: "Cân nặng (kg)", value: (row) => row.weightKg, kind: "number" },
  { header: "Nhóm cân nặng", value: (row) => row.bracketLabel },
  { header: "Dị ứng", value: (row) => row.allergies, width: 24 },
  { header: "Lưu ý hành vi", value: (row) => row.behaviorNotes, width: 24 },
  { header: "Trạng thái", value: (row) => STATUS_TEXT[row.status] },
];
