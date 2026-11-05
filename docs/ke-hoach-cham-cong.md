# Kế hoạch: chấm công và quản lý giờ làm nhân viên

Ngày: 2026-11-05. Trạng thái: plan đã duyệt (tự duyệt theo quy ước dự án), chờ thread coding làm theo các PR ở mục 12.

## 1. Tóm tắt

grace muốn quản lý giờ làm của nhân viên. Hiện hệ thống chỉ có **ca thu ngân** (`cash_shifts`, mở/đóng két ở POS) và **quyền theo (nhân viên, chi nhánh)** (`staff_branches`). Chưa có lịch làm việc, chưa có giờ vào/ra, chưa có nghỉ phép.

Module mới gồm năm phần, mỗi phần dùng được ngay khi xong:

1. **Ca mẫu** theo chi nhánh: "Ca sáng 08:00–14:00, nghỉ 0 phút", "Ca chiều 14:00–20:00", "Ca trực đêm 20:00–08:00" (qua đêm được).
2. **Lịch ca (xếp ca)**: lưới tuần, mỗi dòng một nhân viên, mỗi cột một ngày; bấm ô để gán ca, chép lịch tuần trước.
3. **Chấm công vào/ra**: nhân viên tự bấm "Vào ca" / "Ra ca" trên tài khoản admin của mình (máy quầy, iPad, điện thoại). Giờ lấy từ máy chủ, không lấy giờ máy khách. Quản lý sửa giờ khi quên bấm, mọi lần sửa đều có lý do và lưu lịch sử.
4. **Nghỉ phép**: nhân viên gửi đơn (phép năm, ốm, không lương, khác; cả ngày hoặc nửa ngày), quản lý duyệt/từ chối. Có số ngày phép năm theo người theo năm.
5. **Báo cáo giờ công**: tổng hợp theo nhân viên (giờ làm, đi muộn, về sớm, vắng, tăng ca, ngày nghỉ) và **bảng công tháng** (nhân viên × ngày, ký hiệu X/M/V/P...), xuất Excel/CSV/PDF bằng bộ export có sẵn.

**Không làm lương** trong đợt này (xem mục 15). Báo cáo đủ số liệu để sau này tính lương.

**SQL cần chạy**: bốn migration mới `supabase/migrations/20261110010000_attendance_shifts.sql`, `...020000_attendance_time_entries.sql`, `...030000_attendance_leave.sql`, `...040000_attendance_reports.sql`. Số mới hơn mọi migration đã chạy (mới nhất hiện tại là `20261103010000_dashboard_layouts.sql`). Workflow "Supabase migrate" tự chạy khi merge, grace không phải dán tay. Nếu có migration khác merge vào main với số lớn hơn trước khi PR này merge, **đổi số file của PR này cho lớn hơn** (db push hỏng khi chạy lệch thứ tự).

## 2. Hiện trạng (đã đọc code)

**Nhân viên**

- `public.users`: mọi tài khoản. `users.role` là "loại tài khoản" (`customer`, `admin`, `superAdmin`, `cashier`, ...). Nhân viên là mọi tài khoản có `role <> 'customer'` (`packages/supabase/src/users/staff.ts`, `listStaff`).
- `public.staff_branches (user_id, branch_id, role, does_services)`: vai trò của một nhân viên **tại từng chi nhánh**. `does_services` đánh dấu người làm dịch vụ spa. FK `user_id → public.users on delete cascade`.
- `staff_display_name(uuid)`: tên hiển thị (dùng để chụp tên vào bản ghi, ví dụ `cash_shifts.opened_by_name`).
- `list_branch_staff(p_branch)`: nhân viên của một chi nhánh, chặn bằng `can_schedule('VIEW')`.
- Gán nhân viên vào chi nhánh: màn Vai trò (`features/admin/settings/roles/AssignStaffSheet.vue`), RPC `save_staff_branches`.

**Ca thu ngân (không phải ca làm)**

- `cash_shifts`: mã `CN-CA-000001` (`next_doc_code(branch, 'CA')`), `opened_by`, `opening_cash`, `counted_cash`, trạng thái `open`/`closed`. Mỗi người chỉ một ca mở tại một chi nhánh.
- RPC `open_cash_shift`, `close_cash_shift`, `cash_shift_summary`, báo cáo `report_shifts`.
- UI: `features/admin/pos/shifts`, `pos/components/OpenShiftDialog.vue`, `CloseShiftDialog.vue`.
- Đây là ca **tiền**, gắn với két. Chấm công là ca **người**. Hai thứ tách riêng (mục 3, quyết định Q2).

**Quyền (RBAC)**

- `permissions (name, methods[], module, sort_order)`, `role_permissions (role, permission, methods[])`, method thuộc `CREATE/VIEW/DELETE/UPDATE/IMPORT/EXPORT/SETTING/ALL`.
- `has_permission(perm, method, branch)`: super admin hoặc có vai trò tại chi nhánh đó có quyền. `branch = null` nghĩa là "ở bất kỳ chi nhánh nào" — **không được tin** cho hàm có tham số chi nhánh nullable (CLAUDE.md), phải mở rộng thành danh sách như `report_branch_ids`.
- Mỗi module có hàm `can_xxx(method, branch)` = `is_admin() or has_permission('xxx', ...)` (`can_pos`, `can_schedule`, `can_report`, `can_boarding`, `can_medical`...).
- JWT có `user_role` và `branch_ids` (`custom_access_token_hook`). `is_staff()` đọc JWT.
- Phía web: `packages/core/src/auth/access.ts` (`canUse`, `ADMIN_ROUTE_PERMISSIONS`), store `auth-parts/adminGrants.ts`, `composables/usePermission.ts`, `useCurrentBranch.ts`. Test `apps/web/tests/db/permissions.parity.test.ts` bắt menu và DB phải nói giống nhau.

**Chi nhánh và giờ**

- `branches (code, name, is_active)`; `branch_hours (branch_id, weekday 1..7 = isodow, open_time, close_time, is_closed)`.
- Múi giờ: các hàm dùng hằng `'Asia/Ho_Chi_Minh'`; có sẵn `boarding_local_date(timestamptz) → date`.
- Spa: `appointment_items.staff_id` có ràng buộc `EXCLUDE USING gist` chống trùng giờ (đã bật `btree_gist`). Lịch spa không biết ai đang trong ca.

