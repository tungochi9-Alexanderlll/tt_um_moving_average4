# G01 · Sự cố đã biết và phán xử (Known Issues)

> ## ✅ Trạng thái: **ĐÃ ÁP DỤNG** — 2026-09-24
>
> Giảng viên đã duyệt. Bản vá **§A.4** đã được áp dụng vào
> `05_VERIFICATION/testbench/g01_tb.sv`: toàn bộ chuỗi kỳ vọng được tính lại theo **cửa sổ
> trượt** (chuỗi mẫu đầu vào giữ nguyên, thêm một mẫu thứ 17 để xung `255` rời hẳn cửa sổ).
> Nhật ký đầy đủ: [`08_ORIGINAL_SOURCE/PATCHLOG.md`](../08_ORIGINAL_SOURCE/PATCHLOG.md).
>
> **Kết quả xác minh bằng công cụ thật sau khi vá:**
>
> | Bước | Trước khi vá | Sau khi vá |
> |---|---|---|
> | Mô hình chuẩn Python | PASS — `G01 golden reference PASS` | ✅ PASS, mã thoát 0 |
> | Biên dịch `iverilog -g2012` | PASS | ✅ PASS, không cảnh báo |
> | Mô phỏng `vvp` | ❌ `FATAL g01_tb.sv:22 valid mismatch`, `Time: 76` (dừng ở `send()` thứ 6/16) | ✅ **`G01 TB completed`**, `$finish` tại `t = 196` — **17/17** `send()` PASS |
> | Tổng hợp `yosys` | 260 cell · 58 FF · 2 623,7664 µm² | ✅ **260 cell · 58 FF · 2 623,7664 µm²** (không đổi) |
>
> **Số liệu vật lý KHÔNG đổi** — bản vá chỉ chạm vào testbench, RTL giữ nguyên nguyên vẹn.
>
> **Chưa áp dụng** (xem `PATCHLOG.md` §5): ca CA-TX-1 "khuyến nghị bổ sung" ở §A.4; mục **B**
> (assertion nằm trong `ifdef G01_SVA` chưa từng chạy — vá trọn vẹn cần sửa cả
> `01_run_sim.sh`, nằm ngoài ranh giới file được sửa); mục **C** (file log nằm ngoài ranh
> giới, sẽ tự khép khi sinh lại hồ sơ); mục **D** (cần thầy duyệt ánh xạ chân).
>
> Phần chẩn đoán bên dưới được **giữ nguyên** làm tài liệu dạy học. Mọi câu "CHƯA ÁP DỤNG"
> trong đó phản ánh trạng thái **tại thời điểm phán xử**, không phải trạng thái hiện nay.

| # | Tầng | Hiện tượng | Phán xử | Mức độ |
|---|---|---|---|---|
| **A** | Mô phỏng RTL | `FATAL g01_tb.sv:22 valid mismatch`, `Time: 76` | **LỖI TESTBENCH** — testbench giả định trung bình **theo khối**, trong khi đề và RTL là trung bình **trượt** | Chặn nghiệm thu chức năng |
| B | Kiểm chứng | Assertion `assert_no_early_valid` đếm theo chu kỳ clock thay vì theo nhịp mẫu | **LỖI ASSERTION** (chưa từng chạy vì thiếu cờ `-DG01_SVA`) | Bằng chứng yếu |
| C | Bằng chứng | `python_reference_run.log` chỉ có đầu ra của `bounds.py` | **THIẾU BẰNG CHỨNG** cho `reference_model.py` | Lỗ hổng truy vết |
| D | Giao diện | Không có module ánh xạ chân Tiny Tapeout; xung đột `uio[0]` chưa sửa | **CHƯA THOẢ Charter mục 4** | Chặn tích hợp |

**Tổng hợp và STA đều PASS.** Mọi số liệu vật lý của G01 là số liệu thật.

