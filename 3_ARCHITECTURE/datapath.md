# G01 · Đường dữ liệu (Datapath)

---

## 1. G01 gần như **toàn bộ là datapath**

Trong ba đề F09 / F10 / G01, G01 là đề duy nhất có datapath đúng nghĩa: có bộ nhớ, có phép
cộng, có phép trừ, có phép chia. Phần điều khiển chỉ là một bộ đếm bão hoà 3 bit và một
con trỏ vòng 2 bit (xem `control.md`).

| Phần | Số FF | Tỷ lệ |
|---|---:|---:|
| **Datapath** (`sample_mem` 32 + `sum_q` 10 + `avg_out` 8) | **50** | 86,2 % |
| **Điều khiển** (`count_q` 3 + `wr_ptr` 2 + bản sao con trỏ 2 + `valid_out` 1) | **8** | 13,8 % |
| Tổng | 58 | 100 % |

```
   sample_in[7:0] ══╗
                    ║   ┌─────────────┐
                    ╠══▶│  MỞ RỘNG 0  │══▶ sample_ext[9:0]  (0 cell — chỉ là dây)
                    ║   └─────────────┘            ║
                    ║                              ║
                    ║   ┌──────────────────────┐   ║
                    ╚══▶│ sample_mem[wr_ptr]   │   ║
                        │ ← GHI mẫu mới        │   ║
                        │ → ĐỌC mẫu CŨ NHẤT    │   ║
                        └──────────┬───────────┘   ║
                                   ║ oldest_ext[9:0]
                                   ▼               ▼
                        ┌──────────────────────────────────┐
              sum_q ═══▶│  +  sample_ext   −  oldest_ext   │
              [9:0]     │  (chuỗi carry 10 bit nối tiếp)   │
                        └──────────────┬───────────────────┘
                                       ║ sum_next[9:0]
                          ┌────────────╨────────────┐
                          ▼                         ▼
                   ┌────────────┐          bit [9:2] (bỏ [1:0])
                   │ sum_q[9:0] │                   ▼
                   │  10 FF     │          ┌─────────────────┐
                   └────────────┘          │ avg_out[7:0]    │
                                           │  8 FF           │
                                           └─────────────────┘
```

## 2. Bảng các đường dữ liệu

| Đường | Độ rộng | Từ | Đến | Bản chất |
|---|---:|---|---|---|
| `sample_in[7:0]` | 8 | cổng vào | `sample_mem`, `sample_ext` | Mẫu mới. **Đi thẳng vào bộ cộng, không qua thanh ghi** ⇒ là startpoint của đường tới hạn |
| `sample_ext[9:0]` | 10 | dòng 23 | bộ cộng | Mở rộng 0 — **0 cell**, chỉ nối dây |
| `sample_mem[0:3][7:0]` | 4 × 8 | 32 FF | bộ đọc | **Cửa sổ** — 55 % tổng ô nhớ |
| `oldest_ext[9:0]` | 10 | 8 × `mux4_2` | bộ trừ | Mẫu cũ nhất, chọn theo `wr_ptr` |
| `sum_q[9:0]` | 10 | 10 FF | bộ cộng, `avg_out` | **Bộ tích luỹ** — bất biến INV-3 |
| `sum_next[9:0]` | 10 | logic tổ hợp | `sum_q`, `avg_out` | **Đường tới hạn kết thúc ở bit [9]** |
| `avg_out[7:0]` | 8 | 8 FF | cổng ra | Bằng `sum_next[9:2]` đã chốt |
| `valid_out` | 1 | 1 FF | cổng ra | Cờ |

### 2.1 Phép chia cho 4 — **không tốn một cell nào**

```systemverilog
avg_out <= sum_next >> 2;    // dòng 58
```

Với hằng số dịch, `>> 2` chỉ là **đổi chỉ số dây**: `avg_out[i]` nhận `sum_next[i+2]`. Ba
bằng chứng độc lập trong hồ sơ:

1. **Bảng phân bố cell không có cell dịch nào.** 260 cell gồm FF, cổng logic, `mux4_2`,
   `mux2_1` — không có barrel shifter, không có bộ chia.
2. **`avg_out` chỉ có 8 FF cho 8 bit** — bằng đúng độ rộng cổng ra, không có phần cứng phụ.
3. **`avg_out` không nằm trên đường tới hạn.** Endpoint là `sum_q[9]`; nếu `>>2` tốn logic,
   `avg_out` đã phải xuất hiện trong báo cáo STA.

⇒ **Trả lời Charter mục 2 câu 2: phép chia cho 4 tốn 0 cell.** Điều tốn phần cứng là **hai
bit bị bỏ đi** — `sum_next[1:0]` vẫn được bộ cộng tính ra rồi vứt (nhưng chúng cần thiết cho
chuỗi carry, nên không thể cắt).

Lưu ý kỹ thuật cần nêu khi bảo vệ: `avg_out` và `sum_q[9:2]` **dùng chung nón logic
`sum_next`** nhưng **không dùng chung chân D**. Bằng chứng trên netlist: `sum_q[9]` có
`.D(_042_)` còn `avg_out[7]` có `.D(_027_)` — hai net khác nhau, vì `avg_out` chỉ được nạp
khi `count_q >= 3` còn `sum_q` được nạp mỗi khi `valid_in`. Đó là hai điều kiện enable khác
nhau, nên phải có hai MUX giữ khác nhau.

## 3. Đồ thị phụ thuộc và độ sâu logic

```
  mức 0   sample_in[7:0] (cổng vào, + input_delay 1,00 ns)
             │
             │        sum_q[7:0] (FF)        sample_mem[*][*] (32 FF)
             │             │                        │
             │             │                  ┌─────┴──────┐
             │             │                  │ mux4_2 × 8 │  (song song, KHÔNG tới hạn)
             │             │                  └─────┬──────┘
             │             │                        │ oldest_ext
  mức 1   ┌──┴─────────────┴────────────────────────┴──┐
          │  tầng sinh generate/propagate (xnor2, o21ai)│
          └──────────────────┬──────────────────────────┘
                             │
  mức 2–7  ┌─────────────────┴──────────────────────────┐
           │  CHUỖI CARRY 10 BIT — 6 × maj3_1 NỐI TIẾP  │  ← NÚT THẮT
           │  carry[i+1] cần carry[i] đã ổn định        │
           └─────────────────┬──────────────────────────┘
                             │
  mức 8–10 ┌─────────────────┴──────────────────────────┐
           │  bit tổng (xnor2) + gộp (o2111ai)          │
           └─────────────────┬──────────────────────────┘
                             │
  mức 11   ┌─────────────────┴──────────┐
           │ mux2_1: count_q < 4 ?      │   ← chọn "cộng" hay "cộng-trừ"
           └─────────────────┬──────────┘
  mức 12   ┌─────────────────┴──────────┐
           │ nor2: logic giữ/nạp sum_q  │
           └─────────────────┬──────────┘
  mức 13                     ▼
                        D của sum_q[9]
```

| Đầu ra (chân D) | Độ sâu (cell thật) | Ghi chú |
|---|---:|---|
| `wr_ptr[1:0]` | ~2 | Nông nhất |
| `count_q[2:0]` | ~3 | |
| `valid_out` | ~3 | |
| `sample_mem[i][j]` | ~2 | Chỉ là MUX giữ/nạp |
| `avg_out[7:0]` | ~12 | Gần tới hạn, nhưng thấp hơn `sum_q[9]` một bậc |
| **`sum_q[9]`** | **14** | ✅ **đường tới hạn thật** |

