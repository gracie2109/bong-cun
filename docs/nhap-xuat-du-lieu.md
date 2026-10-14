# Nhập/xuất dữ liệu ở admin (PDF, Excel, CSV)

Kế hoạch ngày 14/10/2026. Đề xuất của chị: xuất PDF, Excel, CSV; nhập cũng PDF, Excel, CSV. Dự án là pet project cá nhân, nên ưu tiên đơn giản, thư viện miễn phí, không thêm dịch vụ ngoài. Module sản phẩm đã có nhập/xuất Excel (PR #70, [module-san-pham.md](module-san-pham.md) mục 3.5, 5.3, 6.7); kế hoạch này tổng quát hoá phần đó thành bộ dùng chung, không làm lại.

**Tiến độ:** kế hoạch tự duyệt; các câu hỏi mở đã chọn mặc định ở mục 10. Đã làm đủ 6 bước (mục 12).

## 1. Kết luận ngắn

**Có nên làm không?** Có, nhưng không làm đều cho mọi màn:

- **Xuất: làm cho gần như mọi bảng.** Rẻ (chạy ở trình duyệt, dùng lại API danh sách đã có), hữu ích thật: gửi kế toán, lưu trữ, in danh sách, đối chiếu. Một nút "Tải xuống" dùng chung trên thanh công cụ bảng (đúng như ảnh chị gửi) với 3 lựa chọn **Excel, CSV, PDF**.
- **Nhập: chỉ cho dữ liệu gốc (master data)**: sản phẩm (đã có), khách hàng kèm thú cưng, nhà cung cấp, và tồn đầu kỳ qua phiếu nhập kho nháp. **Không** nhập hoá đơn, ca thu ngân, lịch spa, đơn online, phiếu kho đã ghi sổ hay báo cáo: các dữ liệu này phải đi qua luồng nghiệp vụ (chốt giá trong DB, trừ kho FEFO, ca mở/đóng, mã chứng từ theo cơ sở), nhập từ file sẽ phá các quy tắc đó.
- **Nhập: Excel (.xlsx) và CSV. Không nhập PDF.** PDF là định dạng để in/xem, không có cấu trúc bảng: đọc lại cần nhận dạng vị trí chữ hoặc OCR, sai cột là chuyện thường, thư viện nặng, lỗi khó báo theo dòng. Mặc định: người dùng tải **file mẫu Excel**, điền rồi nhập; CSV cho ai xuất từ phần mềm khác.
- **PDF xuất bằng chức năng in của trình duyệt** (trang HTML trong iframe ẩn, giống in hoá đơn POS đã làm ở `receipt.ts`), người dùng chọn "Lưu thành PDF". Không thêm thư viện, tiếng Việt hiển thị đúng vì dùng font web Be Vietnam Pro, trên iPad dùng "In → Chia sẻ → Lưu vào Tệp". Đánh đổi: không ra file ngay bằng một chạm; nếu sau này cần file trực tiếp thì thêm `pdfmake` (mục 9, Could).

## 2. Màn nào làm gì

| Màn | Xuất | Nhập | Ghi chú |
| --- | --- | --- | --- |
| Sản phẩm | Excel (đã có, cùng mẫu nhập), CSV, PDF bảng giá | Excel (đã có) + CSV (chỉ sheet sản phẩm) | Chuyển sang bộ dùng chung, giữ nguyên mẫu file |
| Thú cưng (kèm chủ) | Excel, CSV, PDF | **Có**: một file "Khách và thú cưng" | Khoá khách = số điện thoại; khoá thú cưng = microchip hoặc (chủ + tên) |
| Khách hàng (tài khoản web) | Excel, CSV, PDF | Không | Khách vãng lai nhập qua file thú cưng (dòng không có tên thú cưng = chỉ tạo khách) |
| Tồn kho | Excel, CSV, PDF (phiếu kiểm kê để in) | **Có (Should)**: dòng phiếu nhập nháp | File chỉ điền dòng vào phiếu nháp; tồn chỉ đổi khi bấm Ghi sổ như cũ |
| Phiếu kho | Excel, CSV | Không | In một phiếu là Could |
| Nhà cung cấp | Excel, CSV | **Có** | Khoá = mã số thuế, không có thì tên |
| Hoá đơn | Excel, CSV, PDF | Không | Một dòng một hoá đơn; chi tiết dòng hàng đã có ở báo cáo mặt hàng |
| Ca thu ngân | Excel, CSV, PDF | Không | |
| Lịch spa (danh sách lịch hẹn) | Excel, CSV, PDF | Không | PDF lịch trong ngày để dán ở quầy |
| Đơn online | Excel, CSV, PDF | Không | |
| Báo cáo (5 tab) | CSV (đã có) + Excel + PDF | Không | Thay `ExportButton` CSV bằng menu chung |
| Dịch vụ, bảng giá dịch vụ, combo | Excel, CSV | Không (Could: nhập bảng giá) | |
| Nhân viên, vai trò, phân quyền, cài đặt | Không | Không | Dữ liệu nhạy cảm, ít dòng |

## 3. Quy tắc chung

### 3.1 Xuất

- Xuất **đúng bộ lọc đang chọn** trên màn (tìm kiếm, cơ sở, trạng thái, khoảng ngày), không chỉ trang đang xem. Client gọi lại đúng hàm danh sách của màn đó theo từng trang 500 dòng cho tới hết.
- Giới hạn: Excel/CSV tối đa **10.000 dòng**, PDF tối đa **1.000 dòng** (in hơn thế không ai đọc). Vượt giới hạn thì vẫn xuất phần đầu và hiện toast cảnh báo "Chỉ xuất 10.000 dòng đầu, hãy lọc hẹp hơn". Báo cáo giữ `EXPORT_LIMIT = 5000` như hiện tại.
- Có thanh tiến độ trong menu khi đang tải nhiều trang ("Đang lấy 1.500 / 4.200 dòng"), nút bị khoá tới khi xong.
- Cột xuất do từng màn định nghĩa (không phải chụp nguyên bảng HTML): tên cột tiếng Việt, tiền là số (Excel định dạng `#,##0`), ngày là ngày thật (Excel `dd/mm/yyyy`, PDF/CSV theo `vi-VN`), cờ là "Có"/"Không".
- Tên file: `<tên-màn>-<yyyymmdd-hhmm>.<đuôi>`, không dấu, ví dụ `hoa-don-20261014-0910.xlsx`. Báo cáo giữ tên cũ `bao-cao-<tab>-<từ>-<đến>`.
- CSV: UTF-8 có BOM, CRLF, dấu phẩy (như `lib/csv.ts` hiện tại). **Chống chèn công thức**: ô chữ bắt đầu bằng `=`, `+`, `-`, `@`, tab hoặc CR thì thêm `'` ở đầu (tên khách do người ngoài gõ trên shop). Excel dùng ô kiểu chuỗi nên không cần.
- PDF: A4, khổ ngang nếu quá 6 cột; đầu trang có tên màn, cơ sở, bộ lọc tóm tắt, thời điểm xuất, người xuất; cuối có tổng số dòng (và tổng tiền nếu màn có cột tiền).

### 3.2 Nhập

Giữ đúng quy trình sản phẩm đã chạy tốt, áp cho mọi màn có nhập:

1. Tải **file mẫu** (Excel có dòng tiêu đề + 2 đến 3 dòng ví dụ; CSV mẫu cùng cột).
2. Chọn file `.xlsx` hoặc `.csv`, đọc ở trình duyệt (thư viện tải lười).
3. **Ghép cột theo tên tiêu đề**, không theo vị trí: bỏ dấu, không phân biệt hoa thường, chấp nhận vài tên khác (ví dụ "SĐT", "Số điện thoại", "Phone"). Cột thừa bị bỏ qua, thiếu cột bắt buộc thì báo lỗi cả file. (Sản phẩm giữ đọc theo vị trí cho tới khi chuyển ở bước 3, khi chuyển thì đọc theo tên, cùng tiêu đề như mẫu cũ, nên file cũ vẫn nhập được.)
4. Kiểm tra ở client: kiểu số, ngày, cờ Có/Không, giá trị trong danh sách, trùng khoá trong file. Lỗi ghi theo **số dòng trong file**.
5. Gửi lô **200 dòng** cho RPC với `p_dry_run = true` (không ghi gì), RPC trả từng dòng: `create` / `update` / `skip` và danh sách lỗi tiếng Việt ngắn.
6. Màn xem trước: tổng ("120 dòng: 100 tạo, 15 cập nhật, 5 lỗi"), bảng phân trang ở client, lọc "Chỉ dòng lỗi", nút **Tải file lỗi** (file Excel gồm các dòng lỗi + cột "Lỗi" để sửa rồi nhập lại).
7. Không còn lỗi mới bấm **Nhập**: gửi lại cùng dữ liệu với `p_dry_run = false`, mỗi lô một giao dịch. Lô hỏng thì cả lô không ghi, UI báo lô nào; nhập lại an toàn vì theo khoá.

Quy tắc dữ liệu:

- **Nhập không bao giờ xoá**, không bao giờ xoá trắng một trường: ô trống trong file = giữ giá trị cũ.
- Tối đa **2.000 dòng** mỗi file (như sản phẩm).
- Ngày nhận `dd/mm/yyyy`, `yyyy-mm-dd` hoặc ô ngày của Excel. Số nhận dấu chấm hoặc phẩy thập phân, không đoán dấu phân cách hàng nghìn (như `parseRows.ts`).
- CSV: tự nhận dấu phân cách `,` hoặc `;` (Excel tiếng Việt trên Windows hay lưu bằng `;`) theo dòng tiêu đề. Mã hoá: thử UTF-8 (có hoặc không BOM) với `TextDecoder("utf-8", { fatal: true })`, lỗi thì đọc bằng `windows-1258` rồi `windows-1252`.

## 4. Quyền

Hệ thống quyền đã có sẵn method `IMPORT` và `EXPORT` (`role_permissions.methods`, `METHODS` trong `rbac.ts`), `reports` đã dùng `EXPORT`. Dùng luôn, không tạo mã quyền mới:

| Việc | Quyền | Kiểm tra ở đâu |
| --- | --- | --- |
| Xuất ở một màn | `<mã quyền của màn>: EXPORT` | Ẩn nút ở UI (`auth.can(perm, 'EXPORT')`). Dữ liệu vẫn đọc qua RLS/RPC như màn đó, nên đây là chặn ở giao diện; người có VIEW vẫn đọc được từng trang |
| Nhập sản phẩm | `products: IMPORT` **hoặc** (`CREATE` và `UPDATE`) | Trong RPC `import_products` (giữ điều kiện cũ để vai trò đang có không bị mất quyền) |
| Nhập khách và thú cưng | `pets: IMPORT` | Trong RPC `import_pets` |
| Nhập nhà cung cấp | `inventory: IMPORT` | Trong RPC `import_suppliers` |
| Điền phiếu nhập từ file | `inventory: CREATE` (như tạo phiếu) | Không có RPC ghi mới; lưu nháp qua `save_stock_document` như cũ |

Mã quyền theo màn: thú cưng và khách hàng `pets` / `users` (theo `ADMIN_ROUTE_PERMISSIONS`), hoá đơn và ca `pos`, tồn kho, phiếu, nhà cung cấp `inventory`, lịch spa `schedule`, đơn online `shop_orders`, dịch vụ `petServices`, báo cáo `reports`.

Các mã `users`, `pets`, `petServices`, `schedule` (trong `supabase/seed.sql`) và `products` đã có đủ `IMPORT`/`EXPORT`; `pos`, `reports` có `EXPORT`. Còn thiếu: `shop_orders` (`EXPORT`) và `inventory` (`IMPORT`). Migration bước 1 thêm hai method này vào `permissions.methods`, viết kiểu hợp mảng không trùng, chạy lại được; nhân tiện kiểm mọi mã quyền của mục 2 đều có `EXPORT` (thêm nếu thiếu). Không cấp thêm cho vai trò nào: admin có `ALL`, vai trò khác do superAdmin tick ở màn phân quyền.

## 5. Kiến trúc dùng chung

### 5.1 Xuất (toàn bộ ở client)

```ts
// src/lib/data-io/columns.ts
export type CellKind = "text" | "number" | "money" | "date" | "datetime" | "flag";
export type ExportColumn<T> = {
  header: string;                      // tiêu đề tiếng Việt
  value: (row: T) => string | number | boolean | Date | null | undefined;
  kind?: CellKind;                     // mặc định text
  width?: number;                      // độ rộng cột Excel (ký tự)
};
export type ExportFormat = "xlsx" | "csv" | "pdf";
```

- `CsvColumn<T>` trong `lib/csv.ts` trở thành bí danh của `ExportColumn<T>` (cột báo cáo đang có dùng được ngay, không phải viết lại).
- `writeCsv(rows, columns)`: dùng lại `toCsv`, thêm chống chèn công thức và định dạng theo `kind`.
- `writeXlsx(rows, columns, sheetName)`: `write-excel-file/browser` (đã có trong `package.json`), import động. Dòng tiêu đề đậm, cố định dòng đầu (`stickyRowsCount: 1`), `format` theo `kind`, `width` theo cột.
- `printTable({ title, meta, columns, rows, totals? })`: dựng HTML bảng rồi in qua iframe ẩn. Tách hàm in iframe ở `receipt.ts` ra `lib/print.ts` (`printHtml(html)`), hoá đơn POS và bảng PDF dùng chung. HTML có thẻ `<link>` Google Fonts Be Vietnam Pro, `@page { size: A4 landscape; margin: 10mm }`, `thead { display: table-header-group }` để lặp tiêu đề mỗi trang.
- `fetchAllPages(fetchPage, { pageSize: 500, cap, onProgress })`: gọi lần lượt tới khi đủ `total` hoặc chạm `cap`; trả `{ rows, total, truncated }`.
- Composable `useTableExport({ name, permission, columns, fetchPage, pdf? })` trả `{ canExport, exporting, progress, run(format) }`; báo lỗi và cảnh báo cắt dòng bằng toast (giống `useReportExport`).
- Component `ExportMenu.vue`: nút icon tải xuống (như ảnh), mở popover 3 mục **PDF / Excel / CSV** có icon; màn nào không có PDF thì ẩn mục đó. Đặt ở cạnh phải thanh lọc của màn (cùng hàng với bộ lọc và nút cột). Không đặt trong `PagedTableCard` để thẻ bảng vẫn chỉ lo bảng và phân trang; mỗi màn truyền `useTableExport` vào `ExportMenu`.

Hàm danh sách hiện có đều nhận `(filter, page)` và trả `Page<T>` (`rows`, `total`), nên `fetchPage` chỉ là bọc lại: `(pageIndex) => listInvoices(client, filter.value, { pageIndex, pageSize: 500 })`. Nếu một hàm danh sách giới hạn `page_size` nhỏ hơn 500 ở RPC (xem `report_limit`), dùng đúng giới hạn đó.

### 5.2 Nhập (đọc ở client, ghi bằng RPC)

Tổng quát hoá từ `src/views/admin/products/import/`:

| Hiện có (sản phẩm) | Bản dùng chung |
| --- | --- |
| `useProductImport.ts` | `composables/useTableImport.ts`: pha `idle → reading → checking → checked → importing → done`, tiến độ, chạy thử rồi nhập thật, nhận `schema` và `send(rows, dryRun)` |
| `batches.ts` | `lib/data-io/batches.ts`: `batchRows(rows, size, keyOf?)` (giữ các dòng cùng khoá đi chung lô, như nhóm sản phẩm), `mergeReports` chung |
| `parseRows.ts` (`text`, `toNumber`, `toFlag`) | `lib/data-io/cells.ts`: các hàm đọc ô + `toDate`, `toChoice` |
| (theo vị trí cột) | `lib/data-io/importSchema.ts`: `ImportColumn = { key, header, aliases?, required?, kind, choices? }`, `mapHeaders`, `parseTable(sheet, schema) → { rows, problems }` |
| `read-excel-file` trong `loadFile` | `lib/data-io/readTable.ts`: `.xlsx` qua `read-excel-file/browser`, `.csv` qua `parseCsv` tự viết (~60 dòng, RFC 4180, có ngoặc kép, xuống dòng trong ô) + nhận mã hoá và dấu phân cách |
| `ImportDropzone`, `ImportPreviewTable`, `ImportSummary` | `components/common/data-io/` cùng tên, nhận cột xem trước qua props |
| `importTemplate.ts` | Mỗi màn có `xxxImportSchema.ts`; file mẫu sinh từ schema (`templateSheets(schema, samples)`) |

Kết quả RPC thống nhất (sản phẩm đã gần như vậy):

```ts
type ImportRowResult = { row: string; action: "create" | "update" | "skip"; errors: string[] };
type ImportReport = { ok: boolean; created: number; updated: number; rows: ImportRowResult[]; extra?: Record<string, unknown> };
```

`ImportReport` của sản phẩm giữ các trường riêng (`created_groups`, `new_categories`...) trong `extra` phía client bằng một hàm chuyển, không đổi RPC đã chạy.

Giao diện nhập: nút **Nhập** (icon upload) cạnh `ExportMenu`, chỉ hiện khi có quyền nhập, mở `ImportDialog.vue` (dùng `AppDialog`, rộng `max-w-5xl`): khối 1 "Tải file mẫu (Excel / CSV)", khối 2 ô kéo-thả, khối 3 tổng + bảng xem trước + "Tải file lỗi", chân hộp thoại "Nhập N dòng". Sản phẩm giữ trang riêng `/admin/products/import` nhưng ráp từ cùng component.

### 5.3 Vì sao không xử lý file ở server

Không có backend riêng (Nuxt + Supabase, ưu tiên RPC hơn edge function). Đọc/ghi file ở trình duyệt không tốn tài nguyên server, thư viện đã có sẵn, 10.000 dòng Excel vẫn nhanh. RPC chỉ nhận JSON đã chuẩn hoá, kiểm tra quyền và ràng buộc, ghi trong giao dịch. Edge function chỉ cân nhắc nếu sau này cần xuất định kỳ gửi email.

## 6. Database

### 6.1 Migration

| File | Bước | Nội dung |
| --- | --- | --- |
| `20261017010000_data_io_permissions.sql` | 1 | Thêm `EXPORT` cho `shop_orders`, `IMPORT` cho `inventory` (mục 4) |
| `20261017030000_import_products_permission.sql` | 3 | `create or replace import_products` sao chép nguyên văn bản mới nhất (`20261015050200_import_products.sql`), chỉ đổi điều kiện quyền thành `can_products('IMPORT') or (can_products('CREATE') and can_products('UPDATE'))` |
| `20261017040000_import_pets.sql` | 4 | Hàm `import_pets` |
| `20261017050000_import_suppliers.sql` | 5 | Hàm `import_suppliers` |
| `20261017060000_find_products_by_sku.sql` | 6 | Hàm đọc `find_products_by_sku(p_skus text[])` |

Tất cả: chỉ tiến, chạy lại được (`create or replace`, `if not exists`), không sửa file cũ, cuối file `notify pgrst, 'reload schema';`, `security definer` + `set search_path = ''`, `revoke ... from public, anon`, `grant ... to authenticated`, kiểm tra quyền ở đầu hàm (mã lỗi `42501`), `p_rows` tối đa 500 phần tử (mã `22023`), như `import_products`. Workflow "Supabase migrate" tự chạy khi merge. Sau mỗi bước có hàm mới, cập nhật `src/types/database.types.ts` bằng tay như các PR trước.

### 6.2 `import_pets(p_rows jsonb, p_dry_run boolean) returns jsonb`

Mỗi dòng (client đã đổi tiêu đề sang khoá):

| Khoá | Tiêu đề mẫu | Bắt buộc | Quy tắc |
| --- | --- | --- | --- |
| `owner_phone` | Số điện thoại chủ | Có | 8 đến 15 chữ số sau khi bỏ ký tự khác; khoá tìm khách theo `phone_digits` |
| `owner_name` | Tên chủ | Khi tạo khách mới | |
| `owner_email`, `owner_note` | Email, Ghi chú khách | | |
| `pet_name` | Tên thú cưng | | Trống = dòng chỉ tạo/cập nhật khách |
| `species` | Loài | Khi có `pet_name` | So tên loài đã có (bỏ dấu, không phân biệt hoa thường). Không tự tạo loài (loài gắn khung cân nặng và bảng giá) → lỗi "Loài chưa có: ..." |
| `breed` | Giống | | |
| `sex` | Giới tính | | Đực / Cái / Không rõ (mặc định Không rõ) |
| `neutered` | Đã triệt sản | | Có / Không |
| `birth_date` | Ngày sinh | | Không ở tương lai |
| `microchip` | Microchip | | Duy nhất; nếu có thì là khoá thú cưng |
| `allergies`, `behavior_notes` | Dị ứng, Lưu ý hành vi | | |

Ghép bản ghi:

1. Khách: tìm theo `phone_digits`. Có → cập nhật các ô không trống (tên, email, ghi chú). Chưa có → tạo (cần tên).
2. Thú cưng: có `microchip` → tìm theo microchip; không có → tìm theo (khách chủ chính, `lower(btrim(name))`). Có → cập nhật ô không trống; chưa có → tạo và gắn `pet_owners` vai trò `primary`. Microchip đã thuộc thú cưng của khách khác → lỗi, không chuyển chủ qua file.
3. Không đổi `status`, cân nặng, ảnh qua file.

Trả `{ ok, created, updated, rows, extra: { created_customers, updated_customers } }`. Dòng có lỗi → `skip`; `p_dry_run = false` mà còn dòng lỗi → `raise` mã `22023` hint `import_invalid`, cả lô không ghi. Dùng lại cách viết của `import_products` (`import_add_error`, `import_error_text`).

### 6.3 `import_suppliers(p_rows jsonb, p_dry_run boolean) returns jsonb`

Cột: Tên (bắt buộc), Điện thoại, Email, Địa chỉ, Mã số thuế, Ghi chú, Đang dùng (Có/Không). Khoá: `tax_code` nếu có, không thì `lower(btrim(name))`. Cùng cách trả kết quả. Quyền `inventory: IMPORT`.

### 6.4 `find_products_by_sku(p_skus text[]) returns table (...)`

Đọc, tối đa 2.000 SKU: trả `sku, product_id, name, track_stock, units (id, name, factor, for_purchase)`. Quyền `can_inventory('CREATE')`. Dùng cho "Điền phiếu nhập từ file": file có cột SKU, Số lượng, Đơn vị (tuỳ chọn, phải là đơn vị nhập được), Giá nhập, Số lô, Hạn dùng. Client đổi SKU thành dòng phiếu, SKU không có hoặc đơn vị sai → báo lỗi dòng; dòng hợp lệ được thêm vào phiếu nhập **nháp** đang mở. Người dùng xem lại rồi bấm Lưu / Ghi sổ như cũ, `save_stock_document` không đổi.

## 7. Giao diện và cấu trúc file

```
src/lib/data-io/
  columns.ts           ~40   ExportColumn, CellKind, ExportFormat
  cells.ts             ~90   đọc ô: text, number, flag, date, choice (chuyển từ parseRows.ts)
  formatCell.ts        ~60   định dạng giá trị theo kind cho CSV/PDF
  csvWrite.ts          ~50   toCsv + chống chèn công thức (lib/csv.ts re-export để import cũ không đổi)
  csvRead.ts           ~90   parseCsv, nhận dấu phân cách, giải mã UTF-8 / windows-1258
  xlsxWrite.ts         ~60   write-excel-file lười, format theo kind
  readTable.ts         ~50   .xlsx / .csv → mảng dòng
  printTable.ts        ~110  HTML bảng PDF
  fetchAllPages.ts     ~40
  importSchema.ts      ~120  ImportColumn, mapHeaders, parseTable, templateSheets
  batches.ts           ~50   batchRows, mergeReports (chuyển từ products/import/batches.ts)
  fileName.ts          ~20   slug + thời điểm
  types.ts             ~40   ImportRowResult, ImportReport
src/lib/print.ts       ~35   printHtml (tách từ pos/receipt.ts)
src/composables/
  useTableExport.ts    ~90
  useTableImport.ts    ~120  (tổng quát từ useProductImport.ts)
src/components/common/data-io/
  ExportMenu.vue       ~80   nút + popover PDF/Excel/CSV + tiến độ
  ImportButton.vue     ~40
  ImportDialog.vue     ~120  vỏ AppDialog ráp 3 khối
  ImportDropzone.vue   ~50   (chuyển từ products/import)
  ImportPreviewTable.vue ~90 (nhận cột qua props)
  ImportSummary.vue    ~40
  TemplateDownload.vue ~40
src/views/admin/<màn>/
  <màn>ExportColumns.ts ~40-80  cột xuất của màn
  <màn>ImportSchema.ts  ~60     schema + dòng ví dụ (màn có nhập)
src/repositories/dataImports.ts ~60  importPets, importSuppliers, findProductsBySku
src/queries/dataImports.ts      ~50  mutation có toast lỗi
```

Mỗi file dưới 300 dòng; trang là vỏ mỏng. Màn danh sách chỉ thêm 1 đến 2 dòng template (`<ExportMenu :export="exporter" />`, `<ImportButton ... />`) và 1 dòng gọi `useTableExport` trong composable danh sách sẵn có của màn (ví dụ `useCustomersList`, `usePetsFilters`).

i18n: khoá `dataIo.*` (nút, định dạng, tiến độ, cảnh báo cắt dòng, lỗi đọc file, tổng nhập, tải file lỗi) và `<màn>.export.*`, `<màn>.import.*` cho tiêu đề cột, ở cả `vi` và `en`. Tiêu đề cột trong file luôn tiếng Việt (file mẫu cố định), không theo ngôn ngữ giao diện, để file xuất ra nhập lại được.

Không thêm thư viện mới: `read-excel-file`, `write-excel-file` đã có, PDF dùng trình duyệt, CSV tự viết.

## 8. Thứ tự làm (cho thread code)

Mỗi bước một PR nhỏ, squash merge, commit tiếng Anh.

| Bước | Nội dung | Migration | Kiểm tra chính |
| --- | --- | --- | --- |
| 1 | Lõi xuất: `lib/data-io` phần xuất, `lib/print.ts` (POS receipt dùng lại), `useTableExport`, `ExportMenu`; quyền `EXPORT`; thay nút CSV ở 5 tab báo cáo bằng menu (Excel/CSV/PDF) | `20261017010000` | Báo cáo xuất đủ 3 định dạng, tiếng Việt đúng trong Excel/CSV/PDF; in hoá đơn POS vẫn chạy |
| 2 | Xuất ở các màn POS và kho: hoá đơn, ca thu ngân, tồn kho (PDF phiếu kiểm kê), phiếu kho, nhà cung cấp | không | Xuất theo bộ lọc, quá 10.000 dòng có cảnh báo |
| 3 | Lõi nhập: `readTable` (xlsx + csv), `importSchema`, `useTableImport`, `components/common/data-io`; chuyển trang nhập sản phẩm sang bộ chung, nhận CSV; quyền `products: IMPORT`; xuất sản phẩm thêm CSV và PDF bảng giá | `20261017030000` | File Excel cũ (mẫu PR #70) nhập ra kết quả y như trước; CSV `;` và CSV Windows-1258 đọc đúng |
| 4 | Xuất màn thú cưng, khách hàng, lịch spa, đơn online, dịch vụ; nhập "Khách và thú cưng" ở màn thú cưng | `20261017040000` | Mục 9, ca 4 đến 7 |
| 5 | Nhập nhà cung cấp | `20261017050000` | |
| 6 | (Should) Điền phiếu nhập kho từ file | `20261017060000` | Phiếu vẫn là nháp, tồn chỉ đổi khi Ghi sổ |

Bước 1 trước vì báo cáo đã có xuất CSV, thay vào đó là cách nhanh nhất để kiểm lõi xuất trên dữ liệu thật. Bước 3 tách lõi nhập bằng cách chuyển sản phẩm (đã có test tay) trước khi thêm màn mới.

## 9. Kịch bản kiểm tra

1. Báo cáo doanh thu: xuất Excel, mở bằng Excel và Numbers (iPad): tiền là số có phân cách nghìn, ngày là ngày, tiêu đề đậm và cố định.
2. Xuất CSV một khách có tên `=HYPERLINK(...)` → ô hiện nguyên chữ, không thành công thức.
3. Xuất PDF hoá đơn 50 dòng → tiêu đề lặp mỗi trang, chữ có dấu đúng, có tổng tiền. Trên iPad Safari lưu được thành PDF.
4. Nhập file thú cưng 30 dòng (3 lỗi: thiếu số điện thoại, loài chưa có, microchip trùng trong file) → xem trước đúng 3 lỗi, không ghi gì; "Tải file lỗi" ra 3 dòng có cột Lỗi.
5. Sửa file, nhập → tạo đủ khách và thú cưng; nhập lại lần nữa → toàn bộ "cập nhật", dữ liệu không đổi.
6. Hai dòng cùng số điện thoại, khác tên thú cưng → một khách, hai thú cưng.
7. File có ô "Ghi chú khách" trống cho khách đã có ghi chú → ghi chú cũ giữ nguyên.
8. Người có `pets: VIEW` nhưng không có `IMPORT` → không thấy nút Nhập; gọi thẳng `import_pets` → `42501`. Không có `EXPORT` → không thấy nút tải xuống.
9. Vai trò đang có `products: CREATE, UPDATE` (chưa tick IMPORT) vẫn nhập sản phẩm được như trước.
10. File CSV lưu từ Excel tiếng Việt (dấu `;`, mã Windows-1258) nhập không lỗi phông.
11. File 2.500 dòng → báo lỗi cả file, không gửi gì.
12. Điền phiếu nhập từ file 20 dòng có 1 SKU sai → 19 dòng vào phiếu nháp, 1 dòng báo lỗi; tồn không đổi tới khi Ghi sổ.

## 10. Mặc định đã chọn cho câu hỏi mở

| Câu hỏi | Chọn | Lý do |
| --- | --- | --- |
| Có nhập PDF? | Không | PDF không có cấu trúc bảng; dùng file mẫu Excel/CSV |
| PDF xuất bằng gì? | In trình duyệt (iframe) | Không thêm thư viện, font tiếng Việt sẵn; `pdfmake` để sau nếu cần file trực tiếp |
| Nhập hoá đơn, lịch, đơn online? | Không | Phải qua luồng nghiệp vụ (giá, kho, ca, mã chứng từ) |
| Nhập tồn kho? | Chỉ điền phiếu nhập nháp | Tồn chỉ đổi qua phiếu kho (quy tắc đã chốt) |
| Nhập khách hàng riêng? | Gộp vào file "Khách và thú cưng" | Một file, một RPC; màn Khách hàng chỉ liệt kê tài khoản web |
| Xuất trang hiện tại hay toàn bộ? | Toàn bộ theo bộ lọc, có giới hạn | Đó là điều người dùng cần khi bấm tải |
| Quyền | Method `EXPORT`/`IMPORT` sẵn có | Không cần mã quyền mới, chỉnh ở màn phân quyền |
| Xử lý ở đâu? | Đọc/ghi file ở client, ghi DB qua RPC | Không có backend riêng, chi phí 0 |
| Ghép cột nhập | Theo tên tiêu đề | File đổi thứ tự cột vẫn nhập được |
| Nút đặt ở đâu? | Thanh lọc của màn, không trong `PagedTableCard` | Thẻ bảng chỉ lo bảng và phân trang |
| Lịch sử các lần nhập/xuất | Chưa làm (Could) | `product_imports` đã có cho sản phẩm |

## 11. Rủi ro

| Rủi ro | Cách giảm |
| --- | --- |
| Xuất nhiều dòng làm chậm trình duyệt hoặc tốn truy vấn | Trang 500 dòng, giới hạn 10.000 / 1.000, nút khoá khi đang chạy |
| Lộ danh sách số điện thoại khách | Nút xuất theo quyền `EXPORT`, mặc định chỉ admin có; dữ liệu vẫn qua RLS như màn |
| Chèn công thức qua CSV | Thêm `'` trước ô chữ bắt đầu bằng `= + - @` |
| File CSV sai mã hoá, sai dấu phân cách | Tự nhận UTF-8 / Windows-1258 và `,` / `;` |
| Nhập ghi đè dữ liệu tốt bằng ô trống | Ô trống = giữ nguyên; không bao giờ xoá |
| PDF trình duyệt khác nhau giữa máy | CSS in đơn giản, font web + Arial dự phòng; kiểm trên Chrome và Safari iPad |
| Đổi lõi nhập làm hỏng nhập sản phẩm đang chạy | Bước 3 chạy lại đúng kịch bản 12 đến 14 của module sản phẩm trước khi merge |

## 12. Kết quả làm (14/10/2026)

| Bước | PR | Ghi chú |
| --- | --- | --- |
| 1 Lõi xuất + báo cáo | #82 (đã merge) | Migration `20261017010000` chỉ thêm method EXPORT/IMPORT còn thiếu vào mã quyền |
| 2 Xuất POS và kho | #83 | Hoá đơn, ca thu ngân, tồn kho (PDF là phiếu kiểm kê có cột trống), phiếu kho, nhà cung cấp |
| 3 Lõi nhập + sản phẩm | #83 | `readTable` (xlsx, csv `,` `;`, UTF-8 / Windows-1258), ghép cột theo tên, `useTableImport`, `components/common/data-io`; nhập sản phẩm nhận CSV, có "Tải file lỗi"; xuất sản phẩm thêm CSV và PDF bảng giá. Migration `20261017030000` (quyền `products: IMPORT`) |
| 4 Xuất thêm 5 màn + nhập khách và thú cưng | #83 | Thú cưng, khách hàng, lịch spa, đơn online, dịch vụ. `import_pets` (migration `20261017040000`). Nút Nhập nằm ở màn Thú cưng, cần `pets: IMPORT` |
| 5 Nhập nhà cung cấp | #83 | `import_suppliers` (migration `20261017050000`), cần `inventory: IMPORT` |
| 6 Điền phiếu nhập từ file | #83 | `find_products_by_sku` (migration `20261017060000`). Nút "Điền từ file" trong phiếu nhập nháp; dòng hợp lệ vào phiếu, dòng lỗi bị bỏ qua và liệt kê |

Khác với kế hoạch:

- `fetchPage` của lịch spa và đơn online dùng trang 100 dòng vì hai RPC giới hạn 100 (`useTableExport` có tuỳ chọn `pageSize`).
- Thú cưng đã có microchip mà file ghi cùng tên và microchip mới vẫn khớp theo (chủ, tên) nếu thú cưng đó chưa có microchip, để nhập lại không tạo trùng.
- Điền phiếu từ file cho phép nhập một phần (`allowPartial`): khác các màn nhập khác, một dòng lỗi không chặn cả file vì không ghi gì vào DB.
- Màn xuất thú cưng không có cột microchip và email chủ (view `pet_overview` không có hai trường đó).

Kiểm tra đã làm: typecheck và `nuxt build` qua ở mọi bước; hàm đọc/ghi CSV, so khớp cột, parse sản phẩm (so với bản cũ), khách và thú cưng, phiếu nhập chạy thử bằng Node; `import_pets`, `import_suppliers`, `find_products_by_sku` chạy thử trên Postgres cục bộ với bảng mô phỏng (đủ cột, khoá, ràng buộc liên quan; chưa chạy qua RLS thật). Chưa bấm thử trên trình duyệt: mở file Excel/Numbers, in PDF thật, kéo thả file, các nút theo quyền.
