# G01 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng (Charter mục 1)

> *"Khối làm trơn số đo nhiệt độ trước khi hiển thị, để số trên màn hình không nhảy liên tục
> vì nhiễu."*

```
   MIỀN TƯƠNG TỰ                  │        MIỀN SỐ (trên chip)              │  NGƯỜI DÙNG
 ──────────────────────────────────┼────────────────────────────────────────┼──────────────
                                   │                                        │
  ┌──────────┐    ┌─────────────┐  │  ┌──────────────┐                     │
  │ Cảm biến │───▶│  ADC        │──┼─▶│ Tầng giao    │  sample_in[7:0]     │
  │ nhiệt độ │ mV │  (8 bit)    │  │  │ tiếp ADC     ├──────────┐          │
  └──────────┘    └─────────────┘  │  │ sinh valid   │ valid_in │          │
       ▲                ▲          │  └──────────────┘          │          │
       │                │          │                            ▼          │
   nhiễu nhiệt     nhiễu lượng     │   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓   │
   + nhiễu điện    tử hoá ±½ LSB   │   ┃   ►► G01 ◄◄                   ┃   │
                                   │   ┃  g01_moving_average4          ┃   │
                                   │   ┃   • sample_mem 4×8  (32 FF)   ┃   │
                                   │   ┃   • sum_q 10 bit    (10 FF)   ┃   │
                                   │   ┃   • >> 2  (0 cell)            ┃   │
                                   │   ┗━━━━━━━┳━━━━━━━━━━━━━┳━━━━━━━━━┛   │
                                   │           │ avg_out[7:0]│ valid_out   │
                                   │           ▼             ▼             │
                                   │   ┌───────────────────────────────┐   │
                                   │   │ Bộ chuyển mã → 7 đoạn / LCD   │   │──▶ ┌────────┐
                                   │   │ (chỉ cập nhật khi valid_out)  │   │    │ 23 °C  │
                                   │   └───────────────────────────────┘   │    └────────┘
                                   │                                        │
  ⬜ CHƯA CÓ trong RTL: tầng ánh xạ chân Tiny Tapeout (ui_in/uo_out/uio_*)  │
```

## 2. Ranh giới khối — cái gì thuộc G01, cái gì không

| Thành phần | Thuộc G01? | Bằng chứng / ghi chú |
|---|:-:|---|
| Bộ nhớ 4 mẫu (cửa sổ) | ✅ | `sample_mem[0:3]`, dòng 14 — **32 flip-flop** trên netlist |
| Bộ tích luỹ trượt 10 bit | ✅ | `sum_q`, dòng 17 — 10 FF |
| Chia 4 bằng dịch phải | ✅ | `sum_next >> 2`, dòng 58 — **0 cell** |
| Cờ kết quả hợp lệ | ✅ | `valid_out`, dòng 45/57 |
| Con trỏ vòng | ✅ | `wr_ptr`, dòng 15 |
| Đếm số mẫu đã nhận | ✅ | `count_q`, dòng 16 |
| **Sinh `valid_in` từ ADC** | ❌ | Tầng giao tiếp ADC |
| **Lấy mẫu / chống trùng lặp mẫu** | ❌ | Tầng ngoài |
| Chuyển mã hiển thị, đơn vị °C | ❌ | Tầng hiển thị |
| Hiệu chuẩn cảm biến, bù phi tuyến | ❌ | Phần mềm |
| **Tầng ánh xạ chân Tiny Tapeout** | ❌ **nhưng Charter mục 4 yêu cầu** | ⇒ **CHƯA THOẢ**, xem `02_SPECIFICATION/functional_spec.md` |

### Nghĩa vụ hợp đồng của tầng ngoài

1. `valid_in` phải là **một xung cho mỗi mẫu mới**. Giữ `valid_in` cao nhiều chu kỳ sẽ nạp
   **cùng một mẫu nhiều lần** và làm sai cửa sổ — G01 không có cách nào phát hiện.
2. `sample_in` phải ổn định tại sườn lên khi `valid_in = 1`, và **không được có `X`/`Z`**
   (BIÊN-7: một mẫu hỏng làm hỏng `sum_q` vĩnh viễn).
3. **Chỉ dùng `avg_out` khi `valid_out = 1`.** Trước đó `avg_out` giữ giá trị cũ — và `0`
   sau reset là một giá trị trung bình hợp lệ, không phân biệt được.
4. `rst_n` phải giữ thấp qua ít nhất một sườn lên `clk` (reset đồng bộ).