> ⚠️ *(Nguyên văn lúc phán xử — **nay đã lỗi thời**, xem khối trạng thái đầu file.)*
> **Không bản vá nào dưới đây đã được áp dụng.** RTL và testbench giữ nguyên bản gốc
> của thầy. Mọi thay đổi cần thầy duyệt trước.

---

# A. LỖI MÔ PHỎNG — `g01_tb.sv:22`

## A.1 Trích chính xác thông báo lỗi

`05_VERIFICATION/simulation.log` (toàn bộ, 2 dòng):

```
FATAL: /…/runs/G01/work/g01_tb.sv:22: valid mismatch
       Time: 76  Scope: g01_tb.send
```

`iverilog_compile.log`: **rỗng** — không lỗi biên dịch.

## A.2 Đoạn mã gây lỗi

`05_VERIFICATION/testbench/g01_tb.sv` dòng 21–22 là assertion bên trong task `send()`:

```systemverilog
assert(valid_out == exp_valid)
    else $fatal(1,"valid mismatch");
```

Lời gọi làm nó FAIL là **lần `send()` thứ sáu**, dòng 42:

```systemverilog
send(10,0,0);   // 1
send(10,0,0);   // 2
send(10,0,0);   // 3
send(10,1,10);  // 4  ← kết quả đầu tiên
send(10,1,10);  // 5

send(4,0,0);    // 6  ← dòng 42: kỳ vọng valid_out = 0   ✗ FATAL
send(8,0,0);    // 7
send(12,0,0);   // 8
send(16,1,10);  // 9
```

Xác nhận bằng thời gian: `Time: 76`; sườn lên tại `t = 5 + 10k`; `send()` kiểm tại
`t = sườn + 1`. Lần `send()` thứ sáu kiểm tại `t = 76`. **Khớp chính xác.**

## A.3 Phán xử: **LỖI Ở TESTBENCH** — nhầm "trung bình trượt" với "trung bình theo khối"

Testbench giả định bộ lọc **khởi động lại sau mỗi khối 4 mẫu**: ba mẫu đầu của khối mới cho
`valid_out = 0`, mẫu thứ tư cho kết quả. RTL (và đề bài) là **cửa sổ trượt từng mẫu**: kể
từ mẫu thứ tư, **mọi mẫu đều cho kết quả hợp lệ**.

### Bằng chứng 1 — RTL

```systemverilog
if (count_q < 3'd4) count_q <= count_q + 3'd1;      // dòng 51–52: BÃO HOÀ ở 4
...
if (count_q >= 3'd3) begin                          // dòng 56
    valid_out <= 1'b1;
    avg_out   <= sum_next >> 2;
end
```

`count_q` **bão hoà**, không bao giờ quay về 0. Nên từ mẫu thứ tư trở đi, `count_q >= 3`
**luôn đúng** ⇒ `valid_out = 1` cho mọi mẫu hợp lệ. Không có cơ chế "khởi động lại" nào
trong RTL.

### Bằng chứng 2 — mô hình chuẩn Python

`golden_model/reference_model.py` dòng 1–14:

```python
window.append(x)
if len(window) < 4:
    out.append((False, None))
else:
    if len(window) > 4: window.pop(0)
    out.append((True, sum(window) // 4))
```

`len(window) >= 4` ⇒ **luôn** `(True, …)`. Và `test_impulse` (dòng 42–44) khẳng định tường
minh **ba kết quả hợp lệ liên tiếp**:

```python
assert moving_average4([0,0,0,255,0,0]) == [
    (False,None),(False,None),(False,None),(True,63),(True,63),(True,63)]
```

### Bằng chứng 3 — testbench tự mâu thuẫn

Dòng 39–40 của chính testbench:

```systemverilog
send(10,1,10);   // mẫu 4 — hợp lệ
send(10,1,10);   // mẫu 5 — hợp lệ  ← TB THỪA NHẬN cửa sổ vẫn trượt
```

