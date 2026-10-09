# Kế hoạch biến thể sản phẩm

Bản kế hoạch ngày 07/10/2026.

> **Ghi chú:** đây là bản kế hoạch gốc. Ngày 07/10/2026 chủ dự án chọn hướng "dynamic nhất có thể", nên bản đã triển khai (PR #46, migration `20261007140000_product_variants.sql`) khác ở mấy điểm: không giới hạn số thuộc tính, thuộc tính và giá trị dùng chung giữa các sản phẩm (`product_attributes`, `product_attribute_values`, `product_group_attributes`, `product_variant_values` thay cho `product_group_options`), mỗi biến thể có ảnh riêng. Tên biến thể có dạng "Nhóm · giá trị 1 / giá trị 2".

## Kết luận

Thêm biến thể vẫn ổn, không phải làm lại POS hay kho. Hiện mỗi dòng `products` là một mặt hàng bán được: có giá, mã vạch, tồn theo lô, và được hóa đơn, phiếu kho, trả hàng tham chiếu tới. Nếu giữ nguyên nghĩa đó (mỗi biến thể là một dòng `products`, tức một SKU) và chỉ thêm một tầng "nhóm sản phẩm" ở trên, thì toàn bộ FEFO, phiếu nhập/xuất, trả hàng và báo cáo sẽ chạy y như cũ.

Cách này giống KiotViet ("hàng cùng loại" + thuộc tính) và Shopify (product → variants).

## Mô hình dữ liệu

Hai tầng: **nhóm sản phẩm** (cái khách nhìn thấy) và **biến thể** (cái bán và cái nằm trong kho).

| Bảng | Chứa gì | Ví dụ |
| --- | --- | --- |
| `product_groups` (mới) | Tên chung, mô tả, danh mục, thương hiệu, ảnh, danh sách thuộc tính | "Hạt Royal Canin Mini Adult", thuộc tính: Khối lượng |
| `products` (giữ nguyên, thêm cột) | Một biến thể = một SKU: mã, mã vạch, giá, đơn vị, theo dõi tồn; thêm `group_id`, `option_values`, `sort_order` | 2kg · SKU RC-MINI-2 · 420.000đ |
| `product_group_options` (mới) | Tên thuộc tính và các giá trị, theo thứ tự hiển thị | Khối lượng: 800g, 2kg, 4kg |

Quy tắc:

- Tối đa 3 thuộc tính mỗi nhóm (ví dụ Khối lượng × Vị × Màu). Một tổ hợp giá trị chỉ có một SKU, được ràng buộc `unique (group_id, option_values)`.
- Sản phẩm không có biến thể vẫn là một nhóm có đúng một SKU. Dữ liệu hiện có được chuyển tự động: mỗi dòng `products` sinh một nhóm cùng tên.
- Tên in trên hóa đơn = tên nhóm + giá trị, ví dụ "Hạt Royal Canin Mini Adult · 2kg". Hóa đơn vẫn chụp lại tên và giá lúc bán.
- Giá theo từng biến thể. Sau này giá riêng theo chi nhánh cũng gắn vào biến thể.

Khác với **quy đổi đơn vị** (hộp 10 viên so với 1 viên): đó là cùng một hàng bán theo nhiều đơn vị và dùng chung tồn, nên sẽ là một việc riêng, không dùng biến thể.

## Ảnh hưởng tới các phần đã làm

| Phần | Thay đổi |
| --- | --- |
| Kho (lô, FEFO, phiếu NK/XH/KK) | Không đổi: tồn vẫn tính theo `products.id`, tức theo từng biến thể. Màn tồn kho thêm lựa chọn gộp theo nhóm. |
| POS | Quét mã vạch ra đúng biến thể, không phải chọn thêm. Khi bấm vào nhóm có nhiều biến thể thì hiện bảng chọn, kèm giá và tồn từng biến thể. |
| Hóa đơn, trả hàng | Không đổi cấu trúc, chỉ đổi cách ghép tên dòng. |
| Shop online | Trang sản phẩm hiển thị theo nhóm, khách chọn biến thể; giỏ hàng lưu `product_id` của biến thể. Giỏ hàng hiện vẫn là dữ liệu mẫu (size XL/M) nên sẽ nối thẳng vào mô hình này. |
| Đơn online (`create_order`) | Cần thêm dòng sản phẩm vào đơn và trừ kho. Việc này đã nằm sẵn trong danh sách còn nợ, không phát sinh thêm do biến thể. |
| Báo cáo doanh thu | Báo cáo được theo từng biến thể hoặc gộp theo nhóm. |

## Màn hình

**Admin · Sản phẩm**

- Danh sách theo nhóm. Mỗi dòng hiện số biến thể, khoảng giá (420.000đ – 1.150.000đ) và tổng tồn. Bấm vào để mở ra các biến thể.
- Form nhóm gồm: thông tin chung, khu thuộc tính (nhập "Khối lượng: 800g, 2kg, 4kg") và nút **Tạo biến thể**. Nút này sinh sẵn mọi tổ hợp thành một bảng, sửa trực tiếp trên ô cho SKU, mã vạch, giá, đơn vị, bật/tắt. Có ô "áp giá cho tất cả".
- Tạm ngừng bán một biến thể thì không ảnh hưởng các biến thể khác. Biến thể đã có giao dịch thì chỉ được lưu trữ, không được xoá.

**POS** · Thẻ sản phẩm hiện tên nhóm và nhãn "3 loại". Bấm vào thì mở popup chọn loại, mỗi loại kèm giá và tồn; loại đã hết hàng bị làm mờ.

**Shop** · Trang chi tiết có nút chọn cho từng thuộc tính. Giá và ảnh đổi theo lựa chọn; tổ hợp hết hàng bị khoá.

## Triển khai và việc cần chị quyết

Làm trong module sản phẩm đầy đủ, theo thứ tự:

1. Migration: tạo `product_groups` và `product_group_options`, thêm cột vào `products`, chuyển dữ liệu cũ sang mỗi sản phẩm một nhóm. Có RPC `save_product_group` lưu nhóm và biến thể trong một giao dịch.
2. Admin Sản phẩm: danh sách theo nhóm, form thuộc tính và bảng biến thể. Làm chung với danh mục, thương hiệu và ảnh.
3. POS: popup chọn biến thể. Màn kho thêm cách xem gộp theo nhóm.
4. Shop: trang chi tiết và giỏ hàng dùng dữ liệu thật, đơn online trừ kho.

Cần chị quyết:

- [ ] Giới hạn 3 thuộc tính mỗi nhóm có đủ không?
- [ ] Ảnh để chung cho cả nhóm, hay mỗi biến thể được có ảnh riêng (ví dụ áo theo màu)?
- [ ] Nhãn "Freeship" và "7 ngày đổi trả" trên shop có phải chính sách thật không, hay chỉ là nội dung mẫu?
