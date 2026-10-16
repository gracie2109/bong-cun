# Tài liệu

| File | Nội dung |
| --- | --- |
| [kho-theo-lo-han-dung.md](kho-theo-lo-han-dung.md) | Phân tích và thiết kế kho theo lô, hạn dùng (FEFO), phiếu kho, trả hàng |
| [bien-the-san-pham.md](bien-the-san-pham.md) | Kế hoạch biến thể sản phẩm (nhóm sản phẩm, thuộc tính, SKU) |
| [thanh-toan-van-chuyen.md](thanh-toan-van-chuyen.md) | Nghiên cứu kiến trúc thanh toán (SePay) và vận chuyển (GHN) |
| [lich-hen-spa.md](lich-hen-spa.md) | Kế hoạch module lịch hẹn spa: bàn spa, chặn trùng giờ, check-in chốt giá, nối POS |
| [khach-san-thu-cung.md](khach-san-thu-cung.md) | Kế hoạch module khách sạn thú cưng (lưu trú): loại chuồng và giá theo đêm, tự xếp chuồng, check-in/out, nhật ký chăm sóc, nối POS, khách xem |
| [ho-so-benh-an.md](ho-so-benh-an.md) | Kế hoạch module Y tế: tiếp nhận và hàng chờ khám, bệnh án SOAP ký khóa, chỉ định và đơn thuốc trừ kho theo lô, sổ tiêm và nhắc lịch, nối POS, báo cáo, khách xem sổ sức khỏe, nội trú dùng chung chuồng |
| [bao-cao-doanh-thu.md](bao-cao-doanh-thu.md) | Kế hoạch module báo cáo doanh thu: định nghĩa số liệu, RPC, màn hình, quyền, chia file |
| [module-san-pham.md](module-san-pham.md) | Kế hoạch phần còn lại của module sản phẩm: danh mục, thương hiệu, bộ ảnh, giá theo cơ sở, đơn vị quy đổi, nhập/xuất Excel |
| [checkout-shop.md](checkout-shop.md) | Kế hoạch checkout shop online: giỏ hàng thống nhất, địa chỉ, phí GHN, COD và nhận tại cửa hàng, đơn online dùng chung hóa đơn/kho, trang theo dõi đơn |
| [giao-dien-khach-hang.md](giao-dien-khach-hang.md) | Kế hoạch giao diện khách hàng: danh sách và chi tiết sản phẩm, khu tài khoản, thú cưng của tôi, bảng giá và đặt lịch spa online, lịch hẹn của tôi |
| [nhap-xuat-du-lieu.md](nhap-xuat-du-lieu.md) | Kế hoạch nhập/xuất dữ liệu ở admin: xuất Excel/CSV/PDF cho các bảng, nhập Excel/CSV cho dữ liệu gốc, bộ dùng chung, quyền IMPORT/EXPORT |
| [thanh-tim-kiem-chung-cho-bang.md](thanh-tim-kiem-chung-cho-bang.md) | Phân tích thanh tìm kiếm chung cho bảng admin (SearchView: tìm kiếm, lọc, xoá lọc, làm mới, chỗ nút nhập/xuất) và kế hoạch chuyển từng màn |
| [he-thong-giao-dien-shop.md](he-thong-giao-dien-shop.md) | Hệ thống giao diện shop công khai sau đợt làm mới: token màu, font, component dùng chung, các màn đã đổi, việc còn lại |
| [ui-san-pham-danh-gia.md](ui-san-pham-danh-gia.md) | Đánh giá UI trang danh sách sản phẩm của shop (vì sao trông cũ) và hướng làm mới: token, chữ, bố cục, kế hoạch chuyển động, file sẽ đổi |
| [pos-luong-va-kich-ban-test.md](pos-luong-va-kich-ban-test.md) | POS bán tại quầy: luồng thực tế, kịch bản test, edge case, lỗi và khoảng trống |
| [danh-gia-kien-truc.md](danh-gia-kien-truc.md) | Đánh giá kiến trúc Nuxt + Supabase sau khi xong các module chính: điểm mạnh, nợ kỹ thuật theo ưu tiên (CI, test SQL, quyền trong hàm security definer, kiểu jsonb), file lớn, đa chi nhánh, lộ trình |
| [ke-hoach-sua-kien-truc.md](ke-hoach-sua-kien-truc.md) | Kế hoạch sửa nợ kỹ thuật theo bài đánh giá kiến trúc: sửa typecheck, CI trên PR, bản chụp schema, test SQL pgTAP, backup hằng tuần, tách file lớn |
| [ke-hoach-viec-con-lai-kien-truc.md](ke-hoach-viec-con-lai-kien-truc.md) | Ba việc còn lại của đợt sửa kiến trúc: kiểu cho RPC `jsonb` (đã làm cho luồng tiền), `pg_cron` và bảng tổng hợp báo cáo (chưa cần, có ngưỡng) |
| [ke-hoach-monorepo.md](ke-hoach-monorepo.md) | Audit codebase và kế hoạch chuyển sang monorepo (apps web/cms/mobile, packages core, supabase, nuxt-base), feature-first; bản 2: backend thay được (Supabase, NestJS), nghiệp vụ trong SQL so với TS, hợp đồng use case, ports chỉ ở dịch vụ ngoài, lộ trình PR nhỏ có đường lui |
| [ke-hoach-don-monorepo-con-lai.md](ke-hoach-don-monorepo-con-lai.md) | Kế hoạch phần còn lại của monorepo: hợp đồng zod và mã lỗi cho kho, spa, lưu trú, y tế; đưa queries/composables vào features có barrel và luật; bỏ vue-multiselect; thứ tự để tránh đụng thread y tế và ảnh thú cưng |
| [sao-luu-du-lieu.md](sao-luu-du-lieu.md) | Sao lưu database hằng tuần (gói Free không có backup): workflow mã hóa, nơi lấy bản backup, cách khôi phục |
| [supabase-setup.md](supabase-setup.md) | Cài đặt Supabase |

Tài liệu phân tích mới được thêm thẳng vào thư mục này.
