# G01 · Nhật ký vá (PATCHLOG)

**Ngày vá:** 2026-09-24 · **Người duyệt:** giảng viên đã duyệt áp dụng toàn bộ bản vá

## 1. Tóm tắt

| # | File | Loại lỗi | Mô tả một dòng | Ảnh hưởng số liệu |
|---|---|---|---|---|
| P-1 | `05_VERIFICATION/testbench/g01_tb.sv` | Lỗi testbench | Chuỗi kỳ vọng được viết theo trung bình **theo khối**, trong khi đề và RTL là trung bình **trượt** — phải tính lại toàn bộ | Không |

Bản vá chỉ chạm vào testbench. **RTL không đổi một ký tự**, nên số liệu tổng hợp / STA /
công suất của hồ sơ giữ nguyên (đã đo lại để xác nhận, xem §3).

## 2. Chi tiết từng bản vá

### P-1 — Tính lại toàn bộ chuỗi kỳ vọng theo cửa sổ trượt

**File:** `05_VERIFICATION/testbench/g01_tb.sv` · **Dòng:** 42–53 (bản gốc) ·
**Phán xử:** lỗi ở **testbench**

**Trước:**
```systemverilog
        send(4,0,0);
        send(8,0,0);
        send(12,0,0);
        send(16,1,10);

        send(0,0,0);
        send(0,0,0);
        send(0,0,0);
        send(255,1,63);
        send(0,1,63);
        send(0,1,63);
        send(0,1,0);
```

**Sau:**
```systemverilog
        // cua so TRUOT tiep - moi mau deu hop le
        send(4, 1, 8);    // (10,10,10,4)  = 34  -> 8
        send(8, 1, 8);    // (10,10,4,8)   = 32  -> 8
        send(12,1, 8);    // (10,4,8,12)   = 34  -> 8
        send(16,1,10);    // (4,8,12,16)   = 40  -> 10   (chuoi tang dan, CC-3)

        send(0,  1, 9);   // (8,12,16,0)   = 36  -> 9
        send(0,  1, 7);   // (12,16,0,0)   = 28  -> 7
        send(0,  1, 4);   // (16,0,0,0)    = 16  -> 4
        send(255,1,63);   // (0,0,0,255)   = 255 -> 63   (xung don, CC-2)
        send(0,  1,63);   // (0,0,255,0)   = 255 -> 63
        send(0,  1,63);   // (0,255,0,0)   = 255 -> 63
        send(0,  1,63);   // (255,0,0,0)   = 255 -> 63   <- SUA: cua so van con 255
        send(0,  1, 0);   // (0,0,0,0)     = 0   -> 0    <- THEM mau de xung roi han
```

**Vì sao:** `g01_moving_average4.sv` dòng 97–98 cho `count_q` **bão hoà** ở 4 và không bao giờ
quay về 0, nên điều kiện phát hành `count_q >= 3'd3` (dòng 102) **luôn đúng** kể từ mẫu thứ
tư. Không có cơ chế "khởi động lại sau mỗi khối 4 mẫu" nào trong RTL. Mô hình chuẩn
(`reference_model.py`) cũng trả `(True, …)` cho mọi mẫu từ mẫu thứ tư, và `test_impulse()`
khẳng định tường minh **bốn** kết quả hợp lệ liên tiếp cho một xung đơn.

Bản gốc còn **tự mâu thuẫn**: mẫu thứ 5 được kỳ vọng hợp lệ (đúng với cửa sổ trượt) nhưng mẫu
thứ 6 lại bị kỳ vọng không hợp lệ (đúng với trung bình theo khối). Không mô hình nào nhất
quán với cả hai ⇒ DUT đúng, mô hình chuẩn đúng, testbench sai.

**Hệ quả:** **chuỗi mẫu đầu vào giữ nguyên hoàn toàn** (vẫn phủ CC-1…CC-4 của Charter), chỉ
cờ `valid` và giá trị kỳ vọng được tính lại. Hai điểm đáng chú ý:

1. Giá trị `10` ở `send(16,1,10)` của bản gốc **tình cờ đúng** với cửa sổ trượt `(4,8,12,16)`.
   Nếu chỉ sửa cờ `valid` mà không tính lại giá trị thì người sửa dễ tưởng mọi thứ đã ổn —
   đây đúng là lý do SPEC yêu cầu **tính lại toàn bộ chuỗi**, không chỉ chỗ FAIL.
