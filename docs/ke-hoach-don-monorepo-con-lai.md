# Kế hoạch dọn monorepo phần còn lại

Ngày: 2026-10-16. Nối tiếp [ke-hoach-monorepo.md](ke-hoach-monorepo.md) mục 24, 25 và 25.1 (đã làm hợp đồng cho POS và checkout). Đây là kế hoạch, không có code ứng dụng.

Ngoài phạm vi (grace hoãn): tách CMS, mobile/Capacitor, layer `nuxt-base`, checkout bước 9 đến 11 (GHN API, VietQR, SePay). Không đổi migration, không chạy SQL lên database thật ở bất kỳ bước nào.

## 1. Ba việc cần làm

| # | Việc | Hiện trạng (đọc mã ngày 2026-10-16) |
| --- | --- | --- |
| 1 | Hợp đồng zod vào/ra, mã lỗi `hint`, mapper sang kiểu miền cho kho, spa, lưu trú, y tế | `packages/supabase/src/{inventory,spa,boarding,medical}` gọi khoảng 105 RPC; khoảng 55 hàm trả `jsonb` (lưu trú 15, y tế 29, spa 10, kho 1). Kết quả đọc bằng `asRecord`/`str`/`numOrNull` (ví dụ `medical/visitMappers.ts`, `boarding/stays.ts`): thiếu khóa thì ra chuỗi rỗng, không báo lỗi. Danh sách `hint` đã có trong `core` (`INVENTORY_ERROR_HINTS`, `BOARDING_ERROR_HINTS`, `MEDICAL_ERROR_HINTS`, `SPA_ERROR_HINTS`) nhưng `toAppError` chỉ đọc hint POS và shop, và test `errorHints.test.ts` chỉ quét hàm tiền |
| 2 | Đưa `src/queries` và `src/composables` vào `src/features`, mỗi feature có `index.ts`, luật dependency-cruiser | 52 file `queries`, 44 file `composables`. Nhiều file dùng chung giữa admin và shop (`queries/shop.ts`, `spa.ts`, `products.ts`, `users.ts`, `boarding/`), nhưng luật hiện tại cấm admin import shop và ngược lại |
| 3 | Bỏ `vue-multiselect` | Chỉ một chỗ dùng: `features/admin/users/components/CustomerGroupsStep.vue`, cộng CSS trong `nuxt.config.ts`. Có sẵn `components/common/CustomCombobox.vue` (reka-ui, có `isMulti`, có ô tìm) chưa ai dùng |

## 2. Thứ tự và lý do

Hai thread khác sắp sửa code: "Y tế còn lại" (nhãn Nội trú trên bảng chuồng, sửa y lệnh, đánh dấu thú cưng đã mất) và "Ảnh thú cưng" (tải ảnh). Để ít đụng nhau:

| Bước | Nội dung | Đụng file nào | Chờ gì |
| --- | --- | --- | --- |
| 1 | Bỏ `vue-multiselect` | `features/admin/users`, `nuxt.config.ts`, `package.json`, lockfile | Không |
| 2 | Hạ tầng hợp đồng chung | `packages/supabase/src/shared`, `core/shared`, `tests/unit`, `tests/db` (helper) | Không |
| 3 | Hợp đồng kho | `core/inventory`, `supabase/inventory` | Không |
| 4a, 4b | Hợp đồng spa (admin, đặt lịch online) | `core/spa`, `supabase/spa` | Không |
| 5a, 5b | Hợp đồng lưu trú | `core/boarding`, `supabase/boarding` | Bước 5b chờ PR "nhãn Nội trú trên bảng chuồng" merge nếu PR đó sửa `boarding_board` |
| 6a, 6b, 6c | Hợp đồng y tế | `core/medical`, `supabase/medical` | **Chờ toàn bộ PR y tế còn lại merge** |
| 7a đến 7e | Chuyển queries/composables vào features, barrel, luật | Gần như mọi màn hình | **Làm cuối**, sau bước 6 và sau PR ảnh thú cưng |

Bước 1 đến 5a làm ngay được. Trước mỗi bước, thread code mở `list_project_prs` xem PR nào đang mở đụng cùng thư mục; nếu có thì làm bước khác trước.

