# Thanh tìm kiếm chung cho bảng admin (SearchView + Table)

Phân tích ngày 14/10/2026, theo ảnh UI bảng ở công ty chị. Mô hình của chị: một màn danh sách gồm 2 component chính:

1. **SearchView**: một ô tìm kiếm dài, rồi hàng nút. Nút mặc định: **Xoá lọc** (đầu), **Lọc** (nội dung bộ lọc do màn truyền vào), **Làm mới** (cuối). Nút mặc định ẩn/hiện được; màn truyền thêm nút riêng (tải xuống, cài đặt...).
2. **Table**: bảng có sẵn phân trang ở chân.

Tài liệu này đối chiếu với code admin hiện tại, kết luận có nên làm, thiết kế API và kế hoạch chuyển từng màn. **Chưa code.**

## 1. Kết luận ngắn

- **Nên làm.** Phần Table mình đã có đúng mô hình (`PagedTableCard`). Phần thiếu là SearchView: hiện mỗi màn tự viết thanh lọc, chép cùng một đoạn markup ô tìm kiếm khoảng 15 lần, không có nút xoá lọc, không có nút làm mới, và nút "Tải xuống" mới (PR #82, #83) mỗi màn đặt một chỗ. Một component chung gọn cả 3 việc và là chỗ đặt sẵn cho nút nhập/xuất sắp có.
- **Làm bản nhẹ, bằng slot, không làm lại bảng.** Giữ `PagedTableCard` + `<table>` viết tay (không quay lại `DataTable` TanStack). Thêm `SearchView` mới + composable `useListFilters`. Xoá `SearchView` cũ đang bỏ không.
- **Chuyển dần, mỗi màn vài dòng.** Làm thử ở 2 màn không đụng thread nhập/xuất (thương hiệu, danh mục), rồi chuyển các màn còn lại **sau khi** thread nhập/xuất xong bước của màn đó.

## 2. Hiện trạng

### 2.1 Table: đã đúng mô hình

`src/components/common/PagedTableCard.vue` (78 dòng) đã là "bảng chứa phân trang": thẻ tự lấp chiều cao còn lại, cuộn x/y bên trong, header dính, chân thẻ có "1–20 / 134", chọn số dòng 10/20/50/100 (nhớ theo từng màn), nút đầu/trước/số trang/sau/cuối (`TablePager`). Dùng ở khoảng 20 màn. `TableStateRows` lo skeleton khi tải và trạng thái rỗng ở giữa bảng.

Còn thiếu nhỏ: trạng thái rỗng không phân biệt "chưa có dữ liệu" với "lọc không ra kết quả", nên không có gợi ý "Xoá bộ lọc" như ảnh tham chiếu trong [cai-thien-bang-va-phan-trang.md](cai-thien-bang-va-phan-trang.md) mục D.

### 2.2 SearchView: chưa có, mỗi màn tự làm

| Cách làm | Màn |
| --- | --- |
| File `XxxFilterBar.vue` riêng | sản phẩm, khách hàng, thú cưng, dịch vụ, hoá đơn, tồn kho, phiếu kho, báo cáo mặt hàng, phân quyền |
| Viết thẳng trong `Index.vue` | nhà cung cấp, thương hiệu, danh mục, lịch hẹn spa, đơn online |
| Không có ô tìm kiếm | ca thu ngân, combo dịch vụ |

Các file này giống nhau ở phần đầu (`relative min-w-60 flex-1` + icon `Search` + `Input pl-9`), khác nhau ở phần bộ lọc. Vấn đề:

1. **Mọi bộ lọc phơi ra ngoài.** Màn nhiều lọc (lịch hẹn spa: từ ngày, đến ngày, trạng thái; thú cưng: loài, khung cân, trạng thái) làm thanh lọc dài và xuống dòng trên iPad. Mô hình của chị gom vào popover "Lọc", ngoài thanh chỉ còn ô tìm kiếm.
2. **Không có nút Xoá lọc.** Muốn về mặc định phải tự chỉnh từng ô.
3. **Không có nút Làm mới.** Muốn lấy dữ liệu mới (đơn online vừa đặt, lịch vừa tạo ở máy khác) phải F5 cả trang.
4. **Không biết đang lọc gì.** Không có số đếm "đang lọc 2" nên dễ tưởng mất dữ liệu.
5. **Nút nhập/xuất không có chỗ cố định.** Báo cáo đặt `ExportMenu` ở slot `actions` của `ReportFilterBar`; PR #83 đặt ở hàng điều hướng cạnh nút "Thêm" hoặc chọn cơ sở. Kế hoạch nhập/xuất ([nhap-xuat-du-lieu.md](nhap-xuat-du-lieu.md) mục 5.1) muốn đặt "cạnh phải thanh lọc", nhưng chưa có thanh lọc chung để đặt.
6. **Debounce không đều.** Đa số 500ms (`SEARCH_DEBOUNCE_MS`), thú cưng 300ms (`SEARCH_DEBOUNCE_FAST_MS`). Không sai, nhưng mỗi màn tự chọn.

Phần trạng thái đã khá tốt và **giữ lại**: `usePagedSearch` (ô tìm kiếm debounce + về trang 1 khi lọc đổi), mỗi màn có `useXxxFilters` trả về `filter` cho query.

### 2.3 Vì sao `SearchView` cũ bị bỏ

Repo đã từng có đúng ý tưởng này: `src/components/common/SearchView.vue` (221 dòng) + `InputSearch.vue` + `SearchRangeTime.vue` + `DataTable/` + hằng `HEADER_ADVANCE_FUNCTION`. Hiện **không màn nào dùng** (chỉ `DataTable` cũ import nó, và `DataTable` cũng không còn màn nào dùng). Nó hỏng vì cách làm, không phải vì ý tưởng:

- Bật nút bằng mảng enum `headerAdvanced` thay vì slot; nút Lọc, Xuất, Nhập chỉ là icon, bấm không làm gì.
- Nút riêng truyền qua prop `buttonFunctions` (một component), không truyền được props/sự kiện.
- Dính chặt TanStack `Table` (bắt buộc prop `table`) và nút "Thêm mới" kiểu `{ type: 'link' | 'function' }`.
- Ô tìm kiếm debounce 1000ms, không có `v-model`, không xoá được từ ngoài.

Bản mới tránh đúng các điểm đó: slot cho mọi phần màn truyền vào, `v-model` cho trạng thái, không phụ thuộc kiểu bảng.

## 3. Thiết kế

### 3.1 Bố cục

```
┌──────────────────────────────────────────────────────────────┬──────────────────────────────┐
│ 🔍 Tìm theo tên, SĐT...                                      │ [#quick] ⌫  ⏷(2)  [#actions] ⟳ │
└──────────────────────────────────────────────────────────────┴──────────────────────────────┘
┌ bảng (PagedTableCard) ────────────────────────────────────────────────────────────────────────┐
│ ...                                                                                            │
│ 1–20 / 134   Số dòng [20]                                        «  ‹  1 2 3 … 7  ›  »          │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Thứ tự nút theo ảnh của chị: **Xoá lọc** (đầu) → **Lọc** → nút riêng của màn (`#actions`: tải xuống, nhập...) → **Làm mới** (cuối). Nút là icon vuông có tooltip, cùng kích thước ô tìm kiếm (h-9), màu primary teal.

Nút chính của màn ("Thêm sản phẩm", chọn cơ sở) **giữ ở hàng điều hướng phía trên** như hiện tại, không đưa vào SearchView: đó là hành động tạo mới / ngữ cảnh của cả trang, không phải công cụ của bảng.

### 3.2 `SearchView` (component)

File `src/components/common/search-view/SearchView.vue`.

```vue
<SearchView
  v-model:search="search"
  :placeholder="$t('products.searchPlaceholder')"
  :active-count="activeCount"
  :refreshing="listQuery.isFetching.value"
  @open-filters="syncDraft"
  @apply="apply"
  @reset-filters="resetDraft"
  @clear="clearAll"
  @refresh="listQuery.refetch()"
>
  <template #filters>
    <!-- các ô lọc, bind vào draft -->
    <CategorySelect v-model="draft.categoryId" />
    <BrandSelect v-model="draft.brandId" />
  </template>
  <template #actions>
    <ExportMenu :exporter="exporter" compact />
    <ImportButton ... />
  </template>
</SearchView>
```

**Props**

| Prop | Kiểu | Mặc định | Ý nghĩa |
| --- | --- | --- | --- |
| `placeholder` | `string` | `""` | Chữ gợi ý của `SearchInput` mặc định (bỏ qua khi truyền `#search`) |
| `activeCount` | `number` | `0` | Số bộ lọc đang khác mặc định; hiện badge trên nút Lọc, bật nút Xoá lọc |
| `refreshing` | `boolean` | `false` | Icon Làm mới quay, nút bị khoá |
| `showSearch` | `boolean` | `true` | Ẩn ô tìm kiếm; màn không có tìm kiếm (ca thu ngân) vẫn dùng được hàng nút |
| `showClear` | `boolean` | `true` | Ẩn/hiện nút Xoá lọc |
| `showFilter` | `boolean` | có slot `#filters` thì `true` | Ẩn/hiện nút Lọc |
| `showRefresh` | `boolean` | `true` | Ẩn/hiện nút Làm mới |
| `filterWidth` | `string` | `"min(720px, 90vw)"` | Độ rộng popover lọc |

**v-model**: chỉ `v-model:search` (chuỗi thô, cập nhật theo từng phím). Debounce không nằm trong component mà trong composable (đã có `usePagedSearch`), để một chỗ quyết định thời gian chờ. Nhấn Enter trong ô tìm kiếm phát `apply` để tìm ngay, không chờ hết debounce.

**Sự kiện**

| Sự kiện | Khi nào |
| --- | --- |
| `apply` | Bấm "Tìm kiếm" trong popover, hoặc Enter (trong ô tìm kiếm hay trong popover) |
| `reset-filters` | Bấm "Đặt lại" trong popover: đưa nháp về mặc định, chưa áp dụng |
| `clear` | Bấm nút Xoá lọc: xoá ô tìm kiếm + bộ lọc đã áp dụng về mặc định, về trang 1 |
| `refresh` | Bấm Làm mới; màn gọi `refetch()` của query, không đổi bộ lọc hay trang |
| `open-filters` | Popover mở; màn copy bộ lọc đang áp dụng vào nháp (composable tự làm) |

**Slot**

| Slot | Nội dung |
| --- | --- |
| `#search` | Ô tìm kiếm chính. Mặc định là `SearchInput` (bind `v-model:search`); màn thay bằng bất kỳ ô nào: `SearchSelect`, `SearchFieldInput`, ô chọn ngày, `InfiniteSelect`... (xem 3.2.1) |
| `#filters` | Các ô lọc trong popover, xếp lưới 3 cột (2 cột ở iPad dọc, 1 cột điện thoại) như ảnh. Popover tự có nút X góc trên, chân "Đặt lại" + "Tìm kiếm" |
| `#quick` | Bộ lọc nhanh cần thấy ngay, áp dụng tức thì, nằm giữa ô tìm kiếm và hàng nút (tab trạng thái đơn online, công tắc "Hiện đã lưu trữ"). Dùng ít, chỉ khi bộ lọc là cách xem chính của màn |
| `#actions` | Nút riêng của màn, nằm giữa nút Lọc và nút Làm mới |
| `#buttons` | Thay cả hàng nút (hiếm): màn tự ráp lại từ các nút nhỏ ở 3.2.1 theo thứ tự riêng |

#### 3.2.1 Tách thành component nhỏ

`SearchView` chỉ là **vỏ bố cục** (ô tìm kiếm bên trái, hàng nút bên phải, xuống dòng trên màn hẹp). Mỗi phần bên trong là một component riêng, dùng được độc lập, kể cả ngoài `SearchView` (ví dụ đặt `RefreshButton` trên một màn lịch không có thanh tìm kiếm):

| Component | Việc | v-model / props chính |
| --- | --- | --- |
| `SearchInput.vue` | Ô input có icon kính lúp, nút x xoá chữ, Enter phát `submit` | `v-model` (chuỗi), `placeholder` |
| `SearchSelect.vue` | Ô select làm ô tìm kiếm chính (ví dụ chọn khách hàng, chọn sản phẩm bằng `InfiniteSelect`, hoặc danh sách cố định) | `v-model` (giá trị), `options` hoặc `loader` (dùng `useInfiniteOptions`), `placeholder`, `clearable` |
| `SearchFieldInput.vue` | Select "tìm theo" + input dính liền (Tên / SĐT / Mã) cho màn cần tìm theo từng trường | `v-model:field`, `v-model:text`, `fields: { value, label }[]` |
| `FilterButton.vue` | Nút Lọc + badge số bộ lọc + popover (ráp `SearchViewFilterPopover`) | `activeCount`, slot mặc định là nội dung lọc; phát `open`, `apply`, `reset` |
| `SearchViewFilterPopover.vue` | Khung popover: lưới, nút X, "Đặt lại" / "Tìm kiếm", Enter, Esc | `width`, slot mặc định |
| `ClearFilterButton.vue` | Nút Xoá lọc (icon tẩy), tự khoá khi không có gì để xoá | `disabled`; phát `click` |
| `RefreshButton.vue` | Nút Làm mới, icon quay khi đang tải | `refreshing`; phát `click` |
| `ToolbarIconButton.vue` | Nút icon vuông + tooltip + badge, là gốc của 3 nút trên và của nút màn truyền vào | `icon`, `label`, `badge`, `disabled`, `loading` |

`SearchView` ráp mặc định: `#search` = `SearchInput`, hàng nút = `ClearFilterButton` → `FilterButton` → `#actions` → `RefreshButton`. Các prop `show*` chỉ là lối tắt để ẩn nút mặc định; muốn khác hẳn thì truyền slot.

Ví dụ ô tìm kiếm là select (màn lịch sử mua của một khách):

```vue
<SearchView :active-count="activeCount" @clear="clearAll" @refresh="refetch()">
  <template #search>
    <SearchSelect v-model="customerId" :loader="searchCustomers" :placeholder="$t('...chooseCustomer')" clearable />
  </template>
</SearchView>
```

Ví dụ tìm theo trường:

```vue
<template #search>
  <SearchFieldInput v-model:field="searchField" v-model:text="search" :fields="SEARCH_FIELDS" />
</template>
```

`useListFilters` không giả định ô tìm kiếm là chuỗi: ô tìm kiếm kiểu select thì để giá trị đó trong `quick` (đổi là áp dụng ngay, Xoá lọc trả về mặc định), không cần `search`.

**Cách áp dụng bộ lọc trong popover: bấm "Tìm kiếm" mới áp dụng** (như ảnh), không áp dụng từng ô. Lý do: popover có nhiều ô (khoảng ngày cần chọn 2 đầu), áp dụng từng ô sẽ gọi API mỗi lần đổi và bảng nhảy dưới popover. Ô tìm kiếm và `#quick` vẫn áp dụng ngay.

**Tách file** (theo quy tắc file nhỏ), tất cả trong `src/components/common/search-view/`:

| File | Dòng |
| --- | --- |
| `SearchView.vue` (vỏ bố cục + ráp mặc định) | ~70 |
| `SearchInput.vue` | ~40 |
| `SearchSelect.vue` | ~60 |
| `SearchFieldInput.vue` | ~50 |
| `FilterButton.vue` | ~40 |
| `SearchViewFilterPopover.vue` | ~60 |
| `ClearFilterButton.vue`, `RefreshButton.vue` | ~20 mỗi file |
| `ToolbarIconButton.vue` | ~35 |
| `types.ts`, `index.ts` | ~30 |

Bước 1 chỉ cần `SearchView`, `SearchInput`, `FilterButton`, popover, 3 nút. `SearchSelect` và `SearchFieldInput` làm khi có màn đầu tiên cần (không viết trước cho chưa ai dùng).

i18n: thêm `common.searchView.clear`, `.filter`, `.refresh`, `.reset`, `.apply`, `.activeFilters` ở `vi` và `en`.

### 3.3 `useListFilters` (trạng thái bộ lọc)

File `src/composables/useListFilters.ts`, dựng trên `usePagedSearch` có sẵn. Gom phần mỗi `useXxxFilters` đang tự viết: giá trị mặc định, nháp, áp dụng, xoá, đếm, về trang 1.

```ts
type ListFiltersOptions<F extends Record<string, unknown>> = {
  pageSize: number;
  /** Giá trị mặc định của bộ lọc trong popover; Xoá lọc trả về đúng các giá trị này. */
  defaults: F;
  debounceMs?: number;                 // mặc định SEARCH_DEBOUNCE_MS (500)
  /** Khoá bộ lọc giữ trên URL (như sản phẩm đang giữ category, brand). */
  urlKeys?: Partial<Record<keyof F, string>>;
  /** Bộ lọc nhanh nằm ngoài popover: đổi là về trang 1, Xoá lọc cũng trả về mặc định. */
  quick?: Record<string, { value: Ref<unknown>; default: unknown }>;
};

const {
  search,          // Ref<string>  → v-model:search
  debouncedSearch, // Ref<string>  → đưa vào filter của query
  applied,         // Readonly<F>  bộ lọc đang áp dụng
  draft,           // F (reactive) bộ lọc đang sửa trong popover
  page,            // { pageIndex, pageSize } → PagedTableCard
  activeCount,     // số bộ lọc (applied + quick) khác mặc định
  isFiltered,      // activeCount > 0 || search !== ""
  apply,           // draft → applied, flush debounce, về trang 1
  resetDraft,      // draft = defaults
  clearAll,        // search = "", applied = draft = defaults, quick về mặc định, về trang 1
  syncDraft,       // draft = applied (gọi khi mở popover)
} = useListFilters({ pageSize: 20, defaults: { categoryId: "", brandId: "" } });
```

Màn vẫn giữ `useXxxFilters` của mình, chỉ thay phần ruột: dùng `useListFilters` rồi `computed` ra `filter` cho query như cũ. Query, repository, RPC **không đổi**. Các luật riêng (đổi loài thì xoá khung cân của thú cưng) vẫn viết trong `useXxxFilters`, giờ `watch` trên `draft`.

So sánh "khác mặc định" dùng so sánh bằng giá trị đơn giản (chuỗi, số, boolean, mảng ngày `[from, to]`), không cần thư viện deep-equal.

### 3.4 Làm mới

`refresh` chỉ gọi `refetch()` của query danh sách (TanStack Query), giữ nguyên bộ lọc và trang. `refreshing` = `isFetching`. Không thêm tự làm mới định kỳ (đơn online đã có `usePolling` riêng cho badge).

### 3.5 Nút nhập/xuất

- `ExportMenu` thêm prop `compact`: chỉ icon tải xuống + tooltip "Tải xuống" (đúng icon trong ảnh); bản có chữ giữ cho chỗ khác. Khi đang xuất, icon thành vòng quay và tooltip hiện tiến độ.
- `ImportButton` (bước 3 của thread nhập/xuất) cũng nên có `compact`, icon upload.
- Cả hai đặt trong `#actions` của `SearchView`, thứ tự: Tải xuống, Nhập. Dòng mô tả "đặt ở cạnh phải thanh lọc" trong [nhap-xuat-du-lieu.md](nhap-xuat-du-lieu.md) mục 5.1 nghĩa là slot này.
- Tới khi màn được chuyển sang `SearchView`, nút vẫn ở chỗ PR #83 đặt (hàng điều hướng). Bước chuyển màn sẽ dời nó vào `#actions`, chỉ 1 dòng.

### 3.6 Table: chỉ thêm nhỏ

- **Không đổi API `PagedTableCard`.** Không gộp SearchView vào trong thẻ bảng: hai component đứng cạnh nhau trong trang, như mô hình của chị, và có màn dùng SearchView mà bảng khác kiểu (báo cáo tổng quan).
- `TableStateRows` thêm prop `filtered` và sự kiện `clear`: khi rỗng mà đang lọc thì hiện "Không có kết quả phù hợp" + nút "Xoá bộ lọc" (gọi `clearAll`).
- Nút cài đặt cột (bánh răng trong ảnh) **chưa làm**: bảng viết tay nên ẩn/hiện cột phải sửa từng màn; khi cần thì thêm vào `#actions` sau.

### 3.7 Báo cáo

5 tab báo cáo giữ `ReportFilterBar` (chọn cơ sở + chip khoảng ngày nằm trên URL, dùng chung giữa các tab, không hợp popover). Riêng `ItemsFilterBar` (tìm kiếm, loại, sắp xếp) chuyển sang `SearchView`, và `ExportMenu` của báo cáo dời vào `#actions` của nó ở tab mặt hàng. Các tab không có ô tìm kiếm giữ nguyên.

### 3.8 Cái không làm

- Không quay lại `DataTable` TanStack hay cột khai báo bằng cấu hình: bảng viết tay đang dễ đọc, mỗi màn có `XxxRow.vue` riêng.
- Không lưu bộ lọc đã dùng ("bộ lọc đã lưu"), không chip tóm tắt bộ lọc dưới thanh. Có thể thêm sau nếu cần.
- Không đổi SQL hay RPC nào.

## 4. Một màn sau khi chuyển (ví dụ thương hiệu)

Trước, trong `brands/Index.vue`: 10 dòng markup ô tìm kiếm + công tắc. Sau:

```vue
<SearchView
  v-model:search="search"
  :placeholder="$t('productCatalog.brands.searchPlaceholder')"
  :active-count="activeCount"
  :refreshing="listQuery.isFetching.value"
  @open-filters="syncDraft"
  @apply="apply"
  @reset-filters="resetDraft"
  @clear="clearAll"
  @refresh="listQuery.refetch()"
>
  <template #filters>
    <label class="flex items-center gap-2 text-sm text-muted-foreground">
      <Switch v-model:checked="draft.showInactive" />
      {{ $t("productCatalog.showInactive") }}
    </label>
  </template>
</SearchView>
```

Màn có `XxxFilterBar.vue` thì file đó thu lại chỉ còn nội dung slot `#filters` (đổi tên `XxxFilterFields.vue`), hoặc xoá hẳn khi chỉ còn 1, 2 ô.

## 5. Kế hoạch chuyển từng màn

Mỗi bước một PR nhỏ, squash merge, commit tiếng Anh. Không cần migration.

| Bước | Nội dung | Phụ thuộc |
| --- | --- | --- |
| 1 | `SearchView` + các nút nhỏ (3.2.1), `useListFilters`, i18n, `TableStateRows` thêm `filtered`; xoá `SearchView` cũ, `InputSearch`, `SearchRangeTime`, `DataTable/`, `HEADER_ADVANCE_FUNCTION` (kiểm `context`/text search không còn ai dùng); chuyển **thương hiệu** và **danh mục** làm mẫu | Không đụng thread nhập/xuất |
| 2 | `ExportMenu` thêm `compact`; chuyển **hoá đơn, ca thu ngân, tồn kho, phiếu kho, nhà cung cấp**, dời `ExportMenu` vào `#actions` | Sau khi PR #83 (xuất POS + kho) đã merge |
| 3 | Chuyển **sản phẩm** (giữ category/brand trên URL bằng `urlKeys`) | Sau bước 3 của thread nhập/xuất (nhập sản phẩm) |
| 4 | Chuyển **thú cưng, khách hàng, lịch hẹn spa, đơn online, dịch vụ, combo dịch vụ** | Sau bước 4 của thread nhập/xuất |
| 5 | Chuyển **phân quyền** và tab **báo cáo mặt hàng** | Không phụ thuộc, làm lúc nào cũng được |

Kiểm tra mỗi màn: tìm kiếm vẫn debounce và về trang 1; mở Lọc, đổi ô, bấm "Tìm kiếm" thì bảng lọc, badge hiện số; "Đặt lại" chỉ đổi nháp; Xoá lọc trả về mặc định và bảng đầy lại; Làm mới giữ trang và bộ lọc; Esc đóng popover; Enter áp dụng; bảng rỗng do lọc có nút "Xoá bộ lọc"; quyền xuất vẫn ẩn nút như cũ.

## 6. Tránh xung đột với thread nhập/xuất

Thread "Làm nhập xuất dữ liệu admin" đang sửa đúng các file màn danh sách:

- PR #83 (đang mở): `Index.vue` của hoá đơn, ca thu ngân, tồn kho, phiếu kho, nhà cung cấp, 5 tab báo cáo; `ExportMenu.vue`, `useTableExport.ts`, i18n.
- Bước 3, 4 sắp tới: trang nhập sản phẩm, `Index.vue` của sản phẩm, thú cưng, khách hàng, lịch spa, đơn online, dịch vụ; thêm `components/common/data-io/ImportButton.vue`.

Vì vậy bước 1 chỉ chạm file mới + 2 màn thương hiệu, danh mục (thread kia không đụng) + file cũ không ai dùng; các bước sau chờ đúng bước tương ứng của thread kia merge rồi mới làm. File i18n cả hai cùng thêm khoá: thêm khoá ở nhánh `common.searchView` riêng để merge không đè nhau.

## 7. Kết quả triển khai (14/10/2026)

Cả 5 bước đã làm xong (PR #86, #88, #92, #93, #95 và PR của bước 5). Những chỗ làm khác plan một chút:

- `useListFilters` có thêm `resetOn` (đổi cơ sở thì về trang 1) và `initial` (lấy giá trị đầu từ URL, như sản phẩm).
- Bộ lọc dùng chung với chỗ khác cho áp dụng ngay bằng `quick`: trạng thái tồn kho (cùng thẻ cảnh báo), chip khách mới, tab đơn online, nút loại ở báo cáo mặt hàng.
- Ca thu ngân và (trước đây) combo không có tìm kiếm; ca thu ngân dùng `SearchView` chỉ với nút tải xuống và Làm mới, combo có thêm ô tìm kiếm vì API đã hỗ trợ sẵn.
- Phân quyền lọc ngay trên trình duyệt nên ô trong popover sửa thẳng bộ lọc đang áp dụng (nút "Tìm kiếm" chỉ đóng popover); hàng chip lọc nhanh và số kết quả giữ nguyên bên dưới.
- Bảng khách hàng vẫn dùng dòng rỗng riêng, chưa có nút "Xoá bộ lọc".
- `SearchSelect` và `SearchFieldInput` chưa viết vì chưa màn nào cần.
- Chỉ kiểm tra bằng typecheck và build; chưa bấm thử trên trình duyệt.
