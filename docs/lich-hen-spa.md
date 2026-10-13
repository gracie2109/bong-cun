# Lịch hẹn spa / grooming

Kế hoạch module lịch hẹn spa. Nguồn: kế hoạch BA/kiến trúc v0.3 (M3 Lịch hẹn, M9 Spa/Grooming, mục 2.3 và thứ tự Phase 1 bước 4-5). Đây là bản kế hoạch, chưa có code hay SQL. Module đứng sau POS (PR #43), kho theo lô (PR #44) và biến thể (PR #46), đều đã merge.

Dự án là pet project cá nhân, chưa có doanh thu, nên phạm vi được giữ ở mức một cơ sở vận hành được hằng ngày, thiết kế sẵn cho nhiều cơ sở, không có tích hợp bên ngoài.

## 1. Trước và sau

**Trước:** có hai luồng đặt lịch trùng nhau và đều thiếu. `bookings` là form liên hệ (tên, SĐT, giờ muốn đến), không gắn dịch vụ. `orders` + `order_items` có dịch vụ/combo và trạng thái từng dòng, nhưng chỉ lưu tên và SĐT dạng chữ, không gắn khách hàng, thú cưng, nhân viên hay bàn spa. Không có lịch theo ngày, không chặn trùng giờ, không check-in, và phiếu spa không đi vào được hóa đơn POS. Trang `/admin/schedule/list-order-schedule` chỉ là danh sách `orders`.

**Sau:** lễ tân đặt lịch cho một khách có sẵn trong `customers`, chọn từng con thú và dịch vụ/combo cho mỗi con, chọn giờ, nhân viên và bàn spa. Hệ thống tính thời lượng, giá dự kiến, và từ chối nếu nhân viên hoặc bàn đã bận giờ đó. Màn lịch ngày hiện các cột nhân viên (hoặc bàn) theo khung 15 phút. Khi khách đến, lễ tân check-in và nhập cân nặng thực tế, giá được chốt theo cân nặng đó. Nhân viên spa bấm bắt đầu / xong cho phần việc của mình. Thu ngân mở POS, kéo các phiếu đã xong của khách vào giỏ chung cùng hàng shop và thanh toán một hóa đơn. Lịch hủy và khách không đến (no-show) được đếm theo khách.

## 2. Phạm vi

| Mức | Nội dung |
| --- | --- |
| **Must** | Bàn spa theo cơ sở; giờ mở cửa theo cơ sở; đánh dấu nhân viên làm dịch vụ; đặt / sửa / dời / hủy lịch; nhiều thú và nhiều dịch vụ trong một lịch; chặn trùng giờ nhân viên và bàn; màn lịch ngày; danh sách lịch hẹn có tìm kiếm và phân trang; check-in + cân nặng thực tế + chốt giá; trạng thái phiếu Chờ → Đang làm → Xong; no-show; đưa phiếu vào giỏ POS |
| **Should** | Màn "Việc của tôi hôm nay" cho nhân viên spa; gợi ý nhân viên/bàn còn trống; ghi chú tình trạng (da, ve rận, hành vi); số lần no-show hiện khi đặt lịch; ngày nghỉ của nhân viên |
| **Could** | Kéo thả để dời lịch; ảnh trước/sau; realtime cho màn lịch; lịch tuần |
| **Won't (lần này)** | Khách tự đặt trên web/app (Phase 3); nhắc lịch qua Zalo/SMS; đặt cọc; gói dịch vụ trả trước; định mức tiêu hao trừ kho; ca làm việc chi tiết của nhân viên |

## 3. Mô hình dữ liệu

Mọi bảng theo cơ sở có `branch_id not null`. Thời gian lưu `timestamptz`, ngày nghiệp vụ theo `public.business_date()` (giờ Việt Nam, đã có từ migration kho).

| Bảng | Vai trò |
| --- | --- |
| `spa_resources` | Bàn spa / bồn tắm của một cơ sở: `branch_id`, `name`, `is_active`, `sort_order`. |
| `branch_hours` | Giờ mở cửa theo thứ trong tuần: `branch_id`, `weekday`, `open_time`, `close_time`, `is_closed`. Thiếu dòng = mặc định 08:00-20:00. |
| `staff_branches.does_services` | Cột mới, bật cho nhân viên được gán làm dịch vụ tại cơ sở đó. |
| `appointments` | Một lần hẹn của một khách tại một cơ sở. |
| `appointment_items` | Phiếu dịch vụ: một dịch vụ hoặc combo cho một con thú, có nhân viên, bàn và khung giờ riêng. |

### `appointments`

| Cột | Ghi chú |
| --- | --- |
| `code` | `CS01-LH-000123`, sinh bằng `next_doc_code(branch, 'LH')` |
| `branch_id`, `customer_id` | Khách bắt buộc; khách mới gõ tại quầy được tạo theo SĐT như `create_invoice` đang làm |
| `customer_name`, `customer_phone` | Bản sao lúc đặt, để danh sách đọc nhanh |
| `start_at`, `end_at` | Min/max của các phiếu, do RPC tính lại mỗi lần lưu |
| `status` | `booked`, `checked_in`, `in_progress`, `done`, `paid`, `cancelled`, `no_show` |
| `source` | `counter`, `phone`, `legacy` (chuyển từ `orders`); `web` để dành cho Phase 3 |
| `note`, `checked_in_at`, `cancelled_at`, `cancel_reason`, `created_by` | |

### `appointment_items`

| Cột | Ghi chú |
| --- | --- |
| `appointment_id`, `line_no` | |
| `pet_id` | Bắt buộc với lịch mới. Cho phép null chỉ với dữ liệu `legacy` (bảng `orders` cũ không có thú); phải chọn thú trước khi check-in |
| `item_type`, `service_id`, `combo_id` | Giống `invoice_lines`: `service` hoặc `combo`, đúng một id |
| `name`, `duration_minutes` | Bản sao từ danh mục lúc đặt |
| `staff_id`, `resource_id` | Nhân viên và bàn; cho phép null khi chưa xếp |
| `start_at`, `end_at` | `end_at = start_at + duration` |
| `status` | `waiting`, `in_progress`, `done`, `cancelled` |
| `est_price` | Giá dự kiến lúc đặt (theo cân nặng gần nhất của thú) |
| `weight_kg`, `unit_price` | Cân nặng thực tế và giá chốt lúc check-in |
| `invoice_line_id` | Gắn khi đã vào hóa đơn; null lại khi hóa đơn bị hủy |
| `note` | Ghi chú tình trạng của nhân viên spa |

### Chặn trùng giờ

Dùng exclusion constraint của Postgres (extension `btree_gist` đã bật từ migration loài/cân nặng), nên việc chặn trùng nằm ở database, kể cả khi hai lễ tân lưu cùng lúc:

```sql
exclude using gist (staff_id with =, tstzrange(start_at, end_at, '[)') with &&)
  where (staff_id is not null and status <> 'cancelled')
exclude using gist (resource_id with =, tstzrange(start_at, end_at, '[)') with &&)
  where (resource_id is not null and status <> 'cancelled')
```

Lịch `cancelled` hoặc `no_show` thì RPC chuyển các phiếu sang `cancelled` để giải phóng giờ.

## 4. Quy tắc nghiệp vụ

1. **Combo là một phiếu**: một nhân viên, một bàn, thời lượng của combo. Không tách thành từng dịch vụ con.
2. **Giá dự kiến lúc đặt, giá chốt lúc check-in** (quy tắc 18 của BA): check-in ghi cân nặng vào `pet_weight_logs` rồi tính lại giá bằng `get_service_price(species, service, weight, branch)`. Dịch vụ giá chung và combo giữ giá danh mục. Sau check-in, giá trên phiếu không đổi theo danh mục nữa.
3. **Giờ hợp lệ**: phiếu phải nằm trong giờ mở cửa của cơ sở và bắt đầu ở bội số 15 phút. Không đặt vào quá khứ, trừ khi sửa lịch đã check-in.
4. **Nhân viên được gán** phải có `does_services` ở cơ sở đó. Một nhân viên không làm hai phiếu chồng giờ (đã chặn bởi constraint).
5. **Trạng thái lịch suy ra từ phiếu**: có phiếu `in_progress` thì lịch `in_progress`; mọi phiếu còn hiệu lực `done` thì lịch `done`; mọi phiếu đã vào hóa đơn thì `paid`. `booked`, `checked_in`, `cancelled`, `no_show` do người dùng bấm.
6. **Dời lịch** chỉ khi `booked` hoặc `checked_in`. **Hủy** chỉ khi chưa có phiếu nào `in_progress` hoặc `done`. **No-show** chỉ khi `booked` và đã qua giờ hẹn.
7. **Thú phải thuộc khách** (`pet_owners` còn hiệu lực), như `create_invoice` đang kiểm tra.
8. **Thanh toán qua POS**: chỉ phiếu `done` và chưa có `invoice_line_id` mới được kéo vào giỏ. Giỏ vẫn cho thêm dịch vụ lẻ không có lịch như hiện nay. Hủy hóa đơn thì phiếu về lại `done` chưa thanh toán.
9. **Cảnh báo**: khách có từ 3 lần no-show trở lên hiện nhãn cảnh báo khi đặt lịch (chỉ hiện, không chặn).

## 5. RPC

Theo quy ước của repo: nghiệp vụ nhiều bước nằm trong Postgres function `security definer`, client chỉ đọc bảng qua RLS.

| RPC | Việc làm |
| --- | --- |
| `save_appointment(p jsonb, p_id uuid default null)` | Tạo hoặc sửa lịch cùng các phiếu trong một transaction: kiểm tra khách/thú, sao chép tên + thời lượng từ danh mục, tính `est_price`, kiểm tra giờ mở cửa, tính `start_at`/`end_at`. Trùng giờ trả lỗi có `hint = 'slot_taken'` và tên nhân viên/bàn bị trùng |
| `check_in_appointment(p_id uuid, p_weights jsonb)` | Ghi cân nặng từng thú, chốt `unit_price`, chuyển `checked_in` |
| `set_appointment_item_status(p_item uuid, p_status text, p_note text default null)` | Bắt đầu / xong / hủy một phiếu, cập nhật trạng thái lịch |
| `cancel_appointment(p_id uuid, p_reason text)` | Hủy lịch và các phiếu |
| `mark_no_show(p_id uuid)` | Đánh dấu khách không đến |
| `list_appointments(p_branch, p_from, p_to, p_status, p_search, p_page, p_page_size)` | Danh sách cho bảng: tìm theo mã, tên, SĐT khách, tên thú; trả `{ rows, total }` |
| `spa_day_board(p_branch uuid, p_date date)` | Dữ liệu màn lịch ngày: giờ mở cửa, nhân viên, bàn và các phiếu trong ngày |
| `spa_free_slots(p_branch, p_date, p_duration, p_staff?, p_resource?)` (Should) | Gợi ý khung giờ trống |
| `billable_appointment_items(p_branch, p_customer)` | Phiếu `done` chưa thanh toán của một khách, cho POS |
| `create_invoice` (sửa) | Nhận thêm dòng `{ type: 'appointment_item', id }`: đọc giá chốt và thú từ phiếu, ghi `invoice_line_id` lên phiếu. `cancel_invoice` gỡ liên kết |

Tìm khách dùng lại `search_customers`; thêm thú nhanh dùng lại `register_pet`.

## 6. Phân quyền

Dùng quyền `schedule` đã có trong seed (`VIEW`, `CREATE`, `UPDATE`, `DELETE`), kiểm tra theo cơ sở bằng `has_permission('schedule', method, branch)`:

| Việc | Quyền |
| --- | --- |
| Xem lịch, danh sách | `schedule: VIEW` |
| Đặt lịch, check-in | `schedule: CREATE` |
| Sửa, dời, no-show, đổi trạng thái phiếu | `schedule: UPDATE` |
| Hủy lịch | `schedule: DELETE` |
| Bàn spa, giờ mở cửa, nhân viên làm dịch vụ | `schedule: SETTING` |

Nhân viên spa không có `schedule: UPDATE` vẫn được bắt đầu / xong **phiếu được gán cho chính mình**: `set_appointment_item_status` cho phép khi `staff_id = auth.uid()`. Kéo phiếu vào hóa đơn đi theo quyền `pos` như hiện tại.

RLS: `appointments`, `appointment_items`, `spa_resources`, `branch_hours` chỉ đọc từ client với `schedule: VIEW` tại cơ sở đó (nhân viên spa đọc được phiếu của mình); mọi ghi đi qua RPC.

## 7. Màn hình

Theo quy ước admin: theme teal, `PagedTableCard` cho bảng, `AppDialog` cho modal, `InfiniteSelect` cho select có tìm kiếm, ô tìm kiếm debounce 500ms.

| Màn | Đường dẫn | Nội dung |
| --- | --- | --- |
| Lịch ngày | `/admin/schedule` | Lưới tự dựng bằng CSS grid: cột = nhân viên (nút chuyển sang cột = bàn), hàng = khung 15 phút trong giờ mở cửa. Thẻ phiếu tô màu theo trạng thái. Bấm ô trống mở dialog đặt lịch với giờ + nhân viên điền sẵn. Chọn ngày, nút Hôm nay. Tải lại khi focus và mỗi 30 giây |
| Danh sách lịch hẹn | `/admin/schedule/appointments` | Bảng: mã, giờ, khách, thú, dịch vụ, nhân viên, trạng thái. Lọc theo khoảng ngày và trạng thái. Thay trang `list-order-schedule` |
| Dialog đặt / sửa lịch | | Tìm khách (thêm khách mới nếu chưa có) → chọn thú (thêm nhanh) → mỗi thú chọn dịch vụ/combo → mỗi phiếu chọn giờ, nhân viên, bàn. Hiện tổng thời lượng, giá dự kiến, số lần no-show. Lỗi trùng giờ chỉ rõ phiếu nào |
| Chi tiết lịch hẹn | `/admin/schedule/appointments/[id]` | Thông tin khách, các phiếu; nút Check-in (nhập cân nặng từng thú), Bắt đầu / Xong từng phiếu, ghi chú, Dời, Hủy, No-show, "Thanh toán tại POS" |
| Việc của tôi (Should) | `/admin/schedule/my-day` | Phiếu hôm nay của nhân viên đang đăng nhập, nút Bắt đầu / Xong |
| Cài đặt spa | `/admin/schedule/settings` | Tab Bàn spa, Giờ mở cửa, Nhân viên làm dịch vụ |
| POS | `/admin/pos` | Khi chọn khách, hiện "Phiếu spa chờ thanh toán (n)"; bấm để thêm các phiếu vào giỏ |

Không dùng thư viện lịch: FullCalendar tính phí cho dạng xem theo cột tài nguyên, còn một lưới ngày với vài chục ô thì tự dựng đơn giản hơn và dễ theo theme admin.

## 8. Dữ liệu cũ

- `bookings` giữ nguyên, là yêu cầu tư vấn từ form liên hệ trên web. Lễ tân đọc rồi tự đặt lịch.
- `orders` / `order_items`: một migration chuyển mỗi `order` thành một `appointment` `source = 'legacy'` (khách tìm hoặc tạo theo SĐT, `pet_id` null, không nhân viên/bàn, trạng thái quy đổi `PENDING/PROCESSING → booked`, `CONFIRMED → done`, `CANCEL → cancelled`). Sau đó `create_order` và các màn `orders` bị gỡ; bảng `orders` để lại chỉ đọc, xóa ở một migration sau.
- Nếu dữ liệu `orders` hiện có chỉ là dữ liệu thử, bỏ bước chuyển và gỡ thẳng (xem câu hỏi 1).

## 9. Thứ tự làm (mỗi bước một PR)

| Bước | Nội dung | SQL |
| --- | --- | --- |
| 1 | Bảng, constraint, RLS, `save_appointment`, `cancel_appointment`, `list_appointments`, `spa_day_board`; màn Cài đặt spa, Danh sách, Dialog đặt lịch | Migration mới `spa_appointments.sql`, chạy sau `product_variants` |
| 2 | Màn Lịch ngày; check-in, trạng thái phiếu, no-show; màn Chi tiết; Việc của tôi | Bổ sung RPC `check_in_appointment`, `set_appointment_item_status`, `mark_no_show` |
| 3 | Nối POS: `billable_appointment_items`, sửa `create_invoice` / `cancel_invoice`, nút trong giỏ | Migration sửa hàm POS; làm sau khi PR #54 (sửa POS) đã merge vì cùng sửa `create_invoice` |
| 4 | Chuyển `orders` sang `appointments`, gỡ `create_order` và màn cũ | Migration chuyển dữ liệu |

Sau đó là báo cáo doanh thu tách Shop / Spa (M11), đọc từ `invoice_lines` theo `item_type`.

Mỗi PR có SQL sẽ ghi rõ tên file và thứ tự chạy; bản để dán vào SQL Editor đặt ở `/mnt/project-files/pet-care-plan/migration-*.sql`.

## 10. Mặc định đã chọn

- Lịch hẹn do nhân viên tạo (tại quầy hoặc qua điện thoại); khách chưa tự đặt.
- Bước thời gian 15 phút; giờ mở cửa mặc định 08:00-20:00 khi chưa cài.
- Combo là một phiếu, một nhân viên.
- Mỗi phiếu nên có bàn nhưng không bắt buộc, để không chặn những dịch vụ không cần bàn.
- Chọn ai được gán bằng cờ `does_services` trên từng (nhân viên, cơ sở), không suy ra từ vai trò.
- Không đặt cọc, không nhắc lịch tự động.

## 11. Câu hỏi cần chốt

1. Dữ liệu trong `orders` hiện tại là dữ liệu thật hay dữ liệu thử? (mặc định: chuyển sang `appointments`)
2. Ai được gán làm dịch vụ: bật cờ cho từng nhân viên, hay mọi nhân viên của cơ sở? (mặc định: bật cờ)
3. Một nhân viên có làm song song hai con cùng lúc không, ví dụ một con đang sấy, một con đang tắm? (mặc định: không)
4. Bàn spa có bắt buộc cho mọi phiếu không? (mặc định: không bắt buộc)