## 3. Quy ước hợp đồng (áp dụng cho bước 3 đến 6)

Giữ cách đã làm cho POS ở mục 25.1:

- **Đầu vào**: schema zod camelCase trong `packages/core/src/<module>/contract/<nhóm>.ts`, ví dụ `core/boarding/contract/stays.ts`. Mỗi file dưới 300 dòng; `contract/index.ts` gom lại. Chỉ viết schema đầu vào cho RPC ghi (lưu, check-in, ký...), không cho RPC chỉ đọc.
- **Kết quả**: schema zod snake_case của `jsonb` thật mà hàm trả, cùng file với đầu vào. Dùng `.nullish()` đúng chỗ SQL có thể trả `null`, không dùng `.passthrough()`.
- **Mapper**: hàm thuần `toX(row: z.infer<typeof xRowSchema>): X` trong `packages/supabase/src/<module>/mappers/<nhóm>.ts`, đổi tên khóa sang kiểu miền đã có trong `core` (`MedicalVisit`, `BoardingStay`...). Repository gọi `parseRpc(rpc, schema, data)` rồi mapper. Bỏ dần `asRecord`/`str` trong module đó; giữ hàm trong `shared/parse.ts` tới khi không ai dùng, rồi xóa.
- **Kiểu miền không đổi** trừ khi mapper lộ ra kiểu sai (ví dụ trường thật ra có thể `null`). Khi đó sửa kiểu và mọi chỗ dùng trong cùng PR, ghi rõ trong mô tả PR.
- **Hàm trả `TABLE(...)`** (`stock_summary`, `sellable_stock`, `branch_prices`...) đã có kiểu từ `database.types.ts`: chỉ cần mapper, không cần schema kết quả.
- **Hàm trả `uuid`/`void`**: không cần schema kết quả.
- **Mã lỗi**: `toAppError` đọc thêm hint của kho, spa, lưu trú, y tế (bước 2). Màn hình vẫn dùng `xxxErrorHint` như cũ; không đổi thông báo nào.

## 4. Các bước

Mỗi bước là một PR, squash merge khi CI xanh (typecheck, build, `deps:check`, Vitest, job `db`). Mỗi PR giữ nguyên hành vi, không có migration. Đường lui chung: revert đúng PR đó trên `main` (không có dữ liệu nào bị đổi).

### Bước 1: Bỏ `vue-multiselect`

- `CustomerGroupsStep.vue` dùng `CustomCombobox` với `isMulti`, `searchLabel`, `showClear`; đổi mảng nhóm thành `SelectOptionValue` (`{ label: name, value: id }`) trong một hàm thuần cạnh component (`customerGroupOptions.ts`).
- Sửa luôn lỗi nhỏ thấy khi đọc: ô nhóm luôn bắt đầu rỗng (`ref([])`) nên khi sửa khách đã có nhóm sẽ không hiện nhóm cũ. Lấy giá trị đầu từ `form.values.groupIds`.
- Xóa dòng CSS trong `nuxt.config.ts`, gỡ gói bằng `npm uninstall vue-multiselect -w @bongcun/web` (lockfile do npm sinh, không sửa tay).
- `CustomCombobox.vue` đang 217 dòng; nếu phải sửa thì tách logic chọn ra `useComboboxSelection.ts` để giữ dưới 300 dòng.
- Kiểm: `grep -r vue-multiselect apps` rỗng; typecheck, build. grace bấm thử: Khách hàng > sửa khách > bước nhóm (chọn nhiều, bỏ chọn, tìm, lưu, mở lại thấy đúng nhóm).
- Rủi ro: thấp, một màn hình.

### Bước 2: Hạ tầng hợp đồng chung