**Hạ tầng dùng lại được**

- `pg_cron` đã bật (job `auto-cancel-expired-bookings` mỗi 15 phút, job hủy đơn online 02:00).
- Báo cáo: `features/admin/reports/*`, `report_staff_revenue`, `report_branch_ids`, mẫu phân trang `p_search/p_limit/p_offset` trả `total_count`.
- Danh sách admin: `PagedTableCard`, `SearchView` + `useListFilters`, `AppDialog`, export `useXxxExport` + `xxxExportColumns.ts`.
- Dashboard: bộ widget `features/admin/dashboard/widgets/*`, danh mục số liệu viết trong code.
- Hợp đồng: zod trong `packages/core/src/<feature>/contract`, mã lỗi từ `hint` (`errors.ts`, `toAppError`), query trong `packages/supabase/src/<feature>`, test DB trong `apps/web/tests/db/*.contract.test.ts`, pgTAP trong `supabase/tests`.

## 3. Quyết định chính

| # | Câu hỏi | Chọn | Lý do |
| --- | --- | --- | --- |
| Q1 | Ai được chấm công? | Mọi nhân viên có dòng trong `staff_branches` tại chi nhánh đó. Không cần quyền riêng để tự chấm công và gửi đơn nghỉ của chính mình. | Tự phục vụ; quyền chỉ cần cho việc xem/sửa của người khác. |
| Q2 | Gộp với ca thu ngân? | **Không gộp.** Mở két vẫn là `cash_shifts`. Khi mở ca thu ngân mà chưa "Vào ca", POS hiện nhắc (không chặn). | Một người có thể làm ca mà không giữ két (bác sĩ, groomer). Gộp sẽ phá luồng POS đang chạy. |
| Q3 | Chống chấm hộ? | Bản đầu: giờ máy chủ + mỗi người một tài khoản + nhật ký sửa. Bước tùy chọn A9: giới hạn IP chi nhánh (đọc `cf-connecting-ip`/`x-forwarded-for` từ `request.headers`). Không GPS, không ảnh selfie, không QR. | Dự án cá nhân, chi phí thấp. IP để sau vì cần thử thực tế trên Supabase. |
| Q4 | Ca qua đêm? | Có. Ca mẫu lưu `start_time`/`end_time`; khi gán, tính ra `start_at`/`end_at` (timestamptz) theo giờ VN, `end_time <= start_time` nghĩa là sang hôm sau. | Nội trú/trực đêm cần. Lưu mốc tuyệt đối thì so giờ đơn giản. |
| Q5 | Một người nhiều chi nhánh? | Được, nhưng không trùng giờ: ràng buộc `EXCLUDE` theo `user_id` trên mọi chi nhánh. Chỉ một lượt "đang trong ca" mỗi người. | Một người không thể ở hai nơi. |
| Q6 | Quên ra ca? | Lượt mở quá `review_after_hours` (mặc định 16 giờ) bị đóng tự động với **0 phút làm** và cờ `missing_checkout`; quản lý sửa giờ thật. Không tự bịa giờ ra. | An toàn cho số liệu; không chặn người đó vào ca hôm sau. |
| Q7 | Sửa giờ của chính mình? | Quản lý không sửa/duyệt được bản ghi và đơn của chính mình (trừ super admin). | Tránh tự sửa công. |
| Q8 | Tính giờ làm | Giờ thật (ra − vào) trừ `break_minutes` của ca. Đi muộn/về sớm so với giờ ca, có phút ân hạn. Tăng ca = phần ra sau giờ kết thúc ca, chỉ tính khi ≥ `overtime_min_minutes`. Đến sớm không tính tăng ca. | Đơn giản, đủ cho bảng công. |
| Q9 | Ngày nghỉ phép tính sao? | Cả ngày: đếm các ngày trong khoảng mà chi nhánh mở cửa (`branch_hours.is_closed = false`). Nửa ngày: 0,5. Không có bảng ngày lễ trong đợt này. | Không cần lịch làm của từng người mới tính được. |
| Q10 | Hết phép năm? | Chỉ **cảnh báo** khi gửi và khi duyệt, không chặn. Quản lý có thể đổi loại sang "không lương" khi duyệt. | Chủ quyết định, hệ thống không cứng nhắc. |
| Q11 | Đơn nghỉ thuộc chi nhánh nào? | Chọn một chi nhánh duyệt khi gửi (mặc định chi nhánh đang chọn). Đơn đã duyệt có hiệu lực cho người đó ở **mọi** chi nhánh. | Quyền duyệt cần một chi nhánh; nghỉ thì nghỉ cả người. |
| Q12 | Quyền | Một quyền mới `attendance` (module "Nhân sự"). VIEW xem công cả chi nhánh; CREATE xếp ca; UPDATE sửa giờ, duyệt đơn; DELETE xóa ca/lượt chấm; EXPORT xuất báo cáo; SETTING ca mẫu, cài đặt, số ngày phép. Gán sẵn `admin: ALL`. | Theo mẫu `can_xxx` có sẵn. |
| Q13 | Mã chứng từ? | Không đánh mã cho ca/lượt chấm/đơn nghỉ. | Không in, không đối chiếu tiền. |
| Q14 | Bảng mới hay sửa bảng cũ? | Chỉ thêm bảng/hàm mới. Không sửa `cash_shifts`, `staff_branches`, `has_permission`. | Không đụng luồng đang chạy. |

## 4. Luồng người dùng

**Nhân viên (mọi vai trò)**

1. Đăng nhập admin. Trên thanh đầu trang có nút đồng hồ: "Vào ca" (xanh) hoặc "Đang trong ca 3g12p · Ra ca".
2. Bấm "Vào ca": nếu có ca được xếp trong cửa sổ cho phép, lượt chấm gắn vào ca đó; nếu không, hỏi "Bạn không có ca lúc này. Vẫn vào ca?" (khi chi nhánh cho phép ca ngoài lịch).
3. Trang "Của tôi" (`/admin/attendance/me`): lịch ca 2 tuần tới, lượt chấm tháng này kèm trạng thái (đúng giờ / muộn 7 phút / về sớm / thiếu giờ ra), số ngày phép còn lại, danh sách đơn nghỉ, nút "Xin nghỉ".

**Quản lý chi nhánh (có `attendance`)**

