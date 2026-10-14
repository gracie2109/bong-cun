import { flagRepeats, readSheet, type CellValue } from "@/lib/data-io/importSchema";
import type { SheetTable } from "@/lib/data-io/readTable";
import { addProblem, type ParsedImport } from "@/lib/data-io/types";
import type { PetImportRow } from "./petsImportRow";
import { PET_COLUMNS } from "./petsImportSchema";

const str = (value: CellValue | undefined): string => (value === null || value === undefined ? "" : String(value));

const SEXES: Record<string, PetImportRow["sex"]> = {
  duc: "male",
  male: "male",
  cai: "female",
  female: "female",
  "khong ro": "unknown",
  unknown: "unknown",
};

const plain = (text: string): string =>
  text.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/gi, "d").toLowerCase().trim();

const MIN_PHONE_DIGITS = 8;
const MAX_PHONE_DIGITS = 15;

/** Reads the first sheet of a "Khách và thú cưng" file (Excel or CSV) into rows for `import_pets`. */
export const parsePets = (sheets: SheetTable[]): ParsedImport<PetImportRow> => {
  const sheet = sheets[0];
  const read = readSheet(sheet?.data ?? [], PET_COLUMNS);
  const problems = read.problems;
  const rows: PetImportRow[] = read.rows.map((item) => {
    const { values } = item;
    const sexText = str(values.sex);
    const sex = sexText ? SEXES[plain(sexText)] : "";
    if (sexText && sex === undefined) addProblem(problems, item.row, "Giới tính chỉ nhận Đực, Cái hoặc Không rõ");
    const digits = str(values.owner_phone).replace(/\D/g, "").length;
    if (str(values.owner_phone) && (digits < MIN_PHONE_DIGITS || digits > MAX_PHONE_DIGITS)) {
      addProblem(problems, item.row, "Số điện thoại chủ cần 8 đến 15 chữ số");
    }
    return {
      row: item.row,
      owner_phone: str(values.owner_phone),
      owner_name: str(values.owner_name),
      owner_email: str(values.owner_email),
      owner_note: str(values.owner_note),
      pet_name: str(values.pet_name),
      species: str(values.species),
      breed: str(values.breed),
      sex: sex ?? "",
      neutered: typeof values.neutered === "boolean" ? values.neutered : null,
      birth_date: typeof values.birth_date === "string" ? values.birth_date : null,
      microchip: str(values.microchip),
      allergies: str(values.allergies),
      behavior_notes: str(values.behavior_notes),
    };
  });
  flagRepeats(read.rows, "microchip", "Microchip lặp lại trong file", problems);
  return { rows, problems, source: sheet?.data };
};