- `packages/supabase/src/shared/errors.ts`: `DbErrorCode` và `toAppError` nhận thêm `InventoryErrorHint`, `SpaErrorHint`, `BoardingErrorHint`, `MedicalErrorHint`. Thứ tự giữ như cũ: mã Postgres trước, rồi hint. Hint trùng tên giữa module (`not_found`, `duplicate_name`) là cùng một chuỗi nên không xung đột.
- `tests/unit/errorHints.test.ts` tách thành bảng `{ module, hints, functions }` (file dữ liệu riêng `errorHintModules.ts`); thêm danh sách hàm của 4 module. Danh sách hàm lấy từ các lời gọi `.rpc("...")` trong `packages/supabase/src/<module>` (đọc file bằng regex trong test), nên thêm RPC mới mà quên hint sẽ đỏ.
- `tests/db/fixtures/` thêm helper tạo dữ liệu nền cho lưu trú và y tế (loại chuồng, chuồng, dịch vụ khám, bác sĩ), dùng lại SQL đang có trong `supabase/tests/boarding.test.sql` và `medical_visit.test.sql` (chuyển phần dựng dữ liệu vào `supabase/tests/_helpers/setup.psql` dưới dạng hàm `tests.create_*`, để pgTAP và Vitest dùng chung). Đây là file test, không phải migration.
- Kiểm: unit test đỏ nếu bỏ một hint khỏi danh sách (thử rồi hoàn lại); `npm run db:test` và `npm run test:db` xanh.
- Rủi ro: thấp. Test có thể đỏ ngay vì hàm SQL ném hint mà `core` chưa đặt tên: thêm tên vào danh sách `core` tương ứng (không đổi SQL).

### Bước 3: Hợp đồng kho

- Đầu vào: `save_stock_document` (phiếu nhập, xuất, điều chỉnh, chuyển kho; các dòng có lô và hạn), `post_stock_document`, `cancel_stock_document`, `set_min_stock`.
- Kết quả: `stock_alert_counts` (schema). Mapper cho `stock_summary`, `sellable_stock`, lô, chuyển động kho.
- Test DB `inventory.contract.test.ts`: tạo phiếu nhập nháp, ghi sổ, `stock_summary` tăng đúng; xuất quá tồn ném `lot_short`; ghi sổ phiếu đã ghi ném `not_draft`.
- Rủi ro: thấp; kho đã có test pgTAP gián tiếp qua POS.

### Bước 4a: Hợp đồng spa phía admin

- Đầu vào: `save_appointment`, `check_in_appointment`, `set_appointment_item_status`, `cancel_appointment`, `mark_no_show`, `save_pet_service`, `save_pet_combo`, `save_service_prices`, `save_branch_hours`, `save_spa_resource`.
- Kết quả: `get_appointment`, `list_appointments`, `spa_day_board`, `spa_week_hours`, `billable_appointment_items`.
- Test DB: lưu lịch hẹn, xem bảng ngày, check-in, `billable_appointment_items` khớp schema; trùng giờ ném đúng hint.

### Bước 4b: Hợp đồng đặt lịch spa online

- Đầu vào: `book_my_appointment`. Kết quả: `spa_public_catalog`, `spa_web_rules`, `spa_web_slots`, `spa_web_quote`, `book_my_appointment`.
- Test DB: khách đăng nhập đặt lịch trên khung giờ trống; khung đã kín ném hint; báo giá theo cân nặng khớp `core/spa/rules.ts` (đối chiếu TS và SQL như phí ship ở mục 25).
- Rủi ro: trung bình; trang shop server render. `parseRpc` ném lỗi khi sai hình dạng, nên trên SSR sẽ là trang lỗi thay vì ô trống: chạy build và mở thử `/spa` cục bộ nếu có DB.

### Bước 5a: Hợp đồng lưu trú (đặt chỗ, nhận, trả)

- Đầu vào: `save_boarding_stay`, `check_in_boarding`, `check_out_boarding`, `extend_boarding_stay`, `move_boarding_pet`, `cancel_boarding_stay`, `mark_boarding_no_show`, `add_boarding_extra`, `remove_boarding_extra`.
- Kết quả: `boarding_quote`, `boarding_availability`, `save_boarding_stay`, `get_boarding_stay`, `list_boarding_stays`, `check_in_boarding`, `check_out_boarding`, `boarding_checkout_preview`, `billable_boarding_charges`.
- Thay mapper tay trong `supabase/boarding/stays.ts` (193 dòng) bằng `mappers/stays.ts`; `warnings` có schema riêng thay vì ép kiểu `as QuoteWarning[]`.
- Test DB: đặt chỗ, báo giá, nhận chuồng, trả chuồng, phí ra POS.

### Bước 5b: Hợp đồng lưu trú (bảng chuồng, nhật ký, cài đặt)

