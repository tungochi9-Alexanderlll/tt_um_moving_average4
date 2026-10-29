# G01 · Đặc tả chức năng (Functional Specification)

---

## ⚠️ CẢNH BÁO ĐẦU FILE — RTL KHÔNG KHỚP CHARTER MỤC 4 · **CHƯA THOẢ**

> Cảnh báo bắt buộc, đặt trước mọi nội dung khác. **Không tự sửa RTL** — chỉ ghi nhận và
> chờ thầy duyệt.

Charter mục 4 yêu cầu ánh xạ chân:

```
ui_in[7:0] = mẫu vào · uio_in[0] = mẫu hợp lệ
uo_out[7:0] = trung bình · uio_out[0] = kết quả hợp lệ
Ngân sách chân: 9 bit vào + 9 bit ra = 18 / 24 chân.
Lỗi ánh xạ cần sửa trước khi thiết kế: chân uio[0] bị gán vừa làm đầu vào vừa làm đầu ra.
```

| # | Điều Charter mục 4 yêu cầu | RTL có? | Phán xử |
|---|---|:-:|---|
| 1 | Cổng mẫu vào 8 bit | ✅ `sample_in[W-1:0]`, `W = 8` | THOẢ về ý nghĩa |
| 2 | Cổng "mẫu hợp lệ" | ✅ `valid_in` | THOẢ về ý nghĩa |
| 3 | Cổng trung bình 8 bit | ✅ `avg_out[W-1:0]` | THOẢ về ý nghĩa |
| 4 | Cổng "kết quả hợp lệ" | ✅ `valid_out` | THOẢ về ý nghĩa |
| 5 | **Module top ánh xạ chân Tiny Tapeout** (`ui_in`/`uo_out`/`uio_in`/`uio_out`/`uio_oe`) | ❌ **KHÔNG CÓ** | **CHƯA THOẢ** — thư mục `04_IMPLEMENTATION/rtl/` chỉ có `g01_moving_average4.sv` và `g01_direct_sum_reference.sv`, không module nào có cổng Tiny Tapeout |
| 6 | **Sửa xung đột `uio[0]` vừa vào vừa ra** | ❌ | **CHƯA THOẢ** — chưa đánh số lại chân. Charter đã chỉ ra lỗi này và yêu cầu sửa *"trước khi thiết kế"* |
| 7 | Cổng `clk`, `rst_n` | ✅ có trong lõi | Tiny Tapeout cấp riêng, không tính vào 24 chân |

**Kết luận:** lõi tính toán **đúng chức năng và đủ tín hiệu**, nhưng **thiếu hẳn tầng ánh
xạ chân**, và xung đột `uio[0]` mà Charter yêu cầu sửa thì vẫn còn. Đề xuất ánh xạ (để thầy
duyệt, **chưa hiện thực**):

```
ui_in[7:0]   → sample_in[7:0]
uio_in[1]    → valid_in          (dời từ uio[0] sang uio[1] để hết xung đột)
uo_out[7:0]  ← avg_out[7:0]
uio_out[0]   ← valid_out
uio_oe       = 8'b0000_0001      (chỉ uio[0] là đầu ra)
```

Tổng: 9 bit vào + 9 bit ra = **18/24 chân**, đúng ngân sách Charter.

---

## 1. Chức năng: bộ lọc trung bình trượt bốn điểm

Mỗi khi có một mẫu hợp lệ, khối trả về **trung bình của mẫu đó và ba mẫu ngay trước**:

```
   avg[n] = ( x[n] + x[n−1] + x[n−2] + x[n−3] ) / 4        với n ≥ 4
```

Trong đó `n` đếm **số mẫu hợp lệ** (nhịp `valid_in`), **không phải** số chu kỳ clock. Khối
là một bộ lọc **FIR bốn hệ số bằng nhau** — hệ số `[¼, ¼, ¼, ¼]`.