2. Dòng cuối bản gốc `send(0,1,0)` kỳ vọng `avg = 0` **quá sớm**: sau `255, 0, 0, 0` thì cửa
   sổ `(255,0,0,0)` vẫn còn chứa `255` ⇒ `avg = 63`. Phải **thêm một mẫu thứ tám** thì `255`
   mới rời hẳn cửa sổ. Testbench sau vá có **17** lời gọi `send()` thay vì 16.

Toàn bộ 13 giá trị kỳ vọng đã được tính tay theo cửa sổ trượt liên tục và đối chiếu với
`moving_average4()` của mô hình chuẩn trước khi ghi vào file.

### Chênh lệch so với bản vá đã soạn trong `known_issues.md`

**Không có.** Bản vá được áp dụng **đúng nguyên văn** khối diff ở §A.4 của
`05_VERIFICATION/known_issues.md`. Phần "khuyến nghị bổ sung" (ca CA-TX-1, chuỗi bước nhảy)
**chưa áp dụng** — nó mở rộng độ phủ chứ không sửa lỗi, nên để lại ở §5 theo nguyên tắc sửa
tối thiểu. Comment được viết **không dấu (ASCII)** theo quy ước mã nguồn.

## 3. Kết quả xác minh sau khi vá

| Bước | Trước khi vá | Sau khi vá |
|---|---|---|
| Mô hình chuẩn Python | PASS — `G01 golden reference PASS`, mã thoát 0 | PASS — `G01 golden reference PASS`, mã thoát 0 (không đổi) |
| Biên dịch | PASS, không cảnh báo | PASS, không cảnh báo |
| Mô phỏng | ❌ `FATAL g01_tb.sv:22 valid mismatch`, `Time: 76` (dừng ở lần `send()` thứ 6/16) | ✅ **`G01 TB completed`**, `$finish` tại `t = 196`, mã thoát 0 — **17/17** lời gọi `send()` PASS |
| Tổng hợp | 260 cell / 58 FF / 2 623,7664 µm² | **260 cell / 58 FF / 2 623,7664 µm²** (không đổi — RTL không bị chạm) |

Mục *"Chế độ ổn định (mẫu ≥ 6)"* ở bảng §E của `known_issues.md` — trước đây ghi *"chưa chứng
minh bằng mô phỏng RTL"* — **nay đã được chứng minh**, gồm cả ca đáp ứng xung đơn với đủ bốn
mẫu ra bằng nhau rồi tụt về 0.

Lệnh đã chạy để xác minh:

```bash
D=<…>/out/G01_Bo_loc_trung_binh_truot_bon_diem
T=$(mktemp -d)
LIB=<…>/sky130hd.lib

python3 $D/05_VERIFICATION/golden_model/reference_model.py

iverilog -g2012 -o $T/sim.vvp \
   $D/04_IMPLEMENTATION/rtl/*.sv \
   $D/05_VERIFICATION/testbench/*.sv
cd $T && vvp sim.vvp

yosys -Q -p "read_verilog -sv $D/04_IMPLEMENTATION/rtl/*.sv; \
   hierarchy -check -top g01_moving_average4; proc; opt; fsm; opt; memory; opt; techmap; opt; \
   dfflibmap -liberty $LIB; abc -liberty $LIB; setundef -zero; splitnets; opt_clean -purge; \
   stat -liberty $LIB"
```

> Ghi chú: `05_VERIFICATION/golden_model/` của G01 chỉ có `reference_model.py` và `bounds.py`,
> không có file `.sv` nào, nên dòng `$D/05_VERIFICATION/golden_model/*.sv` trong mẫu lệnh của
> SPEC được bỏ khỏi lệnh `iverilog`. Mô hình chuẩn mức SystemVerilog
> (`g01_direct_sum_reference`) nằm trong `04_IMPLEMENTATION/rtl/` nên vẫn được biên dịch.

## 4. Cách quay lui

```bash
cp 08_ORIGINAL_SOURCE/rtl/*            04_IMPLEMENTATION/rtl/
cp 08_ORIGINAL_SOURCE/golden_model/*   05_VERIFICATION/golden_model/
cp 08_ORIGINAL_SOURCE/testbench/*      05_VERIFICATION/testbench/
```