- Kết quả: `boarding_board`, `boarding_timeline`, `list_kennels`, `list_kennel_types`, `boarding_settings_get`, `boarding_public_catalog`. Đầu vào: `add_care_log`, `save_kennel`, `save_kennel_type`, `set_kennel_status`, `save_boarding_settings`.
- Chờ: nếu PR "nhãn Nội trú trên bảng chuồng" thêm khóa vào `boarding_board`, làm sau khi PR đó merge để schema có luôn khóa mới.

### Bước 6: Hợp đồng y tế (bắt đầu sau khi mọi PR y tế còn lại merge)

Chia ba PR, mỗi PR một nhóm file:

- **6a Lượt khám**: `medical_queue`, `list_medical_visits`, `get_medical_visit`, `check_in_medical_visit`, `sign_medical_visit`, `add_medical_item`, `update_medical_item`, `medical_prescription`, `billable_medical_items`, `pet_medical_history`; đầu vào `schedule_medical_visit`, `save_medical_record`, `add_medical_item`, `assign_medical_vet`, `add_medical_addendum`. Thay `visitMappers.ts` (128 dòng) bằng mapper trên dữ liệu đã parse. Test DB: tiếp nhận, khám, kê đơn, ký, ra POS.
- **6b Tiêm và danh mục**: `pet_vaccinations`, `give_vaccination`, `vaccine_lots`, `medical_reminders`, `list_vaccine_types`, `list_diagnosis_terms`, `medical_settings_get`, `medical_vets`, `pet_health_flags`, `list_medical_attachments`; đầu vào tương ứng. Nếu thread "Ảnh thú cưng" đổi `storage.ts`, đính kèm y tế theo cách mới đó.
- **6c Nội trú**: `inpatient_ward`, `inpatient_kennels`, `admit_inpatient`, `discharge_inpatient`, `give_inpatient_dose`; đầu vào `save_inpatient_order` (gồm phần "sửa y lệnh" mới), `add_inpatient_log`. Kiểm hint `pet_deceased` và các hint mới do thread y tế thêm đều có trong `MEDICAL_ERROR_HINTS` (test bước 2 bắt được).

Rủi ro: trung bình; y tế là module lớn nhất. Mỗi PR chỉ đổi adapter và test, màn hình không đổi.

### Bước 7: Đưa queries và composables vào features (làm cuối)

**Trạng thái (2026-10-17): xong 7a đến 7e, đã merge #183, #185, #186, #187.**

**Cấu trúc đích**

```
src/features/
  admin/<module>/        màn hình, components, queries/, composables/, index.ts
  shop/<module>/         như trên
  shared/<module>/       queries/composables dùng cả admin lẫn shop (spa, shop, products, users, account, boarding)
  auth/, home/
src/queries/             chỉ hạ tầng: keys.ts, invalidate.ts, notify.ts
src/composables/         chỉ composable chung không thuộc nghiệp vụ: usePagedList, useListFilters,
                         useTableExport/Import, usePermission, useCurrentBranch, useValidation, usePolling...
```

Quy tắc chọn chỗ: file chỉ một feature dùng thì vào feature đó; file dùng ở cả admin và shop thì vào `features/shared/<module>`; file chỉ admin dùng nhưng nhiều module admin dùng (ví dụ `queries/pos.ts` dùng ở POS, lưu trú, y tế, lịch) thì vào module sở hữu nghiệp vụ (`admin/pos`) và module khác import qua `admin/pos/index.ts`. Bảng chủ sở hữu từng file làm ở 7a bằng script (đếm ai import), không đoán tay.

**Các PR**