## 3. Vòng đời RTL → GDSII — trạng thái **thật** của G01

```
  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
  │ Đặc tả       │──▶│ RTL          │──▶│ Mô phỏng     │──▶│ Tổng hợp     │
  │ (Charter)    │   │ SystemVerilog│   │ hành vi      │   │ Yosys 0.33   │
  │      ✅      │   │      ✅      │   │  ⚠️ DỪNG     │   │  ✅ PASS     │
  └──────────────┘   └──────────────┘   │  t = 76      │   │ 260 cell     │
                                        └──────────────┘   │ 58 FF        │
                                                           │ 2623,7664 µm²│
                                                           └──────┬───────┘
                                                                  ▼
  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
  │ CTS          │◀──│ Placement    │◀──│ Floorplan    │◀──│ STA          │
  │  ⬜ chưa     │   │  ⬜ chưa     │   │  ⬜ chưa     │   │  ✅ PASS     │
  └──────────────┘   └──────────────┘   └──────────────┘   │ slack 5,36ns │
                                                           └──────────────┘
  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
  │ Routing      │   │ DRC          │   │ LVS          │   │ GDS          │
  │  ⬜ chưa     │   │  ⬜ chưa     │   │  ⬜ chưa     │   │  ⬜ chưa     │
  └──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
```

| Bước | Trạng thái | Bằng chứng | Số liệu |
|---|---|---|---|
| Chứng minh độ rộng tích luỹ | ✅ PASS | `python_reference_run.log` | `G01 accumulator-width proof PASS for W=1..64` |
| Mô hình chuẩn hành vi | ⚠️ **xem ghi chú dưới** | `golden_model/reference_model.py` | — |
| Mô phỏng RTL | ⚠️ RAN_WITH_ISSUES | `simulation.log` | `FATAL g01_tb.sv:22`, `Time: 76` |
| Biên dịch Icarus | ✅ không lỗi | `iverilog_compile.log` rỗng | — |
| Tổng hợp | ✅ PASS | `synth_stat.txt` | **260 cell · 58 FF · 2 623,7664 µm²** |
| STA | ✅ PASS (`real_clock`) | `timing_report_max.txt` | arrival **4,56 ns**, slack **5,36 ns**, WNS/TNS **0,00 / 0,00** |
| Công suất | ✅ ước lượng | `power_report.txt` | **3,28e-04 W** — tuần tự 77,3 %, tổ hợp 22,7 % |
| CTS → GDS | ⬜ chưa chạy | các `README.md` | — |

> ⚠️ **Lỗ hổng bằng chứng cần nêu trung thực:** `python_reference_run.log` chỉ chứa **một
> dòng** — `G01 accumulator-width proof PASS for W=1..64` — tức đầu ra của `bounds.py`.
> Dòng `G01 golden reference PASS` mà `reference_model.py` in ra ở dòng 60 **không có trong
> log**. `brief/G01.md` ghi "Python reference: PASS", nhưng **hồ sơ không lưu bằng chứng
> chạy của `reference_model.py`**. Điều kiện để bổ sung: chạy
> `python3 05_VERIFICATION/golden_model/reference_model.py` và ghi đầu ra vào log.

## 4. Vì sao đường tới hạn bắt đầu từ **chân vào**

Kết quả STA (`summary.txt`):

```
Startpoint                           Endpoint                               Slack
sample_in[1] (input)                 _446_/D (sky130_fd_sc_hd__dfxtp_1)      5.36
```

`_446_` là flip-flop của **`sum_q[9]`**. Đường tới hạn đi **từ cổng vào `sample_in[1]`
thẳng vào bộ cộng 10 bit** rồi tới bit cao nhất của bộ tích luỹ — nghĩa là mẫu mới **không
đi qua thanh ghi nào** trước khi được cộng.

Đây là hệ quả kiến trúc: `sum_next = sum_q + sample_ext` là `always_comb` (dòng 26–31), lấy
`sample_in` trực tiếp từ chân. Hậu quả thực tế: **độ trễ của G01 phụ thuộc vào thời điểm
tầng ADC đưa dữ liệu ra**. SDC giả định `set_input_delay 1.0` — và 1,00 ns đó chiếm **22 %**
trong tổng 4,56 ns. Nếu tầng ADC chậm hơn giả định, slack sẽ co lại tương ứng.

Cách khắc phục nếu cần (ngoài phạm vi đề): chèn một thanh ghi đệm cho `sample_in` — tốn
8 FF, thêm 1 chu kỳ độ trễ, nhưng cắt hẳn phụ thuộc vào `input_delay`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