1. **Hôm nay** (`/admin/attendance`): ai đang trong ca, ai chưa vào dù đã tới giờ, ai nghỉ phép, ai ra về; các lượt cần xem lại (quên ra ca, ngoài lịch). Bấm một dòng để sửa giờ (bắt nhập lý do).
2. **Lịch ca** (`/admin/attendance/roster`): lưới tuần; bấm ô → chọn ca mẫu hoặc giờ tùy chỉnh; "Chép tuần trước"; ô có đơn nghỉ đã duyệt hiện màu nghỉ.
3. **Đơn nghỉ** (`/admin/attendance/leave`): lọc theo trạng thái, duyệt/từ chối kèm ghi chú, nhập đơn hộ nhân viên.
4. **Bảng công** (`/admin/attendance/timesheet`): hai tab "Tổng hợp" và "Bảng công tháng", xuất file.
5. **Cài đặt** (`/admin/attendance/settings`): ca mẫu, phút ân hạn, cửa sổ vào ca sớm, cho phép ca ngoài lịch, số ngày phép năm của từng người.

## 5. Mô hình dữ liệu

Tất cả bảng bật RLS, `revoke all from anon, authenticated`, chỉ `grant select` cho `authenticated` với policy đọc; **mọi thao tác ghi qua RPC `security definer`** (giống `dashboard_layouts`, `cash_shifts`).

### 5.1 `attendance_settings` (một dòng mỗi chi nhánh, tạo khi lưu lần đầu; thiếu dòng thì dùng mặc định)

| Cột | Kiểu | Mặc định | Ràng buộc |
| --- | --- | --- | --- |
| `branch_id` | uuid PK → `branches` on delete cascade | | |
| `late_grace_minutes` | int | 5 | 0–60 |
| `early_grace_minutes` | int | 5 | 0–60 |
| `checkin_early_minutes` | int | 60 | 0–240: được vào ca sớm hơn giờ bắt đầu bao lâu mà vẫn gắn vào ca |
| `overtime_min_minutes` | int | 30 | 0–240 |
| `allow_unscheduled` | boolean | true | |
| `review_after_hours` | int | 16 | 4–24 |
| `updated_at`, `updated_by` | | | |

Hàm `attendance_rules(p_branch) returns jsonb` trả cài đặt đã gộp mặc định (dùng trong mọi RPC khác, không đọc bảng trực tiếp).

### 5.2 `shift_templates` (ca mẫu)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | uuid PK | |
| `branch_id` | uuid → `branches` on delete cascade | |
| `name` | text | `length(btrim(name)) between 1 and 40`; unique `(branch_id, lower(name))` |
| `start_time`, `end_time` | time | `end_time <> start_time`; `end_time < start_time` = qua đêm |
| `break_minutes` | int default 0 | `>= 0` và nhỏ hơn độ dài ca |
| `color` | text default `'teal'` | một trong `teal, sky, amber, rose, violet, slate` (bảng màu cố định trong code) |
| `is_active` | boolean default true | không xóa ca mẫu, chỉ ẩn |
| `sort_order` | int default 0 | |
| `created_at`, `updated_at` | | |

### 5.3 `shift_assignments` (ca đã xếp)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | uuid PK | |
| `branch_id` | uuid → `branches` | |
| `user_id` | uuid → `public.users` **on delete restrict** | giữ lịch sử khi nhân viên nghỉ việc |
| `work_date` | date | ngày bắt đầu ca theo giờ VN |
| `template_id` | uuid → `shift_templates` on delete set null | null = giờ tùy chỉnh |
| `name` | text | chụp tên ca lúc gán ("Ca sáng" hoặc "Tùy chỉnh") |
| `start_at`, `end_at` | timestamptz | `end_at > start_at`, `end_at - start_at <= interval '16 hours'` |
| `break_minutes` | int | chụp từ ca mẫu |
| `note` | text null | |
| `created_by`, `created_at`, `updated_at` | | |

Ràng buộc: `exclude using gist (user_id with =, tstzrange(start_at, end_at, '[)') with &&)` (`btree_gist` đã có). Chỉ mục `(branch_id, work_date)`, `(user_id, work_date)`.

### 5.4 `time_entries` (lượt chấm công)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | uuid PK | |
| `branch_id` | uuid → `branches` | |
| `user_id` | uuid → `public.users` on delete restrict | |
| `user_name` | text | chụp `staff_display_name` |
| `assignment_id` | uuid null → `shift_assignments` on delete set null | unique khi khác null (mỗi ca một lượt) |
| `work_date` | date | ngày của `check_in_at` theo giờ VN (`boarding_local_date`) |
| `check_in_at` | timestamptz | |
| `check_out_at` | timestamptz null | `check_out_at >= check_in_at`; `check_out_at - check_in_at <= 24 hours` |
| `in_source`, `out_source` | text | `self` / `manager` / `auto` |
| `review_reason` | text null | `missing_checkout` / `unscheduled` / null |
| `reviewed_by`, `reviewed_at` | null | quản lý bấm "Đã xem" thì cờ còn nhưng không hiện trong hàng đợi |
| `note` | text null | |
| `created_at`, `updated_at` | | |

Ràng buộc: unique index `(user_id) where check_out_at is null` (một lượt mở mỗi người, toàn hệ thống). Chỉ mục `(branch_id, work_date)`, `(user_id, work_date)`.

### 5.5 `time_entry_changes` (nhật ký sửa)

| Cột | Kiểu |
| --- | --- |
| `id` | uuid PK |
| `entry_id` | uuid (không FK để giữ dòng khi lượt chấm bị xóa) |
| `branch_id`, `user_id` | uuid (chủ của lượt chấm, để lọc) |
| `action` | text: `create` / `update` / `delete` / `auto_close` |
| `before`, `after` | jsonb (chỉ các cột giờ, ca, ghi chú) |
| `reason` | text not null (trừ `auto_close`) |
| `changed_by`, `changed_by_name`, `changed_at` | |

### 5.6 `leave_allowances` (phép năm)

`(user_id → public.users on delete cascade, year int check 2020..2100, annual_days numeric(4,1) check 0..60, updated_by, updated_at)`, PK `(user_id, year)`. Thiếu dòng = mặc định **12 ngày** (hằng trong hàm `leave_allowance_days`, theo Bộ luật Lao động cho người làm đủ năm; quản lý sửa theo từng người).