- **7a** Script và bảng chủ sở hữu: `scripts/feature-owners.mjs` in bảng file → feature dùng → chỗ đích; đưa bảng vào doc này. Chưa chuyển file.
- **7b** Phía shop: `composables/shop`, `composables/account`, `composables/spa`, `queries/shop*.ts`, `account*.ts`, `spaWeb.ts`, `boardingWeb.ts`... vào `features/shop/*` hoặc `features/shared/*`. `git mv` và viết lại import bằng script, không đổi nội dung.
- **7c** Admin nghiệp vụ: y tế, lưu trú, POS, kho, lịch.
- **7d** Admin còn lại: sản phẩm, khách hàng, thú cưng, cài đặt, báo cáo, nhân viên.
- **7e** Barrel và luật: mỗi `features/<area>/<module>/index.ts` export đúng những gì feature khác đang dùng (danh sách lấy từ build, không `export *` cả thư mục). Luật dependency-cruiser mới:
  - `feature-via-index`: import sang feature khác chỉ qua `index.ts` của nó; trong cùng feature dùng đường tương đối.
  - `shared-features-standalone`: `features/shared` không import `features/admin|shop|auth|home`.
  - `queries-infra-only`: `src/queries` chỉ còn `keys`, `invalidate`, `notify`.
  - Giữ luật cũ: admin và shop không import nhau (cả hai được import `features/shared`).

### Bảng chủ sở hữu (7a, 2026-10-17)

Chạy `node apps/web/scripts/feature-owners.mjs` (trong `apps/web`) để in lại bảng từ đồ thị import. Quyết định cuối cho các file không có một chủ duy nhất nằm ở `apps/web/scripts/featureDecisions.mjs`: file dùng chung nhiều module và không có chủ nghiệp vụ ở lại `src/composables`; file dùng cả admin lẫn shop vào `features/shared/<module>`; file nhiều module admin dùng vào module giữ luật nghiệp vụ.

