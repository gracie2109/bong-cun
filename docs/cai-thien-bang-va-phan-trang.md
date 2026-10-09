# Cải thiện giao diện bảng và phân trang (admin)

Phân tích từ code nhánh `refactor/view-structure` và 4 ảnh chụp: tồn kho, sản phẩm, và bảng tham chiếu từ app cũ (kèm trạng thái rỗng).

## 1. Hiện trạng

Admin có 4 kiểu bảng cùng tồn tại:

| Kiểu | Dùng ở | Ghi chú |
| --- | --- | --- |
| `PagedTableCard` + `<table>` viết tay | tồn kho, sản phẩm, hóa đơn, ca thu ngân, thú cưng, dịch vụ, phiếu kho, nhà cung cấp | Phổ biến nhất, mỗi màn tự viết class cho `th`/`td` |
| `TablePager` đứng riêng | combo dịch vụ, khách hàng | Cùng nút trang như trên nhưng không có thẻ bọc |
| `DataTable` (TanStack) + `CustomPagination` | lịch dịch vụ | Giống ảnh tham chiếu (số trang, số dòng mỗi trang) nhưng chỉ còn 1 màn dùng |
| Bảng riêng | phân quyền, ma trận | Không phân trang |

Phân trang hiện tại (`TablePager`): chỉ có nút trước/sau và chữ "Trang 1 / 1", nằm ở thanh trên của thẻ. Mỗi màn cố định số dòng (ví dụ sản phẩm 20), người dùng không đổi được, không nhảy về trang đầu/cuối, không thấy mình đang xem dòng nào trong tổng bao nhiêu (chỉ có chip "12 / 12").

## 2. Vấn đề nhìn thấy trong ảnh

**Tồn kho (ảnh 1)**
- Mọi dòng đều số 0 màu đỏ nên đỏ mất ý nghĩa cảnh báo. Chỉ nên đỏ khi dưới mức tối thiểu hoặc đã hết hạn.
- Nhiều cột chỉ có "—" lặp lại, làm bảng rỗng và rời rạc. Cột tên chiếm quá nhiều chỗ, các cột số bị đẩy sang phải rất xa nhau.
- Các biến thể của cùng một sản phẩm hiện thành các dòng tách rời, không gom nhóm.
- Chiều rộng tối đa 2200px (thay đổi lần tách file, đã trả về 1600px) làm khoảng cách giữa các cột còn xa hơn.

**Sản phẩm (ảnh 2)**
- Header chữ hoa nhỏ màu nhạt, khó phân biệt với nội dung. Không có đường ngăn rõ ràng giữa header và dòng đầu.
- Nút `⋮` nằm sát mép phải, xa cột giá. Cột SKU luôn "—" khi nhóm có biến thể.
- Bảng ít dòng thì phần dưới trống, không có chỗ cho phân trang ở cuối nên mắt phải nhìn lên góc trên.

**Bảng tham chiếu (ảnh 3, 4)** có những điểm đáng lấy: header nền xám với chữ đậm đen, thanh công cụ (xóa lọc, lọc, cột hiển thị, làm mới), phân trang ở cuối với "Số bản ghi trên trang" và số trang, trạng thái rỗng có biểu tượng và chữ "Không có dữ liệu". Điểm không nên lấy: chữ nhỏ dày đặc, viền xám đậm, nền xám ngoài bảng làm giảm tương phản.

## 3. Giải pháp đề xuất

Gom về một bộ bảng dùng chung. Vì 8 màn đã dùng `PagedTableCard`, sửa ở component chung là các màn được cải thiện cùng lúc, không phải sửa từng màn.

**A. Phân trang mới (`TablePager`), đặt ở chân bảng**
- Bên trái: "Hiển thị 1–20 / 134" và ô chọn số dòng mỗi trang (10, 20, 50, 100).
- Bên phải: về trang đầu, trước, các số trang (rút gọn bằng "…", ví dụ 1 … 4 5 6 … 12), sau, về trang cuối.
- Màn hẹp (iPad dọc, điện thoại): chỉ còn trước/sau và "Trang x / y", ô chọn số dòng xuống dòng dưới.
- Số dòng mỗi trang nhớ theo từng bảng trong trình duyệt. Đổi số dòng thì về trang 1.
- Dùng sẵn các component `src/components/ui/pagination/*`. Phân trang đã chạy ở phía server (range), đổi số dòng chỉ là đổi `page.pageSize`, **không cần SQL**.

**B. Thẻ bảng (`PagedTableCard`)**
- Thanh trên giữ chip tổng số và có chỗ (slot) cho nút làm mới, chọn cột sau này. Phân trang chuyển xuống chân thẻ, luôn hiện (không cuộn mất).
- Có trạng thái đang tải lại (làm mờ nhẹ dòng cũ) thay vì giật khi đổi trang.