## 5. Việc còn lại

Các mục dưới đây **không** được vá trong lần này, và **không** chặn tiêu chí đạt ở §3.

1. **Ca bước nhảy CA-TX-1** (`known_issues.md` §A.4, phần khuyến nghị bổ sung). Chuỗi
   `0,0,0 → 255,255,255,255` chứng minh cửa sổ trượt **từng mẫu** rõ hơn bất kỳ ca nào hiện
   có (`63 → 127 → 191 → 255`). Chưa thêm vì đây là mở rộng độ phủ, không phải sửa lỗi.
2. **Mục B — assertion `assert_no_early_valid` đếm theo chu kỳ clock thay vì theo nhịp mẫu.**
   **Không vá trong đợt này**: hai assertion trong `properties.sv` nằm trong `ifdef G01_SVA`
   và `04_IMPLEMENTATION/scripts/01_run_sim.sh` không truyền cờ `-DG01_SVA` ⇒ chúng **chưa
   từng được biên dịch**, không ảnh hưởng kết quả ở §3. Vá trọn vẹn cần sửa **cả** script chạy
   mô phỏng, mà `04_IMPLEMENTATION/scripts/` nằm ngoài ranh giới file được sửa (SPEC §0).
   Vẫn phải nhắc lại: **không được coi hai assertion này là bằng chứng.**
3. **Mục C — thiếu bằng chứng chạy `reference_model.py` trong `python_reference_run.log`.**
   `python_reference_run.log` là file bằng chứng do luồng sinh tài liệu ghi ra, nằm ngoài
   ranh giới file được sửa. Lỗ hổng truy vết này sẽ tự khép lại khi hồ sơ được sinh lại: lệnh
   ở §3 đã chạy và in `G01 golden reference PASS` với mã thoát 0.
4. **Mục D — thiếu tầng ánh xạ chân Tiny Tapeout, xung đột `uio[0]`.** **Không vá**: cần thầy
   duyệt phương án ánh xạ chân (xem `02_SPECIFICATION/functional_spec.md`). Không ảnh hưởng
   số liệu ở §3 nhưng **chặn tích hợp lên ô Tiny Tapeout**.

## 6. Áp dụng lại (2026-09-24)

**Vì sao phải làm lại:** một bước sinh tài liệu tự động (`generate2.py`) đã chép mã nguồn cũ từ
`runs/<mã>/work/` **đè lên** `04_IMPLEMENTATION/rtl/`, `05_VERIFICATION/golden_model/` và
`05_VERIFICATION/testbench/`, xoá mất bản vá P-1. Lỗi của bộ sinh đã được sửa. Trước khi áp
dụng lại, ba thư mục này đã được đối chiếu với `08_ORIGINAL_SOURCE/` và **trùng khít** — xác
nhận chúng đã quay về đúng trạng thái chưa vá.

**Đã áp dụng lại:** **1/1** bản vá — P-1 (`05_VERIFICATION/testbench/g01_tb.sv`), đúng nguyên
văn khối "Sau" ở §2. RTL và mô hình chuẩn không bị chạm. Không phát hiện chênh lệch nào giữa
mô tả trong PATCHLOG và bản vá thực tế; không phải sửa khác đi.

**Kết quả xác minh lần này** (chạy bằng đúng lệnh ở §3):

| Bước | Kết quả đo lần này | Khớp §3? |
|---|---|---|
| Mô hình chuẩn Python | `G01 golden reference PASS`, mã thoát 0 | ✅ |
| Biên dịch iverilog 12.0 | thành công, mã thoát 0, không cảnh báo | ✅ |
| Mô phỏng | `G01 TB completed`, `$finish` tại `t = 196`, mã thoát 0, không `ERROR`/`FATAL`/`mismatch` | ✅ |
| Tổng hợp yosys 0.33 + sky130hd | **260 cell / 58 FF (`dfxtp_1`) / 2 623,7664 µm²** | ✅ khớp chính xác |

Số cell, số flip-flop và diện tích **trùng khớp tuyệt đối** với §3. Mục §5 (việc còn lại) giữ
nguyên — lần áp dụng lại này không thêm bản vá nào ngoài P-1.