Bối cảnh (Charter mục 1): làm trơn số đo nhiệt độ trước khi hiển thị. Tác dụng vật lý: nhiễu
trắng độc lập giữa các mẫu bị giảm biên độ khoảng **√4 = 2 lần**, đổi lại đáp ứng chậm đi —
một bước nhảy thật cần 4 mẫu mới hiện đủ trên đầu ra.

## 2. Định nghĩa tín hiệu

| Tín hiệu | Kiểu | Ý nghĩa |
|---|---|---|
| `clk` | vào | Clock |
| `rst_n` | vào | Reset **đồng bộ**, tích cực thấp (bằng chứng: `always_ff @(posedge clk)` rồi `if (!rst_n)`, dòng 33–34) |
| `valid_in` | vào | **Nhịp của bộ lọc.** Chỉ khi `valid_in = 1` thì mẫu mới được nạp và cửa sổ mới trượt |
| `sample_in[7:0]` | vào | Mẫu, **không dấu** (bằng chứng: `logic [W-1:0]`, không `signed`; mô hình chuẩn kiểm `0 <= x <= 255`) |
| `valid_out` | ra | 1 chu kỳ, báo `avg_out` vừa cập nhật và hợp lệ |
| `avg_out[7:0]` | ra | Trung bình, **làm tròn xuống** (`>> 2`, không làm tròn gần nhất) |

**Tham số:** `W = 8` (mặc định), `SUM_W = W + 2 = 10`.

## 3. Đặc tả hành vi chính xác

Gọi `k` = số mẫu hợp lệ đã nhận (tính cả mẫu hiện tại).

| Điều kiện | `valid_out` (chu kỳ sau) | `avg_out` (chu kỳ sau) |
|---|:--:|---|
| `valid_in = 0` | **0** | **giữ nguyên** |
| `valid_in = 1`, `k ≤ 3` | **0** | **giữ nguyên** (sau reset là `0`) |
| `valid_in = 1`, `k ≥ 4` | **1** | `⌊(x[k] + x[k−1] + x[k−2] + x[k−3]) / 4⌋` |

**Đặc tả quan trọng nhất và cũng là chỗ testbench hiểu sai:** kể từ mẫu hợp lệ thứ tư trở
đi, **mọi mẫu đều sinh một kết quả hợp lệ**. Cửa sổ **trượt liên tục từng mẫu một**, không
phải lấy trung bình theo từng khối 4 mẫu.

Mô hình chuẩn khẳng định đúng điều này (`golden_model/reference_model.py` dòng 1–14):

```python
window.append(x)
if len(window) < 4:
    out.append((False, None))
else:
    if len(window) > 4: window.pop(0)
    out.append((True, sum(window) // 4))
```

`len(window) >= 4` ⇒ `(True, …)` cho **mọi** mẫu tiếp theo. Xem `05_VERIFICATION/known_issues.md`.

### 3.1 Độ trễ

| Đại lượng | Giá trị |
|---|---|
| Từ `valid_in` tới `valid_out` | **1 chu kỳ clock** (đầu ra được thanh ghi hoá) |
| Số mẫu hợp lệ cần để có kết quả đầu tiên | **4** |
| Thông lượng | **1 mẫu / chu kỳ** khi `valid_in` giữ cao |

### 3.2 Ràng buộc độ rộng — vì sao phải 10 bit

Tổng bốn mẫu 8 bit không dấu lớn nhất là `4 × 255 = 1020`, cần **10 bit** (`1020 < 1024`).
Cộng vào biến 8 bit sẽ **tràn** — đây chính là "chỗ hay tắc" mà Charter mục 10 cảnh báo.