**Vì sao `sum_q[9]` sâu hơn `avg_out[7]`** dù cả hai lấy từ `sum_next`: `avg_out[7]` lấy
`sum_next[9]` giống hệt, nhưng đường của nó **kết thúc sớm hơn** — MUX enable của `avg_out`
đơn giản hơn MUX enable của `sum_q` (một điều kiện `count_q>=3` đã tính sẵn, so với logic
nạp của `sum_q`). Chênh lệch chỉ vài phần mười ns, nên nếu thư viện hoặc ràng buộc đổi,
endpoint có thể chuyển sang `avg_out`.

## 4. Dự đoán từ RTL và đối chiếu với STA thật

### 4.1 Dự đoán trước khi xem báo cáo

Đọc RTL, biểu thức nặng nhất là dòng 30:

```systemverilog
sum_next = sum_q + sample_ext - oldest_ext;
```

Một phép cộng **và** một phép trừ, đều 10 bit, **nối tiếp nhau**. Cả hai đều có chuỗi carry
lan từ bit 0 lên bit 9. Dự đoán: đường tới hạn là chuỗi carry này, độ sâu ≈ 10 + 10 = 20
tầng nếu công cụ làm hai bộ cộng riêng.

### 4.2 Số liệu STA thật

Nguồn: `06_GDSII/sta/summary.txt`, `timing_report_max.txt`.

| Đại lượng | Giá trị |
|---|---:|
| Startpoint | **`sample_in[1]` (input port clocked by clk)** |
| Endpoint | `_446_/D` = **`sum_q[9]`** |
| Path group / type | `clk` / `max` |
| Input external delay | **1,00 ns** (giả định SDC) |
| **Data arrival time** | **4,56 ns** |
| Library setup time | −0,07 ns |
| Data required time | 9,93 ns |
| **Slack** | **5,36 ns (MET)** |
| WNS / TNS (max) | **0,00 / 0,00** |
| Số cell trên đường | **14** |

Chi tiết từng chặng:

| Cell | Loại | Delay (ns) | Time (ns) | Vai trò |
|---|---|---:|---:|---|
| — | input delay | 1,00 | 1,00 | **Giả định SDC**, không phải phần cứng |
| `_253_` | `xnor2_1` | 0,17 | 1,17 | Tầng propagate của bit thấp |
| `_261_` | `o21ai_0` | 0,15 | 1,32 | Tầng generate |
| `_270_` | `maj3_1` | 0,40 | 1,71 | **carry bit 1** |
| `_282_` | `maj3_1` | 0,39 | 2,11 | carry bit 2 |
| `_292_` | `maj3_1` | 0,39 | 2,50 | carry bit 3 |
| `_303_` | `maj3_1` | 0,39 | 2,89 | carry bit 4 |
| `_315_` | `maj3_1` | 0,39 | 3,28 | carry bit 5 |
| `_327_` | `maj3_1` | 0,39 | 3,67 | **carry bit 6** |
| `_329_` | `xnor2_1` | 0,21 | 3,88 | bit tổng |
| `_331_` | `o2111ai_1` | 0,16 | 4,03 | gộp |
| `_337_` | `xnor2_1` | 0,17 | 4,21 | bit tổng bậc cao |
| `_374_` | `mux2_1` | 0,29 | 4,49 | **chọn `count_q<4 ? cộng : cộng-trừ`** |
| `_375_` | `nor2_1` | 0,07 | 4,56 | logic nạp `sum_q` |
| `_446_` | `dfxtp_1` | — | 4,56 | FF đích |

### 4.3 Dự đoán **đúng về bản chất, sai về độ lớn**