### 5.7 `leave_requests` (đơn nghỉ)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | uuid PK | |
| `user_id`, `user_name` | | |
| `branch_id` | uuid → `branches` | chi nhánh duyệt |
| `leave_type` | text | `annual` / `sick` / `unpaid` / `other` |
| `from_date`, `to_date` | date | `to_date >= from_date`, `to_date - from_date <= 60` |
| `part` | text default `full` | `full` / `am` / `pm`; `am`/`pm` chỉ khi `from_date = to_date` |
| `days` | numeric(5,1) | tính lúc tạo bằng `leave_days()` |
| `reason` | text not null | 1–500 ký tự |
| `status` | text default `pending` | `pending` / `approved` / `rejected` / `cancelled` |
| `decided_by`, `decided_by_name`, `decided_at`, `decision_note` | null | |
| `created_by` | uuid | khác `user_id` khi quản lý nhập hộ |
| `created_at`, `updated_at` | | |

Ràng buộc: `exclude using gist (user_id with =, daterange(from_date, to_date, '[]') with &&) where (status in ('pending','approved'))` — không có hai đơn còn hiệu lực chồng ngày.

Ca nửa ngày: đơn `am` phủ ca **bắt đầu trước 12:00** giờ VN, `pm` phủ ca bắt đầu từ 12:00.

### 5.8 Policy đọc

- `shift_templates`, `attendance_settings`: đọc được nếu là nhân viên chi nhánh đó (`exists staff_branches`) hoặc `can_attendance('VIEW', branch_id)`.
- `shift_assignments`, `time_entries`, `leave_requests`: `user_id = auth.uid()` **hoặc** `can_attendance('VIEW', branch_id)`.
- `time_entry_changes`: `can_attendance('VIEW', branch_id)` hoặc chủ lượt chấm.
- `leave_allowances`: chính mình, hoặc có `attendance VIEW` tại một chi nhánh mà người đó thuộc về.

Màn hình đọc qua RPC (đã gộp tên, trạng thái), không select bảng trực tiếp; policy chỉ là lớp bảo vệ thứ hai.

## 6. Quyền và phạm vi chi nhánh

```sql
insert into public.permissions (name, description, methods, module, sort_order) values
  ('attendance', 'Nhân sự: lịch ca, chấm công, nghỉ phép, bảng công',
   array['CREATE','VIEW','DELETE','UPDATE','EXPORT','SETTING','ALL'], 'Nhân sự', 70)
on conflict (name) do nothing;
-- admin: ALL (theo mẫu 20261014010000_reports_access.sql)

create or replace function public.can_attendance(p_method text, p_branch uuid) returns boolean
language sql stable set search_path = '' as $$
  select coalesce((select public.is_admin()), false)
      or (p_branch is not null and (select public.has_permission('attendance', p_method, p_branch)));
$$;
```

`p_branch` **bắt buộc** ở `can_attendance` (null trả false, trừ admin). Mọi RPC có tham số chi nhánh nullable (báo cáo "Tất cả chi nhánh") dùng:

```sql
-- Giống report_branch_ids: null mở rộng thành danh sách chi nhánh người gọi có quyền,
-- không bao giờ gọi has_permission(..., null).
create or replace function public.attendance_branch_ids(p_branch uuid, p_method text default 'VIEW')
returns uuid[] language plpgsql stable security definer set search_path = '' as $$ ... $$;
revoke all on function public.attendance_branch_ids(uuid, text) from public, anon, authenticated;
```

Kèm test pgTAP `supabase/tests/attendance_branch_scope.test.sql` (quản lý chi nhánh A gọi `report_timesheet(null, ...)` chỉ thấy A).

Hàm phụ `is_branch_staff(p_branch uuid) returns boolean` = `exists (select 1 from staff_branches where user_id = auth.uid() and branch_id = p_branch)`, dùng cho thao tác tự phục vụ.

Phía web:

- `ADMIN_ROUTE_PERMISSIONS`: `attendanceToday`, `attendanceRoster`, `attendanceLeave`, `attendanceTimesheet`, `attendanceSettings` → `attendance`. Trang `attendanceMe` **không** có trong bảng (mở cho mọi nhân viên).
- Thêm `attendance` vào danh sách quyền trong `permissions.parity.test.ts`.
- Nút đồng hồ ở đầu trang chỉ hiện khi người dùng có ít nhất một chi nhánh trong `branch_ids`.

## 7. Quy tắc tính công

Hàm nội bộ `attendance_rows(p_branch_ids uuid[], p_from date, p_to date, p_user uuid default null)` (không grant cho client) trả **một dòng cho mỗi ca đã xếp** và **một dòng cho mỗi lượt chấm ngoài lịch**:

| Cột | Cách tính |
| --- | --- |
| `scheduled_minutes` | `end_at - start_at - break_minutes` (0 cho dòng ngoài lịch) |
| `worked_minutes` | lượt đã đóng: `greatest(0, phút(check_out_at - check_in_at) - break_minutes)`; ngoài lịch không trừ nghỉ; lượt đang mở: 0 |
| `late_minutes` | `phút(check_in_at - start_at)` nếu lớn hơn `late_grace_minutes`, ngược lại 0 |
| `early_minutes` | `phút(end_at - check_out_at)` nếu lớn hơn `early_grace_minutes`, ngược lại 0 |
| `overtime_minutes` | `phút(check_out_at - end_at)` nếu ≥ `overtime_min_minutes`, ngược lại 0 |
| `status` | xem bảng dưới |

Trạng thái (ưu tiên từ trên xuống):

| `status` | Khi nào | Ký hiệu bảng công |
| --- | --- | --- |
| `leave` | có đơn `approved` phủ ngày (và phủ nửa ngày đúng buổi) | P (phép năm), Ô (ốm), K (không lương), N (khác) |
| `missing_checkout` | lượt có `review_reason = 'missing_checkout'` và chưa được sửa | ? |
| `working` | lượt đang mở | (không hiện trong bảng tháng) |
| `late_early` | muộn và về sớm | M |
| `late` | `late_minutes > 0` | M |
| `early` | `early_minutes > 0` | S |
| `present` | có lượt, không muộn/sớm | X |
| `unscheduled` | lượt không gắn ca | X+ |
| `absent` | không lượt, `end_at < now()` | V |
| `not_in` | không lượt, đang trong giờ ca | (chỉ ở màn Hôm nay) |
| `upcoming` | `start_at > now()` | (trống) |