Nếu bộ lọc thật sự làm việc theo khối 4 mẫu, thì mẫu thứ 5 phải là mẫu đầu của khối mới ⇒
`valid_out = 0`. Testbench cho mẫu 5 là hợp lệ, rồi lại cho mẫu 6 là **không** hợp lệ.
**Không có mô hình nào nhất quán với cả hai.**

⇒ **DUT đúng, mô hình chuẩn đúng, testbench sai.** Năm mốc kiểm đầu PASS, gồm cả **mẫu thứ
5 — chu kỳ đầu tiên phép trừ hoạt động**, là phần khó nhất của thiết kế.

### Nguyên nhân gốc

Lỗi bắt nguồn từ **hiểu sai đặc tả**, không phải sai sót gõ nhầm. Ba khối `send()` trong
testbench (dòng 36–40, 42–45, 47–53) được viết như ba **thí nghiệm độc lập**, mỗi thí
nghiệm bắt đầu bằng ba mẫu "chưa đủ". Nhưng RTL **không có reset giữa các khối** — cửa sổ
tiếp tục trượt qua ranh giới khối.

## A.4 Bản vá tối thiểu (CHƯA ÁP DỤNG)

Giữ nguyên chuỗi mẫu (vẫn phủ đủ CC-1…CC-4 của Charter), **chỉ sửa kỳ vọng**. Giá trị dưới
đây tính bằng tay theo cửa sổ trượt liên tục, và trùng với `reference_model.py`:

```diff
--- a/05_VERIFICATION/testbench/g01_tb.sv
+++ b/05_VERIFICATION/testbench/g01_tb.sv
@@ -36,19 +36,22 @@
         send(10,0,0);
         send(10,0,0);
         send(10,0,0);
         send(10,1,10);
         send(10,1,10);
 
-        send(4,0,0);
-        send(8,0,0);
-        send(12,0,0);
-        send(16,1,10);
+        // cua so TRUOT tiep — moi mau deu hop le
+        send(4, 1, 8);    // (10,10,10,4)  = 34  -> 8
+        send(8, 1, 8);    // (10,10,4,8)   = 32  -> 8
+        send(12,1, 8);    // (10,4,8,12)   = 34  -> 8
+        send(16,1,10);    // (4,8,12,16)   = 40  -> 10   (chuoi tang dan, CC-3)
 
-        send(0,0,0);
-        send(0,0,0);
-        send(0,0,0);
-        send(255,1,63);
-        send(0,1,63);
-        send(0,1,63);
-        send(0,1,0);
+        send(0,  1, 9);   // (8,12,16,0)   = 36  -> 9
+        send(0,  1, 7);   // (12,16,0,0)   = 28  -> 7
+        send(0,  1, 4);   // (16,0,0,0)    = 16  -> 4
+        send(255,1,63);   // (0,0,0,255)   = 255 -> 63   (xung don, CC-2)
+        send(0,  1,63);   // (0,0,255,0)   = 255 -> 63
+        send(0,  1,63);   // (0,255,0,0)   = 255 -> 63
+        send(0,  1,63);   // (255,0,0,0)   = 255 -> 63   ← SUA: cua so van con 255
+        send(0,  1, 0);   // (0,0,0,0)     = 0   -> 0    ← THEM mau thu 8 de xung roi han
```

**Hai chỗ sửa đáng chú ý:**

1. Dòng cuối bản gốc `send(0,1,0)` kỳ vọng `avg = 0` **quá sớm**. Sau `255, 0, 0, 0` thì
   cửa sổ vẫn chứa `255` ⇒ `avg = 63`. Phải **thêm một mẫu nữa** thì `255` mới rời hẳn cửa
   sổ. Đây là lỗi thứ hai của testbench, cùng gốc với lỗi thứ nhất.
