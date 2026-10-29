# G01 · Ca kiểm thử và ca biên (Corner Cases)

---

## 0. Cách đọc file này

Cột "Đã có trong TB?" đọc trực tiếp từ `05_VERIFICATION/testbench/g01_tb.sv` (61 dòng),
`golden_model/reference_model.py` và `golden_model/bounds.py`.

> ⚠️ Mô phỏng RTL **dừng** ở `g01_tb.sv:22` (`FATAL … valid mismatch`, `Time: 76`,
> `Scope: g01_tb.send`). Đó là **lần gọi `send()` thứ sáu** — dòng 42. Mọi ca từ dòng 42 trở
> đi **chưa từng chạy**. Phán xử: `05_VERIFICATION/known_issues.md`.

---

## 1. Bốn ca bắt buộc của Charter mục 8

| # | Ca Charter | Vì sao bắt buộc (lý do kỹ thuật) | Đã có trong TB? |
|---|---|---|---|
| CC-1 | **Chuỗi hằng số** — kết quả phải bằng chính nó | Kiểm **độ lợi một chiều (DC gain) = 1**. Nếu ai đó dịch phải 3 bit thay vì 2, hoặc quên mở rộng bit, ca này lộ ra ngay: `10,10,10,10` phải cho `10`, không phải `5` hay `2` | ✅ dòng 36–40 |
| CC-2 | **Bước nhảy** — kiểm đáp ứng chuyển tiếp | Kiểm bộ lọc **trượt đúng từng mẫu**: một bước nhảy phải mất đúng 4 mẫu mới hiện đủ. Đây là ca phân biệt "trượt" với "theo khối" | ⚠️ **KHÔNG CÓ ca bước nhảy tường minh** |
| CC-3 | **Chuỗi tăng dần** | Với chuỗi tuyến tính, trung bình trượt phải cho lại một chuỗi tuyến tính **trễ 1,5 mẫu**. Kiểm rằng phép trừ mẫu cũ đúng chỉ số (`wr_ptr`) | 🟡 dòng 42–45 (`4, 8, 12, 16`) — **nhưng kỳ vọng viết sai**, xem §7 |
| CC-4 | **Hành vi khi chưa đủ 4 mẫu** | Kiểm `valid_out = 0` và `avg_out` không phát giá trị rác. Đây là ca bảo vệ tầng ngoài | ✅ dòng 36–38 (ba mẫu đầu) |

**Kết luận phủ:** TB phủ CC-1 và CC-4 đúng; CC-3 có dữ liệu nhưng kỳ vọng sai; **thiếu hẳn
CC-2**. Mô hình chuẩn Python phủ tốt hơn: có `test_constant`, `test_ramp`, `test_impulse`,
`test_bounds`, `test_equivalence`.

## 2. Phân loại ca theo tiêu chí kỹ thuật riêng của G01

Tiêu chí đúng bản chất đề này là **giai đoạn của bộ tích luỹ trượt** — vì chính `count_q`
quyết định nhánh nào của `always_comb` được chọn (dòng 26–31):

| Giai đoạn | `count_q` | Biểu thức `sum_next` | Ý nghĩa | TB phủ |
|---|:--:|---|---|---|
| **Nạp đầy** (mẫu 1–4) | `0…3` | `sum_q + sample_ext` — **không trừ** | Cửa sổ chưa đầy, chỉ cộng dồn | ✅ 4/4 |
| **Chuyển tiếp** (mẫu 5) | `4` (lần đầu) | `sum_q + sample_ext − oldest` | **Lần đầu tiên đường trừ hoạt động** | ✅ 1 lần (dòng 40) |
| **Ổn định** (mẫu ≥ 6) | `4` | như trên | Chế độ làm việc bình thường | ❌ **chưa mẫu nào chạy được** — mô phỏng dừng đúng ở mẫu 6 |

Đây là bảng quan trọng nhất của tài liệu này: **mô phỏng dừng đúng tại mẫu đầu tiên của
giai đoạn ổn định**. Nghĩa là chế độ làm việc chính của bộ lọc **chưa hề được kiểm chứng
bằng mô phỏng RTL** — dù thuật toán đã được mô hình chuẩn kiểm.

Phân loại thứ hai, theo **giá trị**:

| Nhóm | Ca | Vì sao |
|---|---|---|
| Biên dưới | 4 mẫu `0` | `avg = 0` — trùng giá trị mặc định sau reset ⇒ chỉ `valid_out` phân biệt được |
| Biên trên | 4 mẫu `255` | `sum_q = 1020` — giá trị lớn nhất, kiểm không tràn 10 bit |
| Sai số làm tròn lớn nhất | tổng `≡ 3 (mod 4)`, ví dụ `0,0,0,255` | `⌊255/4⌋ = 63`, sai số **0,75** — lớn nhất có thể |
| Đường trừ | mẫu 5 trở đi | Kiểm `sample_mem[wr_ptr]` đúng chỉ số |

## 3. Hai ca tự xây dựng bổ sung (có ca biên)

### CA-TX-1 — Bước nhảy đầy đủ (bù ca CC-2 còn thiếu)

```
mẫu:      0    0    0    0  │ 255  255  255  255  255
valid:    0    0    0    1  │  1    1    1    1    1
avg:      –    –    –    0  │  63  127  191  255  255
                            ▲
                         bước nhảy ở đây — mất ĐÚNG 4 mẫu mới lên hết
```

Kiểm bằng tay: cửa sổ lần lượt là `(0,0,0,255) = 255 → 63`;
`(0,0,255,255) = 510 → 127`; `(0,255,255,255) = 765 → 191`;
`(255,255,255,255) = 1020 → 255`.

**Vì sao chọn:** đây là ca duy nhất chứng minh **cửa sổ trượt từng mẫu**. Một hiện thực
"trung bình theo khối" sẽ cho `0, –, –, 255` thay vì dãy `63,127,191,255`. Nó cũng đi qua
**cả biên dưới lẫn biên trên** của `sum_q` trong một chuỗi.
**Biên ở chỗ nào:** `sum_q` chạm `1020` — giá trị lớn nhất có thể.

### CA-TX-2 — Xung đơn ở biên và sai số làm tròn (ca biên)

```
mẫu:      0    0    0   255   0    0    0    0
valid:    0    0    0    1    1    1    1    1
avg:      –    –    –   63   63   63   63    0
```

**Vì sao chọn:** (a) đáp ứng xung của FIR 4 điểm phải là **bốn mẫu bằng nhau** — chứng minh
trực tiếp bốn hệ số bằng nhau; (b) `⌊255/4⌋ = 63` cho **sai số làm tròn lớn nhất 0,75**,
kiểm rằng RTL dùng `>>` (làm tròn xuống) chứ không phải làm tròn gần nhất; (c) mẫu thứ 8
trả về `0`, chứng minh xung **đã rời hẳn cửa sổ**.
**Biên ở chỗ nào:** giá trị mẫu lớn nhất `255` đi qua toàn bộ cửa sổ.

> ⚠️ `g01_tb.sv` dòng 47–53 **cố gắng** làm ca này nhưng đếm thiếu một mẫu: nó chỉ gửi
> `0,0,0` sau xung rồi kỳ vọng `avg = 0`, trong khi lúc đó cửa sổ vẫn là `(255,0,0,0) = 63`.
> Chi tiết ở `known_issues.md` §A.4.

### CA-TX-3 (khuyến nghị) — `valid_in` ngắt quãng giữa chuỗi

Gửi 4 mẫu, hạ `valid_in` vài chu kỳ, rồi gửi tiếp. Kiểm rằng `sum_q`, `wr_ptr`, `count_q`
**đứng yên** trong khoảng nghỉ và chuỗi kết quả **không đổi** so với khi gửi liên tục
(BIÊN-5). Ca này chứng minh bộ lọc chạy theo **nhịp mẫu**, không theo nhịp clock. TB có một
phần rất nhỏ của ý này ở dòng 55–57 (một chu kỳ nghỉ, chỉ kiểm `!valid_out`).

## 4. Ca **KHÔNG** áp dụng cho đề này

| Ca | Vì sao không áp dụng |
|---|---|
| Ca số có dấu (âm) | `sample_in` là `logic [W-1:0]` không dấu; mô hình chuẩn kiểm `0 <= x <= 255`. Nếu chuyển sang có dấu thì `>> 2` phải đổi thành `>>>` và phải mở rộng dấu — **một đề khác** |
| Ca tràn `avg_out` | Không thể xảy ra: INV-6 chứng minh `avg_out ≤ 255` |
| Ca cửa sổ dài hơn 4 / hệ số có trọng số / IIR | Charter mục 3: **ngoài phạm vi** (IIR là đề G06) |
| Ca thay đổi `W` lúc chạy | `W` là `parameter`, cố định lúc biên dịch. Nhưng **nên** kiểm tổng hợp lại với `W = 4` và `W = 16` để xác nhận `SUM_W = W+2` đúng — `bounds.py` đã chứng minh hình thức cho `W = 1…64` |
| Ca độ trễ đường tổ hợp | Mô phỏng RTL zero-delay; chỉ có nghĩa ở gate-level |

