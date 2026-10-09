# Kho theo lô và hạn dùng (FEFO)

Phân tích và thiết kế module kho. Nguồn: kế hoạch BA/kiến trúc v0.3 (mục 1.3.C "Quản lý kho") và PR #44 (merge vào `main` ngày 07/10/2026, commit b488661). Migration: `supabase/migrations/20261007130000_inventory_lots.sql`, chạy sau `20261007120000_pos_invoices.sql`.

## 1. Yêu cầu nghiệp vụ (từ kế hoạch BA)

1. **Danh mục hàng hóa**: loại (thức ăn, thuốc, vaccine, vật tư tiêu hao, phụ kiện), đơn vị tính nhiều cấp (thùng → hộp → viên), có quản lý lô/HSD hay không, có bán lẻ hay chỉ dùng nội bộ.
2. **Nhập hàng**: đơn đặt hàng NCC → phiếu nhập (lô, HSD, giá vốn) → công nợ NCC.
3. **Xuất kho** theo các nguồn: bán POS, đơn thuốc, y lệnh nội trú, tiêu hao dịch vụ (định mức: 1 lần tắm dùng 30ml sữa tắm), hủy hàng hết hạn.
4. **Kiểm kê** định kỳ, chênh lệch cần duyệt.
5. **Cảnh báo**: tồn dưới mức tối thiểu, hàng sắp hết hạn (30/60/90 ngày), lô bị thu hồi.
6. **Giá vốn**: bình quân gia quyền (khuyến nghị) hoặc theo lô.

Quyết định kiến trúc liên quan: tồn kho tách theo chi nhánh; tồn chỉ thay đổi qua chứng từ; xuất theo FEFO (lô hết hạn sớm xuất trước).

## 2. Trước và sau

**Trước:** sản phẩm không có tồn. POS bán bao nhiêu cũng được, hủy hóa đơn không ảnh hưởng kho, và không trả hàng được sau khi đóng ca.

**Sau:** mỗi chi nhánh giữ tồn theo lô (số lô, hạn dùng, giá vốn). Bán tại quầy lấy lô hết hạn sớm nhất, không bao giờ bán lô đã hết hạn, và báo lỗi khi không đủ hàng còn hạn. Nhân viên nhập hàng, xuất hủy và kiểm kê qua phiếu kho; mọi thay đổi hiện trên thẻ kho của sản phẩm. Thu ngân nhận trả hàng trên bất kỳ hóa đơn đã thanh toán nào; tiền hoàn lấy từ ca đang mở của họ, hàng về lại đúng lô.

## 3. Mô hình dữ liệu

| Bảng | Vai trò |
| --- | --- |
| `stock_lots` | Tồn theo chi nhánh + sản phẩm + lô: `lot_no`, `expiry`, `unit_cost`, số lượng. Không bao giờ âm. |
| `stock_documents` + `stock_document_lines` | Phiếu kho: nhập **NK**, xuất hủy **XH**, kiểm kê **KK**. Có trạng thái nháp → đã ghi sổ → đã hủy. |
| `stock_movements` | Sổ biến động chỉ ghi thêm (append-only), là nguồn của thẻ kho. |
| `suppliers` | Nhà cung cấp. |
| `stock_thresholds` | Tồn tối thiểu theo chi nhánh để cảnh báo. |
| `sales_returns` + `sales_return_lines` | Phiếu trả hàng **TH** gắn với hóa đơn. |
| `products.track_stock` | Có quản lý tồn hay không (mặc định bật). |
| `invoice_lines.cost_amount` | Giá vốn của dòng hóa đơn, tính từ các lô đã xuất. |

## 4. Quy tắc