Một ngày có hai ca thì ô bảng công hiện ký hiệu "tệ nhất" (V > ? > M > S > X) và tooltip liệt kê từng ca. Ngày có đơn nghỉ mà không xếp ca vẫn hiện ký hiệu nghỉ.

Các hàm thuần tương ứng ở `packages/core/src/attendance/rules.ts` chỉ để **hiển thị** (định dạng "3g12p", chọn ký hiệu cho ô, màu trạng thái); con số luôn lấy từ SQL, không tính lại ở client.

## 8. Migration

Tất cả idempotent (`create table if not exists`, `create or replace function`, `drop policy if exists`, `on conflict do nothing`), lỗi trả `errcode` + `hint` (mã lỗi dùng ở mục 9.2).

### 8.1 A1 — `20261110010000_attendance_shifts.sql`

- Quyền `attendance`, `can_attendance`, `attendance_branch_ids`, `is_branch_staff`.
- Bảng `attendance_settings`, `shift_templates`, `shift_assignments` + RLS + policy.
- `attendance_rules(p_branch) → jsonb`.
- `save_attendance_settings(p_branch uuid, p jsonb) → jsonb` — `SETTING`.
- `list_shift_templates(p_branch uuid, p_include_inactive boolean default false) → setof jsonb` — nhân viên chi nhánh hoặc `VIEW`.
- `save_shift_template(p_branch uuid, p jsonb) → uuid` (có `id` = sửa) — `SETTING`. Sửa ca mẫu **không** đổi các ca đã xếp (đã chụp giờ).
- `set_shift_template_active(p_id uuid, p_active boolean)` — `SETTING`.
- `assign_shift(p_branch uuid, p_user uuid, p_date date, p_template uuid, p_start time default null, p_end time default null, p_break int default null, p_note text default null) → uuid` — `CREATE`. `p_template` null thì bắt buộc `p_start`/`p_end`. Người được gán phải thuộc `staff_branches` của chi nhánh (`hint = 'not_branch_staff'`). Trùng giờ → bắt lỗi exclusion, trả `hint = 'shift_overlap'`. Ngày có đơn nghỉ đã duyệt → vẫn cho gán nhưng trả `{ id, warning: 'on_leave' }`.
- `update_shift_assignment(p_id uuid, p jsonb)` — `UPDATE`; không cho sửa khi đã có lượt chấm (`hint = 'has_entry'`), trừ ghi chú.
- `remove_shift_assignment(p_id uuid)` — `DELETE`; có lượt chấm thì từ chối (`has_entry`).
- `copy_roster_week(p_branch uuid, p_from_monday date, p_to_monday date, p_overwrite boolean default false) → jsonb {copied, skipped}` — `CREATE`. Bỏ qua người không còn thuộc chi nhánh, ô đã có ca (khi không overwrite), ô trùng giờ.
- `shift_roster(p_branch uuid, p_from date, p_to date) → jsonb` — `VIEW`. Trả `{ staff: [{user_id, name, role, photo_url}], templates: [...], assignments: [...], leaves: [{user_id, from_date, to_date, part, leave_type}] }`. Giới hạn khoảng 42 ngày.
- `my_schedule(p_from date, p_to date) → jsonb` — chính mình, mọi chi nhánh; gồm ca, lượt chấm, đơn nghỉ.

Giờ VN khi tính `start_at`: `(p_date + p_start) at time zone 'Asia/Ho_Chi_Minh'`; nếu `p_end <= p_start` thì `end_at` cộng thêm 1 ngày.

pgTAP: `supabase/tests/attendance_shifts.test.sql` — gán ca qua đêm, trùng giờ giữa hai chi nhánh bị chặn, người ngoài chi nhánh bị chặn, chép tuần, nhân viên thường không gán được ca, quản lý chi nhánh A không gán được ở B.

### 8.2 A2 — `20261110020000_attendance_time_entries.sql`

- Bảng `time_entries`, `time_entry_changes` + RLS.
- `close_stale_entries(p_user uuid default null) → int`: lượt mở quá `review_after_hours` của chi nhánh → `check_out_at = check_in_at`, `out_source = 'auto'`, `review_reason = 'missing_checkout'`, ghi `time_entry_changes` (`auto_close`). Không grant cho client; gọi bởi cron và bởi `clock_in`.
- `clock_status() → jsonb`: lượt đang mở (nếu có), ca hiện tại/kế tiếp hôm nay ở mọi chi nhánh, chi nhánh được phép chấm.
- `clock_in(p_branch uuid, p_note text default null, p_unscheduled_ok boolean default false) → jsonb`:
  1. `auth.uid()` thuộc `staff_branches` của `p_branch`, chi nhánh `is_active` (`not_branch_staff`).
  2. `close_stale_entries(auth.uid())`.
  3. Còn lượt mở → `already_in`.
  4. Tìm ca của người đó tại chi nhánh: `now() between start_at - checkin_early_minutes and end_at`, chưa có lượt; lấy ca bắt đầu sớm nhất.
  5. Không có ca: nếu `allow_unscheduled = false` → `no_shift`; nếu `p_unscheduled_ok = false` → `confirm_unscheduled` (web hỏi lại rồi gọi với `true`); ngược lại tạo lượt `review_reason = 'unscheduled'`.
  6. Có đơn nghỉ đã duyệt phủ ca → vẫn cho vào, trả `warning: 'on_leave'`.
  7. Trả `{ entry_id, assignment, late_minutes }`.
- `clock_out(p_note text default null) → jsonb`: đóng lượt mở của chính mình (`not_in`), trả số phút làm, về sớm.
- `attendance_today(p_branch uuid, p_date date default null) → jsonb` — `VIEW`: mọi nhân viên chi nhánh + dòng từ `attendance_rows` + đơn nghỉ + hàng đợi xem lại.
- `add_time_entry(p_branch uuid, p_user uuid, p_in timestamptz, p_out timestamptz, p_assignment uuid, p_reason text) → uuid` — `UPDATE`.
- `edit_time_entry(p_id uuid, p_in timestamptz, p_out timestamptz, p_assignment uuid, p_reason text)` — `UPDATE`; sửa xong thì xóa `review_reason`.
- `delete_time_entry(p_id uuid, p_reason text)` — `DELETE`.
- `mark_entry_reviewed(p_id uuid)` — `UPDATE`.
- `time_entry_history(p_id uuid) → setof jsonb` — `VIEW` hoặc chủ lượt chấm.
- Ba hàm sửa: `p_reason` bắt buộc (`reason_required`); người gọi không được sửa lượt của chính mình (`own_entry`) trừ `is_super_admin()`; không cho giờ trong tương lai (`future_time`).
- `pg_cron`: job `close-stale-time-entries` chạy `'5 * * * *'` gọi `close_stale_entries()`.

