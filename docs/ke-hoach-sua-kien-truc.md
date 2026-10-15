# Kế hoạch sửa nợ kỹ thuật kiến trúc

Ngày: 2026-10-15. Nguồn: [danh-gia-kien-truc.md](danh-gia-kien-truc.md) (PR #125), grace duyệt lộ trình và cho làm luôn. Supabase đang dùng gói Free.

Mục tiêu: có lưới an toàn trước production (CI, test SQL, backup) mà không đổi tính năng. Mỗi bước là một PR nhỏ, squash merge.

## Kết quả (2026-10-15)

| Bước | PR | Trạng thái |
| --- | --- | --- |
| 1. Sửa typecheck, gỡ gói không dùng | #127 | xong, typecheck 0 lỗi, build chạy |
| 2-4. CI, bản chụp schema, test pgTAP | #128 | xong, 28 test, CI xanh |
| 5. Backup hằng tuần | #129 | xong, lần chạy tay đầu tiên thành công (artifact `bongcun-20261015`, 139 KB) |
| 6. Tách 6 file trên 300 dòng | #130 | xong, file lớn nhất còn 294 dòng, CI xanh |
| 7. Cập nhật tài liệu | PR này | xong |

Không có migration mới, không chạy SQL nào lên DB thật. Chưa thử khôi phục backup vào một project thật.

## Đã kiểm trước khi lên plan

- Dựng Supabase cục bộ bằng `supabase db start` (CLI 2.121.0, Postgres 17 theo `supabase/config.toml`): **cả 121 migration chạy sạch trên DB rỗng**, kèm `supabase/seed.sql`. Vậy CI dựng DB từ đầu là khả thi, không cần sửa migration cũ.
- `nuxt typecheck` trên `main`: 4 lỗi có sẵn (xem bước 1).
- Rà lại 16 chỗ dùng `is_staff()`: tất cả là đọc danh mục dùng chung (loại chuồng, giá chuồng, chẩn đoán, loại vaccine), cờ sức khỏe ở quầy (`pet_health_flags`, chỉ trả cờ, không trả bệnh án) và tìm khách ở quầy (`search_customers`). Đây là chủ ý thiết kế ("mọi nhân viên đều đọc"), không phải lỗ hổng. Bài đánh giá viết hơi nặng ở điểm này; bước 7 chỉ sửa lại câu chữ trong tài liệu, không đổi quyền trên DB thật.

## Bước 1. Sửa 4 lỗi typecheck và gỡ gói không dùng

| Lỗi | Cách sửa |
| --- | --- |
| `src/components/common/RangeDateShadcn/Index.vue` import `radix-vue/dist/date`, `radix-vue/dist/date/types` (không còn trong radix-vue 1.9) | Lấy kiểu từ `@internationalized/date` (`DateValue`) và hàm từ entry chính của `radix-vue` hoặc viết helper nhỏ; giữ nguyên hành vi. |
| `src/components/common/Zooming.vue`: `vue-zoomable` thiếu kiểu theo `exports` | Thêm khai báo module trong `src/types/shims/vue-zoomable.d.ts`. |
| `src/components/ui/toast/use-toast.ts:82` TS2589 | Ghi kiểu tường minh cho giá trị gây suy luận vô hạn (thường là `ref<State>` bọc `VNode`), không dùng `any`. |

Gỡ: `uuid`, `@types/uuid` (code dùng `crypto.randomUUID()`), `@vuepic/vue-datepicker` và dòng CSS của nó trong `nuxt.config.ts` (không còn component nào dùng). Kiểm: `nuxt typecheck` sạch, `nuxt build` chạy được.

Không làm ở bước này: chuyển `radix-vue` sang `reka-ui` (155 file). Ghi lại là việc làm dần khi đụng tới.

## Bước 2. CI trên mỗi PR (`.github/workflows/ci.yml`)

Chạy trên `pull_request` và `push` vào `main`. Hai job song song:

1. **app**: `npm ci`, `npm run type-check`, `npm run build`. Không cần secret.
2. **db**: `supabase/setup-cli` (ghim phiên bản CLI), `supabase db start` (dựng Postgres có sẵn schema `auth`, `storage`, role `anon`/`authenticated`, chạy toàn bộ migration và seed), `supabase test db` (bước 4), so bản chụp schema (bước 3). Không cần secret, không chạm DB thật.

Workflow `supabase-migrate.yml` giữ nguyên (vẫn chạy khi merge). Nhờ job **db**, một migration lỗi cú pháp hay sai thứ tự sẽ đỏ ở PR thay vì hỏng trên production.

Thêm script npm: `db:start`, `db:test`, `db:schema` để thread sau chạy y hệt CI.

## Bước 3. Bản chụp schema (`supabase/schema.sql`)

- Sinh bằng `supabase db dump --local --schema public` sau khi chạy toàn bộ migration. File chỉ để **đọc và tra**: bản hiện hành của mọi hàm, bảng, policy nằm một chỗ. Không bao giờ chạy file này lên DB.
- Job **db** sinh lại và `git diff --exit-code`: PR nào thêm migration mà quên cập nhật bản chụp sẽ đỏ, kèm lời nhắc chạy `npm run db:schema`.
- Ghi quy ước vào `AGENTS.md`/`CLAUDE.md`: muốn sửa một hàm, đọc bản trong `supabase/schema.sql`, không chép từ migration cũ.

## Bước 4. Test SQL bằng pgTAP (`supabase/tests/*.test.sql`)

Chạy bằng `supabase test db` trong transaction, tự rollback. Một file helper tạo dữ liệu mẫu (chi nhánh, người dùng trong `auth.users`, role theo chi nhánh, sản phẩm, lô hàng, ca thu ngân) và hàm giả lập đăng nhập: đặt `request.jwt.claims` (sub, `user_role`, `branch_ids`) rồi `set local role authenticated`.

Ca test đợt đầu (ưu tiên luồng tiền và kho):

| File | Kiểm |
| --- | --- |
| `pos_invoice.test.sql` | bán hàng trừ kho theo FEFO (lô hết hạn sớm trước), tổng tiền tính phía server, gửi lại cùng `client_ref` không tạo hóa đơn thứ hai, hủy hóa đơn hoàn kho đúng lô. |
| `sales_return.test.sql` | trả hàng hoàn kho và không cho trả vượt số đã bán. |
| `permissions.test.sql` | `anon` không gọi được RPC nhân viên; thu ngân không có quyền `pos` ở chi nhánh B không bán được ở B; người chỉ có `VIEW` không hủy được hóa đơn; khách hàng không đọc được bảng `invoices`, `medical_visits`. |
| `rls_smoke.test.sql` | mọi bảng trong `public` đều bật RLS (truy vấn `pg_class.relrowsecurity`); mọi hàm `security definer` đều có `search_path` cố định. |

Thêm dần các luồng khác (lưu trú, y tế) ở các PR sau, không nhồi hết vào đợt này.

## Bước 5. Backup hằng tuần (`.github/workflows/supabase-backup.yml`)

Gói Free không có backup tải về được, nên:

- Chạy theo lịch mỗi Chủ nhật và chạy tay được. Dùng secret có sẵn (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`), **grace không phải thêm gì**.
- `supabase db dump` ba phần: roles, schema, data (gồm cả schema `auth` để giữ tài khoản).
- **Mã hóa** bằng `gpg --symmetric` (AES256) với mật khẩu DB làm passphrase, vì repo công khai: artifact của repo công khai ai đăng nhập GitHub cũng tải được. Ai giải mã được thì vốn đã có mật khẩu DB, nên không lộ thêm gì.
- Lưu làm artifact 90 ngày (tối đa của GitHub). Hướng dẫn khôi phục ghi trong `docs/sao-luu-du-lieu.md`.
- Không ghi gì lên DB, chỉ đọc.

## Bước 6. Tách 6 file trên 300 dòng

Giữ nguyên hành vi và API xuất ra (import cũ vẫn chạy nhờ file barrel):

| File | Tách thành |
| --- | --- |
| `src/repositories/pos.ts` (544) | `repositories/pos/` : `invoices.ts`, `shifts.ts`, `returns.ts`, `errors.ts`, `types.ts`, `index.ts` |
| `src/repositories/inventory.ts` (524) | `repositories/inventory/` theo lô, phiếu kho, nhà cung cấp, ngưỡng tồn, `index.ts` |
| `src/stores/modules/auth.ts` (409) | giữ store, chuyển phần quyền admin và hồ sơ ra helper/composable |
| `src/repositories/medical/visits.ts` (384) | `visits.ts` (đọc) và `visitActions.ts` (ghi) |
| `src/types/boarding.ts` (321) | `types/boarding/` theo đặt chỗ, chăm sóc, thanh toán, `index.ts` |
| `src/queries/boarding.ts` (312) | tách theo nhóm giống repository |

Kiểm: typecheck, build, và CI xanh.

## Bước 7. Cập nhật tài liệu

Sửa mục 4.3 của `danh-gia-kien-truc.md` theo kết quả rà `is_staff()`, đánh dấu các bước đã làm, cập nhật `docs/README.md`, bản sao ở project files.

## Không làm trong đợt này

- Chuyển `radix-vue` sang `reka-ui`, zod parse cho RPC `jsonb`, `pg_cron`, bảng tổng hợp báo cáo: làm khi đụng tới hoặc khi có khách thật.
- Không sửa migration cũ, không chạy SQL tay lên DB thật. Đợt này không có migration mới nào.

## Rủi ro

- `supabase db start` trong CI mất khoảng 1 đến 2 phút mỗi PR; chấp nhận được.
- Bản chụp schema phụ thuộc phiên bản CLI và Postgres: ghim phiên bản CLI trong workflow và script để file sinh ra giống nhau.
- Backup chỉ an toàn khi mật khẩu DB được giữ kín; nếu đổi mật khẩu DB, các bản backup cũ cần mật khẩu cũ để giải mã.
