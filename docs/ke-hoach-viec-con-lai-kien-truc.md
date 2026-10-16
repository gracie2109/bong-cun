# Kế hoạch ba việc còn lại của đợt sửa kiến trúc

Ngày: 2026-10-16. Nguồn: mục 4.4, 4.6, 4.7 của [danh-gia-kien-truc.md](danh-gia-kien-truc.md). grace yêu cầu lên plan rồi làm. Không có migration mới, không chạy SQL nào lên DB thật.

## Kết luận ngắn

| Việc | Quyết định | Lý do |
| --- | --- | --- |
| 4.4 Kiểu cho RPC `jsonb` | **Làm ngay** cho luồng tiền, mở rộng dần | Đổi tên một khóa trong SQL hiện `String(undefined)` trên màn hình mà không ai báo. |
| 4.6 `pg_cron` | **Chưa làm**, ghi sẵn thiết kế | Trong DB chưa có việc nào cần chạy nền: không có cột hạn giữ đơn, không có hàm nhả đơn hay dọn dữ liệu. Tạo job rỗng chỉ thêm chỗ để hỏng. |
| 4.7 Bảng tổng hợp báo cáo | **Chưa làm**, ghi sẵn ngưỡng | Báo cáo tính trực tiếp trên bảng giao dịch, đủ nhanh ở quy mô hiện tại; bảng tổng hợp thêm một nguồn sự thật phải giữ đồng bộ. |

## 4.4 Parse `jsonb` bằng zod

- `parseRpc(tên_rpc, schema, dữ_liệu)` trong `src/repositories/shared.ts`: nếu thiếu hoặc sai kiểu một khóa, ném lỗi nêu tên RPC và khóa đó.
- Áp dụng đợt này cho 3 luồng tiền: `create_invoice`, `create_sales_return`, `cash_shift_summary` (cũng là kết quả của `close_cash_shift`). Schema đối chiếu với thân hàm trong `supabase/schema.sql`.
- Test SQL `pos_invoice.test.sql` kiểm `create_invoice` trả đủ khóa mà app đọc, nên đổi khóa trong SQL sẽ đỏ ở CI trước khi tới màn hình.
- Làm tiếp khi đụng tới: lưu trú (`save_boarding_stay`, `check_in_boarding`), y tế (`check_in_medical_visit`, `sign_medical_visit`). Quy ước: hàm mới ưu tiên `returns table`, chỉ dùng `jsonb` khi kết quả lồng nhau, và nếu dùng `jsonb` thì kèm schema zod và một ca test khóa.

## 4.6 `pg_cron` (khi nào và làm thế nào)

Chưa làm vì chưa có việc. Khi có đủ một trong các điều kiện sau thì làm:

- Đơn online chưa thanh toán cần tự hủy và nhả hàng: cần cột hạn giữ đơn trước, rồi một hàm `release_expired_orders()`.
- Nhắc lịch tiêm, cảnh báo lô sắp hết hạn: hiện đã có danh sách gọi điện xem trên màn hình; chỉ cần job khi có kênh gửi tin.

Cách làm: một migration bật `pg_cron` (Free có sẵn), `cron.schedule` gọi đúng một hàm `security definer` đã có test; mỗi job một hàm, idempotent, ghi số dòng đã xử lý. Job ghi dữ liệu thật, nên cần grace duyệt hàm cụ thể trước khi migration chạy tự động lên DB thật.

## 4.7 Bảng tổng hợp báo cáo (ngưỡng)

Chưa làm. Làm khi một trong hai điều xảy ra: `report_overview` trên dữ liệu thật quá khoảng 1 giây, hoặc hóa đơn lên hàng trăm nghìn dòng. Cách làm khi đó: bảng `daily_sales(branch_id, day, ...)` cập nhật bằng trigger trên `invoices` và `sales_returns`, kèm test SQL so tổng bảng tổng hợp với tổng tính trực tiếp.

## Kiểm

Typecheck 0 lỗi, build chạy, 53 test SQL qua (thêm 1 ca khóa `create_invoice`).