| Điểm | Dự đoán | STA thật | Nhận xét |
|---|---|---|---|
| Nút thắt là chuỗi carry | Có | ✅ **đúng** — 6 `maj3_1` nối tiếp, **2,35 ns / 4,56 ns = 52 %** tổng độ trễ | Bản chất số học nối tiếp, giống hệt bài học của A01 |
| Độ sâu ~20 tầng (cộng rồi trừ) | Có | ❌ **SAI** — chỉ **14 cell**, và chỉ **6** tầng carry | `abc` **hợp nhất cộng và trừ thành MỘT mạng carry**: `a − b` được làm thành `a + ¬b + 1`, rồi ba toán hạng được nén bằng `maj3` (carry-save). Đó là lý do chỉ còn một chuỗi carry, không phải hai |
| Startpoint là `sum_q` | Ngầm giả định | ❌ **SAI** — là **cổng vào `sample_in[1]`** | `sample_in` đi thẳng vào bộ cộng, không qua thanh ghi ⇒ đường tính từ **chân**, và **1,00 ns input delay chiếm 22 %** arrival |
| Endpoint là `avg_out` | Có thể | ❌ — là `sum_q[9]` | Xác nhận phép `>> 2` không tốn gì (§2.1) |
| Chuỗi carry chỉ có 6 `maj3` chứ không phải 10 | — | Đúng như báo cáo | Không phải mọi bit đều cần một tầng: `abc` rút gọn được các bit thấp nhờ `sample_ext[9:8] = 0` và `oldest_ext[9:8] = 0` |

**Kết luận đối chiếu:** dự đoán đúng *chỗ nào chậm*, nhưng công cụ đã tối ưu **mạnh hơn dự
kiến** bằng cách hợp nhất cộng-trừ. Khi số liệu tool khác với suy luận cấu trúc, **tin
tool**, rồi đọc netlist để hiểu nó đã làm gì — ở đây là `maj3_1` (carry-save) thay cho hai
bộ ripple riêng.

### 4.4 Điều kiện tạo ra các con số trên

| Hạng mục | Giá trị |
|---|---|
| Công cụ | OpenSTA 3.1.0 |
| Netlist | `06_GDSII/synthesis/netlist.v` (Yosys 0.33) |
| Liberty | `sky130_fd_sc_hd__tt_025C_1v80.lib` — typical · 25 °C · 1,80 V |
| SDC | `create_clock -period 10.0`; `set_input_delay/set_output_delay 1.0` |
| Ký sinh dây | **CHƯA CÓ** — sau tổng hợp, chưa P&R |
| Clock network | **lý tưởng**, chưa CTS |

> ❗ **Không được đọc "slack 5,36 ns" thành "G01 chạy được ở 100 MHz".** Đặc biệt với G01,
> vì **1,00 ns của arrival là giả định về tầng ADC**, không phải phần cứng của khối. Nếu
> tầng trước chậm hơn, slack co lại đúng bằng phần chênh.

## 5. Vì sao datapath phải rộng 10 bit

| Câu hỏi | Trả lời |
|---|---|
| Vì sao không cộng vào biến 8 bit? | `4 × 255 = 1020 > 255` ⇒ **tràn**. Đây là "chỗ hay tắc" Charter mục 10 nêu đích danh |
| Vì sao đúng `W + 2`? | `4·(2^W − 1) < 2^(W+2)`. **Đã chứng minh hình thức** cho `W = 1…64` trong `bounds.py`, kết quả trong `python_reference_run.log` |
| Có cần 11 bit cho phép trừ không? | **Không.** `sum_q + x − oldest` không bao giờ âm vì `oldest` luôn là một trong các số hạng đang có trong `sum_q` (INV-3). Kết quả trung gian nằm trong `[0, 1275]`? — **không**: thứ tự thực hiện là `(sum_q + x) − oldest`, giá trị trung gian tối đa là `1020 + 255 = 1275`, **cần 11 bit**. RTL dùng 10 bit ⇒ giá trị trung gian **bị cắt**, nhưng kết quả cuối vẫn đúng vì số học modulo `2^10` và kết quả thật luôn `< 1024`. Đây là một chi tiết tinh tế **đúng nhưng dễ bị coi là lỗi** — xem `implementation-notes_G01.md` §9 |
| Có cần mở rộng dấu không? | Không — mọi giá trị đều không dấu; `>>` (không phải `>>>`) là đúng |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
