# G01 · Sơ đồ khối bên trong (Block Diagram)

---

## 1. Sơ đồ vẽ theo đúng mã RTL

Nguồn: `04_IMPLEMENTATION/rtl/g01_moving_average4.sv` (64 dòng).

```
   sample_in[7:0] ══════════════════════════════╦══════════════════╗
                                                ║                  ║
   valid_in ──┬─────────────────────────────────╫──┐               ║
              │                                 ║  │               ║
              │   ┌─────────────────────────┐   ║  │               ║
              │   │ wr_ptr[1:0]   (2 FF)    │   ║  │               ║
              ├──▶│  +1 mỗi mẫu hợp lệ      │   ║  │               ║
              │   └────┬───────────────┬────┘   ║  │               ║
              │        │ địa chỉ GHI   │ địa chỉ ĐỌC                ║
              │        ▼               ▼        ║  │               ║
              │   ┌──────────────────────────┐  ║  │               ║
              │   │  sample_mem[0:3][7:0]    │◀═╝  │               ║
              │   │  BỘ NHỚ CỬA SỔ — 32 FF   │     │               ║
              │   │  (ghi 1 ô / mẫu)         │     │               ║
              │   └────────────┬─────────────┘     │               ║
              │                │ đọc ô CŨ NHẤT     │               ║
              │                │ (8 × mux4_2)      │               ║
              │                ▼                   │               ║
              │        oldest_ext[9:0]             │               ║
              │                │                   │               ║
              │   ┌────────────▼──────────────────────────────┐    ║
              │   │  always_comb  (dòng 26–31)                │    ║
              │   │                                            │◀═══╝
              │   │   count_q < 4 ?  sum_q + x                │
              │   │                : sum_q + x − oldest       │
              │   │   ↑ CHUỖI CARRY 10 BIT — đường tới hạn    │
              │   └────────────────────┬───────────────────────┘
              │                        │ sum_next[9:0]
              │           ┌────────────┼───────────────┐
              │           ▼            │               │ bit [9:2]
              │   ┌──────────────┐     │               ▼
              │   │ sum_q[9:0]   │◀────┘        ┌─────────────┐
              │   │  (10 FF)     │              │ avg_out[7:0]│  ← ">> 2" chỉ là
              │   └──────────────┘              │   (8 FF)    │    ĐỔI CHỈ SỐ DÂY
              │                                 └─────────────┘    (0 cell)
              │   ┌──────────────────────┐
              ├──▶│ count_q[2:0]  (3 FF) │──▶ count_q >= 3 ? ──▶ ┌────────────┐
              │   │ bão hoà ở 4          │                       │ valid_out  │
              │   └──────────────────────┘                       │   (1 FF)   │
              └────────────────────────────────────────────────▶ └────────────┘
```

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

Đối chiếu trực tiếp với `06_GDSII/synthesis/netlist.v` và `synth_stat.txt`.

| Dòng RTL | Cấu trúc | Phần cứng | FF | Xác nhận trên netlist |
|---:|---|---|---:|---|
| 12 | `localparam SUM_W = W + 2;` | Không sinh phần cứng — quyết định độ rộng | 0 | `sum_q` rộng 10 bit ✅ |
| 14 | `logic [W-1:0] sample_mem [0:3];` | **Bộ nhớ 4×8 hiện thực bằng flip-flop** | **32** | 32 `dfxtp_1` có `Q = sample_mem[i][j]` ✅ |
| 15 | `logic [1:0] wr_ptr;` | Con trỏ vòng | **2** | 2 `dfxtp_1` có `Q = wr_ptr[i]` |
| — | (hệ quả của pass `memory` trong Yosys) | **Bản sao con trỏ ĐỌC** | **2** | `_406_`/`_407_` → `_000_`/`_001_`, lái chân `S0`/`S1` của **8 cell `mux4_2`** ✅ |
| 16 | `logic [2:0] count_q;` | Bộ đếm bão hoà | **3** | 3 `dfxtp_1` |
| 17 | `logic [SUM_W-1:0] sum_q;` | Bộ tích luỹ | **10** | 10 `dfxtp_1` |
| 23 | `assign sample_ext = {2'b00, sample_in};` | **Dây thuần** — mở rộng 0 | 0 | không sinh cell |
| 24 | `assign oldest_ext = {2'b00, sample_mem[wr_ptr]};` | **Bộ chọn 4→1, 8 bit** | 0 | **8 cell `mux4_2`** ✅ |
| 26–31 | `always_comb` cộng / cộng-trừ | Bộ cộng 10 bit + bộ trừ 10 bit + MUX chọn | 0 | `maj3_1` × 12 (carry), `xor2`/`xnor2` × 33 (sum), `mux2_1` × 3 |
| 33 | `always_ff @(posedge clk)` | Ranh giới chốt | — | — |
| 34–43 | reset **đồng bộ** | MUX trên đường D của mọi FF | 0 | `dfxtp_1` không có chân reset ✅ |
| 45 | `valid_out <= 1'b0;` (mặc định) | Xung 1 chu kỳ | 0 | — |
| 47 | `if (valid_in)` | **Enable toàn cục** cho gần như mọi FF | 0 | `mux2i_1` × 12 và `a32o_1` × 16 phần lớn là logic giữ/nạp |
| 51–52 | `if (count_q < 4) count_q <= count_q + 1;` | Bộ đếm bão hoà 3 bit | 0 | |
| 56–58 | `if (count_q >= 3) begin valid_out<=1; avg_out <= sum_next >> 2; end` | `valid_out` + **`>>2` là đổi chỉ số dây** | **1 + 8** | `_424_…_431_` có `Q = avg_out[i]` |
| | | **TỔNG FF** | **58** | `synth_stat.txt`: `dfxtp_1  58` ✅ **KHỚP** |

