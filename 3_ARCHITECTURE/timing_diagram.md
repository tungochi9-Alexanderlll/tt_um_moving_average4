# G01 · Giản đồ thời gian (Timing Diagram)

---

## 0. Nguồn gốc của giản đồ — đọc trước khi dùng

> ⚠️ Giản đồ dưới đây là **mô phỏng hành vi (zero-delay)** bằng Icarus Verilog 12.0. Nó
> minh hoạ **quan hệ theo chu kỳ**, **không** minh hoạ độ trễ vật lý. Độ trễ thật của đường
> dài nhất là **4,56 ns** (`06_GDSII/sta/timing_report_max.txt`) và **không** xuất hiện ở
> đây.
>
> ⚠️ `05_VERIFICATION/waveforms/` **rỗng**: `g01_tb.sv` không có `$dumpfile`/`$dumpvars`
> ⇒ **không có file VCD**. Giản đồ được dựng lại từng chu kỳ từ RTL và từ chuỗi kích thích
> của `g01_tb.sv`, và **đối chiếu với các mốc assertion đã PASS thật** trong `simulation.log`.
>
> **Điều kiện để có waveform thật:** thêm vào `g01_tb.sv`
> ```systemverilog
> initial begin $dumpfile("g01_tb.vcd"); $dumpvars(0, g01_tb); end
> ```
> rồi chạy `bash 04_IMPLEMENTATION/scripts/01_run_sim.sh`.

Quy ước thời gian: `always #5 clk = ~clk` ⇒ chu kỳ **10 đơn vị**, sườn lên tại
`t = 5, 15, 25, …`. Task `send()` đặt `sample_in`/`valid_in`, chờ sườn lên rồi `#1` mới
kiểm ⇒ **mốc kiểm tại `t = sườn + 1`**.

## 1. Giai đoạn nạp đầy — bốn mẫu đầu (ca CC-4 và CC-1)

Chuỗi `10, 10, 10, 10, 10`. Đây là đoạn **đã chạy thật và PASS toàn bộ**.

```
 sườn lên     #1     #2     #3     #4     #5     #6     #7
 t =          5      15     25     35     45     55     65
              │      │      │      │      │      │      │
 clk       ___│‾‾\___│‾‾\___│‾‾\___│‾‾\___│‾‾\___│‾‾\___│‾‾\___
 ─────────────┼──────┼──────┼──────┼──────┼──────┼──────┼───────
 rst_n     ___│______│‾‾‾‾‾‾│‾‾‾‾‾‾│‾‾‾‾‾‾│‾‾‾‾‾‾│‾‾‾‾‾‾│‾‾‾‾‾‾
 valid_in  ___│______│___/‾‾│‾\_/‾‾│‾\_/‾‾│‾\_/‾‾│‾\_/‾‾│‾\____
 sample_in    0      0     10     10     10     10     10
 ─────────────┼──────┼──────┼──────┼──────┼──────┼──────┼───────
              │      │   mẫu 1  mẫu 2  mẫu 3  mẫu 4  mẫu 5
 count_q      0      0      1      2      3      4      4
  (sau sườn)  │      │      │      │      │      │      │
 sum_q        0      0     10     20     30     40     40
  (sau sườn)  │      │      │      │      │      │      │
 wr_ptr       0      0      1      2      3      0      1
 ─────────────┼──────┼──────┼──────┼──────┼──────┼──────┼───────
 valid_out    0      0      0      0      0     ▁█▁    ▁█▁
 avg_out      0      0      0      0      0     10     10
 ─────────────┴──────┴──────┴──────┴──────┴──────┴──────┴───────
                                            ▲      ▲
                                            │      └─ mẫu 5: LẦN ĐẦU có phép trừ
                                            │         sum = 40 + 10 − mem[0](=10) = 40
                                            └─ mẫu 4: KẾT QUẢ ĐẦU TIÊN
                                               sum = 30 + 10 = 40 → 40>>2 = 10 ✅
```

**Ba điều đọc được từ giản đồ:**

1. **Cần đúng 4 mẫu hợp lệ** mới có kết quả đầu tiên — `valid_out` lên lần đầu ở mẫu 4.
2. **Độ trễ 1 chu kỳ clock** từ lúc lấy mẫu tới lúc `avg_out` ổn định (đầu ra thanh ghi hoá).
3. **`wr_ptr` cuộn về 0 đúng tại mẫu 5**, nên phép trừ đầu tiên trừ đúng mẫu 1. Đây là
   chi tiết quan trọng nhất của toàn bộ thiết kế và nó chỉ lộ ra khi vẽ đủ 5 mẫu.

## 2. Chuyển sang chế độ ổn định — và chỗ mô phỏng dừng

Tiếp chuỗi trên bằng mẫu `4` (dòng 42 của testbench).

```
 mẫu số        4      5      6
 sample_in    10     10      4
 ─────────────┼──────┼──────┼──────
 count_q       4      4      4
 wr_ptr        0      1      2
 mem[wr_ptr]  (10)   (10)   (10)      ← mẫu cũ nhất bị đẩy ra
 sum_q        40     40     34         ← 40 + 4 − 10 = 34
 ─────────────┼──────┼──────┼──────
 valid_out   ▁█▁    ▁█▁    ▁█▁         ← RTL: HỢP LỆ
 avg_out      10     10      8         ← 34 >> 2 = 8
 ─────────────┴──────┴──────┴──────
                            ▲
                            │ t = 76 — testbench kỳ vọng valid_out = 0
                            └─ ✗ FATAL "valid mismatch"
```

