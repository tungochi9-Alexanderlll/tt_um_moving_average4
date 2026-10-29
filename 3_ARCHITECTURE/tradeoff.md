# G01 · Phân tích đánh đổi (Trade-off)

Số liệu lấy từ `06_GDSII/synthesis/synth_stat.txt`, `06_GDSII/sta/timing_report_max.txt`,
`06_GDSII/power/power_report.txt` của **chính lần chạy này**.

---

## 1. Kiến trúc đã chọn — số liệu thật

| Chỉ số | Giá trị đo được | Nguồn |
|---|---:|---|
| Tổng số cell | **260** | `synth_stat.txt` |
| Flip-flop (`dfxtp_1`) | **58** | như trên |
| Diện tích | **2 623,7664 µm²** | như trên |
| Đường tới hạn | `sample_in[1]` → `sum_q[9]`, **14 cell** | `timing_report_max.txt` |
| Data arrival time | **4,56 ns** (gồm 1,00 ns input delay) | như trên |
| Slack | **5,36 ns (MET)** | `summary.txt` |
| WNS / TNS (max) | **0,00 / 0,00** | `wns.txt`, `tns.txt` |
| Công suất tổng (ước lượng) | **3,28e-04 W** | `power_report.txt` |
| — tuần tự | **77,3 %** (2,53e-04 W) | như trên |
| — tổ hợp | **22,7 %** (7,43e-05 W) | như trên |
| Độ trễ nhóm | 4 mẫu hợp lệ trước kết quả đầu tiên | RTL |
| Thông lượng | 1 mẫu / chu kỳ | RTL |

**Điều kiện tạo ra bằng chứng:** Yosys 0.33 · OpenSTA 3.1.0 · `sky130_fd_sc_hd` ·
`sky130_fd_sc_hd__tt_025C_1v80.lib` (typical · 25 °C · 1,80 V) · **chưa có ký sinh dây** ·
clock lý tưởng, chưa CTS.

## 2. So sánh với ba kiến trúc thay thế

| Tiêu chí | **(A) Tích luỹ trượt + bộ nhớ vòng — ĐÃ CHỌN** | (B) Cộng thẳng 4 mẫu mỗi chu kỳ (`g01_direct_sum_reference.sv`) | (C) Thanh ghi dịch + cây cộng | (D) Lọc IIR một cực (trung bình luỹ thừa) |
|---|---|---|---|---|
| Ô nhớ | **58** (đo được) | ≈ **48** — bỏ `sum_q` (10 FF) | ≈ **48** — dịch thay vì con trỏ, bỏ `wr_ptr` + bản sao | ≈ **18** — chỉ giữ 1 tích luỹ 16 bit + cờ |
| Số phép cộng 10 bit / chu kỳ | **1 cộng + 1 trừ** (đã hợp nhất thành 1 mạng carry) | **3 cộng** (cây) + 1 cộng + 1 trừ (dòng 40–41) | **3 cộng** (cây 2 tầng) | 1 cộng + 1 trừ, không cần bộ nhớ cửa sổ |
| Độ sâu tổ hợp | **14 cell / 4,56 ns** (đo được) | ⬜ chưa đo — dự đoán **sâu hơn**, vì cây cộng 4 số hạng cần ≥ 2 tầng carry | ⬜ chưa đo — tương tự (B) | ⬜ chưa đo — nông nhất |
| Diện tích | **2 623,7664 µm²** (đo được) | ⬜ chưa đo | ⬜ chưa đo | ⬜ chưa đo |
| Có đúng trung bình 4 điểm? | ✅ | ✅ | ✅ | ❌ — đáp ứng xung vô hạn, không phải trung bình cửa sổ |
| Mở rộng lên cửa sổ N | **O(1)** phép cộng, O(N) ô nhớ | **O(N)** phép cộng | **O(N)** phép cộng | O(1) cả hai |
| Trong phạm vi Charter? | ✅ | ✅ (có trong hồ sơ) | ✅ | ❌ **Charter mục 3: IIR là đề G06** |

### 2.1 Vì sao (A) **chưa chắc** rẻ hơn (B) với N = 4 — phân tích trung thực

Charter mục 9 yêu cầu *"nêu thêm cách làm tiết kiệm hơn dùng bộ tích luỹ trượt, và nó tiết
kiệm được gì"*. Câu trả lời trung thực là: **RTL đã dùng bộ tích luỹ trượt rồi**, và với
**N = 4 thì nó gần như không tiết kiệm được gì** so với cộng thẳng.