| File | Used by | Destination | Note |
| --- | --- | --- | --- |
| `src/composables/account/useMyAppointments.ts` | shop/account | `features/shop/account/composables` | one module |
| `src/composables/account/useMyBoarding.ts` | shop/account | `features/shop/account/composables` | one module |
| `src/composables/account/useMyPets.ts` | shop/account | `features/shop/account/composables` | one module |
| `src/composables/account/useProfileForm.ts` | shop/account | `features/shop/account/composables` | one module |
| `src/composables/layout/useHeaderSearch.ts` | - | `src/composables (stays)` | generic or unused |
| `src/composables/listFilters.ts` | admin/boarding, admin/inventory, admin/medical, admin/pets, admin/pos, admin/products, admin/reports, admin/schedule, admin/users, admin/shop-orders | `src/composables (stays)` | generic or unused |
| `src/composables/shop/useAddToCart.ts` | shop/product, home, shop/catalog | `features/shop/cart/composables` | decided in featureDecisions.mjs |
| `src/composables/shop/useAddressBook.ts` | shop/account | `features/shop/account/composables` | one module |
| `src/composables/shop/useAddressForm.ts` | shop/account, shop/checkout | `features/shop/account/composables` | decided in featureDecisions.mjs |
| `src/composables/shop/useCartPage.ts` | shop/cart | `features/shop/cart/composables` | one module |
| `src/composables/shop/useCartView.ts` | shop/checkout, shop/cart | `features/shop/cart/composables` | decided in featureDecisions.mjs |
| `src/composables/shop/useCatalog.ts` | shop/catalog | `features/shop/catalog/composables` | one module |
| `src/composables/shop/useCatalogChips.ts` | shop/catalog | `features/shop/catalog/composables` | one module |
| `src/composables/shop/useCatalogFilters.ts` | shop/catalog | `features/shop/catalog/composables` | one module |
| `src/composables/shop/useCheckout.ts` | shop/checkout | `features/shop/checkout/composables` | one module |
| `src/composables/shop/useCheckoutAddress.ts` | shop/checkout | `features/shop/checkout/composables` | one module |
| `src/composables/shop/useGhnLocationPicker.ts` | admin/shop-orders, shop/account, shop/checkout | `features/shared/shop/composables` | decided in featureDecisions.mjs |
| `src/composables/shop/useMyOrders.ts` | shop/account | `features/shop/account/composables` | one module |
| `src/composables/shop/useOrderFeeQuote.ts` | admin/shop-orders | `features/admin/shop-orders/composables` | one module |
| `src/composables/shop/useOrderPage.ts` | shop/orders | `features/shop/orders/composables` | one module |
| `src/composables/shop/useOrderSheet.ts` | admin/shop-orders | `features/admin/shop-orders/composables` | one module |
| `src/composables/shop/useOrdersPage.ts` | admin/shop-orders | `features/admin/shop-orders/composables` | one module |
| `src/composables/shop/useProductPage.ts` | shop/product | `features/shop/product/composables` | one module |
| `src/composables/shop/useQtyInput.ts` | shop/cart | `features/shop/cart/composables` | one module |
| `src/composables/shop/useServerPrefetch.ts` | home, shop/catalog | `src/composables (stays)` | generic or unused |
| `src/composables/shop/useShippingQuote.ts` | shop/checkout | `features/shop/checkout/composables` | one module |
| `src/composables/shop/useShippingTest.ts` | admin/shop-orders | `features/admin/shop-orders/composables` | one module |
| `src/composables/shop/useShopSettingsForm.ts` | admin/shop-orders | `features/admin/shop-orders/composables` | one module |
| `src/composables/spa/useBookingWizard.ts` | shop/spa | `features/shop/spa/composables` | one module |
| `src/composables/spa/useDurationLabel.ts` | home, shop/spa | `features/shop/spa/composables` | decided in featureDecisions.mjs |
| `src/composables/spa/useSpaCatalog.ts` | home, shop/spa | `features/shop/spa/composables` | decided in featureDecisions.mjs |
| `src/composables/useCurrentBranch.ts` | admin/boarding, admin/dashboard, admin/inventory, admin/medical, admin/pos, admin/reports, admin/schedule | `src/composables (stays)` | generic or unused |
| `src/composables/useInfiniteOptions.ts` | admin/inventory, admin/pos, admin/products, shop/product, home, shop/catalog | `src/composables (stays)` | generic or unused |
| `src/composables/useListFilters.ts` | admin/boarding, admin/inventory, admin/medical, admin/pets, admin/pos, admin/products, admin/reports, admin/schedule, admin/users, admin/shop-orders | `src/composables (stays)` | generic or unused |
| `src/composables/usePagedList.ts` | admin/boarding, admin/inventory, admin/medical, admin/pets, admin/pos, admin/products, admin/reports, admin/schedule, admin/users, admin/shop-orders | `src/composables (stays)` | generic or unused |
| `src/composables/usePagedRows.ts` | - | `src/composables (stays)` | generic or unused |
| `src/composables/usePagedSearch.ts` | admin/reports | `src/composables (stays)` | generic or unused |
| `src/composables/usePermission.ts` | admin/inventory, admin/pets, admin/pos, admin/products, admin/settings, admin/users | `src/composables (stays)` | generic or unused |
| `src/composables/usePolling.ts` | - | `src/composables (stays)` | generic or unused |
| `src/composables/useTableExport.ts` | admin/boarding, admin/inventory, admin/medical, admin/pets, admin/pos, admin/products, admin/reports, admin/schedule, admin/shop-orders, admin/users | `src/composables (stays)` | generic or unused |
| `src/composables/useTableImport.ts` | admin/inventory, admin/pets, admin/products | `src/composables (stays)` | generic or unused |
| `src/composables/useToastImage.ts` | - | `src/composables (stays)` | generic or unused |
| `src/composables/useValidation.ts` | auth, admin/components, admin/users, shop/account, admin/products | `src/composables (stays)` | generic or unused |
| `src/composables/useVariantChoice.ts` | admin/pos, shop/product, home, shop/catalog | `features/shared/products/composables` | decided in featureDecisions.mjs |
| `src/queries/account.ts` | shop/account, shop/spa | `features/shop/account/queries` | decided in featureDecisions.mjs |
| `src/queries/accountAppointments.ts` | shop/account | `features/shop/account/queries` | one module |
| `src/queries/accountBoarding.ts` | shop/account | `features/shop/account/queries` | one module |
| `src/queries/accountHealth.ts` | shop/account | `features/shop/account/queries` | one module |
| `src/queries/boarding/action.ts` | admin/boarding, admin/dashboard, admin/pos | `features/admin/boarding/queries` | decided in featureDecisions.mjs |
| `src/queries/boarding/calendar.ts` | admin/boarding, admin/dashboard, admin/pos | `features/admin/boarding/queries` | decided in featureDecisions.mjs |
| `src/queries/boarding/care.ts` | admin/boarding, admin/dashboard, admin/pos | `features/admin/boarding/queries` | decided in featureDecisions.mjs |
| `src/queries/boarding/failure.ts` | admin/boarding, admin/dashboard, admin/pos | `features/admin/boarding/queries` | decided in featureDecisions.mjs |
| `src/queries/boarding/index.ts` | admin/boarding, admin/dashboard, admin/pos | `features/admin/boarding/queries` | decided in featureDecisions.mjs |
| `src/queries/boarding/kennels.ts` | admin/boarding, admin/dashboard, admin/pos | `features/admin/boarding/queries` | decided in featureDecisions.mjs |
| `src/queries/boarding/stays.ts` | admin/boarding, admin/dashboard, admin/pos | `features/admin/boarding/queries` | decided in featureDecisions.mjs |
| `src/queries/boardingWeb.ts` | shop/boarding | `features/shop/boarding/queries` | one module |
| `src/queries/bookings.ts` | - | `src/queries (stays)` | generic or unused |
| `src/queries/branchPrices.ts` | admin/pos, admin/products | `features/admin/products/queries` | decided in featureDecisions.mjs |
| `src/queries/branches.ts` | admin/reports, admin/pets, admin/products, admin/settings, admin/shop-orders, admin/boarding, admin/dashboard, admin/inventory, admin/medical, admin/pos, admin/schedule, home, shop/spa | `features/shared/branches/queries` | decided in featureDecisions.mjs |
| `src/queries/customerAccounts.ts` | admin/pets | `features/admin/pets/queries` | one module |
| `src/queries/customers.ts` | admin/pos, admin/pets | `features/admin/pets/queries` | decided in featureDecisions.mjs |
| `src/queries/dataImports.ts` | admin/inventory, admin/pets | `features/admin/inventory/queries` | decided in featureDecisions.mjs |
| `src/queries/ghnLocations.ts` | admin/shop-orders, shop/account, shop/checkout | `features/shared/shop/queries` | decided in featureDecisions.mjs |
| `src/queries/inpatient.ts` | admin/medical | `features/admin/medical/queries` | one module |
| `src/queries/inventory.ts` | admin/inventory, admin/pos | `features/admin/inventory/queries` | decided in featureDecisions.mjs |
| `src/queries/medical.ts` | admin/medical, admin/dashboard, admin/pets | `features/admin/medical/queries` | decided in featureDecisions.mjs |
| `src/queries/medicalAttachments.ts` | admin/medical | `features/admin/medical/queries` | one module |
| `src/queries/medicalBilling.ts` | admin/pos | `features/admin/pos/queries` | one module |
| `src/queries/medicalFlags.ts` | admin/medical | `features/admin/medical/queries` | one module |
| `src/queries/medicalVisits.ts` | admin/dashboard, admin/medical, admin/pets | `features/admin/medical/queries` | decided in featureDecisions.mjs |
| `src/queries/orders.ts` | admin/users | `features/admin/users/queries` | one module |
| `src/queries/permissions.ts` | admin/settings | `features/admin/settings/queries` | one module |
| `src/queries/petCombos.ts` | admin/pets | `features/admin/pets/queries` | one module |
| `src/queries/petServices.ts` | admin/boarding, admin/medical, admin/pets, admin/pos, admin/schedule | `features/admin/pets/queries` | decided in featureDecisions.mjs |
| `src/queries/pets.ts` | admin/pets | `features/admin/pets/queries` | one module |
| `src/queries/pos.ts` | admin/boarding, admin/medical, admin/pos, admin/schedule | `features/admin/pos/queries` | decided in featureDecisions.mjs |
| `src/queries/productCategories.ts` | admin/pos, admin/products, home, shop/catalog | `features/shared/products/queries` | decided in featureDecisions.mjs |
| `src/queries/productClinicOnly.ts` | admin/products | `features/admin/products/queries` | one module |
| `src/queries/productImport.ts` | admin/products | `features/admin/products/queries` | one module |
| `src/queries/products.ts` | admin/inventory, admin/pos, admin/products, shop/product | `features/shared/products/queries` | decided in featureDecisions.mjs |
| `src/queries/reports.ts` | admin/dashboard, admin/reports | `features/admin/reports/queries` | decided in featureDecisions.mjs |
| `src/queries/roles.ts` | admin/settings | `features/admin/settings/queries` | one module |
| `src/queries/servicePrices.ts` | admin/pets | `features/admin/pets/queries` | one module |
| `src/queries/shop.ts` | shop/product, admin/shop-orders, shop/checkout, shop/cart | `features/shared/shop/queries` | decided in featureDecisions.mjs |
| `src/queries/shopAddresses.ts` | shop/checkout, shop/account | `features/shop/account/queries` | decided in featureDecisions.mjs |
| `src/queries/shopCatalog.ts` | home, shop/product, shop/catalog | `features/shop/catalog/queries` | decided in featureDecisions.mjs |
| `src/queries/shopOrders.ts` | shop/account, shop/orders, shop/checkout | `features/shop/orders/queries` | decided in featureDecisions.mjs |
| `src/queries/shopOrdersAdmin.ts` | admin/shop-orders | `features/admin/shop-orders/queries` | one module |
| `src/queries/spa.ts` | admin/pos, admin/schedule | `features/admin/schedule/queries` | decided in featureDecisions.mjs |
| `src/queries/spaCatalog.ts` | home, shop/spa | `features/shop/spa/queries` | decided in featureDecisions.mjs |
| `src/queries/spaWeb.ts` | shop/spa | `features/shop/spa/queries` | one module |
| `src/queries/species.ts` | admin/boarding, admin/medical, admin/pets | `features/admin/pets/queries` | decided in featureDecisions.mjs |
| `src/queries/staff.ts` | admin/settings | `features/admin/settings/queries` | one module |
| `src/queries/users.ts` | admin/users | `features/admin/users/queries` | one module |
| `src/queries/vaccinations.ts` | admin/dashboard, admin/medical, admin/pets | `features/admin/medical/queries` | decided in featureDecisions.mjs |
| `src/queries/weightBrackets.ts` | admin/pets | `features/admin/pets/queries` | one module |