pgTAP: `supabase/tests/attendance_clock.test.sql` — vào ca gắn đúng ca, vào sớm trong cửa sổ, ngoài lịch cần xác nhận, chặn hai lượt mở, ra ca, tự đóng sau 16 giờ với 0 phút, quản lý sửa ghi nhật ký, không tự sửa của mình, quản lý chi nhánh B không sửa được lượt ở A.

### 8.3 A3 — `20261110030000_attendance_leave.sql`

- Bảng `leave_allowances`, `leave_requests` + RLS.
- `leave_days(p_branch uuid, p_from date, p_to date, p_part text) → numeric`.
- `leave_balance(p_user uuid, p_year int) → jsonb {allowance, used, pending, remaining}`: chính mình hoặc có `VIEW` tại chi nhánh của người đó. `used` = tổng `days` đơn `annual` đã duyệt có `from_date` trong năm.
- `save_leave_allowance(p_user uuid, p_year int, p_days numeric)` — `SETTING` tại một chi nhánh của người đó.
- `request_leave(p_branch uuid, p_type text, p_from date, p_to date, p_part text, p_reason text) → jsonb {id, days, warning?}` — chính mình, thuộc chi nhánh; `p_from >= hôm nay - 7 ngày` (`too_old`, để kịp xin phép ốm); trùng đơn → `leave_overlap`; vượt phép năm → `warning: 'over_allowance'`.
- `request_leave_for(p_user uuid, ...)` — `UPDATE`, tạo luôn ở trạng thái `approved` (nhập hộ), không cho chính mình.
- `cancel_leave(p_id uuid)` — chủ đơn: khi `pending`, hoặc `approved` mà `from_date > hôm nay`.
- `decide_leave(p_id uuid, p_approve boolean, p_note text default null, p_type text default null) → jsonb` — `UPDATE` tại `branch_id` của đơn; chỉ đơn `pending` (`not_pending`); không tự duyệt (`own_request`); `p_type` cho phép đổi loại khi duyệt; tính lại `days`.
- `list_leave_requests(p_branch uuid, p_status text default 'pending', p_from date default null, p_to date default null, p_search text default null, p_page int default 1, p_page_size int default 20) → jsonb {rows, total}` — `VIEW` (dùng `attendance_branch_ids` khi `p_branch` null).
- `my_leave_requests(p_year int) → jsonb`.
- `pending_leave_count(p_branch uuid) → int` — badge menu.

pgTAP: `supabase/tests/attendance_leave.test.sql` — nửa ngày chỉ một ngày, đếm bỏ ngày chi nhánh đóng cửa, trùng đơn bị chặn, cảnh báo hết phép, không tự duyệt, hủy đơn đã duyệt trong quá khứ bị chặn, phạm vi chi nhánh khi `p_branch` null.

### 8.4 A4 — `20261110040000_attendance_reports.sql`

- `attendance_rows(...)` (mục 7), `revoke` khỏi client.
- `report_timesheet(p_branch uuid, p_from date, p_to date, p_search text default null, p_limit int default 20, p_offset int default 0)` returns table `(user_id, name, branch_codes text, shifts_scheduled, shifts_worked, scheduled_minutes, worked_minutes, late_count, late_minutes, early_count, early_minutes, overtime_minutes, absent_count, unscheduled_count, missing_checkout_count, leave_annual, leave_sick, leave_unpaid, leave_other, total_count)` — `VIEW`, phạm vi qua `attendance_branch_ids`; khoảng tối đa 93 ngày.
- `report_timesheet_grid(p_branch uuid, p_month date) → jsonb` — một chi nhánh bắt buộc; `{ days: [...], staff: [{user_id, name, cells: [{date, code, minutes, detail}], totals}] }`.
- `my_timesheet(p_from date, p_to date) → jsonb` — dòng `attendance_rows` của chính mình + tổng.

pgTAP: `supabase/tests/attendance_branch_scope.test.sql` (bắt buộc theo CLAUDE.md) và `supabase/tests/attendance_report.test.sql` (muộn trong/ngoài ân hạn, về sớm, tăng ca dưới/trên ngưỡng, vắng, nghỉ nửa ngày, ca qua đêm cắt qua nửa đêm vẫn thuộc ngày bắt đầu).

Sau mỗi migration: `npm run db:start`, `npm run db:test`, `npm run db:schema`, commit `supabase/schema.sql` và `database.types.ts` mới.

## 9. Hợp đồng và lớp truy vấn

### 9.1 `packages/core/src/attendance/`

```
attendance/
  index.ts
  types.ts            // ShiftTemplate, ShiftAssignment, TimeEntry, LeaveRequest, AttendanceRow, AttendanceStatus...
  errors.ts           // ATTENDANCE_ERROR_HINTS + attendanceErrorOf(error)
  rules.ts            // thuần: formatMinutes, cellCode(statuses[]), statusTone(status), isOvernight(start, end)
  week.ts             // thuần: mondayOf(date), weekDays(monday), monthDays(month)
  contract/
    index.ts
    shifts.ts         // zod: ShiftTemplateInput, AssignShiftInput, RosterResponse
    clock.ts          // zod: ClockStatus, ClockInResult, ClockOutResult
    leave.ts          // zod: LeaveRequestInput, LeaveBalance, LeaveListResponse
    report.ts         // zod: TimesheetRow, TimesheetGrid
```

Test Vitest cạnh file (`rules.test.ts`, `week.test.ts`).

### 9.2 Mã lỗi (`hint`)

`not_branch_staff`, `shift_overlap`, `has_entry`, `already_in`, `not_in`, `no_shift`, `confirm_unscheduled`, `reason_required`, `own_entry`, `future_time`, `leave_overlap`, `too_old`, `not_pending`, `own_request`, `range_too_long`. Mỗi mã có câu tiếng Việt trong i18n `admin.attendance.errors.*`.

