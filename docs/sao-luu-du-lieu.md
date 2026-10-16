# Sao lưu và khôi phục dữ liệu

Supabase gói Free không có bản backup tải về được. Workflow `Supabase backup` (`.github/workflows/supabase-backup.yml`) tự sao lưu database thật mỗi tuần.

## Workflow làm gì

- Chạy 03:00 sáng Chủ nhật (giờ Việt Nam), hoặc bấm tay: GitHub > Actions > **Supabase backup** > **Run workflow**.
- Chỉ đọc: `supabase db dump` ba phần `roles.sql`, `schema.sql`, `data.sql` (gồm cả tài khoản trong schema `auth`), và chép bucket ảnh thú cưng `pet-photos` vào thư mục `pet-photos/`. Không ghi gì vào database hay Storage.
- Nén và **mã hóa AES256 bằng mật khẩu database** (secret `SUPABASE_DB_PASSWORD`), vì repo công khai và ai đăng nhập GitHub cũng tải được artifact. Ai giải mã được thì vốn đã có mật khẩu database.
- Lưu thành artifact `bongcun-YYYYMMDD` trong 90 ngày (tối đa của GitHub), tức khoảng 13 bản gần nhất.
- Dùng 3 secret đã có (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`), không cần thêm gì.

Lưu ý: nếu đổi mật khẩu database, các bản cũ vẫn cần **mật khẩu cũ** để giải mã. Ghi lại mật khẩu cũ ở chỗ an toàn trước khi đổi. Muốn giữ lâu hơn 90 ngày thì tải file về máy.

## Khôi phục

1. Tải artifact từ trang chạy workflow (Actions > Supabase backup > chọn lần chạy > Artifacts), giải nén file zip của GitHub ra `bongcun-YYYYMMDD.tar.gz.gpg`.
2. Giải mã và giải nén (cần `gpg`, nhập mật khẩu database khi được hỏi):

   ```sh
   gpg -d bongcun-YYYYMMDD.tar.gz.gpg | tar xz
   ```

3. Khôi phục vào **một project Supabase mới, trống** (không chạy đè lên project đang dùng). Lấy chuỗi kết nối của project mới ở Dashboard > Connect, rồi:

   ```sh
   psql --single-transaction --variable ON_ERROR_STOP=1 \
     --file roles.sql --file schema.sql \
     --command 'SET session_replication_role = replica' \
     --file data.sql \
     --dbname "postgresql://postgres:[MẬT_KHẨU]@db.[REF_MỚI].supabase.co:5432/postgres"
   ```

4. Ở project mới: bật lại Custom Access Token Hook (`public.custom_access_token_hook`, xem `docs/supabase-setup.md`), tải lại ảnh trong Storage (bản dump chỉ có thông tin file, không có nội dung ảnh; ảnh thú cưng có trong bản backup, xem bước 5; ảnh sản phẩm và đính kèm bệnh án thì không), đổi `SUPABASE_URL`/key trên Vercel và `SUPABASE_PROJECT_REF` trong secret của repo.

5. Ảnh thú cưng nằm trong thư mục `pet-photos/` của bản giải nén. Sau khi project mới đã có bucket `pet-photos` (migration `20261024010000` tạo bucket), tải lại bằng CLI đã đăng nhập và `link` tới project mới:

   ```sh
   supabase storage cp -r pet-photos ss:///pet-photos --linked
   ```

   Database giữ `pets.photo_path` và `photo_url`; nếu `photo_url` trỏ tới project cũ thì sửa phần địa chỉ gốc cho khớp project mới.

Các bước 3 và 4 là thủ tục chuẩn của Supabase cho bản dump bằng CLI. Việc dump, mã hóa và giải mã đã được thử trên database cục bộ; chưa thử khôi phục toàn bộ vào một project thật.

## Không có trong backup

- File trong Storage ngoài ảnh thú cưng (ảnh sản phẩm, đính kèm bệnh án): chỉ có bảng metadata. Muốn sao lưu cả file thì thêm một bước tải bucket tương tự `pet-photos`, chưa làm.
- Nếu bước "Download pet photos" báo lỗi (có dấu cảnh báo vàng trong lần chạy), bản backup vẫn có database nhưng không có ảnh.