Lý do đếm được:

| | Tích luỹ trượt (A) | Cộng thẳng (B) |
|---|---|---|
| Số hạng phải cộng | `sum_q`, `+x`, `−oldest` ⇒ **3 số hạng 10 bit** | `mem[0..3]` ⇒ **4 số hạng 10 bit** |
| Ô nhớ phụ | **+10 FF** cho `sum_q` | 0 |
| Vẫn phải giữ 4 mẫu? | **Có** — cần `oldest` để trừ | Có |

Với `N = 4`, "3 số hạng" so với "4 số hạng" là chênh lệch rất nhỏ, trong khi (A) tốn thêm
**10 flip-flop**. Chỉ khi `N` lớn (16, 64, 256) thì (A) mới thắng áp đảo: số số hạng của
(A) **luôn là 3**, còn của (B) là `N`.

⇒ **Kết luận đúng cho đề này:** bộ tích luỹ trượt ở đây là lựa chọn **theo kiến trúc mở
rộng được**, không phải theo tiết kiệm tức thời. Lợi ích thật của nó là **độ trễ tổ hợp
không tăng khi N tăng**.

> ⬜ **Chưa có số liệu để kết luận định lượng.** `g01_direct_sum_reference.sv` **chưa được
> tổng hợp** (top là `g01_moving_average4`, xem `synth.ys`). Điều kiện để so sánh bằng số:
> đổi `hierarchy -check -top` sang `g01_direct_sum_reference`, chạy lại
> `02_run_synth.sh` và `03_run_sta.tcl`, rồi so cột cell / FF / diện tích / arrival. Đây là
> **một thí nghiệm nhỏ, rẻ, và rất đáng làm** — hồ sơ đã có sẵn cả hai bản RTL.

### 2.2 Cách **thật sự** tiết kiệm hơn cho N = 4

| Phương án | Tiết kiệm | Giá phải trả |
|---|---|---|
| Bỏ `sum_q`, cộng thẳng (chính là (B)) | **−10 FF** (58 → 48), ≈ −17 % ô nhớ | Đường tổ hợp sâu hơn; không mở rộng được cho N lớn |
| Bỏ thanh ghi `avg_out`, đưa `sum_next[9:2]` thẳng ra chân | **−8 FF** (≈ −14 %) | Đầu ra thành tổ hợp ⇒ **có glitch**, và đường tới hạn kéo dài tới tận chân ra |
| Thay `count_q` 3 bit bằng 1 cờ + bộ đếm 2 bit | −0 FF thực tế (vẫn 3 FF) | Không lợi |
| Dùng thanh ghi dịch thay bộ nhớ vòng (phương án C) | **−4 FF** (`wr_ptr` 2 + bản sao con trỏ 2) và **−8 cell `mux4_2`** | 32 FF phải dịch mỗi mẫu ⇒ **công suất chuyển mạch tăng**: thay vì ghi 1 ô/mẫu thì phải ghi cả 4 ô. Với tuần tự chiếm 77,3 % công suất, đây là đánh đổi **xấu về năng lượng** |

Phương án (C) là ví dụ hay để dạy: nó **giảm diện tích** nhưng **tăng công suất** — hai chỉ
tiêu đi ngược nhau, và không có câu trả lời "tốt hơn" nếu chưa biết ràng buộc nào quan trọng.

## 3. Đánh đổi bên trong kiến trúc đã chọn — bằng số liệu thật