**C. Kiểu dáng bảng, viết 1 lần trong `index.css` (class `.admin-table`)**
- Header: nền xám nhạt, chữ đậm 12–13px, không viết hoa toàn bộ, sticky khi cuộn (đã có).
- Dòng: cao vừa phải (`py-2.5`), đường kẻ mảnh, hover nhẹ, cột số căn phải và dùng số cùng độ rộng (`tabular-nums`).
- Dòng đầu tiên là tên in đậm, dòng phụ (SKU, đơn vị) chữ nhỏ nhạt như hiện tại.
- Cột thao tác `⋮` có độ rộng cố định, sát cột cuối.

**D. Trạng thái rỗng và lỗi (`TableStateRows`)**
- Rỗng: biểu tượng, câu giải thích và gợi ý hành động (ví dụ "Xóa bộ lọc").
- Đang tải: skeleton đúng số cột. Lỗi: thông báo kèm nút "Thử lại".

**E. Sửa riêng cho tồn kho**
- Chỉ tô đỏ khi dưới mức tối thiểu, đã hết hạn hoặc bằng 0 của sản phẩm đang theo dõi tồn.
- Gom dòng biến thể dưới tên nhóm sản phẩm, hoặc ít nhất hiện tên nhóm ở dòng trên, biến thể ở dòng dưới.

## 4. Thứ tự làm

1. `TablePager` mới + `PagedTableCard` (chân trang, số dòng mỗi trang). Cả 8 màn tự được cập nhật.
2. Class `.admin-table` và áp vào các `<table>` hiện có (chỉ đổi class, không đổi logic).
3. Chuyển 2 màn đang dùng `TablePager` rời (combo, khách hàng) sang `PagedTableCard`.
4. Làm lại tồn kho (mục E). Chuyển lịch dịch vụ sang bộ chung rồi bỏ `CustomPagination` nếu không còn ai dùng.

Mỗi bước là một PR nhỏ. Không có thay đổi cơ sở dữ liệu nào.

## 5. Cần chốt

- Header: nền xám chữ đậm như ảnh tham chiếu (khuyên dùng) hay giữ chữ hoa nhỏ như hiện tại?
- Phân trang: chỉ ở chân bảng (khuyên dùng) hay cả trên lẫn dưới?
- Phạm vi: áp dụng ngay cho cả 8 màn (khuyên dùng, vì sửa ở component chung) hay thử trên tồn kho và sản phẩm trước?

## 6. Bổ sung: bảng chiếm hết chiều cao và quy ước API danh sách

**Bảng full chiều cao.** `ContentWrap` có thuộc tính `fill`: trang cao đúng bằng màn hình trừ thanh header, xếp theo cột. Phần lọc ở trên giữ chiều cao tự nhiên, `PagedTableCard` chiếm phần còn lại. Hàng cuộn cả hai chiều trong khung, header dính ở trên, phân trang cố định ở chân. Thẻ nhận thêm `height` (chiều cao cố định) và `scroll-x` (độ rộng tối thiểu của bảng, hẹp hơn thì cuộn ngang).

**Quy ước API danh sách.** Hàm lấy danh sách nhận `(client, page, filter)` với `page = { pageIndex, pageSize }` và `filter.search`, trả về `{ rows, total }`.
- Đã có sẵn: tồn kho, phiếu kho, nhà cung cấp, hóa đơn, thú cưng, dịch vụ, khách hàng, nhóm sản phẩm.
- Thêm trong lần này: tìm theo tên cho combo, tìm theo tên/số điện thoại cho đơn hàng, tìm theo mã/người mở cho ca thu ngân.
- Danh sách trong ô chọn: `useInfiniteOptions` đọc từng trang (20 dòng), tìm kiếm chạy ở server (trễ 500ms) và cuộn tới cuối thì tải trang kế (`InfiniteSelect`, `ScrollSentinel`). Đã dùng cho ô chọn nhà cung cấp ở phiếu nhập và ô thêm sản phẩm vào phiếu kho (`listSupplierOptions`, `listSellableProducts`).
- Chưa đổi: các danh mục nhỏ, cố định (chi nhánh, loài, vai trò, quyền, thuộc tính, mốc cân nặng, nhân viên) và tìm khách ở POS (hàm `search_customers` chỉ nhận số dòng tối đa, thêm phân trang cần sửa SQL).

## 7. Áp dụng cho tất cả các bảng

- Trang danh sách dùng thẻ bảng chung (`PagedTableCard`, chiều cao đầy đủ, phân trang ở chân): 8 màn đầu, combo dịch vụ, khách hàng (full chiều cao từ màn `xl` trở lên, hẹp hơn thì xếp dọc), lịch dịch vụ (`DataTable`, bỏ thanh phân trang cố định ở đáy màn hình) và danh sách quyền.
- Trạng thái rỗng căn giữa khung nhờ thuộc tính `data-table-empty` của `TableStateRows` và CSS `.admin-table`.
- Bảng nhỏ nằm trong form hoặc khung bên (dòng phiếu kho, lô, biến thể, hóa đơn, bảng giá, mốc cân nặng, ma trận quyền) chỉ đổi kiểu header qua class `admin-table`.
- `DataTable` không còn cắt trang ở phía client (`manualPagination`), vì dữ liệu đã được server phân trang sẵn.
