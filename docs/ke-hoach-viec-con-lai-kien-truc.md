# Kế hoạch ba việc còn lại của đợt sửa kiến trúc

Ngày: 2026-10-16. Nguồn: mục 4.4, 4.6, 4.7 của [danh-gia-kien-truc.md](danh-gia-kien-truc.md). grace yêu cầu lên plan rồi làm. Không có migration mới, không chạy SQL nào lên DB thật.

## Kết luận ngắn

| Việc | Quyết định | Lý do |
| --- | --- | --- |
| 4.4 Kiểu cho RPC `jsonb` | **Làm ngay** cho luồng tiền, mở rộng dần | Đổi tên một khóa trong SQL hiện `String(undefined)` trên màn hình mà không ai báo. |
| 4.6 `pg_cron` | **Đã làm một job**: tự hủy đơn online pending quá hạn | Đơn bị bỏ quên khóa tồn kho mãi. grace chọn 48 giờ. |
| 4.7 Bảng tổng hợp báo cáo | **Đã đo, không làm** | 300.000 hóa đơn: báo cáo 30 ngày 0,2 giây, cả năm 1,8 giây. Bảng tổng hợp thêm rủi ro sai số mà chưa có lợi ích. |

## 4.4 Parse `jsonb` bằng zod

- `parseRpc(tên_rpc, schema, dữ_liệu)` trong `src/repositories/shared.ts`: nếu thiếu hoặc sai kiểu một khóa, ném lỗi nêu tên RPC và khóa đó.
- Áp dụng đợt này cho 3 luồng tiền: `create_invoice`, `create_sales_return`, `cash_shift_summary` (cũng là kết quả của `close_cash_shift`). Schema đối chiếu với thân hàm trong `supabase/schema.sql`.
- Test SQL `pos_invoice.test.sql` kiểm `create_invoice` trả đủ khóa mà app đọc, nên đổi khóa trong SQL sẽ đỏ ở CI trước khi tới màn hình.
- Làm tiếp khi đụng tới: lưu trú (`save_boarding_stay`, `check_in_boarding`), y tế (`check_in_medical_visit`, `sign_medical_visit`). Quy ước: hàm mới ưu tiên `returns table`, chỉ dùng `jsonb` khi kết quả lồng nhau, và nếu dùng `jsonb` thì kèm schema zod và một ca test khóa.

## 4.6 `pg_cron`: tự hủy đơn online bị bỏ quên

Việc thật đầu tiên cần chạy nền: đơn online `pending` giữ hàng (trừ vào tồn bán được) nên đơn không ai xác nhận khóa tồn kho mãi, và đơn chỉ có COD hoặc nhận tại cửa hàng nên không có bước thanh toán nào tự dọn.

- Migration `20261022010000_auto_cancel_stale_shop_orders.sql`: hàm `auto_cancel_stale_shop_orders(p_hours)` (mặc định 48) hủy đơn còn `pending`, chưa có hóa đơn, đặt quá `p_hours` giờ; ghi lý do "Tự hủy: quá N giờ chưa được xác nhận" và một dòng nhật ký đơn do "Hệ thống". Đơn đã xác nhận không bị đụng. Hàm chỉ cấp cho `service_role` (đã có test: người đăng nhập gọi bị 42501). Job `auto-cancel-stale-shop-orders` chạy 02:00 giờ Việt Nam mỗi đêm.
- Test: `shop_order_auto_cancel.test.sql` (8 ca: hủy đơn cũ, giữ đơn mới, không đụng đơn đã xác nhận, ghi nhật ký, chạy lại không đổi gì, không ai ngoài `service_role` gọi được).
- grace chọn 48 giờ (2026-10-16), giống mức 1 đến 2 ngày người bán trên sàn phải xử lý đơn COD. Muốn đổi, sửa lệnh trong `cron.schedule` ở một migration mới.
- Việc chạy nền khác (nhắc lịch tiêm, cảnh báo lô sắp hết hạn) chưa làm: hiện đã có danh sách gọi điện trên màn hình, chỉ cần job khi có kênh gửi tin.

## 4.7 Bảng tổng hợp báo cáo (đã đo, chưa cần)

Đo ngày 2026-10-16 trên Postgres cục bộ: 300.000 hóa đơn (mỗi hóa đơn 1 dòng hàng và 1 thanh toán, trải 400 ngày, tức khoảng 750 hóa đơn mỗi ngày, gấp nhiều lần một cửa hàng thú cưng), 1/50 bị hủy.

| Khoảng báo cáo | Số hóa đơn trong khoảng | `report_overview_core` |
| --- | --- | --- |
| 30 ngày | 21.332 | 0,15 đến 0,20 giây |
| 366 ngày | 268.078 | 1,8 giây |

`report_overview` gọi hàm này hai lần (kỳ này và kỳ trước), nên 30 ngày vẫn dưới nửa giây. Vì vậy chưa làm bảng tổng hợp.

Lý do không làm sớm: báo cáo dựa vào nhiều bảng (hóa đơn, thanh toán, dòng hàng theo nhóm dịch vụ, phiếu trả hàng, giá vốn từ kho) và một hóa đơn bị hủy hay trả hàng muộn làm đổi số của ngày cũ. Bảng tổng hợp phải cập nhật khi hủy và trả hàng; sai một chỗ thì báo cáo doanh thu sai mà không ai thấy, trong khi chưa có lợi ích tốc độ nào để đổi lại.

Làm khi: báo cáo 30 ngày trên dữ liệu thật quá khoảng 1 giây. Cách làm khi đó: bảng `daily_sales(branch_id, day, ...)` tính lại cho các ngày bị đụng tới (hóa đơn tạo, hủy, trả hàng) bằng chính `report_overview_core` cho từng ngày, kèm test SQL so tổng bảng tổng hợp với tổng tính trực tiếp.

## Kiểm

Typecheck 0 lỗi, build chạy, 61 test SQL qua, 122 migration chạy sạch trên DB rỗng.