Ghi chú: `composables/layout/useHeaderSearch`, `usePagedRows`, `usePolling`, `useToastImage` và `queries/bookings` hiện không màn hình nào import; giữ nguyên, không xóa trong bước này. Vì `features/shared` không được import `admin` hay `shop`, nếu 7e báo `queries/shop` hay `queries/products` import ngược một module admin/shop thì tách phần đó ra khỏi `shared`.

**Kiểm mỗi PR**: typecheck, build, `deps:check`, Vitest; `git diff --stat -M` cho thấy toàn bộ là rename (100%) trừ dòng import. Sau 7b, 7c, 7d grace bấm thử nhanh: shop (xem sản phẩm, giỏ, đặt lịch spa, tài khoản), admin (POS bán một đơn, mở bệnh án, bảng chuồng, nhập kho).

**Rủi ro**

- Nuxt tự import file ở cấp đầu `src/composables`; chuyển đi thì mất tự import. Mã hiện import tường minh (168 chỗ `@/composables`), typecheck sẽ bắt chỗ nào còn dựa vào tự import.
- Xung đột với mọi PR đang mở: chỉ làm khi `list_project_prs` không còn PR mở nào đụng `apps/web/src` (trừ PR #53). Mỗi PR chuyển xong merge ngay để không kéo dài.
- Vòng import giữa feature qua barrel: dependency-cruiser bật `no-circular` cho `src/features` ở 7e.

## 5. Bảo đảm xuyên suốt

- Không file `.vue`/`.ts` mới hoặc bị sửa nào quá khoảng 300 dòng; UI, logic, helper, composable, kiểu ở file riêng.
- Không đổi hành vi, chữ hiển thị, quyền hay SQL. Hint mới chỉ thêm tên ở `core`.
- Mỗi PR chạy GitNexus `detect_changes` trước khi commit (theo `CLAUDE.md`).
- Commit, tiêu đề PR bằng tiếng Anh; tác giả gracie2109; squash merge.
- Cập nhật mục 24/25 của `ke-hoach-monorepo.md` khi xong từng nhóm bước.

## 6. Việc grace làm sau

- Sau bước 1: bấm thử chọn nhóm khách.
- Sau bước 4b: mở trang đặt lịch spa trên shop.
- Sau 7b, 7c, 7d: bấm thử nhanh như ở bước 7.