### 9.3 `packages/supabase/src/attendance/`

`shifts.ts`, `clock.ts`, `entries.ts`, `leave.ts`, `reports.ts`, `index.ts`: mỗi hàm gọi một RPC rồi `parse` bằng zod của core (theo mẫu `packages/supabase/src/boarding`). Thêm `attendance` vào barrel và luật dependency-cruiser nếu cần.

### 9.4 Test hợp đồng

`apps/web/tests/db/attendance.contract.test.ts` (+ `attendanceFixture.ts`): mỗi RPC trả đúng schema zod, mỗi `hint` map đúng mã lỗi. Mở rộng `permissions.parity.test.ts` với `attendance`.

## 10. Cấu trúc code web

Theo luật tách file của dự án (UI / composable / helper / types riêng, dưới ~300 dòng, page là vỏ mỏng):

```
apps/web/src/features/admin/attendance/
  index.ts
  AttendanceNav.vue                    // tab: Hôm nay · Lịch ca · Đơn nghỉ · Bảng công · Cài đặt
  queries/                             // useQuery/useMutation bọc packages/supabase/attendance
    keys.ts  shifts.ts  clock.ts  leave.ts  reports.ts
  clock/                               // nút đồng hồ ở header
    ClockButton.vue  ClockDialog.vue  UnscheduledConfirm.vue
    useClock.ts  useElapsed.ts
  today/
    Index.vue  TodayStaffRow.vue  ReviewQueue.vue  EntryEditDialog.vue  EntryHistory.vue
    useAttendanceToday.ts  useEntryEdit.ts
  roster/
    Index.vue  RosterToolbar.vue  RosterGrid.vue  RosterCell.vue  AssignShiftDialog.vue  CopyWeekDialog.vue
    useRoster.ts  useRosterWeek.ts  rosterGrid.ts (thuần: dựng ma trận người × ngày)
  leave/
    Index.vue  LeaveFilterFields.vue  LeaveRow.vue  LeaveDecideDialog.vue  LeaveRequestForm.vue  LeaveBalanceChip.vue
    useLeaveList.ts  useLeaveForm.ts  leaveExportColumns.ts
  timesheet/
    Index.vue  TimesheetTabs.vue  SummaryTable.vue  MonthGrid.vue  MonthGridCell.vue  GridLegend.vue
    useTimesheetSummary.ts  useTimesheetGrid.ts  useTimesheetExport.ts  timesheetExportColumns.ts
  settings/
    Index.vue  RulesCard.vue  TemplatesCard.vue  TemplateDialog.vue  AllowancesCard.vue
    useAttendanceRules.ts  useShiftTemplates.ts  useAllowances.ts
  me/
    Index.vue  MyScheduleList.vue  MyEntriesTable.vue  MyLeaveCard.vue
    useMySchedule.ts  useMyTimesheet.ts
  shared/
    StatusPill.vue  ShiftChip.vue  MinutesText.vue  attendanceFormat.ts  shiftColors.ts

apps/web/src/pages/admin/attendance/
  index.vue (attendanceToday)  roster.vue  leave.vue  timesheet.vue  settings.vue  me.vue
```

- `lib/navigations.ts`: nhóm mới `adminNav.staff` ("Nhân sự") với 5 mục quản lý + "Chấm công của tôi". Badge số đơn chờ duyệt dùng `pending_leave_count`.
- Header admin: chèn `ClockButton` (một dòng trong layout, không viết logic ở layout).
- i18n: `vi/admin.json` và `en/admin.json` khóa `attendance.*`, `adminNav.staff*`.
- Dùng lại: `PagedTableCard`, `SearchView` + `useListFilters` (đơn nghỉ, bảng công), `AppDialog`, bộ chọn ngày/khoảng ngày reka-ui, `useCurrentBranch`, export Excel/CSV/PDF có sẵn.
- iPad: lưới lịch ca cuộn ngang với cột tên dính trái; ô tối thiểu 44px; bấm ô mở dialog (không kéo thả trong bản đầu).

## 11. Kết nối với module khác

| Chỗ | Thay đổi | PR |
| --- | --- | --- |
| POS mở ca thu ngân | Nếu `clock_status()` cho biết chưa vào ca tại chi nhánh đó: hiện dòng nhắc trong `OpenShiftDialog` + nút "Vào ca luôn". Không chặn. | A8 |
| Dashboard | Widget "Nhân sự hôm nay" (đang làm / chưa vào / nghỉ) cho người có `attendance VIEW`; thẻ "Ca của tôi" cho mọi nhân viên. Thêm vào danh mục widget trong code, không đổi `dashboard_layouts`. | A8 |
| Spa: chọn người làm | Không đổi trong đợt này. Sau này có thể làm mờ người không có ca giờ đó (mục 15). | — |
| Báo cáo nhân viên | Không đổi `report_staff_revenue`. Bảng công là trang riêng trong nhóm Nhân sự. | — |
| Sao lưu tuần | Bảng mới nằm trong schema `public`, backup hiện tại đã lấy. Không cần đổi. | — |

## 12. Các PR (thứ tự làm)

Mỗi PR nhỏ, tự đủ, CI xanh rồi squash merge. Tiêu đề tiếng Anh.

| PR | Tiêu đề gợi ý | Nội dung | Migration |
| --- | --- | --- | --- |
| A1 | Add shift templates, roster tables and attendance permission | Mục 8.1, pgTAP, `schema.sql`, `database.types.ts`, core `types/errors/week/contract/shifts`, supabase `shifts.ts`, test hợp đồng, parity | `20261110010000` |
| A2 | Attendance settings and shift templates screens | `settings/` (RulesCard, TemplatesCard), nav "Nhân sự", trang settings, i18n | — |
| A3 | Weekly roster grid | `roster/`, chép tuần, cảnh báo nghỉ phép | — |
| A4 | Add clock in/out and time entry corrections | Mục 8.2, pgTAP, cron, core `clock`, supabase `clock/entries`, test hợp đồng | `20261110020000` |
| A5 | Clock button, today board and entry review | `clock/`, `today/`, `me/` (phần lịch + lượt chấm) | — |
| A6 | Add leave requests and annual allowances | Mục 8.3 + toàn bộ `leave/`, `AllowancesCard`, `me/MyLeaveCard`, badge | `20261110030000` |
| A7 | Add timesheet reports and export | Mục 8.4 + `timesheet/`, export, `my_timesheet` ở trang Của tôi | `20261110040000` |
| A8 | Attendance hints in POS and dashboard widgets | Mục 11 | — |
| A9 (tùy chọn) | Restrict clock-in to branch IP addresses | `attendance_settings.allowed_ips cidr[]`, đọc `current_setting('request.headers', true)::jsonb ->> 'cf-connecting-ip'` (dự phòng `x-forwarded-for` phần đầu), test trên Supabase thật trước khi bật; mặc định tắt | `2026111005xxxx` |
| A10 | Docs: attendance done + manual test list | Cập nhật mục 16 của file này, `docs/README.md` | — |