RTL dùng `localparam int SUM_W = W + 2;` (dòng 12) và `logic [SUM_W-1:0] sum_q;` (dòng 17).
Hồ sơ có **chứng minh hình thức** cho công thức này: `golden_model/bounds.py` kiểm
`4·(2^w − 1) < 2^(w+2)` cho `w = 1…64`, và `python_reference_run.log` ghi
`G01 accumulator-width proof PASS for W=1..64`. Đây là một trong số ít bằng chứng dạng
**chứng minh** (không phải kiểm mẫu) trong toàn bộ hồ sơ — rất đáng nêu khi bảo vệ.

## 4. Ràng buộc cấu trúc bắt buộc

Tên đề chỉ định **"trung bình trượt bốn điểm"**. Do đó:

1. Cửa sổ phải **trượt từng mẫu** (sliding), **không phải** trung bình theo khối (block
   averaging). Đây là ràng buộc về hành vi, và nó quyết định đúng/sai của testbench.
2. Phải giữ **đủ bốn mẫu** — vì muốn mẫu cũ nhất rời cửa sổ thì phải biết nó bằng bao nhiêu.
3. Chia cho 4 phải bằng **dịch phải 2 bit**, không dùng bộ chia (Charter mục 2, câu 2).
4. Tổng phải rộng **ít nhất `W + 2`** bit trước khi dịch (Charter mục 10).
5. Charter mục 3 ghi rõ **ngoài phạm vi**: cửa sổ dài hơn, hệ số có trọng số, lọc IIR (G06).

## 5. Trạng thái sau reset

| Phần tử | Giá trị |
|---|---|
| `sample_mem[0..3]` | tất cả `8'd0` |
| `wr_ptr` | `2'd0` |
| `count_q` | `3'd0` |
| `sum_q` | `10'd0` |
| `valid_out` | `0` |
| `avg_out` | `8'd0` |

Reset **đồng bộ** ⇒ cần ít nhất một sườn lên `clk` với `rst_n = 0`.

## 6. Tính chất bất biến (invariants)

| ID | Phát biểu | Lý do / bằng chứng |
|---|---|---|
| **INV-1** | `valid_out` ⟹ đã có ít nhất 4 mẫu hợp lệ | Điều kiện `count_q >= 3'd3` tại thời điểm mẫu thứ 4 |
| **INV-2** | `valid_out` ⟹ `$past(valid_in)` | `valid_out` chỉ bật bên trong `if (valid_in)`. Đã có trong `properties.sv` (`assert_valid_requires_input`) |
| **INV-3** | `sum_q` = tổng của các mẫu hiện có trong cửa sổ (tối đa 4) | Bất biến của bộ tích luỹ trượt; được chứng minh gián tiếp bởi `reference_model.py::test_equivalence` |
| **INV-4** | `sum_q ≤ 1020` | Bốn mẫu 8 bit; `bounds.py` chứng minh cho mọi `W` |
| **INV-5** | `count_q ≤ 4` | Bão hoà bởi `if (count_q < 3'd4)` |
| **INV-6** | `avg_out ≤ 255` | `sum_q ≤ 1020`, `1020 >> 2 = 255` ⇒ **không bao giờ tràn cổng ra 8 bit** |
| **INV-7** | `!valid_in` ⟹ `valid_out == 0` và `avg_out` không đổi | Gán mặc định `valid_out <= 1'b0` ở dòng 45; `avg_out` chỉ gán trong `if (valid_in)` |
| **INV-8** | Với chuỗi hằng số `x`, sau 4 mẫu thì `avg_out == x` | Vì `4x/4 = x`, không mất mát do dịch |
| **INV-9** | Số ô nhớ cho cửa sổ = `4 × W = 32` | Kiểm cấu trúc; **đã xác nhận trên netlist**: 32 `dfxtp_1` có `Q = sample_mem[i][j]` |

> INV-1, INV-3…INV-9 **chưa có** trong `properties.sv` (file chỉ có 2 assertion). Xem
> `corner_cases.md` §5.

## 7. Điều kiện biên và hành vi không xác định