- **Chỉ một cửa thay đổi tồn:** mọi thay đổi đi qua `move_stock()`, hàm này từ chối nếu tồn bị âm và ghi `stock_movements`.
- **FEFO khi bán:** trigger trên `invoice_lines` gọi `take_stock_fefo` trong cùng giao dịch với `create_invoice`: lấy lô có hạn sớm nhất, bỏ qua lô đã hết hạn, thiếu hàng thì cả hóa đơn lỗi. `create_invoice` không phải sửa.
- **Hủy hóa đơn:** trigger trả hàng về đúng lô đã xuất. Không cho hủy nếu hóa đơn đã có phiếu trả hàng.
- **Trả hàng sau đóng ca** (`create_sales_return`): tiền hoàn lấy từ ca đang mở của người nhận trả; `cash_shift_summary` trừ tiền hoàn khỏi tiền mặt dự kiến.
- **Phiếu nhập** đã ghi sổ chỉ hủy được khi hàng của nó vẫn còn trong kho.
- **Sản phẩm `track_stock = true`** không bán được cho đến khi nhập kho. Hàng không cần tồn (ví dụ túi đựng) thì tắt công tắc này.

## 5. RPC

| RPC | Việc |
| --- | --- |
| `save_stock_document` | Lưu phiếu nháp. |
| `post_stock_document` | Ghi sổ phiếu: nhập cần `inventory: CREATE`; xuất hủy và kiểm kê cần `inventory: UPDATE` (quản lý duyệt). |
| `cancel_stock_document` | Hủy phiếu nhập đã ghi sổ (`inventory: DELETE`). |
| `set_min_stock` | Đặt tồn tối thiểu. |
| `stock_summary`, `stock_alert_counts` | Màn tồn kho và đếm cảnh báo (dưới tối thiểu, hết hàng, sắp hết hạn, đã hết hạn). |
| `sellable_stock` | Tồn còn bán được cho POS. |
| `create_sales_return` | Trả hàng (`pos: DELETE`). |

## 6. Phân quyền

- Quyền mới `inventory` và vai trò **Thủ kho**: lập phiếu, ghi sổ phiếu nhập.
- Xuất hủy và kiểm kê phải do quản lý ghi sổ.
- Thu ngân đọc được lô ở chi nhánh của mình để bán, không xem được sổ biến động hay phiếu kho, không ghi trực tiếp vào bảng.

## 7. Màn hình

- Menu **Kho**: Tồn kho (cảnh báo dưới tối thiểu, hết hàng, sắp hết hạn 30/60/90 ngày, lô đã hết hạn; xem từng lô và thẻ kho), Phiếu kho (NK, XH, KK), Nhà cung cấp.
- POS: ô sản phẩm hiện "Còn N" / "Hết hàng".
- Chi tiết hóa đơn: nút "Trả hàng". Hộp thoại đóng ca có dòng tiền hoàn.
- Form sản phẩm: công tắc "Quản lý tồn kho".

## 8. Đã kiểm thử

Migration chạy trên Postgres 16 local cùng mọi migration trước, chạy lại hai lần (idempotent), và thử: nhập 3 lô gồm một lô đã hết hạn, bán FEFO qua nhiều lô có giá vốn, bán quá tồn bị chặn, trả một phần về đúng lô, hủy bị chặn khi đã trả hàng, hủy trả lại kho, xuất hủy, chênh lệch kiểm kê, không hủy được phiếu nhập sau khi đã bán, cảnh báo tồn tối thiểu, tổng kết ca có tiền hoàn, RLS của thu ngân.

## 9. Chưa làm

- Quy đổi đơn vị (thùng → hộp → viên).
- Trừ kho cho đơn online (`create_order`).
- Chuyển kho giữa chi nhánh.
- Đơn đặt hàng NCC và công nợ nhà cung cấp.
- Xuất kho theo đơn thuốc, y lệnh nội trú, định mức tiêu hao dịch vụ; lô bị thu hồi.

Biến thể sản phẩm (PR #46) không đổi module kho: mỗi biến thể là một dòng `products`, tồn vẫn tính theo từng biến thể. Xem [bien-the-san-pham.md](bien-the-san-pham.md).
