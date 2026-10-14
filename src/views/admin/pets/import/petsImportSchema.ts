import type { ImportColumn } from "@/lib/data-io/importSchema";

/** Columns of the "Khách và thú cưng" file; order in the file does not matter. */
export const PET_COLUMNS: ImportColumn[] = [
  { key: "owner_phone", header: "Số điện thoại chủ", aliases: ["SĐT", "Số điện thoại", "Phone"], required: true },
  { key: "owner_name", header: "Tên chủ", aliases: ["Tên khách"] },
  { key: "owner_email", header: "Email" },
  { key: "owner_note", header: "Ghi chú khách" },
  { key: "pet_name", header: "Tên thú cưng", aliases: ["Tên pet"] },
  { key: "species", header: "Loài" },
  { key: "breed", header: "Giống" },
  { key: "sex", header: "Giới tính" },
  { key: "neutered", header: "Đã triệt sản", kind: "flag", emptyAsNull: true },
  { key: "birth_date", header: "Ngày sinh", kind: "date" },
  { key: "microchip", header: "Microchip" },
  { key: "allergies", header: "Dị ứng" },
  { key: "behavior_notes", header: "Lưu ý hành vi", aliases: ["Hành vi"] },
];

export const PETS_TEMPLATE_BASE = "mau-nhap-khach-thu-cung";

/** Example rows of the template, in the order of PET_COLUMNS. */
export const PETS_TEMPLATE_SAMPLES: (string | number)[][] = [
  ["0901234567", "Nguyễn An", "an@example.com", "Khách quen", "Bông", "Chó", "Poodle", "Đực", "Có", "15/03/2023", "", "Dị ứng gà", ""],
  ["0901234567", "", "", "", "Mướp", "Mèo", "Anh lông ngắn", "Cái", "Không", "", "985112000123456", "", "Hay cắn khi tắm"],
  ["0987654321", "Trần Bình", "", "", "", "", "", "", "", "", "", "", ""],
];