2. Kết quả `10` ở `send(16,1,10)` của bản gốc **tình cờ đúng** — nên nếu chỉ sửa cờ
   `valid` mà không kiểm lại giá trị, người sửa dễ tưởng mọi thứ đã ổn.

**Khuyến nghị bổ sung** (phủ ca còn thiếu, xem `corner_cases.md` §3):

```systemverilog
// CA-TX-1: buoc nhay — chung minh cua so TRUOT tung mau
send(0,1,0); send(0,1,0); send(0,1,0);       // dua cua so ve 0
send(255,1,63); send(255,1,127); send(255,1,191); send(255,1,255);
```

## A.5 Giá trị dạy học

Đây là bẫy **"hiểu sai đặc tả, không phải viết sai mã"** — loại lỗi đắt nhất trong thực tế
vì nó không lộ ra ở bất kỳ bước kiểm cú pháp nào.

1. **"Trượt" khác "theo khối".** Trung bình trượt cho **một kết quả trên mỗi mẫu**; trung
   bình theo khối cho một kết quả trên mỗi N mẫu và có **tốc độ đầu ra giảm N lần**. Hai
   mạch hoàn toàn khác nhau, tên gọi lại gần giống.
2. **Cách phát hiện nhanh nhất: đếm số kết quả hợp lệ.** Với K mẫu vào, trượt cho `K − 3`
   kết quả; theo khối cho `⌊K/4⌋`. Testbench bản gốc gửi 16 mẫu nhưng chỉ kỳ vọng 6 kết
   quả — con số này không khớp cả hai mô hình, đó là dấu hiệu đầu tiên.
3. **Testbench tự mâu thuẫn là bằng chứng mạnh nhất.** Ở đây chỉ cần so mẫu 5 (kỳ vọng
   hợp lệ) với mẫu 6 (kỳ vọng không hợp lệ) là đủ kết luận.
4. **Đáp ứng xung là phép thử phân biệt tốt nhất.** FIR 4 hệ số bằng nhau phải cho **đúng
   4 mẫu ra bằng nhau**. Bản gốc chỉ kỳ vọng 3 — sai đúng ở chỗ này.
5. **Khi sửa testbench, phải tính lại TOÀN BỘ chuỗi kỳ vọng**, không chỉ chỗ FAIL. Ở đây
   một giá trị đúng ngẫu nhiên (`10`) đã che giấu vấn đề.

---

# B. Assertion `assert_no_early_valid` đếm sai đơn vị thời gian

`05_VERIFICATION/testbench/properties.sv`:

```systemverilog
assert_no_early_valid:
    assert property (@(posedge clk) valid_out |-> $past(valid_in,3));
```

`$past(valid_in,3)` nhìn lại **3 chu kỳ clock**. Nhưng bộ lọc đếm theo **nhịp mẫu**
(`valid_in`), không theo nhịp clock. Nếu `valid_in` ngắt quãng — điều hoàn toàn hợp lệ theo
BIÊN-5 — thì `valid_out` có thể bật trong khi `valid_in` của 3 chu kỳ trước bằng 0, và
assertion **báo lỗi dù mạch đúng**.

**Bản vá đề xuất (CHƯA ÁP DỤNG):**

```diff
-assert_no_early_valid:
-    assert property (@(posedge clk) valid_out |-> $past(valid_in,3));
+assert_no_early_valid:
+    assert property (@(posedge clk) valid_out |-> ($past(count_q) >= 3'd3));
```

**Lưu ý quan trọng:** cả hai assertion trong `properties.sv` nằm trong khối
`ifdef G01_SVA`, và `04_IMPLEMENTATION/scripts/01_run_sim.sh` **không truyền cờ
`-DG01_SVA`** cho `iverilog`. ⇒ **Chúng chưa từng được biên dịch, chưa từng chạy.** Không
được coi chúng là bằng chứng.

---

# C. Thiếu bằng chứng chạy `reference_model.py`

`05_VERIFICATION/python_reference_run.log` chứa **đúng một dòng**:

```
G01 accumulator-width proof PASS for W=1..64
```

Đó là đầu ra của `golden_model/bounds.py`. Nhưng `golden_model/reference_model.py` dòng
54–60 in ra dòng khác:

```python
if __name__ == "__main__":
    test_constant(); test_ramp(); test_impulse(); test_bounds(); test_equivalence()
    print("G01 golden reference PASS")
```

Dòng `G01 golden reference PASS` **không có trong log**. `brief/G01.md` ghi "Python
reference: PASS", nhưng hồ sơ **không lưu bằng chứng** cho phần quan trọng nhất — 5 ca kiểm
hành vi, trong đó có `test_equivalence` chứng minh bộ tích luỹ trượt tương đương với cộng
thẳng.

**Điều kiện để bổ sung:**

```bash
python3 05_VERIFICATION/golden_model/reference_model.py | tee -a 05_VERIFICATION/python_reference_run.log
```

**Đây là lỗ hổng truy vết, không phải lỗi kỹ thuật** — nhưng theo Charter mục 6 (*"mỗi
khẳng định đi kèm bằng chứng"*), nó phải được ghi nhận thay vì bỏ qua.

---

# D. Thiếu tầng ánh xạ chân Tiny Tapeout — CHƯA THOẢ Charter mục 4

Chi tiết và đề xuất ánh xạ: `02_SPECIFICATION/functional_spec.md`, phần cảnh báo đầu file.
Tóm tắt: `04_IMPLEMENTATION/rtl/` **không có** module nào có cổng `ui_in`/`uo_out`/`uio_*`,
và xung đột `uio[0]` (vừa vào vừa ra) mà Charter yêu cầu sửa *"trước khi thiết kế"* vẫn còn.

Việc này **không ảnh hưởng số liệu** trong hồ sơ (lõi `g01_moving_average4` vẫn tổng hợp và
STA bình thường), nhưng **chặn bước tích hợp lên ô Tiny Tapeout**.

---

# E. Tổng kết trạng thái

*(Cột "Hiện tại" đã được cập nhật sau khi áp bản vá ngày 2026-09-24.)*

| Hạng mục | Hiện tại | Điều kiện để gỡ |
|---|---|---|
| Mô phỏng chạy hết testbench | ✅ **PASS** — `G01 TB completed`, 17/17 `send()` | ~~Bản vá §A.4~~ — **đã áp dụng** |
| Giai đoạn nạp đầy (4 mẫu đầu) | ✅ **đã chứng minh** — 4 mốc PASS | — |
| Phép trừ đầu tiên (mẫu 5) | ✅ **đã chứng minh** — mốc thứ 5 PASS | — |
| Chế độ ổn định (mẫu ≥ 6) | ✅ **đã chứng minh bằng mô phỏng RTL** — gồm cả đáp ứng xung đơn đủ 4 mẫu ra | ~~Bản vá §A.4~~ — **đã áp dụng** |
| Ca bước nhảy (CC-2) | ⬜ testbench không có | CA-TX-1 |
| Assertion SVA | ❌ chưa từng chạy, và 1/2 viết sai | Thêm `-DG01_SVA`, sửa theo §B |
| Bằng chứng `reference_model.py` | ⬜ thiếu trong log | §C |
| Tổng hợp | ✅ PASS — 260 cell · 58 FF · 2 623,7664 µm² | — |
| STA | ✅ PASS — arrival 4,56 ns, slack 5,36 ns | — |
| Công suất | ✅ ước lượng 3,28e-04 W | Muốn chính xác: VCD thật |
| Mô phỏng gate-level | ⬜ chưa chạy | Có sẵn netlist, cần script |
| P&R → GDS | ⬜ chưa chạy | `04_run_librelane.sh` + PDK sky130A |
| Thoả Charter mục 4 | ❌ **CHƯA THOẢ** | §D — cần thầy duyệt ánh xạ chân |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