Testbench giả định bộ lọc **khởi động lại** sau khối 4 mẫu đầu. RTL và mô hình chuẩn đều
cho rằng cửa sổ **trượt liên tục**. Phán xử: `05_VERIFICATION/known_issues.md`.

Đối chiếu thời gian: `simulation.log` ghi `Time: 76` ⇒ sườn `t = 75` ⇒ sườn **#8** ⇒ lần
`send()` thứ sáu. **Khớp chính xác.**

## 3. Đáp ứng bước nhảy (ca CA-TX-1 — chưa có trong testbench)

Giản đồ này minh hoạ đặc trưng **trượt từng mẫu** rõ nhất.

```
 mẫu số        1    2    3    4  │  5    6    7    8    9
 sample_in     0    0    0    0  │ 255  255  255  255  255
 ─────────────┼────┼────┼────┼───┼────┼────┼────┼────┼────
 cửa sổ       -    -    -  0000 │ 0,0,0,255 …
 sum_q         0    0    0    0  │ 255  510  765 1020 1020
 ─────────────┼────┼────┼────┼───┼────┼────┼────┼────┼────
 valid_out     0    0    0   ▁█▁ │ ▁█▁  ▁█▁  ▁█▁  ▁█▁  ▁█▁
 avg_out       0    0    0    0  │  63  127  191  255  255
 ─────────────┴────┴────┴────┴───┴────┴────┴────┴────┴────
                                    ▲                ▲
                                    │                └─ sau ĐÚNG 4 mẫu mới lên hết
                                    └─ bước nhảy vào cửa sổ
```

Đây là **sườn lên dốc tuyến tính bốn bậc** — chữ ký của một FIR bốn hệ số bằng nhau. Nếu
đầu ra nhảy thẳng từ `0` lên `255` thì mạch **không phải** bộ lọc trung bình trượt.
Chú ý `sum_q = 1020` là **giá trị lớn nhất có thể**, kiểm luôn biên chống tràn (INV-4).

## 4. `valid_in` ngắt quãng — bộ lọc chạy theo nhịp mẫu (ca CA-TX-3)

```
 chu kỳ clock  c1   c2   c3   c4   c5   c6   c7
 valid_in     ▁█▁  ▁█▁   0    0   ▁█▁  ▁█▁   0
 sample_in     a    b    –    –    c    d    –
 ─────────────┼────┼────┼────┼────┼────┼────┼────
 count_q       1    2    2    2    3    4    4     ← ĐỨNG YÊN khi valid_in = 0
 sum_q         a   a+b  a+b  a+b a+b+c …           ← ĐỨNG YÊN
 valid_out     0    0    0    0    0   ▁█▁   0
 avg_out       0    0    0    0    0  (a+b+c+d)>>2
 ─────────────┴────┴────┴────┴────┴────┴────┴────
```

Kết quả **không phụ thuộc vào việc các mẫu đến liên tục hay ngắt quãng** — chỉ phụ thuộc
**thứ tự** mẫu. Đây là bằng chứng cho BIÊN-5 và cũng là lý do assertion
`assert_no_early_valid` trong `properties.sv` (dùng `$past(valid_in,3)`, đếm theo chu kỳ
clock) **viết chưa đúng** — xem `corner_cases.md` §5.

## 5. Đối chiếu với mô phỏng thật

`05_VERIFICATION/simulation.log`:

```
FATAL: /…/g01_tb.sv:22: valid mismatch
       Time: 76  Scope: g01_tb.send
```

| Lần `send()` | `t` kiểm | Mẫu | Kỳ vọng TB | RTL cho | Kết quả |
|---:|---:|---|---|---|---|
| 1 | 26 | `10` | `valid=0` | `valid=0` | ✅ PASS |
| 2 | 36 | `10` | `valid=0` | `valid=0` | ✅ PASS |
| 3 | 46 | `10` | `valid=0` | `valid=0` | ✅ PASS |
| 4 | 56 | `10` | `valid=1, avg=10` | `valid=1, avg=10` | ✅ PASS |
| 5 | 66 | `10` | `valid=1, avg=10` | `valid=1, avg=10` | ✅ PASS |
| **6** | **76** | `4` | `valid=0` | **`valid=1, avg=8`** | ❌ **FATAL** |

⇒ **Năm mốc kiểm đầu PASS**, bao gồm cả mẫu thứ 5 — tức **phép trừ đầu tiên đã được chứng
minh đúng bằng mô phỏng thật**. Giản đồ §1 khớp hành vi thật cho tới đúng thời điểm đó.

## 6. Những gì giản đồ này **không** chứng minh

| Không chứng minh | Vì sao | Cần gì |
|---|---|---|
| Độ trễ thật 4,56 ns, setup/hold | Zero-delay | Mô phỏng gate-level + SDF |
| Không có glitch trên `avg_out` | Đầu ra thanh ghi hoá nên **được kỳ vọng** sạch, nhưng zero-delay không chứng minh được | Mô phỏng gate-level có độ trễ |
| Chế độ ổn định (mẫu ≥ 6) đúng | **Mô phỏng dừng đúng ở mẫu 6** | Bản vá `known_issues.md` §A.4 |
| Biên `sum_q = 1020` | Chưa có ca | CA-TX-1 |
| Hành vi khi `valid_in` giữ cao nhiều chu kỳ cho **cùng một mẫu** | Không có ca; và RTL **không thể** phân biệt | Nghĩa vụ hợp đồng của tầng ngoài |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
