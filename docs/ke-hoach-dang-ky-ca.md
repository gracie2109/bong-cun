# Kế hoạch: nhân viên tự đăng ký ca làm việc

Ngày: 2026-11-07. Trạng thái: plan đã duyệt (tự duyệt theo quy ước dự án), chờ thread coding làm theo các PR ở mục 11.

## 1. Tóm tắt

Module chấm công (`docs/ke-hoach-cham-cong.md`, PR #233–#240) đã có ca mẫu, lưới lịch ca tuần, vào/ra ca, nghỉ phép, bảng công. Hiện **chỉ quản lý xếp ca**. grace muốn nhân viên **tự đăng ký** ca mình muốn làm, quản lý **duyệt**, ca được duyệt **tự vào lịch ca tuần**.

Đợt này thêm ba phần, mỗi phần dùng được ngay khi xong:

1. **Lịch rảnh (availability)**: mỗi nhân viên khai mẫu lặp lại theo thứ trong tuần: "Thứ 3 bận cả ngày", "Thứ 7 thích làm 08:00–14:00". Không cần duyệt. Quản lý thấy khi xếp ca và khi duyệt.
2. **Đăng ký ca**: trang "Đăng ký ca" cho mọi nhân viên. Chọn tuần (trong cửa sổ đăng ký), tick các ô (ngày × ca mẫu), gửi. Mỗi ô thành một **đơn đăng ký ca** trạng thái "chờ duyệt".
3. **Duyệt đăng ký**: quản lý xem đăng ký ngay trên lưới lịch ca (ô viền đứt) và ở trang danh sách "Đăng ký ca" (lọc, chọn nhiều, duyệt/từ chối hàng loạt). Duyệt = tạo `shift_assignments` như khi quản lý tự xếp, nên chấm công, bảng công, "Ca của tôi" chạy luôn không cần sửa.

Tùy chọn (PR R7): **nhu cầu nhân sự** theo ca mẫu và thứ ("Ca sáng thứ 7 cần 3 người") để nhân viên thấy ca nào còn thiếu người và quản lý thấy độ phủ.

**SQL cần chạy**: ba migration mới `supabase/migrations/20261112010000_staff_availability.sql`, `20261112020000_shift_requests.sql`, `20261112030000_shift_request_review.sql` (+ `20261112040000_shift_staffing_needs.sql` nếu làm R7). Số mới hơn mọi migration đã chạy (mới nhất trên main hôm nay: `20261111010000_pet_overview_deceased_on.sql`). Workflow "Supabase migrate" tự chạy khi merge, grace không phải dán tay. Nếu có migration khác merge vào main với số lớn hơn trước khi PR của đợt này merge, **đổi số file của PR đó cho lớn hơn** (db push hỏng khi chạy lệch thứ tự).

**Không đổi** bảng hay hàm đã có của chấm công, trừ `shift_roster` (thêm hai khóa mới, giữ nguyên các khóa cũ) và `my_schedule` không đổi.

## 2. So sánh với các sản phẩm xếp ca bên ngoài

| Sản phẩm | Lịch rảnh | Nhân viên tự lấy/đăng ký ca | Duyệt | Ghi chú đáng học |
| --- | --- | --- | --- | --- |
| **Deputy** | Có (rảnh / bận, lặp lại). **Không cần duyệt**; quản lý vẫn xếp đè được. | "Open shifts": quản lý đăng ca trống, nhân viên nhận. | Hai kiểu: ai nhận trước được trước, hoặc "Open shifts with approval" (nhân viên bấm Request, quản lý chọn). | Cài đặt "người báo bận vẫn được gợi ý ca" (mặc định tắt). Có tiêu chí chọn: thâm niên, kỹ năng. |
| **When I Work** | "Availability preferences" (thích / không làm được), có thể tắt cho nhân viên. Quản lý xếp ngược sở thích được. | "OpenShifts", bật "Require pick up approval" thành **shift bidding**. | Quản lý thấy danh sách người xin **theo thứ tự xin**, chọn một người. | Khi gán ca hiện sở thích ngay dưới ô "Assign to". |
| **Sling (Toast)** | "Unavailability"; admin bật được "cần duyệt" cho thay đổi lịch bận. | "Available shifts": nhân viên "Apply". | Tùy cài đặt: tự duyệt hoặc chờ quản lý; quản lý xem tab "Pending approval". | Đổi ca chỉ trong 2 tuần quanh ca gốc. |
| **7shifts** | Availability, admin chọn có cần duyệt không (trạng thái Pending + email cho quản lý). | "Shift pool" / "Up for grabs": nhận ca người khác nhả. | "Require approval" cho nhận/đổi ca; quyền duyệt riêng. | Quyền duyệt tách khỏi quyền xếp lịch. |
| **Homebase** | Thay đổi lịch rảnh có thể cần duyệt (không vào bộ xếp lịch cho tới khi duyệt). | Đổi/nhận ca. | Theo cài đặt gói. | Khuyên đặt **hạn chót** cập nhật lịch rảnh trước khi công bố lịch. Bộ xếp lịch kiểm tra lịch rảnh ngay khi xếp. |
| **Fastwork (VN)** | — | **"Đăng ký ca"**: nhân viên đăng ký ca theo ca mẫu. | Quản lý **duyệt nhiều đăng ký cùng lúc** (cả chuỗi cửa hàng). | Gần nhất với nhu cầu của grace. |
| **Tanca (VN)** | — | Nhân viên đăng ký ca qua app; quản lý dựa vào đó xếp lịch. Có đổi ca. | Có (chi tiết không công khai). | Kèm chấm công GPS/Wifi/khuôn mặt (ngoài phạm vi). |
| **KiotViet / Sapo** | Không tìm thấy tính năng này trong tài liệu công khai. | — | — | POS bán lẻ, phần nhân sự rất mỏng. |

Nguồn: [Deputy: Open Shifts with Approval](https://deputy.com/blog/ensure-the-most-suitable-employee-fills-your-open-shift), [Deputy: shift bidding](https://www.deputy.com/blog/shift-bidding-how-to-let-your-team-choose-shifts), [Deputy help](https://help.deputy.com/hc/en-au/articles/4658282900111), [When I Work: Shift bidding](https://help.wheniwork.com/articles/shift-bidding), [When I Work: Filling an OpenShift](https://help.wheniwork.com/articles/filling-an-openshift-computer/), [Sling: Available shifts](https://support.getsling.com/en/articles/12824084-available-shifts-shift-swaps-and-shift-offers), [Sling: Unavailability](https://support.toasttab.com/en/article/Sling-by-Toast-Unavailability-and-Time-Off), [7shifts: Approve availability](https://kb.7shifts.com/hc/en-us/articles/4417519789587), [7shifts: Shift pool settings](https://kb.7shifts.com/hc/en-us/articles/33771308977555), [Homebase: Employee availability](https://www.joinhomebase.com/glossary/employee-availability), [Fastwork: duyệt nhiều đăng ký ca](https://help.fastwork.vn/fastwork-help-center/huong-dan-s-dung-chi-tiet/fastwork-hrm/faststore/thao-tac-nguoi-dung/cach-thuc-hien-duyet-dong-thoi-nhieu-dang-ky-ca-trong-quan-ly-chuoi), [Tanca (FPT Shop)](https://fptshop.com.vn/tin-tuc/giai-tri/tanca-io-cham-cong-xep-ca-177314).

**Rút ra cho Pawtiny** (một cửa hàng, ít nhân viên, nhiều bạn làm bán thời gian):

- Hai khái niệm khác nhau và sản phẩm nào cũng tách: **lịch rảnh** (thông tin, lặp lại, thường không duyệt) và **đăng ký/nhận ca cụ thể** (có duyệt). Làm cả hai, duyệt chỉ cho đăng ký ca.
- Kiểu Fastwork/Tanca (đăng ký theo **ca mẫu × ngày**) hợp hơn kiểu Deputy (quản lý phải đăng từng "ca trống" trước). Ca mẫu đã có sẵn, nên mọi ô (ngày × ca mẫu) coi như một "ca trống". R7 thêm số người cần để có cảm giác "ca trống còn mấy chỗ".
- **Hạn chót** (Homebase) và **cửa sổ đăng ký** là cần: quản lý cần chốt lịch trước khi tuần bắt đầu.
- **Duyệt hàng loạt** (Fastwork) và **xem ngay trên lưới** (When I Work hiện sở thích khi gán) là hai chỗ quản lý dùng nhiều nhất.
- Quản lý luôn **xếp đè** được lịch rảnh (Deputy, When I Work): hệ thống chỉ cảnh báo, không chặn.
- Không làm "ai nhận trước được trước" (tự duyệt) trong đợt này: grace muốn quản lý duyệt. Có thể thêm cờ tự duyệt sau (mục 13).

## 3. Hiện trạng (đã đọc code)

- Bảng `shift_templates` (ca mẫu theo chi nhánh, `is_active`), `shift_assignments` (ca đã xếp; `exclude using gist` chống trùng giờ trên mọi chi nhánh; `name`, giờ, nghỉ được chụp lúc gán), `attendance_settings`, `leave_requests`, `staff_branches`.
- Hàm dùng lại: `can_attendance(method, branch)` (branch null → false trừ admin), `is_branch_staff(branch)`, `attendance_branch_ids(branch, method)` (mở rộng null thành danh sách chi nhánh), `can_view_staff(user)`, `shift_start_at(date, time)`, `shift_end_at(date, start, end)`, `shift_minutes`, `shift_on_leave(user, start_at)`, `assignment_has_entry`, `roster_leaves`, `staff_display_name`.
- `assign_shift` trả `{id, warning?}`, lỗi `shift_overlap`, `not_branch_staff`, `not_found`. `copy_roster_week` trả `{copied, skipped}`: mẫu "làm được phần nào thì làm" sẽ dùng lại cho gửi và duyệt hàng loạt.
- `shift_roster(branch, from, to)` trả `{staff, templates, assignments, leaves}` (bản mới nhất ở migration `20261110030000`).
- Web: `features/admin/attendance/{roster,me,leave,settings,...}`, `queries/*.ts`, `AttendanceNav.vue` (tab có `method`, `null` = mọi nhân viên), badge sidebar trong `layouts/admin.vue` (`usePendingLeaveCount`), `ADMIN_ROUTE_PERMISSIONS` trong `packages/core/src/auth/access.ts`, core `packages/core/src/attendance/{types,errors,week,rules}.ts` + `contract/*`, supabase `packages/supabase/src/attendance/*` (`mappers.ts` đã 261 dòng nên mapper mới để file riêng).

## 4. Quyết định chính

| # | Câu hỏi | Chọn | Lý do |
| --- | --- | --- | --- |
| R-Q1 | Đăng ký theo gì? | **Ca mẫu × ngày**. Bản đầu không cho đăng ký giờ tùy chỉnh. | Giống Fastwork; giao diện tick ô đơn giản trên iPad/điện thoại; quản lý muốn giờ lạ thì tạo thêm ca mẫu. |
| R-Q2 | Lịch rảnh có cần duyệt? | **Không**. Chỉ là thông tin. Quản lý sửa giúp được. | Như Deputy. Ít bước, dự án nhỏ. Hệ thống chỉ cảnh báo khi xếp/duyệt trái lịch rảnh. |
| R-Q3 | Lịch rảnh lưu thế nào? | Mẫu lặp theo thứ (1..7), mỗi dòng: `unavailable` hoặc `preferred`, cả ngày hoặc khoảng giờ. Theo **người**, không theo chi nhánh. Bận một ngày cụ thể: không làm (không đăng ký ca ngày đó, hoặc xin nghỉ nếu đã có ca). | Một người là một người. Ngày lẻ đã có đơn nghỉ lo. |
| R-Q4 | Cửa sổ đăng ký | Theo chi nhánh: bật/tắt (mặc định **tắt**, bật ở Cài đặt), mở trước `weeks_ahead` tuần (mặc định 2), đóng lúc 00:00 giờ VN của ngày `close_days_before` ngày trước thứ Hai của tuần đó (mặc định 2 = đóng 00:00 thứ Bảy). Không đăng ký cho tuần đang chạy. | Như "hạn chót" của Homebase; quản lý có cuối tuần để duyệt. Mặc định tắt để không đổi gì khi merge. |
| R-Q5 | Giới hạn số ca | `max_shifts_per_week` (null = không giới hạn) tính trên đơn chờ duyệt + ca đã có trong tuần tại chi nhánh đó. | Tránh một người tick hết lưới. |
| R-Q6 | Gửi nhiều ô | Một lần gửi = nhiều đơn, mỗi ô một dòng. Ô lỗi bị bỏ qua và trả lý do (`skipped`), ô hợp lệ vẫn tạo. | Giống `copy_roster_week`. Người dùng không mất cả lượt vì một ô. |
| R-Q7 | Trùng giờ | Chặn khi gửi nếu trùng ca đã có của chính mình (mọi chi nhánh) hoặc trùng đơn đang chờ của chính mình. Không chặn khi trùng đơn của người khác (nhiều người cùng xin một ca là chuyện thường). | Ràng buộc `exclude` riêng cho đơn `pending`; ca đã xếp đã có ràng buộc của nó. |
| R-Q8 | Duyệt | Duyệt = chèn `shift_assignments` (chụp tên, giờ, nghỉ từ đơn), gắn `assignment_id`. Nếu người đó **đã có đúng ca đó** ngày đó tại chi nhánh (quản lý xếp tay trước) thì chỉ gắn vào ca có sẵn. Trùng giờ khác → lỗi `shift_overlap` cho dòng đó. | Một nguồn sự thật là `shift_assignments`; mọi màn cũ chạy luôn. |
| R-Q9 | Đổi ý sau khi duyệt | Nhân viên **không** tự hủy đơn đã duyệt; nhờ quản lý gỡ ca trên lưới, hoặc gửi đơn nghỉ. Gỡ ca thì `assignment_id` thành null, đơn vẫn "đã duyệt" và hiện "đã gỡ khỏi lịch". | Ca đã duyệt là cam kết; giữ đơn giản. |
| R-Q10 | Đơn chờ quá giờ | Đơn `pending` mà ca đã bắt đầu (`start_at <= now()`) coi là **quá hạn**: không duyệt được (`too_late`), chỉ từ chối hoặc để đó; không tính vào badge. Tính khi đọc, không cần cron. | Không thêm job; dữ liệu không đổi ngầm. |
| R-Q11 | Quyền | Gửi/hủy đơn của mình, sửa lịch rảnh của mình: mọi nhân viên có dòng `staff_branches` tại chi nhánh (`is_branch_staff`). Xem danh sách đơn: `attendance VIEW`. Duyệt/từ chối: `attendance CREATE` (cùng quyền xếp ca). Cài đặt cửa sổ: `attendance SETTING`. Sửa lịch rảnh giúp nhân viên: `attendance UPDATE` tại một chi nhánh người đó thuộc về. | Không thêm quyền mới, khớp `assign_shift` (CREATE). |
| R-Q12 | Tự duyệt đơn của mình | Không (trừ super admin), mã `own_request`. | Giống đơn nghỉ (Q7 của chấm công). |
| R-Q13 | Nhân viên thấy đơn của người khác? | Không thấy tên. R7 chỉ hiện số "đã xếp / cần" của mỗi ô. | Riêng tư, đơn giản. |
| R-Q14 | Thông báo | Badge sidebar cho quản lý (số đơn chờ duyệt), trạng thái đơn trong trang của nhân viên. Không đẩy/email. | Chưa có tích hợp ngoài (giống đơn nghỉ). |
| R-Q15 | Bảng mới hay sửa bảng cũ? | Bảng mới `staff_availability`, `shift_registration_settings`, `shift_requests` (+ `shift_staffing_needs` ở R7). Không thêm cột vào `attendance_settings` (khỏi viết lại `attendance_rules_raw`, `save_attendance_settings`). Chỉ viết lại `shift_roster`. | Ít đụng luồng đang chạy. |

## 5. Luồng người dùng

**Nhân viên**

1. Trang **"Đăng ký ca"** (`/admin/attendance/register`, mở cho mọi nhân viên, có trong `AttendanceNav` và menu "Nhân sự"). Chọn chi nhánh (nếu làm nhiều nơi) và tuần. Thanh trên báo: "Đang mở đăng ký tuần 17/11–23/11, hạn chót 00:00 thứ Bảy 15/11" hoặc "Chưa mở" / "Đã hết hạn".
2. Lưới: cột là 7 ngày, dòng là ca mẫu đang dùng của chi nhánh. Mỗi ô:
   - trống (tick được), đã tick chưa gửi, **Chờ duyệt** (bấm để hủy), **Đã duyệt**, **Từ chối** (xem ghi chú), **Đã có ca** (quản lý xếp sẵn), **Nghỉ phép**, **Trùng giờ** (mờ, không tick được), **Bạn báo bận** (vẫn tick được, có biểu tượng cảnh báo).
   - R7: góc ô hiện "1/2 người".
3. Thanh dưới: "Đã chọn 4 ca", ô ghi chú chung (tùy chọn), nút **Gửi đăng ký**. Kết quả: "Đã gửi 3 ca, bỏ qua 1 (trùng ca 08:00 thứ Ba)".
4. Trang **"Của tôi"** thêm thẻ **"Lịch rảnh của tôi"** (sửa mẫu tuần) và thẻ **"Đăng ký ca của tôi"** (đơn 4 tuần tới, trạng thái, hủy đơn chờ).

**Quản lý (có `attendance`)**

1. **Lịch ca** (đã có): ô có đơn chờ hiện chip **viền đứt** "Ca sáng · Chờ duyệt", bấm mở hộp **Duyệt / Từ chối** (ghi chú tùy chọn). Ô có lịch bận của người đó tô sọc xám nhạt, tooltip "Bận cả ngày (lịch rảnh)". Thanh công cụ có nút "**N đăng ký chờ duyệt**" dẫn sang trang danh sách đã lọc tuần đó. Hộp gán ca cũ hiện cảnh báo nếu người đó báo bận giờ đó.
2. **Đăng ký ca** (`/admin/attendance/requests`, cần `attendance VIEW`, có badge): bảng phân trang có tìm kiếm (tên), lọc trạng thái (mặc định Chờ duyệt), lọc khoảng ngày, chi nhánh. Mỗi dòng: nhân viên, ngày, ca, giờ, ghi chú, cờ (Nghỉ phép / Báo bận / Trùng ca / Quá hạn), thời điểm gửi. Chọn nhiều → **Duyệt** / **Từ chối** (một ghi chú cho cả lượt). Kết quả: "Duyệt 5, lỗi 1 (trùng ca)".
3. **Cài đặt** (đã có): thẻ mới **"Đăng ký ca"**: bật/tắt, mở trước mấy tuần, hạn chót trước thứ Hai mấy ngày, tối đa ca/tuần, lời nhắn cho nhân viên ("Cuối tuần cần ít nhất 2 người"). R7: bảng số người cần theo ca mẫu × thứ.

## 6. Mô hình dữ liệu

Như chấm công: bật RLS, `revoke all from anon, authenticated`, chỉ `grant select` cho `authenticated` với policy đọc; **mọi thao tác ghi qua RPC `security definer`**; lỗi trả `errcode` + `hint`. Migration idempotent.

### 6.1 `staff_availability` (lịch rảnh, migration 1)

| Cột | Kiểu | Ràng buộc |
| --- | --- | --- |
| `id` | uuid PK default `gen_random_uuid()` | |
| `user_id` | uuid → `public.users` on delete cascade | |
| `weekday` | smallint | `between 1 and 7` (isodow, như `branch_hours`) |
| `kind` | text | `unavailable` / `preferred` |
| `start_time`, `end_time` | time null | cả hai null = cả ngày; hoặc cả hai có và `end_time <> start_time` (`end < start` = qua đêm) |
| `note` | text null | ≤ 200 ký tự |
| `updated_at` | timestamptz default now() | |
| `updated_by` | uuid → users on delete set null | khác `user_id` khi quản lý sửa giúp |

Chỉ mục `(user_id, weekday)`. Tối đa 21 dòng mỗi người (kiểm trong RPC, `too_many`). Policy đọc: `can_view_staff(user_id)`.

### 6.2 `shift_registration_settings` (migration 2; thiếu dòng = mặc định)

| Cột | Kiểu | Mặc định | Ràng buộc |
| --- | --- | --- | --- |
| `branch_id` | uuid PK → `branches` on delete cascade | | |
| `is_open` | boolean | false | |
| `weeks_ahead` | int | 2 | 1–6 |
| `close_days_before` | int | 2 | 0–14 |
| `max_shifts_per_week` | int null | null | null hoặc 1–21 |
| `staff_note` | text null | | ≤ 300 ký tự |
| `updated_at`, `updated_by` | | | |

Policy đọc: `is_branch_staff(branch_id) or can_attendance('VIEW', branch_id)`.

### 6.3 `shift_requests` (đơn đăng ký ca, migration 2)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | uuid PK | |
| `branch_id` | uuid → `branches` on delete cascade | |
| `user_id` | uuid → `public.users` on delete cascade | đơn chờ của người bị xóa vô nghĩa; ca đã duyệt nằm ở `shift_assignments` (restrict) |
| `user_name` | text | chụp `staff_display_name` |
| `work_date` | date | ngày bắt đầu ca (giờ VN) |
| `template_id` | uuid null → `shift_templates` on delete set null | |
| `name` | text | chụp tên ca mẫu |
| `start_at`, `end_at` | timestamptz | `shift_start_at` / `shift_end_at` từ ca mẫu; `end_at > start_at`, `<= 16 hours` |
| `break_minutes` | int ≥ 0 | chụp từ ca mẫu |
| `note` | text null | ≤ 300 |
| `status` | text default `pending` | `pending` / `approved` / `rejected` / `cancelled` |
| `assignment_id` | uuid null → `shift_assignments` on delete set null | có khi duyệt |
| `decided_by`, `decided_by_name`, `decided_at`, `decision_note` (≤ 300) | null | |
| `created_at`, `updated_at` | | trigger `set_updated_at` |

Ràng buộc:

- `exclude using gist (user_id with =, tstzrange(start_at, end_at, '[)') with &&) where (status = 'pending')`: một người không có hai đơn chờ chồng giờ.
- unique index `(user_id, branch_id, work_date, template_id) where status in ('pending', 'approved')`: không đăng ký lặp cùng một ô.
- Chỉ mục `(branch_id, work_date)`, `(user_id, work_date)`, `(branch_id) where status = 'pending'`.

Policy đọc: `user_id = auth.uid() or can_attendance('VIEW', branch_id)`.

### 6.4 `shift_staffing_needs` (tùy chọn R7, migration 4)

`(template_id → shift_templates on delete cascade, weekday smallint 1..7, min_staff int 0..20)`, PK `(template_id, weekday)`. Không có dòng = không đặt nhu cầu. Policy đọc như ca mẫu (nhân viên chi nhánh hoặc VIEW).

## 7. Hàm SQL

Giờ VN: dùng `shift_start_at`/`shift_end_at` có sẵn. "Hôm nay" = `(now() at time zone 'Asia/Ho_Chi_Minh')::date`. Thứ Hai của tuần: `p_monday` phải có `extract(isodow from p_monday) = 1` (`bad_input`).

### 7.1 Migration 1 — `20261112010000_staff_availability.sql` (PR R1)

- Bảng 6.1 + RLS + policy.
- `check_availability_items(p_items jsonb)` (nội bộ, revoke khỏi client): mảng ≤ 21 phần tử, mỗi phần tử `{weekday, kind, start_time?, end_time?, note?}` hợp lệ (`bad_input`, `too_many`).
- `my_availability() → jsonb` — mảng dòng của chính mình, sắp theo `weekday, start_time`.
- `save_my_availability(p_items jsonb) → jsonb` — thay toàn bộ dòng của chính mình (xóa rồi chèn trong một transaction); người gọi phải có ít nhất một dòng `staff_branches` (`not_branch_staff`). Trả lại danh sách mới.
- `staff_availability_of(p_user uuid) → jsonb` — `can_view_staff(p_user)`.
- `save_staff_availability(p_user uuid, p_items jsonb) → jsonb` — có `attendance UPDATE` tại một chi nhánh mà `p_user` thuộc về (`forbidden`); `updated_by` = người gọi.
- `availability_conflict(p_user uuid, p_start_at timestamptz, p_end_at timestamptz) → text` (nội bộ): `'unavailable'` nếu có dòng `unavailable` của thứ đó phủ cả ngày hoặc chồng khoảng giờ (xét ca qua đêm theo ngày bắt đầu), `'preferred'` nếu khớp dòng `preferred`, ngược lại null. Dùng ở 7.2, 7.3.
- `roster_availability(p_branch uuid) → jsonb` (nội bộ): lịch rảnh của mọi người thuộc chi nhánh, dùng ở `shift_roster` (7.3).

pgTAP `supabase/tests/staff_availability.test.sql`: lưu/đọc của mình; quá 21 dòng bị chặn; giờ sai bị chặn; người ngoài chi nhánh không đọc được; quản lý chi nhánh A sửa được cho người ở A, không sửa được người chỉ ở B; `availability_conflict` với ca qua đêm 20:00–08:00 và dòng bận cả ngày.

### 7.2 Migration 2 — `20261112020000_shift_requests.sql` (PR R2)

- Bảng 6.2, 6.3 + RLS + policy + trigger.
- `shift_registration_rules_raw(p_branch) → jsonb` (nội bộ) và `shift_registration_rules(p_branch) → jsonb` (nhân viên chi nhánh hoặc VIEW): cài đặt đã gộp mặc định.
- `save_shift_registration_settings(p_branch uuid, p jsonb) → jsonb` — `SETTING`; kiểu và khoảng như 6.2 (`bad_input`).
- `shift_registration_window(p_branch uuid, p_monday date) → jsonb` (nội bộ, gọi bởi các hàm dưới): `{ open boolean, closes_at timestamptz, reason text|null }`:
  - `closes_at = (p_monday - close_days_before)::timestamp at time zone 'Asia/Ho_Chi_Minh'`.
  - `reason = 'closed'` khi `is_open = false`; `'past_deadline'` khi `now() >= closes_at`; `'too_far'` khi `p_monday > mondayOf(hôm nay) + 7 * weeks_ahead`; ngược lại `open = true`.
- `shift_registration_board(p_branch uuid, p_monday date) → jsonb` — `is_branch_staff(p_branch)` (quản lý không thuộc chi nhánh thì không có trang này; họ dùng lưới lịch ca). Trả một lần đủ cho trang:
  `{ rules, window, templates: [...ca mẫu đang dùng], days: [7 ngày], requests: [đơn của tôi tuần này tại chi nhánh], assignments: [ca của tôi tuần này, mọi chi nhánh, có branch_name], leaves: [đơn nghỉ đã duyệt của tôi phủ tuần], availability: [lịch rảnh của tôi], needs: [] }` (`needs` để trống tới R7).
- `submit_shift_requests(p_branch uuid, p_monday date, p_items jsonb, p_note text default null) → jsonb {created: [{id, work_date, template_id, warning?}], skipped: [{work_date, template_id, hint}]}`:
  1. `is_branch_staff(p_branch)` và chi nhánh `is_active` (`not_branch_staff`).
  2. `shift_registration_window(...).open` (`registration_closed`, kèm `reason` trong message).
  3. `p_items` là mảng 1–21 phần tử `{work_date, template_id}` (`bad_input`).
  4. Mỗi phần tử, trong khối `begin ... exception` riêng:
     - `work_date` trong `[p_monday, p_monday + 6]` (`bad_input`);
     - ca mẫu thuộc chi nhánh và `is_active` (`not_found`);
     - đã có đơn `pending`/`approved` cùng ô (`duplicate`);
     - đã có ca xếp cùng ca mẫu ngày đó tại chi nhánh (`already_on_roster`);
     - chồng giờ ca đã xếp của mình ở bất kỳ chi nhánh (`shift_overlap`);
     - vượt `max_shifts_per_week` = (đơn `pending` + ca đã xếp của mình tại chi nhánh trong tuần) (`over_weekly_limit`);
     - chèn; bắt `exclusion_violation` → `request_overlap`, `unique_violation` → `duplicate`;
     - `warning`: `on_leave` nếu `shift_on_leave`, `unavailable` nếu `availability_conflict = 'unavailable'`.
- `cancel_shift_request(p_id uuid)` — chủ đơn; chỉ `pending` (`not_pending`); `status = 'cancelled'`.
- `my_shift_requests(p_from date, p_to date) → jsonb` — đơn của mình mọi chi nhánh (kèm `branch_name`, `expired` = pending và `start_at <= now()`); khoảng ≤ 93 ngày (`range_too_long`).

pgTAP `supabase/tests/shift_requests.test.sql`: cửa sổ (tắt, quá hạn chót, quá xa, tuần đang chạy); gửi nhiều ô có ô lỗi vẫn tạo ô hợp lệ; trùng ô; trùng ca đã có ở chi nhánh khác; giới hạn ca/tuần; cảnh báo nghỉ phép và báo bận; người ngoài chi nhánh bị chặn; hủy đơn chờ, không hủy được đơn đã duyệt; ca mẫu ngừng dùng bị bỏ qua; nhân viên A không thấy đơn của B qua select bảng.

### 7.3 Migration 3 — `20261112030000_shift_request_review.sql` (PR R4)

- `shift_request_row(r public.shift_requests, p_branch_name text) → jsonb` (nội bộ): cột của đơn + cờ tính khi đọc: `expired`, `on_leave` (`shift_on_leave`), `availability` (`availability_conflict`), `overlaps_assignment` (chồng giờ ca đã xếp của người đó, cho đơn `pending`), `on_roster` (`assignment_id` còn tồn tại).
- `list_shift_requests(p_branch uuid, p_status text default 'pending', p_from date default null, p_to date default null, p_search text default null, p_page int default 1, p_page_size int default 20) → jsonb {rows, total}` — `VIEW`; `p_branch` null → `attendance_branch_ids(null, 'VIEW')` (không bao giờ `has_permission(..., null)`); `p_status` thuộc `pending/approved/rejected/cancelled/all`; tìm theo `user_name` (unaccent như các RPC tìm kiếm khác nếu có sẵn hàm chuẩn hóa, không thì `ilike`); sắp `work_date, start_at, created_at`.
- `decide_shift_requests(p_ids uuid[], p_approve boolean, p_note text default null) → jsonb {approved, rejected, failed: [{id, hint}]}` — 1–200 id (`bad_input`). Mỗi id trong khối `begin ... exception` riêng:
  - có quyền `can_attendance('CREATE', branch_id)` (`forbidden`);
  - `status = 'pending'` (`not_pending`);
  - không phải đơn của mình trừ `is_super_admin()` (`own_request`);
  - duyệt: `start_at > now()` (`too_late`); người đó còn thuộc chi nhánh (`not_branch_staff`); nếu đã có `shift_assignments` cùng (user, branch, work_date, template_id) và cùng giờ → gắn vào; ngược lại chèn `shift_assignments` (`name`, `start_at`, `end_at`, `break_minutes` từ đơn, `note` = ghi chú đơn, `created_by` = người duyệt); `exclusion_violation` → `shift_overlap`;
  - ghi `status`, `decided_by`, `decided_by_name`, `decided_at`, `decision_note`.
- `pending_shift_request_count(p_branch uuid default null) → int` — đơn `pending` chưa quá hạn ở các chi nhánh người gọi có `CREATE` (null → mở rộng như `attendance_branch_ids(null, 'CREATE')`, nhưng trả 0 thay vì lỗi khi không có chi nhánh nào).
- `shift_roster(p_branch, p_from, p_to)` viết lại **từ bản hiện tại trong `supabase/schema.sql`**, giữ nguyên `staff`, `templates`, `assignments`, `leaves`, thêm:
  - `requests`: đơn `pending` tại chi nhánh trong khoảng (`id, user_id, work_date, template_id, name, color, start_at, end_at, note, expired, availability, on_leave`);
  - `availability`: `roster_availability(p_branch)`.
  Web cũ vẫn chạy vì zod sẽ có `default([])` cho hai khóa mới.

pgTAP `supabase/tests/shift_request_review.test.sql`: duyệt tạo ca trên lưới và `assignment_id`; duyệt khi đã có ca xếp tay → gắn vào; trùng giờ → `failed` với `shift_overlap`, các đơn khác vẫn duyệt; quá hạn → `too_late`; không tự duyệt; nhân viên thường không duyệt được; quản lý chi nhánh B không duyệt được đơn ở A; từ chối có ghi chú; `pending_shift_request_count` bỏ đơn quá hạn; `shift_roster` có `requests`, `availability`.

Thêm vào `supabase/tests/attendance_branch_scope.test.sql` (hoặc file mới `shift_request_branch_scope.test.sql`): quản lý chỉ ở A gọi `list_shift_requests(null, ...)` và `pending_shift_request_count(null)` chỉ thấy A (bắt buộc theo CLAUDE.md).

### 7.4 Migration 4 (tùy chọn) — `20261112040000_shift_staffing_needs.sql` (PR R7)

- Bảng 6.4 + RLS.
- `save_shift_staffing_needs(p_branch uuid, p_items jsonb)` — `SETTING`; thay toàn bộ nhu cầu của các ca mẫu thuộc chi nhánh.
- `shift_registration_board` và `shift_roster` viết lại (từ `schema.sql`) để trả `needs: [{template_id, weekday, min_staff, assigned, pending}]` với `assigned` = số ca đã xếp cùng ca mẫu ngày đó, `pending` = số đơn chờ. Nhân viên chỉ thấy số, không thấy tên.

Sau mỗi migration: `npm run db:start`, `npm run db:test`, `npm run db:schema`, commit `supabase/schema.sql` và `database.types.ts` mới.

### 7.5 Mã lỗi mới (`hint`)

`registration_closed`, `duplicate`, `already_on_roster`, `request_overlap`, `over_weekly_limit`, `too_late`, `too_many`. Dùng lại: `not_branch_staff`, `shift_overlap`, `not_pending`, `own_request`, `not_found`, `bad_input`, `forbidden`, `range_too_long`. Mỗi mã mới có câu tiếng Việt trong `admin.attendance.errors.*` (vi + en). Thêm vào `ATTENDANCE_ERROR_HINTS` ở `packages/core/src/attendance/errors.ts`.

## 8. Hợp đồng và lớp truy vấn

```
packages/core/src/attendance/
  registrationTypes.ts        // StaffAvailability, AvailabilityKind, RegistrationRules, RegistrationWindow,
                              // ShiftRequest, ShiftRequestStatus, RegistrationBoard, DecideResult, StaffingNeed
  registration.ts             // thuần: cellState(board, date, templateId), windowLabel(window), isOvernightRange,
                              // availabilityFor(items, weekday) — chỉ để hiển thị
  registration.test.ts
  contract/availability.ts    // zod: AvailabilityItem, AvailabilityList
  contract/registration.ts    // zod: RegistrationRules, RegistrationBoard, SubmitResult, MyRequests
  contract/review.ts          // zod: ShiftRequestRow, ShiftRequestList, DecideResult
  contract/shifts.ts          // Roster thêm requests, availability với .default([])
packages/supabase/src/attendance/
  availability.ts  registration.ts  review.ts  registrationMappers.ts   // mỗi hàm gọi một RPC rồi parse zod
apps/web/tests/db/
  attendanceRegistration.contract.test.ts  // dùng attendanceFixture.ts có sẵn
```

`types.ts` (251 dòng) và `mappers.ts` (261 dòng) **không** nhận thêm: kiểu và mapper mới vào file riêng để giữ dưới 300 dòng. Barrel `index.ts` export thêm.

## 9. Cấu trúc code web

Theo luật tách file (UI / composable / helper / types riêng, < ~300 dòng, page là vỏ mỏng):

```
apps/web/src/features/admin/attendance/
  queries/
    availability.ts            // useMyAvailability, useSaveMyAvailability, useStaffAvailability, useSaveStaffAvailability
    registration.ts            // useRegistrationBoard, useSubmitShiftRequests, useCancelShiftRequest, useMyShiftRequests,
                               // useRegistrationRules, useSaveRegistrationSettings
    review.ts                  // useShiftRequestList, useDecideShiftRequests, usePendingShiftRequestCount
  availability/
    AvailabilityCard.vue       // thẻ trong "Của tôi" (và hộp sửa giúp của quản lý)
    AvailabilityDialog.vue  AvailabilityRow.vue  AvailabilityWeekView.vue
    availabilityDraft.ts       // thuần: draft <-> items, kiểm hợp lệ
    useAvailabilityForm.ts
  register/                    // trang của nhân viên
    Index.vue
    RegisterToolbar.vue        // tuần trước/sau, chọn chi nhánh
    RegisterWindowNotice.vue   // mở / hạn chót / chưa mở + lời nhắn của chi nhánh
    RegisterGrid.vue  RegisterCell.vue  RegisterCellBadge.vue
    RegisterSubmitBar.vue      // số ô đã chọn, ghi chú, nút gửi
    RegisterResultDialog.vue   // danh sách ô bị bỏ qua và lý do
    registerGrid.ts            // thuần: ma trận ca mẫu × ngày + trạng thái ô
    registerGrid.test.ts
    useRegisterWeek.ts  useRegisterSelection.ts  useRegistrationBoard.ts
  requests/                    // trang duyệt của quản lý
    Index.vue
    RequestFilterFields.vue    // SearchView + useListFilters
    RequestTable.vue  RequestRow.vue  RequestFlags.vue
    RequestBulkBar.vue         // đã chọn N: Duyệt / Từ chối
    DecideRequestsDialog.vue   // ghi chú + kết quả failed
    useRequestBoard.ts  useRequestSelection.ts
  roster/                      // thêm, không viết lại
    RosterRequestChip.vue      // chip viền đứt trong ô
    RequestDecideDialog.vue    // duyệt/từ chối một đơn từ lưới
    AvailabilityHint.vue       // dòng cảnh báo trong AssignShiftDialog
    RosterPendingButton.vue    // "N đăng ký chờ duyệt" trên RosterToolbar
    rosterGrid.ts              // RosterCellData thêm requests[], availability
  settings/
    RegistrationCard.vue  useRegistrationSettingsForm.ts
    StaffingNeedsCard.vue  useStaffingNeeds.ts          // R7
  me/
    MyAvailabilityCard.vue (bọc AvailabilityCard)  MyShiftRequestsCard.vue

apps/web/src/pages/admin/attendance/
  register.vue (name attendanceRegister)  requests.vue (name attendanceRequests)
```

- `AttendanceNav.vue`: thêm tab `attendanceRequests` (`method: "VIEW"`) và `attendanceRegister` (`method: null`).
- `lib/navigations.ts` nhóm "Nhân sự": thêm "Đăng ký ca" (`attendanceRegister`) và "Duyệt đăng ký ca" (`attendanceRequests`).
- `ADMIN_ROUTE_PERMISSIONS`: `attendanceRequests: "attendance"`; `attendanceRegister` **không** có trong bảng (như `attendanceMe`). Cập nhật `permissions.parity.test.ts` nếu test liệt kê route.
- `layouts/admin.vue`: badge `attendanceRequests` từ `usePendingShiftRequestCount` (chỉ hỏi khi mở được route), cùng kiểu `leaveBadge`.
- `queries/keys.ts`: `attendanceKeys.registration(branch, monday)`, `requests(filters)`, `pendingRequests()`, `availability(user)`. Mọi mutation invalidate `attendanceKeys.all` (giống roster).
- i18n `vi/admin.json`, `en/admin.json`: `attendance.register.*`, `attendance.requests.*`, `attendance.availability.*`, `attendance.registrationSettings.*`, lỗi mới, `adminNav.attendanceRegister`, `adminNav.attendanceRequests`.
- Dùng lại: `PagedTableCard`, `SearchView` + `useListFilters`, `AppDialog`, `BranchPicker`, `useCurrentBranch`, `ShiftChip`, `shiftColors`, `mondayOf/weekDays/addDays`.
- iPad/điện thoại: lưới đăng ký cuộn ngang, cột tên ca dính trái, ô ≥ 44px; trên màn hẹp hiện dạng danh sách theo ngày (mỗi ngày một thẻ có các ca dạng nút bật/tắt) — chọn bằng `useMediaQuery` trong `Index.vue`, hai component con riêng.

## 10. Kết nối với module khác

| Chỗ | Thay đổi | PR |
| --- | --- | --- |
| Lịch ca | Chip chờ duyệt, tô lịch bận, cảnh báo khi gán, nút sang trang duyệt | R5 |
| Chấm công / bảng công | Không đổi: ca đã duyệt là `shift_assignments` bình thường | — |
| Trang "Của tôi" | Thẻ lịch rảnh, thẻ đăng ký ca | R1, R6 |
| Dashboard | Widget "Đăng ký ca chờ duyệt" (người có `attendance CREATE`), thêm vào danh mục widget trong code | R6 |
| Spa, POS | Không đổi | — |

## 11. Các PR (thứ tự làm)

Mỗi PR nhỏ, tự đủ, CI xanh rồi squash merge. Tiêu đề và commit tiếng Anh.

| PR | Tiêu đề gợi ý | Nội dung | Migration |
| --- | --- | --- | --- |
| R0 | docs: plan staff shift registration | File này + `docs/README.md` | — |
| R1 | Add staff weekly availability | Mục 7.1, pgTAP, `schema.sql`, `database.types.ts`, core `registrationTypes` (phần availability) + `contract/availability`, supabase `availability.ts`, test hợp đồng, thẻ "Lịch rảnh của tôi" ở trang Của tôi | `20261112010000` |
| R2 | Add shift registration requests and window settings | Mục 7.2, pgTAP, core `contract/registration`, supabase `registration.ts`, test hợp đồng, mã lỗi + i18n lỗi | `20261112020000` |
| R3 | Shift registration page for staff | `register/`, `settings/RegistrationCard`, nav, route, i18n, Vitest `registerGrid` | — |
| R4 | Add shift request review and roster requests | Mục 7.3, pgTAP (gồm phạm vi chi nhánh), core `contract/review` + Roster mở rộng, supabase `review.ts`, test hợp đồng | `20261112030000` |
| R5 | Review shift requests on the roster and request list | `requests/`, các file thêm trong `roster/`, badge sidebar, sửa lịch rảnh giúp nhân viên (mở từ tên người trên lưới), `ADMIN_ROUTE_PERMISSIONS`, parity | — |
| R6 | Shift requests on my page, dashboard widget and docs | `me/MyShiftRequestsCard`, widget dashboard, cập nhật mục 15 file này + test tay | — |
| R7 (tùy chọn) | Add staffing needs per shift template | Mục 7.4 + `StaffingNeedsCard`, số "x/y" trên lưới đăng ký và lưới lịch ca | `20261112040000` |

Phụ thuộc: R2 cần R1 (cảnh báo báo bận); R3 cần R2; R4 cần R2; R5 cần R4 (và R1); R6 cần R5; R7 cần R4. R1 UI và R2 có thể làm song song nếu tách nhánh.

## 12. Kiểm thử

- **pgTAP** (mỗi PR có migration): file ở mục 7, đăng nhập bằng `tests.login(user)` + `set local role authenticated`, tạo nhân viên bằng helper có sẵn trong `supabase/tests/_helpers/setup.psql`. Thời gian trong test: dùng tuần ở tương lai xa và chỉnh `close_days_before`/`weeks_ahead` để không phụ thuộc ngày chạy CI; trường hợp "quá hạn" tạo đơn có `start_at` trong quá khứ bằng insert trực tiếp với quyền postgres.
- **Test hợp đồng DB** (`npm run test:db`): mọi RPC mới trả đúng zod, mọi `hint` mới map đúng.
- **Vitest**: `registration.ts` (core), `registerGrid.ts`, `availabilityDraft.ts`, `rosterGrid.ts` (ô có đơn chờ, lịch bận).
- **CI**: typecheck, build, `deps:check`, schema không cũ.
- Không bấm thử trình duyệt được trong cloud: mỗi PR UI báo rõ chỉ mới typecheck/build/test.

## 13. Rủi ro

| Rủi ro | Cách giảm |
| --- | --- |
| Đánh số migration lệch (thread khác merge số lớn hơn trước) | Kiểm `ls supabase/migrations` trên `origin/main` ngay trước khi merge mỗi PR có migration; đổi số nếu cần. |
| Viết lại `shift_roster` làm mất phần đã có | Bắt đầu từ định nghĩa trong `supabase/schema.sql` (luật CLAUDE.md), pgTAP kiểm cả bốn khóa cũ còn đó. |
| Giờ VN và hạn chót lệch một ngày | Một hàm `shift_registration_window` duy nhất; test biên 23:59 / 00:00; web chỉ hiển thị `closes_at` từ SQL, không tự tính. |
| Duyệt hàng loạt lỗi giữa chừng | Mỗi đơn một khối exception riêng, trả `failed`; không có trạng thái nửa vời. |
| `has_permission(..., null)` lộ chi nhánh khác | `list_shift_requests` và `pending_shift_request_count` mở rộng null bằng danh sách chi nhánh; test phạm vi bắt buộc. |
| Nhân viên tick quá nhiều | `max_shifts_per_week`, giới hạn 21 ô mỗi lần gửi. |
| Ca mẫu bị sửa giờ sau khi đăng ký | Đơn đã chụp giờ lúc gửi; duyệt dùng giờ của đơn (giống ca đã xếp không đổi khi sửa ca mẫu). |
| Quản lý quên duyệt, tuần đã chạy | Đơn quá hạn hiện "Quá hạn", không tính badge; lưới vẫn cho xếp tay. |

## 14. Không làm trong đợt này

- Đổi ca / nhả ca / nhận ca của người khác (shift swap, drop, shift pool).
- Quản lý đăng ca trống riêng lẻ (open shift kiểu Deputy) và chế độ "ai nhận trước được trước" (tự duyệt). Có thể thêm cờ `auto_approve` vào `shift_registration_settings` sau.
- Đăng ký giờ tùy chỉnh ngoài ca mẫu.
- Lịch bận theo ngày cụ thể (ngoài đơn nghỉ), lịch rảnh có hiệu lực từ ngày nào đến ngày nào.
- Duyệt thay đổi lịch rảnh.
- Lịch nháp / công bố lịch (publish) và khóa lịch đã công bố.
- Tự xếp lịch (auto-schedule) theo lịch rảnh và nhu cầu.
- Thông báo đẩy, email, Zalo.
- Đăng ký ca trong app mobile (app chỉ dành cho khách).

## 15. Đã làm

- R1 (#245) lịch rảnh; R2 (#246) cửa sổ đăng ký + gửi đơn; R3 (#247) trang đăng ký + cài đặt; R4 (#248) duyệt đơn + roster; R5/R6 trang duyệt đơn, chip chờ duyệt trên lịch ca, "Đơn của tôi", widget dashboard.
- Migration đã chạy tự động qua workflow Supabase migrate: 20261112010000, 20261112020000, 20261112030000.
- Chưa làm: R7 (nhu cầu nhân sự). UI mới chỉ typecheck/build, chưa bấm thử trên trình duyệt.

### Test tay cho grace (sau khi xong)

1. Cài đặt → thẻ "Đăng ký ca": bật, mở trước 2 tuần, hạn chót 2 ngày, tối đa 5 ca/tuần, lời nhắn.
2. Đăng nhập tài khoản nhân viên → Của tôi → "Lịch rảnh": báo bận cả ngày thứ Ba, thích ca sáng thứ Bảy.
3. Đăng ký ca → tuần sau: tick 4 ô, trong đó một ô thứ Ba (thấy cảnh báo báo bận), gửi. Thử tick ô trùng giờ ca đã có.
4. Hủy một đơn đang chờ.
5. Đăng nhập quản lý → menu thấy badge "Duyệt đăng ký ca" → duyệt 2 đơn, từ chối 1 đơn kèm ghi chú.
6. Lịch ca tuần sau: thấy 2 ca mới, 1 chip chờ duyệt (nếu còn), ô thứ Ba của người đó tô sọc bận; duyệt ngay trên lưới.
7. Nhân viên mở lại Đăng ký ca và Của tôi: trạng thái Đã duyệt / Từ chối kèm ghi chú.
8. Hôm có ca: "Vào ca" gắn đúng ca đã duyệt; bảng công tính như ca xếp tay.