Phụ thuộc: A2, A3 cần A1; A5 cần A4; A6 cần A1 (và A3 để hiện nghỉ trên lưới); A7 cần A4 + A6; A8 cần A5. A2/A3 có thể làm song song với A4.

## 13. Kiểm thử

- **pgTAP** (mỗi PR có migration): các file ở mục 8, đăng nhập bằng `tests.login(user)` + `set local role authenticated`. Tạo nhân viên bằng helper có sẵn `tests.create_staff`.
- **Test hợp đồng DB** (`npm run test:db`): mọi RPC trả đúng zod, mã lỗi đúng.
- **Vitest**: hàm thuần trong core (`rules`, `week`) và `rosterGrid.ts`.
- **CI**: typecheck, build, `deps:check`, schema không cũ.
- **Không** thể bấm thử trình duyệt trong cloud: báo rõ mỗi PR UI chỉ mới typecheck/build.

## 14. Rủi ro

| Rủi ro | Cách giảm |
| --- | --- |
| Chấm hộ (dùng tài khoản người khác) | Nhật ký sửa, quản lý thấy lượt ngoài lịch; A9 giới hạn IP. Chấp nhận mức này cho dự án cá nhân. |
| Lệch múi giờ, ca qua đêm | Mọi mốc là `timestamptz`, ngày tính bằng `boarding_local_date`; test ca 20:00–08:00. |
| Quên ra ca làm sai bảng công | Tự đóng 0 phút + cờ, hàng đợi xem lại ở màn Hôm nay, ký hiệu "?" trên bảng công. |
| Lưới tuần nặng khi nhiều nhân viên | Một RPC `shift_roster` trả cả tuần; giới hạn 42 ngày; dự án có ít nhân viên. |
| Đánh số migration lệch | Ghi rõ ở mục 1; kiểm số mới nhất trên main trước khi merge. |
| Nhân viên nghỉ việc bị xóa tài khoản | FK `on delete restrict` trên ca và lượt chấm: phải gỡ khỏi chi nhánh chứ không xóa user (giữ lịch sử công). |
| `has_permission(..., null)` lộ dữ liệu chi nhánh khác | `can_attendance` từ chối null; báo cáo dùng `attendance_branch_ids`; test phạm vi. |

## 15. Không làm trong đợt này

- Tính lương, đơn giá giờ, phụ cấp, bảo hiểm, thuế.
- Bảng ngày lễ và hệ số làm ngày lễ.
- Chấm công bằng GPS, ảnh, QR, máy vân tay.
- Đổi ca giữa hai nhân viên (swap) và nhân viên tự đăng ký ca.
- Thông báo đẩy/email nhắc vào ca (chưa có tích hợp ngoài).
- Chấm công trong app mobile (app chỉ dành cho khách).
- Spa làm mờ người không có ca khi chọn người làm.
- Kéo thả trên lưới lịch ca.

## 16. Đã làm

Xong ngày 2026-11-05. Migration `20261110010000`-`040000` đã chạy tự động qua workflow "Supabase migrate" (bản gộp để tham khảo: `pet-care-plan/migration-cham-cong-gop.sql`).

| PR | Nội dung |
| --- | --- |
| #233 | A1: ca mẫu, lịch ca, quyền `attendance` |
| #234 | A2+A3 gộp một PR: màn cài đặt và lưới lịch ca tuần |
| #235 | A4: vào/ra ca, sửa giờ có nhật ký, cron tự đóng ca quên ra |
| #236 | A5: nút chấm công trên header, màn Hôm nay, trang Của tôi |
| #237 | A6: đơn nghỉ, phép năm, badge đơn chờ duyệt |
| #238 | A7: bảng công (tổng hợp + lưới tháng), xuất Excel/CSV/PDF, công của tôi |
| #239 | A8: nhắc chấm công khi mở ca POS, widget "Nhân sự hôm nay" và "Ca của tôi" |

Khác với kế hoạch:

- A2 và A3 gộp một PR; hàm `attendance_rows` nằm trong migration 2 (không phải migration 4).
- Hàm danh sách/báo cáo ở A7 trả `jsonb {rows, total}` thay vì `RETURNS TABLE`.
- Workflow migrate ghim Supabase CLI 2.121.0.
- Widget dashboard có cờ `anyStaff` (hiện cho mọi vai trò tại chi nhánh) cho widget chỉ xem dữ liệu của chính mình.
- **Chưa làm A9** (giới hạn IP chi nhánh, tùy chọn).
- Giao diện mới chỉ qua typecheck/build/test, chưa bấm thử trên trình duyệt.

### Test tay cho grace (sau khi xong)

1. Cài đặt chấm công: tạo 3 ca mẫu (sáng, chiều, đêm 20:00–08:00).
2. Vai trò: tick quyền "Nhân sự" cho vai trò quản lý cần dùng.
3. Lịch ca: xếp ca tuần này cho 2 người, "Chép tuần trước" sang tuần sau.
4. Đăng nhập bằng tài khoản nhân viên: "Vào ca", đợi vài phút, "Ra ca"; thử "Vào ca" khi không có ca.
5. Gửi đơn nghỉ nửa ngày; đăng nhập quản lý duyệt; xem ô trên lịch ca đổi màu.
6. Sửa giờ một lượt chấm (bắt nhập lý do), mở lịch sử sửa.
7. Bảng công tháng: kiểm ký hiệu X/M/S/V/P, xuất Excel.
8. Mở ca ở POS khi chưa chấm công: thấy nhắc và nút "Vào ca luôn"; mở ca vẫn được.
9. Bảng điều khiển "Hôm nay": hai widget "Nhân sự hôm nay" (cần quyền Nhân sự) và "Ca của tôi".