| Quyết định trong RTL | Được | Mất (đo được) |
|---|---|---|
| `sum_q` rộng **10 bit** (`W + 2`) | **Không bao giờ tràn** — chứng minh hình thức trong `bounds.py` cho `W = 1…64` | 10 FF; và 2 bit thấp bị vứt sau `>> 2` nhưng vẫn phải tính (cần cho chuỗi carry) |
| Bộ nhớ vòng + `wr_ptr` thay vì thanh ghi dịch | Mỗi mẫu chỉ ghi **1 ô** ⇒ công suất chuyển mạch thấp | +2 FF (`wr_ptr`) **+2 FF bản sao con trỏ đọc do Yosys sinh** + 8 cell `mux4_2` |
| Đọc và ghi cùng địa chỉ trong một chu kỳ | Mã ngắn, đúng thành ngữ read-before-write | Yosys nhân đôi thanh ghi địa chỉ — **2 FF, 3,4 % ô nhớ**, chỉ thấy được khi đọc netlist |
| Thanh ghi hoá `avg_out` | Đầu ra sạch glitch, cắt đường tới hạn trước chân ra | **8 FF** (13,8 % ô nhớ) |
| `count_q` bão hoà 3 bit | Chống cuộn vòng làm hỏng bộ lọc (`control.md` §3) | 3 FF cho một thông tin gần như nhị phân |
| `>> 2` thay bộ chia | **0 cell** — bằng chứng: không có cell dịch nào trong 260 cell | Chỉ chia được cho luỹ thừa 2 ⇒ **khoá cứng cửa sổ ở 4 điểm** |
| `sample_in` đi thẳng vào bộ cộng (không đệm) | Tiết kiệm 8 FF, giảm 1 chu kỳ độ trễ | Đường tới hạn **bắt đầu từ chân vào** ⇒ phụ thuộc `input_delay` của tầng ADC: **1,00 ns / 4,56 ns = 22 %** arrival |

### Đọc con số công suất cho đúng

`power_report.txt`: **3,28e-04 W**, tuần tự **77,3 %**, tổ hợp **22,7 %**, **Clock 0,0 %**.

* Tỷ lệ tuần tự cao là hệ quả của 58 FF / 260 cell (22 % số cell là flip-flop).
* So với F10 (22 FF, tuần tự 84,7 %): G01 có **nhiều FF hơn** nhưng **tỷ lệ tuần tự thấp
  hơn** — vì phần tổ hợp của G01 (bộ cộng 10 bit, 8 `mux4_2`) lớn hơn hẳn.
* **`Clock 0,00 W` nghĩa là CHƯA CÓ cây clock** (CTS chưa chạy), không phải cây clock miễn
  phí. Với 58 flip-flop, cây clock sau CTS nhiều khả năng sẽ là nhóm tốn nhất.
* Toàn bộ là **ước lượng với hoạt động mặc định**, không lấy từ VCD thật.

## 4. Những đánh đổi **KHÔNG được phép** trong đề này

| Không được làm | Vì sao |
|---|---|
| Đổi sang cửa sổ dài hơn 4 điểm | Charter mục 3: **ngoài phạm vi** |
| Dùng hệ số có trọng số (ví dụ `[1,2,2,1]/6`) | Charter mục 3: ngoài phạm vi; và mất tính "chia bằng dịch bit" |
| Đổi sang lọc IIR / trung bình luỹ thừa | Charter mục 3: **đó là đề G06** |
| Cộng bốn mẫu vào biến 8 bit rồi mới dịch | **Tràn** — Charter mục 10 nêu đích danh đây là chỗ hay tắc |
| Bỏ `valid_out` | Không phân biệt được "chưa sẵn sàng" với "trung bình bằng 0" (`control.md` §5) |
| Tự tối ưu netlist bằng tay, tự làm physical design, tape-out | Charter mục 3, áp dụng cho mọi đề |
| Sửa RTL/testbench trong hồ sơ | Bản vá chỉ được **đề xuất** ở `known_issues.md`, chờ thầy duyệt |

## 5. Dư địa còn lại và điều kiện để khai thác

| Cơ hội | Lợi ích ước tính | Điều kiện để kiểm chứng |
|---|---|---|
| Slack **5,36 / 9,93 ns** ⇒ đường tới hạn dùng **46 %** ngân sách | Có thể hạ chu kỳ xuống ~5 ns, hoặc đổi sang cell nhỏ hơn để giảm diện tích | Chạy lại STA với chu kỳ khác; chạy P&R để có ký sinh thật |
| Tổng hợp `g01_direct_sum_reference` để so sánh | Có số liệu thật cho bảng §2 thay vì ⬜ | Đổi `-top` trong `synth.ys`, chạy lại |
| 5 cell họ `lpflow_*` | Sẽ bị thay khi LibreLane đưa vào `dont_use` | `04_run_librelane.sh` + PDK sky130A |
| 2 FF bản sao con trỏ đọc | ≈ 3,4 % ô nhớ; có thể tránh bằng cách tách biến đọc/ghi tường minh | Viết biến thể RTL, tổng hợp lại, so `synth_stat.txt` |
| Công suất từ VCD thật | Số liệu công suất đáng tin hơn | Thêm `$dumpvars`, xuất VCD, `read_vcd` trong OpenSTA |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