### Bóc tách 58 flip-flop — trả lời Charter mục 2 câu 1 và mục 9

| Nhóm | Số FF | Tỷ lệ | Vai trò |
|---|---:|---:|---|
| `sample_mem[0:3][7:0]` | **32** | 55,2 % | Cửa sổ 4 mẫu — **đúng 32 như Charter dự đoán** ✅ |
| `sum_q[9:0]` | 10 | 17,2 % | Bộ tích luỹ trượt (10 bit chống tràn) |
| `avg_out[7:0]` | 8 | 13,8 % | Đầu ra được thanh ghi hoá |
| `count_q[2:0]` | 3 | 5,2 % | Đếm mẫu, bão hoà ở 4 |
| `wr_ptr[1:0]` | 2 | 3,4 % | Con trỏ vòng ghi |
| **Bản sao con trỏ đọc** (`_000_`, `_001_`) | **2** | 3,4 % | **Do công cụ sinh**, không có trong RTL — xem §3 |
| `valid_out` | 1 | 1,7 % | Cờ |
| **Tổng** | **58** | 100 % | ✅ khớp `synth_stat.txt` |

Charter mục 10 dự đoán *"32 + 2–3 cờ ≈ 34–35 ô nhớ"*. Đo được **58**, chênh **+23…+24**.
Toàn bộ phần dư được giải thích, không còn FF nào không rõ nguồn gốc:

* **+10** cho `sum_q` — Charter không tính bộ tích luỹ (nó giả định cộng lại 4 mẫu mỗi lần).
* **+8** cho `avg_out` — Charter không tính việc thanh ghi hoá đầu ra.
* **+3** cho `count_q` — Charter tính là "2–3 cờ", khớp.
* **+2** cho `wr_ptr`.
* **+2** cho bản sao con trỏ đọc do Yosys sinh.
* **+1** cho `valid_out`.

## 3. Hai flip-flop "lạ" `_000_` / `_001_` — bằng chứng từ log công cụ

Netlist có hai flip-flop không tương ứng tín hiệu nào trong RTL:

```verilog
sky130_fd_sc_hd__dfxtp_1 _406_ ( .CLK(clk), .D(_002_), .Q(_000_) );
sky130_fd_sc_hd__dfxtp_1 _407_ ( .CLK(clk), .D(_003_), .Q(_001_) );
```

Chúng lái chân chọn của **cả 8 cell `mux4_2`** — tức chúng là **địa chỉ đọc** của
`sample_mem`:

```verilog
sky130_fd_sc_hd__mux4_2 _255_ ( .A0(sample_mem[0][1]), .A1(sample_mem[1][1]),
                                .A2(sample_mem[2][1]), .A3(sample_mem[3][1]),
                                .S0(_000_), .S1(_001_), .X(_093_) );
```

Nguồn gốc, đọc từ `06_GDSII/synthesis/yosys.log`:

```
Creating register for signal `\g01_moving_average4.$memwr$\sample_mem$…:48$45_ADDR'
…
4.10. Executing PROC_MEMWR pass (convert process memory writes to cells).
8.3. Executing OPT_MEM_FEEDBACK pass (finding memory read-to-write feedback paths).
8.5. Executing MEMORY_DFF pass (merging $dff cells to $memrd).
```

Vì RTL **vừa đọc vừa ghi** `sample_mem[wr_ptr]` trong cùng một khối (dòng 24 đọc, dòng 48
ghi), pass `memory` của Yosys tách thành một cổng ghi và một cổng đọc, và **nhân đôi thanh
ghi địa chỉ**. Kết quả: 2 flip-flop dư, **≈ 3,4 % tổng ô nhớ**.

**Bài học đáng dạy:** đây là chi phí mà **chỉ đọc netlist mới thấy**. Đếm ô nhớ từ RTL cho
56, công cụ cho 58 — và chênh lệch không phải sai sót mà là hệ quả của một phép biến đổi
cụ thể, tra được trong log.

## 4. Phân bố cell thật (260 cell)

| Cell | Số lượng | Vai trò suy ra |
|---|---:|---|
| `dfxtp_1` | **58** | Toàn bộ ô nhớ |
| `nand2_1` | 33 | Logic điều kiện, enable |
| `o21ai_0` | 22 | |
| `nor2_1` | 21 | |
| `xnor2_1` | 19 | **Bit tổng** của bộ cộng/trừ 10 bit |
| `a32o_1` | 16 | Logic giữ/nạp cho `sample_mem` |
| `xor2_1` | 14 | Bit tổng |
| `a21oi_1` | 12 | |
| **`maj3_1`** | **12** | **Carry của bộ cộng** (majority-of-3 = carry-out của full adder) |
| `mux2i_1` | 12 | Chọn giữ / nạp |
| **`mux4_2`** | **8** | **Bộ đọc `sample_mem[wr_ptr]`** — 1 cell / bit |
| `nand2b_1` | 7 | |
| `and2_0` | 4 | |
| `lpflow_isobufsrc_1` | 4 | Cell cách ly nguồn, `abc` chọn vì diện tích nhỏ |
| `mux2_1`, `a31oi_1` | 3 + 3 | `mux2_1` là bộ chọn `count_q<4 ? … : …` |
| còn lại | 1–2 mỗi loại | |

**Diện tích: 2 623,7664 µm²** cho 260 cell ⇒ ≈ 10,1 µm²/cell. So với F10 (106 cell,
1 019,728 µm²): G01 lớn hơn **2,45×** về cell và **2,57×** về diện tích — đúng tỷ lệ với số
flip-flop (58 vs 22 ≈ 2,6×).

> ⚠️ `lpflow_*` × 5 (4 `isobufsrc` + 1 `inputiso1p`): flow LibreLane thật thường đưa họ này
> vào `dont_use` ⇒ số cell và diện tích sau P&R **sẽ lệch chút ít**.

## 5. Khối con nào nằm trên đường tới hạn

Từ `timing_report_max.txt` — **14 cell**, arrival **4,56 ns** (đã gồm 1,00 ns input delay):

| Khối con (theo RTL) | Có trên đường tới hạn? | Bằng chứng |
|---|:-:|---|
| Cổng vào `sample_in` | ✅ **điểm xuất phát** | `sample_in[1] (input)`, `input external delay 1.00` |
| Bộ cộng/trừ 10 bit — **chuỗi carry** | ✅ **phần đắt nhất** | `_270_, _282_, _292_, _303_, _315_, _327_` — **6 cell `maj3_1` nối tiếp**, mỗi cell ≈ 0,39 ns |
| Bit tổng của bộ cộng | ✅ | `_253_`, `_329_`, `_337_` — `xnor2_1` |
| MUX `count_q < 4 ? … : …` | ✅ | `_374_ mux2_1` (0,29 ns) |
| Logic nạp/giữ `sum_q` | ✅ | `_375_ nor2_1` (0,07 ns) |
| Thanh ghi `sum_q[9]` | ✅ **điểm đích** | `_446_/D` |
| **Bộ đọc `sample_mem[wr_ptr]` (8 × `mux4_2`)** | ❌ | Không xuất hiện trên đường — nó **song song** với đường của `sample_in`, và ngắn hơn |
| **Phép `>> 2` và `avg_out`** | ❌ | Endpoint là `sum_q[9]`, **không phải** `avg_out`. Bằng chứng trực tiếp rằng phép chia 4 **không tốn gì** |
| `count_q`, `wr_ptr`, `valid_out` | ❌ | Đường rất ngắn |

**Kết luận đọc được từ netlist:** nút thắt của G01 là **chuỗi carry của bộ cộng 10 bit**,
đúng như bản chất một bài toán số học nối tiếp — giống chuỗi carry của A01, chỉ khác là ở
đây nó nằm giữa hai thanh ghi thay vì giữa hai cổng.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
