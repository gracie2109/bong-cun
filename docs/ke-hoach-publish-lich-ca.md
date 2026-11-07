# Kế hoạch: hạn chót đăng ký ca, phát hành lịch, thông báo và lịch sử thay đổi

Ngày: 2026-11-07. Trạng thái: plan đã duyệt (tự duyệt theo quy ước dự án), chờ thread coding làm theo các PR ở mục 12.

Xây tiếp trên đăng ký ca (`docs/ke-hoach-dang-ky-ca.md`, PR #245–#252) và chấm công (`docs/ke-hoach-cham-cong.md`, PR #233–#240).

## 1. Yêu cầu của grace (nguyên văn rút gọn)

1. Tất cả nhân viên **bắt buộc đăng ký ca trước thứ Sáu**; ai không đăng ký thì theo sắp xếp của admin/root.
2. Sau khi admin/root **duyệt**, có nút **Phát hành (Publish)**: bắn thông báo lịch làm việc cho nhân viên. Sau khi phát hành, nhân viên **không được CRUD lịch**. Nếu admin/root sửa lịch đã phát hành của nhân viên nào, **nhân viên đó nhận thông báo "lịch đã thay đổi"**.
3. Mọi thay đổi **update/delete** của tính năng này phải có **popup xác nhận** và **lưu lịch sử vào bảng riêng**.

## 2. Tóm tắt kết quả

| Phần | Làm gì | Có sẵn hay mới |
| --- | --- | --- |
| Hạn chót | Dùng cửa sổ đăng ký có sẵn (`close_days_before`). "Trước thứ Sáu" = đặt `close_days_before = 3` (đóng 00:00 thứ Sáu giờ VN). Thêm "đã nộp đăng ký / tuần này không làm", danh sách **ai chưa đăng ký**, nhắc trước hạn, báo quản lý sau hạn. | Mở rộng |
| Trạng thái tuần | Mỗi (chi nhánh, tuần) là **Nháp** hoặc **Đã phát hành** (bảng `schedule_weeks`). Nhân viên chỉ thấy ca của tuần đã phát hành hoặc tuần đã bắt đầu. | Mới |
| Phát hành | Nút "Phát hành lịch tuần" trên Lịch ca, có popup xác nhận; đơn còn chờ duyệt bị từ chối kèm ghi chú; mỗi nhân viên nhận một thông báo. Thứ Hai 00:05 tuần nào còn nháp thì tự phát hành. | Mới |
| Khóa | Tuần đã phát hành: nhân viên không gửi/hủy đăng ký được (`week_published`). Muốn đổi thì xin nghỉ (đã có) hoặc nhắn quản lý. | Mới |
| Thông báo | Bảng `notifications` dùng chung (không riêng ca), chuông trên header admin, đếm chưa đọc, đánh dấu đã đọc. Hỏi lại mỗi 60 giây + khi quay lại tab (chưa dùng Realtime). | Mới |
| Sửa sau phát hành | Quản lý vẫn thêm/sửa/xóa ca được; popup xác nhận có ô **lý do** (tùy chọn); người bị ảnh hưởng nhận "Lịch tuần … đã thay đổi" (gộp thành 1 thông báo chưa đọc mỗi người mỗi tuần). | Mới |
| Lịch sử | Bảng riêng `schedule_history` (chỉ thêm, không sửa/xóa), ghi bằng **trigger** nên mọi đường (RPC, copy tuần, duyệt hàng loạt, cron, SQL Editor) đều được ghi. Trang "Lịch sử lịch ca". | Mới |
| Popup xác nhận | Mọi thao tác sửa/xóa/hủy/duyệt/từ chối/phát hành/lưu cài đặt của tính năng dùng `DialogConfirm` có sẵn qua một composable chung. | Mới (UI) |

**Mặc định không đổi gì khi merge**: phát hành bật theo chi nhánh (`require_publish`, mặc định **tắt**). Khi tắt, mọi thứ chạy như hôm nay (nhân viên thấy ca ngay khi được xếp). Lịch sử và thông báo hạ tầng thì chạy luôn (chỉ ghi thêm, không chặn gì).

**SQL cần chạy**: 4 migration mới `20261113010000_notifications.sql`, `20261113020000_schedule_history.sql`, `20261113030000_schedule_publish.sql`, `20261113040000_schedule_reminders.sql`. Số lớn hơn migration mới nhất trên main hôm nay (`20261112030000_shift_request_review.sql`). Workflow "Supabase migrate" tự chạy khi merge, grace không phải dán tay. Trước khi merge mỗi PR có migration: `ls supabase/migrations` trên `origin/main`, nếu có số lớn hơn thì đổi số file của PR.

## 3. Đối chất yêu cầu: chỗ hở và cách chốt

Những chỗ grace chưa nói, đã tự chốt theo ý dễ đoán nhất (grace muốn chủ động). Chỗ nào grace muốn khác thì đổi được bằng cài đặt, không phải sửa code, trừ khi ghi khác.

| # | Câu hỏi | Chốt | Lý do |
| --- | --- | --- | --- |
| P-Q1 | "Trước thứ Sáu" là thứ Sáu của tuần nào, mấy giờ? | Thứ Sáu **của tuần trước tuần làm việc**, đóng lúc **00:00 thứ Sáu giờ VN** (tức hết thứ Năm). Đặt `close_days_before = 3` ở Cài đặt > Đăng ký ca. Nếu ý grace là "hết ngày thứ Sáu" thì đặt `2` (đóng 00:00 thứ Bảy). | Cửa sổ có sẵn tính theo ngày trước thứ Hai, giờ VN, một hàm SQL duy nhất (`shift_registration_window`). Không thêm giờ lẻ (VD 12:00 thứ Sáu) ở đợt này. |
| P-Q2 | Hạn chót theo tuần hay theo chi nhánh? | **Theo chi nhánh**, áp cho **mọi tuần** (đã như vậy). Tuần nào cũng có hạn riêng = thứ Hai của tuần đó trừ `close_days_before`. | Một cửa hàng; không cần hạn riêng từng tuần. |
| P-Q3 | "Tất cả nhân viên" là ai? | Mọi người có dòng `staff_branches` tại chi nhánh, **trừ**: người có `attendance CREATE` tại chi nhánh đó (quản lý tự xếp mình), và người được **miễn đăng ký** (bảng `shift_registration_exemptions`, quản lý tick, VD nhân viên toàn thời gian ca cố định). | Không ép quản lý tự đăng ký cho mình; nhân viên ca cố định không phải bấm mỗi tuần. |
| P-Q4 | Thế nào là "đã đăng ký"? | Trong tuần đó tại chi nhánh có **ít nhất một đơn** (chờ / duyệt / từ chối) **hoặc** bấm **"Tuần này tôi không làm được ca nào"** (lưu ở `shift_registration_submissions`, kind `none`, kèm lý do). Đơn đã hủy không tính. | Phân biệt "quên đăng ký" với "chủ động báo nghỉ cả tuần"; không có cách này thì người nghỉ cả tuần luôn bị tính là chưa đăng ký. |
| P-Q5 | Người không đăng ký thì sao? "Theo sắp xếp của admin" là tự động? | **Không tự xếp ca bằng thuật toán**. Sau hạn, quản lý thấy danh sách "Chưa đăng ký (N)" trên Lịch ca, tên những người đó có chấm cam trên lưới; quản lý xếp tay như hôm nay. Có nút phụ **"Xếp như tuần trước"** cho từng người chưa đăng ký (dùng lại logic `copy_roster_week` nhưng chỉ một người, bỏ qua ô trùng). Người đó không bị phạt hay khóa gì. | "Theo sự sắp xếp của admin" = quản lý quyết. Auto-schedule công bằng (chia đều giờ, xoay ca cuối tuần) là bài toán lớn, đã để ngoài phạm vi ở plan đăng ký ca; giữ nguyên. |
| P-Q6 | Nhắc nhân viên trước hạn? | Có: thông báo trong app **24 giờ trước hạn** cho người chưa đăng ký (một lần mỗi người mỗi tuần). Sau hạn, mỗi quản lý chi nhánh nhận **một** thông báo "N người chưa đăng ký ca tuần …". | Không có nhắc thì "bắt buộc" khó thành thật. Không gửi email/Zalo (chưa có tích hợp). |
| P-Q7 | "Duyệt" là duyệt gì? | Duyệt **từng đơn đăng ký** (đã có). **Phát hành** là bước chốt cả tuần, tách riêng. Không có bước "duyệt lịch" thứ ba. | Thêm bước nữa chỉ thêm bấm. Nút phát hành chính là chữ ký của quản lý. |
| P-Q8 | "admin/root" là ai trong hệ phân quyền? | Người có **`attendance CREATE`** tại chi nhánh (cùng quyền duyệt đơn, xếp ca), cộng tài khoản `admin` / `superAdmin` (đã luôn qua `can_attendance`). Không thêm quyền mới. Muốn chỉ admin/root mới được thì bỏ tick CREATE ở vai trò quản lý. | Danh sách method quyền đang cố định (`CREATE, VIEW, UPDATE, DELETE, IMPORT, EXPORT, SETTING`); thêm method `PUBLISH` phải sửa ràng buộc `roles` và màn ma trận quyền, không đáng. |
| P-Q9 | Trước khi phát hành nhân viên thấy gì? | Khi chi nhánh bật phát hành: **không thấy ca của tuần nháp** ở "Ca của tôi", "Hôm nay", trang Đăng ký ca; đơn của mình hiện **"Đã gửi, chờ phát hành"** thay vì Đã duyệt / Từ chối. Sau phát hành thấy hết. | Giống Deputy/When I Work: lịch chưa chốt thì chưa đưa ra, tránh nhân viên thấy rồi quản lý đổi. |
| P-Q10 | Quản lý quên phát hành, tuần đã tới? | Tuần **đã bắt đầu luôn được coi là hiện** với nhân viên (để vào ca chấm công được). Cron **00:05 thứ Hai** tự phát hành tuần còn nháp (`auto = true`), gửi thông báo như phát hành tay, ghi lịch sử "Tự phát hành". Chủ nhật 18:00 nhắc quản lý nếu tuần sau còn nháp. | Không bao giờ để nhân viên đi làm mà không thấy ca; chấm công (`clock_in`) không phải sửa. |
| P-Q11 | Phát hành khi còn đơn chờ duyệt? | Popup xác nhận ghi rõ "Còn N đăng ký chờ duyệt sẽ bị **từ chối** với ghi chú 'Không được xếp khi phát hành lịch'". Đồng ý thì từ chối hết rồi phát hành trong **một transaction**. | Sau phát hành không còn đơn treo; nhân viên biết rõ kết quả. |
| P-Q12 | Phát hành tuần không có ca nào? | Được, popup cảnh báo "Tuần này chưa có ca nào". | Chi nhánh có thể nghỉ cả tuần (Tết). |
| P-Q13 | Thu hồi phát hành (unpublish)? | **Không có**. Đã phát hành thì sửa trực tiếp, nhân viên bị ảnh hưởng nhận thông báo. | Thu hồi làm nhân viên rối ("lịch đâu rồi?"); sửa + thông báo đủ dùng. |
| P-Q14 | "Nhân viên không có quyền CRUD lịch" gồm những gì? | Với **tuần đã phát hành**: không gửi đăng ký, không hủy đăng ký, không bấm "tuần này không làm" (`week_published`). Nhân viên vốn **không** sửa được `shift_assignments` (chỉ quản lý), giữ nguyên. **Lịch rảnh** (mẫu lặp theo thứ) **vẫn sửa được**: nó không phải lịch của tuần nào, chỉ là thông tin cho các tuần sau. | Đúng ý "khóa lịch đã chốt" mà không khóa thông tin dài hạn. |
| P-Q15 | Sau phát hành nhân viên cần đổi ca / nghỉ đột xuất? | Dùng **đơn nghỉ phép** có sẵn (vẫn mở sau phát hành). Quản lý duyệt nghỉ rồi tự sửa lịch → người bị ảnh hưởng nhận thông báo thay đổi. **Đổi ca giữa hai nhân viên (swap)** để đợt sau. | Có đường thoát hợp lệ, không cần tính năng mới. |
| P-Q16 | Sửa lịch đã phát hành báo cho ai, báo thế nào? | Báo **người có ca bị thêm / sửa / xóa** (nếu ca bị chuyển ngày thì vẫn một người). Mỗi người mỗi tuần mỗi chi nhánh chỉ có **một** thông báo "đã thay đổi" chưa đọc: sửa tiếp thì cập nhật nội dung + đếm số thay đổi + đẩy lên đầu, không tạo thêm. Nội dung: "Lịch tuần 17/11–23/11 tại Pawtiny Q1 đã thay đổi (3 thay đổi). Lý do: …". Bấm vào mở "Ca của tôi" tuần đó. Chỉ sửa ghi chú ca cũng báo. | Tránh 10 thông báo khi quản lý sửa 10 ô liên tiếp. |
| P-Q17 | Có báo khi chi nhánh **không** bật phát hành? | Không có thông báo phát hành/thay đổi (lịch không có mốc chốt). Lịch sử vẫn ghi. | Giữ hành vi cũ cho chi nhánh chưa bật. |
| P-Q18 | Kênh thông báo? | **Trong app** (bảng `notifications`, chuông header admin). Không push, email, Zalo, SMS. Realtime để sau (mục 13). | Chưa có tích hợp ngoài (đã chốt từ đầu dự án); gói Free; nhân viên mở admin mỗi ngày để vào ca. |
| P-Q19 | Đã đọc / chưa đọc? | Có: `read_at`; badge số chưa đọc trên chuông; "Đánh dấu tất cả đã đọc"; bấm thông báo thì tự đánh dấu đọc. | Cần để badge có nghĩa. |
| P-Q20 | Lịch sử ghi những gì? | **Thêm, sửa, xóa** ca đã xếp (`shift_assignments`); **mọi đổi trạng thái** đơn đăng ký (gửi, hủy, duyệt, từ chối); **phát hành / tự phát hành**; nộp "tuần này không làm"; lưu **cài đặt** đăng ký ca / phát hành; **miễn đăng ký**; **lịch rảnh** (một dòng mỗi lần lưu, trước/sau dạng mảng). Ghi cả *thêm* dù grace chỉ nói sửa/xóa, vì "ai đã xếp ca này" là câu hỏi hay gặp nhất và chi phí gần như bằng 0. | Một bảng duy nhất cho cả tính năng, trả lời được "ai đổi gì, lúc nào, vì sao". |
| P-Q21 | Ca mẫu (`shift_templates`) và chấm công (vào/ra ca, sửa giờ) có ghi vào bảng này? | **Không**. Ca mẫu là cấu hình; sửa giờ chấm công đã có nhật ký riêng (`time_entry_changes` của module chấm công). Popup xác nhận khi sửa/ngừng ca mẫu thì **có** thêm (UI). | Giữ phạm vi "lịch làm việc"; không ghi trùng chỗ đã có nhật ký. |
| P-Q22 | Lịch sử giữ bao lâu, ai xem? | **Giữ mãi** (vài nghìn dòng/năm, nhỏ so với 500 MB gói Free; xem lại khi > 100k dòng). Không ai sửa/xóa được qua API. Xem: người có `attendance VIEW` tại chi nhánh. Nhân viên không xem trang lịch sử (họ có thông báo). | Nhật ký phải đáng tin: chỉ thêm. |
| P-Q23 | Thông báo giữ bao lâu? | Cron hằng ngày xóa thông báo **đã đọc > 90 ngày** và **mọi thông báo > 180 ngày**. | Bảng thông báo không phình mãi; lịch sử thật nằm ở `schedule_history`. |
| P-Q24 | Popup xác nhận cho cả "thêm ca"? | Thêm ca vào tuần **nháp**: không cần (grace chỉ nói update/delete). Thêm ca vào tuần **đã phát hành**: **có** (vì nó bắn thông báo). | Đúng yêu cầu, không thêm bấm vô ích. |
| P-Q25 | Lý do khi sửa sau phát hành bắt buộc? | **Tùy chọn** (ô lý do trong popup). Có thì hiện trong thông báo và lịch sử. | Bắt buộc dễ thành gõ "." cho qua. |
| P-Q26 | Dữ liệu cũ khi bật phát hành? | Lúc bật `require_publish`, hộp xác nhận liệt kê các tuần **tương lai** đã có ca ("Tuần 17/11 có 32 ca sẽ bị ẩn với nhân viên cho tới khi phát hành") và có ô tick **"Phát hành luôn các tuần này (không gửi thông báo)"**, mặc định tick. Tuần hiện tại và quá khứ luôn hiện (P-Q10). | Bật tính năng không làm "mất" ca nhân viên đang thấy. |

### Câu hỏi còn mở (không chặn, đã chọn mặc định)

1. "Trước thứ Sáu" là đóng **00:00 thứ Sáu** (mặc định trong plan, `close_days_before = 3`) hay **hết thứ Sáu** (`2`)? Chỉ là một số trong Cài đặt.
2. Nhân viên có nên thấy **Đã duyệt / Từ chối** ngay khi quản lý bấm, hay chỉ sau khi phát hành (plan chọn: sau khi phát hành)? Đổi được bằng một nhánh `case` trong `shift_registration_board`.

## 4. Hiện trạng liên quan (đã đọc code)

- Cửa sổ đăng ký: `shift_registration_settings(is_open, weeks_ahead, close_days_before, max_shifts_per_week, staff_note)`, `shift_registration_window(branch, monday)` trả `{open, closes_at, reason}`.
- Đơn: `shift_requests` (`pending/approved/rejected/cancelled`), `submit_shift_requests`, `cancel_shift_request`, `decide_shift_requests`, `list_shift_requests`, `pending_shift_request_count`, `shift_registration_board`, `my_shift_requests`.
- Ca: `shift_assignments`, sửa qua `assign_shift`, `update_shift_assignment`, `remove_shift_assignment`, `copy_roster_week` (có xóa khi `p_overwrite`), và `decide_shift_requests` (chèn khi duyệt). Quyền: `can_attendance(method, branch)`.
- Nhân viên đọc: `my_schedule(from, to)`, trang "Hôm nay"/"Của tôi", `clock_in` (tìm ca gần nhất của mình).
- Lịch rảnh: `staff_availability`, `replace_availability`, `save_my_availability`, `save_staff_availability`.
- Chưa có: bảng thông báo, bảng lịch sử chung, trạng thái tuần. `pg_cron` đã dùng (`close-stale-time-entries`, tự hủy đơn online, tự hủy lịch spa).
- Web: `features/admin/attendance/{roster,register,requests,me,settings,availability,shared}`; `DialogConfirm` trong `components/common`; badge sidebar trong `layouts/admin.vue`.
- Mock: `supabase/mock/mock-shift-seed.sql` / `mock-shift-cleanup.sql` (chi nhánh `MOCKCA`, 10 nhân viên `mock-ca-*@mock.invalid`).

## 5. Luồng người dùng

**Nhân viên (chi nhánh đã bật phát hành)**

1. Thứ Hai–thứ Năm: vào **Đăng ký ca**, thanh trên ghi "Hạn chót 00:00 thứ Sáu 14/11 (còn 2 ngày)". Tick ô, gửi; hoặc bấm **"Tuần này tôi không làm được ca nào"** (hộp nhập lý do, có popup xác nhận). Trạng thái tuần: "Đã nộp" / "Chưa nộp".
2. Thứ Năm 00:00 (24 giờ trước hạn) nếu chưa nộp: chuông có thông báo "Còn 1 ngày để đăng ký ca tuần 17/11–23/11".
3. Sau hạn: trang hiện "Đã hết hạn đăng ký, chờ quản lý phát hành lịch". Đơn hiện "Đã gửi, chờ phát hành".
4. Quản lý phát hành: chuông "Lịch tuần 17/11–23/11 đã phát hành: bạn có 4 ca" (hoặc "bạn không có ca nào tuần này"). Bấm mở "Ca của tôi" đúng tuần. Đơn hiện trạng thái thật.
5. Tuần đã phát hành: lưới đăng ký chỉ đọc, banner "Lịch đã phát hành. Cần đổi ca? Gửi đơn nghỉ hoặc liên hệ quản lý" (link sang Nghỉ phép).
6. Quản lý sửa ca của mình: chuông "Lịch tuần … đã thay đổi (2 thay đổi). Lý do: …".

**Quản lý (`attendance CREATE`)**

1. **Lịch ca**: trên thanh công cụ có **nhãn trạng thái tuần** (Nháp xám / Đã phát hành xanh, "phát hành 20:15 thứ Bảy bởi Grace"), nút **"Chưa đăng ký (3)"** mở ngăn bên với tên, nút "Xếp như tuần trước", và nút **"Phát hành lịch"**.
2. Bấm Phát hành → popup: số ca, số nhân viên nhận thông báo, số đơn chờ sẽ bị từ chối, số người chưa đăng ký chưa có ca; nút **Phát hành**.
3. Sửa/xóa ca ở tuần đã phát hành: popup "Lịch tuần này đã phát hành. Nguyễn Minh Anh sẽ nhận thông báo thay đổi." + ô lý do. Sửa/xóa ở tuần nháp: popup xác nhận thường (không lý do).
4. **Copy tuần** vào tuần đã phát hành: popup ghi số người sẽ nhận thông báo; ghi đè (`p_overwrite`) luôn có popup xác nhận.
5. **Lịch sử lịch ca** (trang mới, `attendance VIEW`): bảng lọc theo tuần, nhân viên, loại thao tác, người làm; mỗi dòng mở xem trước/sau. Từ ô trên lưới có mục "Lịch sử ô này".
6. **Cài đặt > Đăng ký ca**: thêm công tắc **"Bắt buộc phát hành lịch"**, danh sách **miễn đăng ký** (chọn nhân viên).

## 6. Mô hình dữ liệu

Như các module trước: bật RLS, `revoke all from anon, authenticated`, chỉ `grant select` có policy; mọi ghi qua RPC `security definer`; lỗi trả `errcode` + `hint`; migration idempotent.

### 6.1 `notifications` (migration 1, dùng chung cho mọi module sau này)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | uuid PK | |
| `user_id` | uuid → `public.users` on delete cascade | người nhận |
| `branch_id` | uuid null → `branches` on delete cascade | |
| `kind` | text | `schedule_published`, `schedule_changed`, `registration_reminder`, `registration_missing`, `publish_reminder` (check bằng danh sách; thêm loại mới = migration mới) |
| `title` | text | ≤ 120, tiếng Việt, ghép sẵn trong SQL |
| `body` | text null | ≤ 500 |
| `link` | jsonb null | `{ "name": "attendanceMe", "query": { "week": "2026-11-17" } }`: tên route + query, web tự dựng URL |
| `data` | jsonb default `{}` | `{week_monday, change_count, reason, shift_count}` |
| `dedupe_key` | text null | unique khi khác null: `reminder:<branch>:<monday>:<user>`, `changed:<branch>:<monday>:<user>` (chỉ khi chưa đọc, xem 7.1) |
| `read_at` | timestamptz null | |
| `created_at`, `updated_at` | timestamptz | |

Chỉ mục `(user_id, created_at desc)`, `(user_id) where read_at is null`. Policy đọc: `user_id = auth.uid()`.

### 6.2 `schedule_history` (migration 2)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | bigint identity PK | thứ tự chắc chắn |
| `branch_id` | uuid null → `branches` on delete cascade | null cho lịch rảnh (theo người) |
| `week_monday` | date null | thứ Hai của `work_date` (hoặc tuần được phát hành) |
| `entity` | text | `assignment`, `request`, `week`, `submission`, `settings`, `exemption`, `availability` |
| `entity_id` | text null | id dòng (uuid dạng text; `branch_id` cho settings) |
| `action` | text | `insert`, `update`, `delete`, `submit`, `cancel`, `approve`, `reject`, `publish`, `auto_publish`, `declare_none`, `replace` |
| `actor_id` | uuid null (không FK, để dòng sống sau khi xóa người) | `auth.uid()`; null = hệ thống (cron, SQL Editor) |
| `actor_name` | text | chụp `staff_display_name`, `'Hệ thống'` khi null |
| `target_user_id`, `target_user_name` | uuid null, text null | nhân viên có ca/đơn bị đổi |
| `before`, `after` | jsonb null | ảnh dòng trước/sau (bỏ `updated_at`) |
| `changed_fields` | text[] | với `update`: các cột khác nhau |
| `reason` | text null | ≤ 300, lý do quản lý nhập |
| `source` | text null | tên RPC (`update_shift_assignment`, `copy_roster_week`, `cron:auto_publish`…) |
| `was_published` | boolean default false | thay đổi xảy ra khi tuần đã phát hành (lọc nhanh "sửa sau phát hành") |
| `created_at` | timestamptz default now() | |

Chỉ mục `(branch_id, week_monday, id desc)`, `(target_user_id, id desc)`, `(entity, entity_id)`. Policy đọc: `branch_id is not null and can_attendance('VIEW', branch_id)`; lịch rảnh (`branch_id` null): `can_view_staff(target_user_id)`. **Không** grant insert/update/delete cho `authenticated`; thêm trigger `before update or delete … raise exception` để cả `postgres` gõ nhầm cũng bị chặn (xóa khi thật cần: tắt trigger có chủ ý, ghi trong docs).

**Cách ghi**: hàm nội bộ `log_schedule_change(...)` và trigger:

- `shift_assignments`: `after insert or update or delete for each row` → `trg_log_shift_assignment`. Bỏ qua `update` mà không cột nào ngoài `updated_at` đổi.
- `shift_requests`: `after insert or update of status` → action theo trạng thái mới (`submit`/`cancel`/`approve`/`reject`).
- `schedule_weeks`, `shift_registration_submissions`, `shift_registration_settings`, `shift_registration_exemptions`: trigger tương tự (migration 3 gắn vào bảng của nó).
- `staff_availability`: không dùng trigger theo dòng (lưu = xóa hết + chèn lại, sẽ thành hàng chục dòng rác); `replace_availability` gọi `log_schedule_change` một lần với `action = 'replace'`, `before`/`after` là mảng.
- **Lý do và nguồn**: RPC gọi `perform set_config('app.schedule_reason', p_reason, true)` và `set_config('app.schedule_source', '<tên hàm>', true)` (phạm vi transaction); trigger đọc bằng `current_setting(..., true)`. Không có thì null.

### 6.3 `schedule_weeks` (migration 3)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `branch_id` | uuid → `branches` on delete cascade | PK cùng `week_monday` |
| `week_monday` | date | check `isodow = 1` |
| `status` | text | `draft` / `published` (không có dòng = nháp) |
| `published_at`, `published_by`, `published_by_name` | | |
| `auto_published` | boolean default false | cron phát hành |
| `notified_count` | int default 0 | số người nhận thông báo lúc phát hành |
| `updated_at` | | |

Policy đọc: `is_branch_staff(branch_id) or can_attendance('VIEW', branch_id)`.

### 6.4 Thêm cột vào `shift_registration_settings` (migration 3)

`require_publish boolean not null default false`. Viết lại `shift_registration_rules_raw` và `save_shift_registration_settings` **từ bản hiện tại trong `supabase/schema.sql`** (thêm khóa, giữ khóa cũ).

### 6.5 `shift_registration_submissions` (migration 3)

`(branch_id, user_id, week_monday)` PK, `kind` (`none`), `reason` text null ≤ 300, `created_at`. Chỉ lưu khai báo "tuần này không làm"; "đã nộp" khi có đơn được tính khi đọc từ `shift_requests`. Gửi đơn mới cho tuần đó thì xóa dòng `none` (trong `submit_shift_requests`). Policy đọc: `user_id = auth.uid() or can_attendance('VIEW', branch_id)`.

### 6.6 `shift_registration_exemptions` (migration 3)

`(branch_id, user_id)` PK, `note` text null, `created_by`, `created_at`. Policy đọc: `can_attendance('VIEW', branch_id) or user_id = auth.uid()`.

## 7. Hàm SQL

Giờ VN mọi chỗ: "hôm nay" = `(now() at time zone 'Asia/Ho_Chi_Minh')::date`, thứ Hai = `date_trunc('week', …)::date`. Hàm cũ bị viết lại thì **chép từ `supabase/schema.sql`** rồi sửa (luật CLAUDE.md).

### 7.1 Migration 1 — `20261113010000_notifications.sql` (PR N1)

- Bảng 6.1 + RLS + trigger `set_updated_at`.
- `notify_user(p_user, p_branch, p_kind, p_title, p_body, p_link, p_data, p_dedupe)` (nội bộ, revoke khỏi client): chèn; nếu `p_dedupe` trùng thì `on conflict do nothing` (nhắc nhở) — trả id hoặc null.
- `notify_schedule_changed(p_user, p_branch, p_monday, p_reason)` (nội bộ): tìm thông báo `schedule_changed` **chưa đọc** cùng (user, branch, tuần); có thì tăng `data.change_count`, cập nhật `body`, `reason`, `created_at = now()`; không có thì chèn mới. Dedupe bằng truy vấn có `for update`, không dùng unique (vì sau khi đọc phải tạo được cái mới).
- `my_notifications(p_page int default 1, p_page_size int default 20, p_unread_only boolean default false) → jsonb {rows, total, unread}`.
- `unread_notification_count() → int`.
- `mark_notifications_read(p_ids uuid[] default null)` — null = tất cả của mình. Trả số dòng.
- `cleanup_notifications()` (nội bộ) + `cron.schedule('cleanup-notifications', '30 19 * * *', …)` (02:30 giờ VN): xóa đã đọc > 90 ngày, mọi dòng > 180 ngày.

pgTAP `supabase/tests/notifications.test.sql`: chỉ thấy của mình; đánh dấu đọc của người khác không có tác dụng; dedupe nhắc nhở; gộp `schedule_changed` khi chưa đọc, tạo mới sau khi đã đọc; client không gọi được `notify_user`; cleanup.

### 7.2 Migration 2 — `20261113020000_schedule_history.sql` (PR H1)

- Bảng 6.2 + RLS + trigger chặn sửa/xóa.
- `week_of(p_date date) → date` (immutable, thứ Hai).
- `log_schedule_change(p_branch, p_week, p_entity, p_entity_id, p_action, p_target, p_before, p_after)` (nội bộ): điền `actor_*`, `reason`, `source` từ `current_setting`, `changed_fields` (so khóa của hai jsonb), `was_published` (tra `schedule_weeks` nếu bảng đã có — migration 2 tạo sẵn hàm `week_is_published(branch, monday)` trả false, migration 3 viết lại).
- Trigger trên `shift_assignments`, `shift_requests`; sửa `replace_availability` (chép từ schema.sql) để gọi log một lần.
- Thêm tham số **`p_reason text default null`** cho `update_shift_assignment`, `remove_shift_assignment`, `assign_shift`, `copy_roster_week`, `decide_shift_requests`: tạo **hàm mới cùng tên có thêm tham số** thì PostgREST sẽ thấy hai overload và lỗi mơ hồ. Cách làm: `drop function` bản cũ rồi `create` bản có `p_reason ... default null` trong cùng migration (chữ ký mới nhận được lời gọi cũ vì tham số cuối có mặc định); `grant execute` lại. Web cũ vẫn gọi được trong lúc deploy.
- `schedule_history_list(p_branch uuid, p_from date, p_to date, p_user uuid default null, p_entity text default null, p_published_only boolean default false, p_page int default 1, p_page_size int default 30) → jsonb {rows, total}` — `VIEW`; `p_branch` null → `attendance_branch_ids(null, 'VIEW')`, **không** `has_permission(..., null)`.
- `schedule_history_of(p_entity text, p_entity_id text) → jsonb` — lịch sử một ca/đơn (cho "Lịch sử ô này").

pgTAP `supabase/tests/schedule_history.test.sql`: gán/sửa/xóa ca sinh 3 dòng đúng `action`, `changed_fields`, `actor_name`; lý do đi qua `set_config`; copy tuần ghi đè sinh `delete` + `insert` với `source = copy_roster_week`; duyệt/từ chối/hủy đơn; lưu lịch rảnh 1 dòng `replace`; `update`/`delete` vào `schedule_history` bị chặn kể cả postgres; quản lý chi nhánh A không đọc được dòng chi nhánh B; `schedule_history_list(null, …)` chỉ trả chi nhánh mình có quyền (thêm vào `attendance_branch_scope.test.sql`); lời gọi kiểu cũ (không `p_reason`) vẫn chạy.

### 7.3 Migration 3 — `20261113030000_schedule_publish.sql` (PR P1)

- Bảng 6.3, 6.5, 6.6, cột 6.4, trigger lịch sử cho các bảng mới.
- `week_is_published(p_branch, p_monday) → boolean` (viết lại): `require_publish = false` → true (chi nhánh không dùng phát hành thì coi như luôn công khai); ngược lại `status = 'published'` **hoặc** `p_monday <= thứ Hai tuần hiện tại` (P-Q10).
- `staff_must_register(p_branch, p_user) → boolean` (nội bộ): thuộc `staff_branches`, không có `attendance CREATE` tại chi nhánh (kiểm bằng hàm quyền theo user, không theo `auth.uid()`: không có sẵn hàm quyền theo user nên viết hàm nội bộ `user_has_attendance(p_user, p_method, p_branch)` chép logic từ `has_permission` trong schema.sql, thay `auth.uid()` bằng `p_user`), không có dòng miễn.
- `registration_status(p_branch, p_monday) → jsonb` — `VIEW`: `[{user_id, name, must_register, state: 'submitted' | 'declared_none' | 'missing' | 'exempt' | 'manager', request_count, assigned_count}]` + `missing_count`, `closes_at`.
- `declare_no_shifts(p_branch, p_monday, p_reason)` — nhân viên; cửa sổ mở; tuần chưa phát hành (`week_published`); không còn đơn `pending`/`approved` trong tuần (`has_requests`, popup gợi ý hủy đơn trước).
- `withdraw_no_shifts(p_branch, p_monday)` — bỏ khai báo (cùng điều kiện).
- `publish_schedule_week(p_branch, p_monday, p_reject_note text default 'Không được xếp khi phát hành lịch') → jsonb {notified, rejected, shifts}` — `CREATE`; `require_publish` bật (`publish_disabled`); chưa phát hành (`already_published`); một transaction: khóa dòng `schedule_weeks` (`insert … on conflict … for update`), từ chối mọi đơn `pending` của tuần (qua cùng đường với `decide_shift_requests` để có lịch sử), đặt `published`, gửi `schedule_published` cho **mọi người `staff_branches` của chi nhánh có ca tuần đó hoặc phải đăng ký** (tiêu đề có số ca), ghi `notified_count`.
- `publish_past_weeks(p_branch)` (nội bộ, gọi từ `save_shift_registration_settings` khi `require_publish` chuyển false → true và `p_publish_existing = true`): đánh dấu đã phát hành mọi tuần tương lai đang có ca, **không** gửi thông báo, lịch sử `publish` với `reason = 'Bật phát hành lịch'`.
- `schedule_week_status(p_branch, p_monday) → jsonb` — nhân viên chi nhánh hoặc VIEW: `{require_publish, status, published_at, published_by_name, auto_published, pending_requests, missing_count}`.
- **Khóa nhân viên**: viết lại `submit_shift_requests` và `cancel_shift_request` (chép từ schema.sql): nếu `require_publish` và tuần đã `published` → `week_published`. `submit_shift_requests` xóa dòng `none` của tuần đó khi tạo được ít nhất một đơn.
- **Ẩn tuần nháp với nhân viên**: viết lại `my_schedule` (lọc `week_is_published(a.branch_id, week_of(a.work_date))`), `shift_registration_board` (ca chỉ hiện khi đã phát hành; đơn `approved`/`rejected` hiện `status = 'submitted'` khi chưa phát hành, thêm khóa `week: schedule_week_status(...)` và `submission`), `my_shift_requests` (cùng luật). `clock_in` **không đổi** (nhờ P-Q10). Nếu "Hôm nay"/widget dashboard của nhân viên đọc `shift_assignments` qua hàm khác thì sửa theo cùng luật — coder `grep` `from public.shift_assignments` trong `schema.sql` để soát hết hàm phía nhân viên.
- **Thông báo thay đổi**: trigger `after insert or update or delete on shift_assignments` (riêng với trigger lịch sử) → nếu `week_is_published` **và** chi nhánh bật `require_publish` **và** `current_setting('app.schedule_publishing', true)` khác `'on'` (để bước phát hành không tự báo "thay đổi") → `notify_schedule_changed(user, branch, tuần, reason)`. Update chuyển ca sang tuần khác: báo cả tuần cũ và tuần mới.
- `assign_to_previous_week(p_branch, p_monday, p_user, p_reason)` — `CREATE`: chép ca của **một** người từ tuần trước (logic `copy_roster_week` không ghi đè, chỉ người đó) → `{copied, skipped}`.
- Exemption: `set_registration_exemption(p_branch, p_user, p_exempt boolean, p_note)` — `SETTING`.
- `save_shift_registration_settings` thêm khóa `require_publish` và tham số tùy chọn `publish_existing` trong `p`.

Mã lỗi mới: `week_published`, `publish_disabled`, `already_published`, `has_requests`. Thêm vào `ATTENDANCE_ERROR_HINTS` và i18n `admin.attendance.errors.*` (vi + en).

pgTAP `supabase/tests/schedule_publish.test.sql`: tắt `require_publish` → mọi thứ như cũ (nhân viên thấy ca ngay, không thông báo); bật → nhân viên không thấy ca tuần nháp tương lai, thấy tuần hiện tại; phát hành từ chối đơn chờ + gửi đúng số thông báo + đơn hiện trạng thái thật; phát hành lần hai `already_published`; nhân viên gửi/hủy đơn tuần đã phát hành → `week_published`; sửa ca tuần đã phát hành sinh **một** thông báo gộp cho người đó sau 3 lần sửa, đổi người không bị báo; sửa tuần nháp không báo; `declare_no_shifts` với đơn đang chờ → `has_requests`; `registration_status` phân loại đúng (quản lý, miễn, chưa nộp, đã nộp, không làm); bật `require_publish` với `publish_existing` phát hành các tuần tương lai có ca, không thông báo; nhân viên thường không phát hành được; quản lý chi nhánh B không phát hành tuần của A.

### 7.4 Migration 4 — `20261113040000_schedule_reminders.sql` (PR P3)

- `run_registration_reminders()` (nội bộ): với mỗi chi nhánh `is_open` và tuần mục tiêu có `closes_at` trong `(now(), now() + 24h]`: gửi `registration_reminder` cho người `staff_must_register` mà trạng thái `missing` (dedupe `reminder:<branch>:<monday>:<user>`). Với tuần có `closes_at` trong 1 giờ vừa qua: gửi `registration_missing` cho người có `attendance CREATE` tại chi nhánh nếu `missing_count > 0` (dedupe `missing:<branch>:<monday>:<manager>`).
- `run_publish_reminders()`: Chủ nhật 18:00 VN, tuần sau còn nháp ở chi nhánh bật phát hành → `publish_reminder` cho quản lý (dedupe).
- `auto_publish_started_weeks()`: tuần hiện tại còn nháp ở chi nhánh bật phát hành → gọi lõi của `publish_schedule_week` với `auto = true`, actor null, `source = 'cron:auto_publish'`.
- `cron.schedule`: `registration-reminders` mỗi giờ phút 10; `publish-reminders` `0 11 * * 0` (18:00 VN Chủ nhật); `auto-publish-weeks` `5 17 * * 0` (00:05 VN thứ Hai). Lịch cron chạy theo UTC; ghi chú giờ VN trong migration. `cron.unschedule` trước khi `schedule` để idempotent.

pgTAP `supabase/tests/schedule_reminders.test.sql`: gọi thẳng các hàm với tuần dựng sẵn (không chờ cron); nhắc một lần dù chạy hai lần; người miễn/đã nộp không bị nhắc; tự phát hành ghi `auto_published` và lịch sử `auto_publish`.

Sau mỗi migration: `npm run db:start`, `npm run db:test`, `npm run db:schema`, commit `supabase/schema.sql` và `database.types.ts`.

## 8. Hợp đồng và lớp truy vấn

```
packages/core/src/notifications/
  types.ts  contract.ts (zod: Notification, NotificationPage)  link.ts (thuần: link → route)  link.test.ts  index.ts
packages/core/src/attendance/
  publishTypes.ts             // WeekStatus, RegistrationStatusRow, PublishResult, Submission
  publish.ts                  // thuần: weekStatusLabel, publishSummary(counts), canStaffEdit(week)
  publish.test.ts
  historyTypes.ts  history.ts // thuần: diffRows(before, after, fields) → [{field, from, to}], actionLabel
  history.test.ts
  contract/publish.ts  contract/history.ts
  contract/registration.ts    // Board thêm week, submission với .default
packages/supabase/src/notifications/  notifications.ts  mappers.ts  index.ts
packages/supabase/src/attendance/     publish.ts  history.ts  publishMappers.ts
apps/web/tests/db/  notifications.contract.test.ts  attendancePublish.contract.test.ts
```

Không nhồi thêm vào `types.ts`, `mappers.ts`, `registrationTypes.ts` nếu file đã gần 300 dòng; tạo file mới, export qua barrel. Thêm luật dependency-cruiser nếu tạo feature `notifications` mới (như 18 feature hiện có).

## 9. Cấu trúc code web

Luật tách file: page là vỏ mỏng; state/data trong `useXxx`; hàm thuần trong helpers; kiểu ở file riêng; mỗi file < ~300 dòng; nút trên thanh công cụ là component riêng.

```
apps/web/src/features/notifications/            // feature mới, dùng chung
  NotificationBell.vue          // icon + badge, mở popover
  NotificationPopover.vue       // 10 thông báo mới nhất, "Đánh dấu tất cả đã đọc", "Xem tất cả"
  NotificationItem.vue
  NotificationListPage.vue      // /admin/notifications: PagedTableCard, lọc chưa đọc
  useNotifications.ts  useUnreadCount.ts (refetchInterval 60s, refetchOnWindowFocus)  useOpenNotification.ts
  queries/notifications.ts  index.ts
apps/web/src/components/common/
  useConfirmAction.ts           // bọc DialogConfirm: confirm({title, message, danger, reason?: {label, required:false}}) → Promise<{ok, reason}>
  ConfirmReasonDialog.vue       // DialogConfirm + ô lý do (khi cần)
apps/web/src/features/admin/attendance/
  publish/
    WeekStatusBadge.vue  PublishWeekButton.vue  PublishWeekDialog.vue
    MissingRegistrationButton.vue  MissingRegistrationDrawer.vue  MissingRegistrationRow.vue
    useWeekStatus.ts  usePublishWeek.ts  useRegistrationStatus.ts
    publishedEditConfirm.ts     // thuần: dựng câu xác nhận theo trạng thái tuần + tên người
  history/
    Index.vue  HistoryFilterFields.vue  HistoryTable.vue  HistoryRow.vue  HistoryDiff.vue
    CellHistoryDialog.vue       // mở từ menu ô trên lưới
    useHistoryList.ts  historyLabels.ts
  register/  (thêm)
    RegisterWeekStateBanner.vue // nháp / đã nộp / hết hạn / đã phát hành (chỉ đọc)
    DeclareNoShiftsButton.vue  DeclareNoShiftsDialog.vue  useDeclareNoShifts.ts
  roster/    (sửa nhỏ)
    RosterToolbar.vue gắn WeekStatusBadge, MissingRegistrationButton, PublishWeekButton
    useRosterActions.ts         // gom gọi confirm trước update/remove/copy, truyền reason
  settings/  (thêm)
    PublishSettingsFields.vue  ExemptionsCard.vue  useExemptions.ts
  queries/   publish.ts  history.ts
apps/web/src/pages/admin/
  notifications.vue (name adminNotifications)  attendance/history.vue (name attendanceHistory)
```

- **Popup xác nhận**: mọi chỗ update/delete của tính năng gọi `useConfirmAction` trước khi gọi mutation: sửa ca, xóa ca, copy tuần (có ghi đè hoặc vào tuần đã phát hành), hủy đơn, duyệt/từ chối (hộp duyệt có sẵn chính là xác nhận: thêm câu "Thao tác sẽ được ghi lịch sử"), phát hành, khai báo/bỏ khai báo không làm, lưu cài đặt đăng ký ca, bật/tắt phát hành, miễn đăng ký, lưu lịch rảnh, sửa/ngừng ca mẫu. Esc đóng, Enter xác nhận (theo quy ước `AppDialog`). Nút nguy hiểm (xóa, ghi đè, phát hành) màu đỏ/cam.
- Header `layouts/admin.vue`: thêm `NotificationBell` cho **mọi** tài khoản vào được admin.
- `AttendanceNav.vue`: tab `attendanceHistory` (`method: "VIEW"`). `lib/navigations.ts` nhóm "Nhân sự": "Lịch sử lịch ca". `ADMIN_ROUTE_PERMISSIONS`: `attendanceHistory: "attendance"`; `adminNotifications` không có trong bảng (ai cũng mở được, như `attendanceMe`). Cập nhật `permissions.parity.test.ts`.
- `queries/keys.ts`: `notificationKeys.all/list/unread`, `attendanceKeys.week(branch, monday)`, `registrationStatus(...)`, `history(filters)`. Mutation của lịch ca invalidate `attendanceKeys.all` (đã vậy) + `notificationKeys.unread` không cần (người sửa không phải người nhận).
- `my_schedule` có tham số `?week=` từ link thông báo: trang "Của tôi" đọc query `week` để nhảy tới tuần đó.
- i18n `vi/admin.json`, `en/admin.json`: `notifications.*`, `attendance.publish.*`, `attendance.history.*`, `attendance.confirm.*`, lỗi mới, `adminNav.*`. Tiêu đề thông báo ghép sẵn tiếng Việt trong SQL (nhân viên dùng tiếng Việt); bản en dùng `kind` + `data` để dựng câu nếu sau này cần.

## 10. Kết nối với module khác

| Chỗ | Thay đổi | PR |
| --- | --- | --- |
| Lịch ca | Nhãn trạng thái tuần, nút phát hành, danh sách chưa đăng ký, xác nhận + lý do, lịch sử ô | P2, H2 |
| Đăng ký ca (nhân viên) | Hạn chót đếm ngược, "không làm tuần này", khóa sau phát hành, trạng thái "chờ phát hành" | P2 |
| Duyệt đăng ký | Popup ghi chú "được ghi lịch sử"; đơn của tuần đã phát hành không còn chờ | H2 |
| Của tôi / Hôm nay | Ẩn ca tuần nháp; nhảy tới tuần từ thông báo | P1 (SQL), P2 |
| Chấm công / bảng công | Không đổi (`clock_in`, `attendance_rows` đọc thẳng `shift_assignments`; tuần đã bắt đầu luôn công khai) | — |
| Nghỉ phép | Không đổi; là đường hợp lệ để xin đổi sau phát hành | — |
| Dashboard | Widget "Đăng ký ca chờ duyệt" không đổi; có thể thêm "Tuần sau: Nháp / Đã phát hành, N chưa đăng ký" sau | — |
| Header admin | Chuông thông báo cho mọi người | N2 |
| Mock `MOCKCA` | Bật `require_publish`; tuần trước + tuần này đã phát hành; tuần sau nháp có đơn chờ, 2 người chưa đăng ký, 1 người "không làm"; vài thông báo mẫu cho nhân viên mock. Cleanup xóa thêm `schedule_weeks`, submissions, exemptions; thông báo và lịch sử tự đi theo khi xóa chi nhánh/người (cascade). | P4 |

## 11. Tương thích với DB đang chạy

- Chỉ **thêm** bảng, cột có mặc định, hàm; các hàm viết lại giữ nguyên chữ ký cũ hoặc thêm tham số cuối có mặc định (drop + create trong cùng migration, `grant execute` lại).
- `require_publish` mặc định `false` → sau khi merge, nhân viên vẫn thấy ca như hôm nay, không ai bị khóa, không thông báo phát hành.
- Trigger lịch sử chạy ngay sau migration 2 trên mọi chi nhánh: chỉ ghi thêm. Không backfill lịch sử cũ (không có dữ liệu "ai sửa" để backfill).
- Cron mới chỉ làm việc ở chi nhánh bật `is_open` / `require_publish`.
- Không sửa file migration cũ. Số migration `20261113*` > `20261112030000`.

## 12. Các PR (thứ tự làm)

Mỗi PR nhỏ, tự đủ, CI xanh rồi squash merge. Tiêu đề và commit tiếng Anh (Conventional Commits).

| PR | Tiêu đề gợi ý | Nội dung | Migration |
| --- | --- | --- | --- |
| S0 | `docs: plan schedule publishing, notifications and history` | File này + `docs/README.md` | — |
| N1 | `feat(notifications): add in-app notifications table and RPCs` | 7.1, pgTAP, core + supabase `notifications`, test hợp đồng | `20261113010000` |
| N2 | `feat(notifications): add notification bell and list page` | `features/notifications`, header, route, i18n, Vitest `link.ts` | — |
| H1 | `feat(attendance): record schedule change history` | 7.2, pgTAP (gồm phạm vi chi nhánh), core/supabase history, test hợp đồng | `20261113020000` |
| H2 | `feat(attendance): confirm schedule edits and show change history` | `useConfirmAction`, `ConfirmReasonDialog`, áp vào mọi thao tác ở mục 9, trang + hộp lịch sử, nav, quyền route, parity | — |
| P1 | `feat(attendance): add schedule week publishing and registration deadline tracking` | 7.3, pgTAP, core/supabase publish, test hợp đồng, mã lỗi | `20261113030000` |
| P2 | `feat(attendance): publish button, missing registrations and locked weeks` | `publish/`, phần thêm của `register/`, `roster/`, `settings/`, trang Của tôi theo `?week=` | — |
| P3 | `feat(attendance): add registration reminders and auto publish` | 7.4, pgTAP | `20261113040000` |
| P4 | `chore(mock): publish states and notifications in shift mock data` + docs mục 15 | Mock + cleanup, cập nhật file này, test tay | — |

Phụ thuộc: N2 cần N1; H1 độc lập với N1 (nhưng làm sau N1 để số migration tăng dần); H2 cần H1; P1 cần N1 + H1; P2 cần P1 + H2 + N2; P3 cần P1; P4 cần P3. Nếu chạy song song nhiều nhánh, **giữ thứ tự merge theo số migration**.

## 13. Không làm trong đợt này

- Push/email/Zalo/SMS; thông báo trong app mobile của khách. (Hạ tầng `notifications` dùng lại được khi làm.)
- Supabase **Realtime** cho chuông (hỏi lại 60 giây là đủ cho lịch tuần; thêm sau bằng kênh `postgres_changes` lọc `user_id`, RLS đã sẵn).
- Đổi ca / nhả ca / nhận ca giữa nhân viên (swap, shift pool).
- Tự xếp lịch bằng thuật toán, công bằng giờ làm, xoay ca cuối tuần.
- Thu hồi phát hành.
- Hạn chót theo giờ lẻ (VD 12:00 thứ Sáu), hạn chót khác nhau từng tuần.
- Số ca tối thiểu bắt buộc mỗi tuần (chỉ bắt buộc "đã nộp").
- Lịch sử cho ca mẫu và chấm công (đã có nhật ký riêng cho sửa giờ công).

## 14. Rủi ro

| Rủi ro | Cách giảm |
| --- | --- |
| Viết lại `my_schedule`, `submit_shift_requests`, `shift_registration_board`… làm mất phần đang có | Chép từ `supabase/schema.sql`; pgTAP cũ (`shift_requests`, `attendance_shifts`…) phải còn xanh; thêm test với `require_publish = false` khẳng định không đổi hành vi. |
| Overload hàm khi thêm `p_reason` làm PostgREST báo mơ hồ | Drop bản cũ + create bản mới trong cùng migration; test hợp đồng gọi cả kiểu cũ và mới. |
| Trigger thông báo bắn khi phát hành hoặc khi copy hàng loạt tạo spam | Cờ `app.schedule_publishing`; gộp `schedule_changed` chưa đọc theo (người, chi nhánh, tuần). |
| Nhân viên không thấy ca mà vẫn phải đi làm | Tuần đã bắt đầu luôn hiện; cron tự phát hành 00:05 thứ Hai; nhắc quản lý tối Chủ nhật. |
| Giờ cron UTC lệch giờ VN | Ghi rõ biểu thức UTC + giờ VN trong migration; hàm nhận "now" qua tham số nội bộ để test. |
| Bảng lịch sử bị sửa | Không grant ghi; trigger chặn update/delete cả với `postgres`. |
| `has_permission(..., null)` lộ chi nhánh khác | `schedule_history_list`, `registration_status` mở rộng null bằng `attendance_branch_ids`; test phạm vi bắt buộc. |
| Số migration lệch do thread khác merge trước | Kiểm `origin/main` ngay trước merge, đổi số nếu cần. |
| UI chưa bấm thử | Mỗi PR UI báo rõ chỉ typecheck/build/test; grace test tay theo mục 15. |

## 15. Test tay cho grace (sau khi xong)

1. Cài đặt > Đăng ký ca: bật đăng ký, `close_days_before = 3`, bật **"Bắt buộc phát hành lịch"** (để tick "Phát hành luôn các tuần đã có ca"). Miễn đăng ký cho một nhân viên.
2. Nhân viên A: Đăng ký ca tuần sau, thấy "Hạn chót 00:00 thứ Sáu". Gửi 3 ca. Nhân viên B: bấm "Tuần này tôi không làm" (thấy popup). Nhân viên C: không làm gì.
3. Quản lý: Lịch ca tuần sau → nhãn **Nháp**, nút "Chưa đăng ký (1)" chỉ có C. Bấm "Xếp như tuần trước" cho C.
4. Duyệt 2 đơn của A, để 1 đơn chờ. Đăng nhập A: "Ca của tôi" tuần sau **chưa có ca**, đơn hiện "Đã gửi, chờ phát hành".
5. Quản lý bấm **Phát hành**: popup ghi 1 đơn chờ sẽ bị từ chối. Đồng ý.
6. A, C: chuông có thông báo phát hành; bấm vào mở đúng tuần; A thấy 2 ca + 1 đơn bị từ chối. A thử hủy đơn / gửi thêm → bị chặn "Lịch tuần này đã phát hành".
7. Quản lý sửa giờ 1 ca của A (popup có ô lý do), xóa 1 ca của C. A và C nhận "Lịch tuần … đã thay đổi"; sửa thêm 1 ca của A → vẫn 1 thông báo, số thay đổi tăng.
8. Trang **Lịch sử lịch ca**: thấy đủ thêm/sửa/xóa/duyệt/từ chối/phát hành, người làm, lý do, trước/sau.
9. Ngày mai (hoặc chạy tay `select public.run_registration_reminders()` trong SQL Editor khi tuần mục tiêu sắp hết hạn): nhân viên chưa nộp nhận nhắc.

## 16. Đã làm

Xong ngày 2026-11-07. Migration `20261113010000`–`040000` chạy qua workflow "Supabase migrate" khi merge.

| PR | Nội dung |
| --- | --- |
| S0 | Plan (#253) |
| N1 (migration 010000) | Bảng `notifications`, `notify_user`, gộp "lịch đổi" chưa đọc, `my_notifications`, đếm chưa đọc, đánh dấu đã đọc, cron dọn thông báo cũ |
| N2 | Chuông thông báo trên header, trang `/admin/notifications`, mở thông báo đưa tới đúng trang |
| H1 (migration 020000) | `schedule_history` chỉ thêm (chặn sửa/xóa), trigger ghi lịch sử ca/đơn/tuần/khai báo, `p_reason` cho 5 hàm xếp ca |
| H2 | Popup xác nhận có ô lý do ở mọi thao tác sửa lịch, trang "Lịch sử lịch ca", nút "Lịch sử ca này" |
| P1 (migration 030000, #258) | `require_publish` theo chi nhánh (mặc định tắt), `schedule_weeks`, khai báo "tuần này không làm", miễn đăng ký, "ai chưa đăng ký", phát hành (từ chối đơn chờ + thông báo), khóa đăng ký/hủy sau khi phát hành, ẩn tuần nháp với nhân viên, thông báo khi sửa tuần đã phát hành |
| P2 (#259) | Nhãn Nháp/Đã phát hành + nút Phát hành trên Lịch ca, nút/ngăn "Chưa đăng ký (N)" kèm "Xếp như tuần trước", cảnh báo thông báo khi sửa tuần đã phát hành, trang đăng ký khóa sau phát hành + ô "Đã gửi" + khai báo không đăng ký, Cài đặt: công tắc phát hành + thẻ miễn đăng ký, "Ca của tôi" mở đúng tuần từ thông báo |
| P3 (migration 040000, #260) | Nhắc đăng ký 24 giờ trước hạn, báo quản lý sau hạn, nhắc phát hành tối Chủ nhật, tự phát hành tuần đã bắt đầu 00:05 thứ Hai |
| P4 | Dữ liệu mẫu (chi nhánh MOCKCA bật phát hành) và mục này |

Lệch so với plan:
- Nhắc và tự phát hành chỉ chạy cho chi nhánh **đã bật** `require_publish` (tắt thì không có gì đổi, đúng nguyên tắc P-Q1).
- `run_registration_reminders(p_now)` nhận thời điểm để test; cron gọi không tham số.
- Tuần đã bắt đầu mà trống thì tự phát hành chỉ đánh dấu, không gửi thông báo.
- Khai báo "tuần này không làm" dùng popup xác nhận có ô lý do, không có dialog riêng.
- Màn đăng ký: đơn đã duyệt/từ chối hiện "Đã gửi" cho tới khi phát hành (nhân viên không thấy kết quả sớm).

Chưa làm: gửi email/Zalo (chưa có tích hợp), bỏ phát hành (unpublish), R7 nhu cầu nhân sự.

**Việc grace cần làm:** vào Cài đặt > Đăng ký ca bật "Phát hành lịch trước khi nhân viên thấy" (giữ tick "Phát hành luôn các tuần đã có ca"), đặt "Chốt trước thứ Hai" = 3, tick quyền "Nhân sự" (xem, tạo, sửa, xóa, cài đặt; mục Lịch sử cần quyền xem) cho vai trò quản lý, rồi làm 9 bước ở mục 15. Giao diện chỉ qua type-check, build và test, **chưa bấm thử trên trình duyệt**.