## 5. Assertion còn thiếu so với `properties.sv`

`properties.sv` có 2 assertion, cả hai trong khối `ifdef G01_SVA`. Kiểm
`04_IMPLEMENTATION/scripts/01_run_sim.sh`: lệnh `iverilog` **không có** cờ `-DG01_SVA`
⇒ **hai assertion này chưa từng chạy**.

Hơn nữa, một trong hai viết chưa đúng:

```systemverilog
assert_no_early_valid:
    assert property (@(posedge clk) valid_out |-> $past(valid_in,3));
```

`$past(valid_in,3)` kiểm `valid_in` của **3 chu kỳ clock trước**. Nhưng bộ lọc đếm theo
**nhịp mẫu**, không theo nhịp clock: nếu `valid_in` ngắt quãng, điều kiện này **sai** dù
mạch đúng. Assertion đúng phải dựa vào `count_q`, ví dụ:

```systemverilog
assert_no_early_valid:
    assert property (@(posedge clk) valid_out |-> ($past(count_q) >= 3'd3));
```

Các assertion nên bổ sung, ánh xạ với invariants:

| Invariant | Assertion đề xuất |
|---|---|
| INV-4 | `sum_q <= 10'd1020` |
| INV-5 | `count_q <= 3'd4` |
| INV-6 | `avg_out <= 8'd255` (luôn đúng với 8 bit — kiểm bằng cách so `sum_q[9:2]`) |
| INV-7 | `!valid_in` ⟹ `$stable(avg_out) && !valid_out` |
| INV-8 | chuỗi hằng số ⇒ `avg_out == sample_in` sau 4 mẫu |

## 6. Ca cần bổ sung khi chuyển sang gate-level / post-layout

| Mức | Ca phải thêm | Vì sao chỉ xuất hiện ở mức đó |
|---|---|---|
| Gate-level | Chạy lại CC-1…CC-4 + CA-TX-1, CA-TX-2 trên `netlist.v` (260 cell) | Chứng minh `abc` không làm sai **chuỗi carry 10 bit** — 6 cell `maj3_1` nối tiếp trên đường tới hạn là phần rủi ro nhất |
| Gate-level | Kiểm bộ nhớ 4×8: ghi `sample_mem[wr_ptr]` và đọc `sample_mem[wr_ptr]` **cùng chu kỳ** | Yosys đã tách địa chỉ đọc thành **2 flip-flop riêng** (`_000_`, `_001_`). Phải xác nhận netlist vẫn đọc **giá trị cũ** trước khi ghi đè |
| Gate-level | Kiểm thoát `X` sau reset | `dfxtp_1` không có chân reset; `sum_q` tích luỹ nên một bit `X` sẽ **không bao giờ tự sạch** (BIÊN-7) |
| Post-layout (SDF) | Setup trên đường `sample_in[1] → sum_q[9]` | Đường tới hạn thật; hiện `arrival = 4,56 ns` (đã gồm 1,00 ns input delay) **chưa có ký sinh dây** |
| Post-layout | Kiểm `input delay` thật của `sample_in` | SDC đang giả định 1,00 ns — con số giả định, không phải đo |

## 7. Ghi chú: kỳ vọng của testbench ở CC-3 viết sai

`g01_tb.sv` dòng 42–45 gửi `4, 8, 12, 16` và kỳ vọng `(0,0), (0,0), (0,0), (1,10)` — tức
coi như bộ lọc **khởi động lại** sau khối 4 mẫu đầu. Giá trị `10` ở mẫu cuối **tình cờ
đúng** (`(4+8+12+16)/4 = 10`), nhưng ba kỳ vọng `valid_out = 0` trước đó thì sai: cửa sổ đã
đầy từ trước nên cả ba mẫu đều phải cho `valid_out = 1` (lần lượt `8, 8, 8`).

Đây chính là lỗi làm mô phỏng dừng. Phán xử đầy đủ và bản vá: `known_issues.md`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