| ID | Tình huống | Hành vi theo RTL | Ghi chú |
|---|---|---|---|
| BIÊN-1 | Chưa đủ 4 mẫu, đọc `avg_out` | Trả về **giá trị cũ** (sau reset là `0`) | **`0` là một giá trị trung bình hợp lệ** ⇒ không thể phân biệt "chưa sẵn sàng" với "trung bình bằng 0" nếu không có `valid_out`. Đây là câu trả lời cho Charter mục 2 câu 3 |
| BIÊN-2 | Tất cả 4 mẫu = 255 | `sum_q = 1020`, `avg_out = 255` | Biên trên, **không tràn** (INV-6) |
| BIÊN-3 | Tất cả 4 mẫu = 0 | `avg_out = 0`, `valid_out = 1` | Biên dưới. Phân biệt với BIÊN-1 **chỉ nhờ** `valid_out` |
| BIÊN-4 | Xung đơn (impulse): `0,0,0,255` rồi toàn `0` | `avg = 63` (= ⌊255/4⌋) ở mẫu chứa xung và **3 mẫu kế tiếp** — tổng cộng **4 mẫu liên tiếp bằng 63** — rồi mới về `0` ở mẫu thứ 4 sau xung | Đáp ứng xung của FIR 4 điểm là **bốn mẫu bằng nhau**. Làm tròn xuống gây sai số 0,75. Khớp `reference_model.py::test_impulse` |
| BIÊN-5 | `valid_in` ngắt quãng | Cửa sổ **đứng yên** — `sum_q`, `wr_ptr`, `count_q` giữ nguyên | Bộ lọc chạy theo nhịp mẫu, không theo nhịp clock |
| BIÊN-6 | Reset giữa chừng | Toàn bộ về 0, phải **đợi lại 4 mẫu** | `valid_out` bảo vệ tầng ngoài khỏi kết quả nửa vời |
| BIÊN-7 | `sample_in` có `X`/`Z` khi `valid_in = 1` | `sum_q` nhiễm `X` và **giữ `X` mãi** (vì tích luỹ) | Nguy hiểm hơn mạch tổ hợp: một mẫu hỏng làm hỏng cả bộ tích luỹ. Tầng ngoài phải bảo đảm mức sạch |
| BIÊN-8 | Mẫu thứ 5 (lần đầu có phép trừ) | `sum_next = sum_q + x − sample_mem[wr_ptr]` với `wr_ptr = 0` ⇒ trừ đúng mẫu thứ 1 | Đây là chu kỳ đầu tiên đường trừ được kích hoạt — **ca chuyển tiếp quan trọng nhất**, xem `corner_cases.md` |

## 8. Hai biến thể RTL trong hồ sơ — cùng hàm, khác cấu trúc

| | `g01_moving_average4.sv` (**TOP, đã tổng hợp**) | `g01_direct_sum_reference.sv` (tham chiếu) |
|---|---|---|
| Cách tính tổng | **Bộ tích luỹ trượt**: `sum_q + x − oldest` | **Cộng thẳng 4 mẫu** mỗi chu kỳ: `mem[0]+mem[1]+mem[2]+mem[3]` |
| Thanh ghi tổng | ✅ `sum_q` (10 FF) | ❌ không có — `total_next` là `always_comb` |
| Số phép cộng/trừ 10 bit mỗi chu kỳ | 1 cộng + 1 trừ | **3 cộng** (cây) + 1 cộng + 1 trừ ở dòng 40–41 |
| Đã tổng hợp? | ✅ — 260 cell, 58 FF | ⬜ **chưa** (chỉ được biên dịch cùng, không phải top) |

Bằng chứng chọn top: `06_GDSII/synthesis/synth.ys` có `hierarchy -check -top
g01_moving_average4`, và `synth_stat.txt` ghi `=== g01_moving_average4 ===`.
So sánh định lượng hai biến thể: `03_ARCHITECTURE/tradeoff.md` §2.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
