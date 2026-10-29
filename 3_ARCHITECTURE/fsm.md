# G01 · Máy trạng thái hữu hạn (FSM)

---

## 1. Kết luận: G01 **không có FSM tường minh** — nhưng **có trạng thái**

Đây là một mục "không áp dụng" có nội dung, không phải mục bỏ trống. Phải phân biệt hai
khái niệm hay bị gộp:

| Khái niệm | G01 có không? | Bằng chứng |
|---|:-:|---|
| **Mạch tuần tự** (có ô nhớ) | ✅ **CÓ** | `always_ff @(posedge clk)` dòng 33; **58 cell `dfxtp_1`** trong `synth_stat.txt`; công suất nhóm Sequential = **77,3 %** |
| **FSM tường minh** (có biến trạng thái, tập trạng thái đặt tên, hàm chuyển dạng `case`) | ❌ **KHÔNG** | Không có `typedef enum`, không có biến tên `state`, không có `case` nào trong RTL |

⇒ G01 là **mạch tuần tự điều khiển bằng bộ đếm**, không phải bằng máy trạng thái.

## 2. Bằng chứng phủ định — ba nguồn độc lập

**(1) Đọc RTL.** `g01_moving_average4.sv` (64 dòng) chứa đúng:

* một `always_comb` (dòng 26–31) — chọn giữa hai biểu thức số học,
* một `always_ff` (dòng 33–62) — với cấu trúc `if (!rst_n) … else if (valid_in) …`,
* **không có** `case`, **không có** `enum`, **không có** biến trạng thái.

**(2) Đọc netlist.** `synth_stat.txt` không có cell giải mã trạng thái đặc trưng của FSM.
Các flip-flop đều ánh xạ 1-1 về **dữ liệu** hoặc **bộ đếm** (xem `block_diagram.md` §2):
32 mẫu + 10 tích luỹ + 8 đầu ra + 3 đếm + 2 con trỏ + 2 bản sao + 1 cờ.

**(3) Đọc log tổng hợp.** `synth.ys` có pass `fsm` (dòng 6). `yosys.log` **không ghi nhận
trích xuất FSM nào** — pass này không tìm thấy máy trạng thái để tối ưu. Nếu có FSM ẩn,
Yosys thường in `Extracting FSM…` và tên tín hiệu; ở đây không có.

## 3. Nhưng G01 **có một máy trạng thái ẩn** — và nó đáng vẽ ra

Dù không viết dưới dạng `case`, hành vi của G01 **có đúng hai chế độ**, phân biệt bởi
`count_q`:

```
                 rst_n = 0
                     │
                     ▼
        ╔════════════════════════╗
        ║  NẠP ĐẦY (WARM-UP)     ║   count_q ∈ {0,1,2,3}
        ║  sum_next = sum_q + x  ║   ← KHÔNG trừ
        ║  valid_out = (cnt≥3)   ║
        ╚═══════════╤════════════╝
                    │  mẫu hợp lệ thứ 4  (count_q: 3 → 4)
                    ▼
        ╔════════════════════════════════════╗
        ║  ỔN ĐỊNH (STEADY)                  ║   count_q = 4 (bão hoà)
        ║  sum_next = sum_q + x − oldest     ║   ← CÓ trừ
        ║  valid_out = 1 với mọi mẫu hợp lệ  ║
        ╚════════════════════════════════════╝
                    ↺  (ở lại vĩnh viễn cho tới khi reset)

        Không có cạnh quay lại NẠP ĐẦY — chỉ reset mới đưa về đó.
```

### Bảng chuyển của máy trạng thái ẩn

| Chế độ | Điều kiện | Chế độ kế | `sum_next` | `valid_out` (chu kỳ sau) |
|---|---|---|---|---|
| NẠP ĐẦY (`count_q` 0→2) | `valid_in` | NẠP ĐẦY | `sum_q + x` | 0 |
| NẠP ĐẦY (`count_q = 3`) | `valid_in` | **ỔN ĐỊNH** | `sum_q + x` | **1** |
| bất kỳ | `!valid_in` | giữ nguyên | (không dùng) | 0 |
| ỔN ĐỊNH (`count_q = 4`) | `valid_in` | ỔN ĐỊNH | `sum_q + x − oldest` | 1 |
| bất kỳ | `!rst_n` | NẠP ĐẦY (`count_q = 0`) | — | 0 |

Điểm tinh tế: ở dòng thứ hai, mẫu thứ tư **vẫn dùng công thức của chế độ NẠP ĐẦY** (không
trừ) nhưng **đã sinh kết quả hợp lệ**. Nghĩa là ranh giới của "công thức" (`count_q < 4`)
và ranh giới của "hợp lệ" (`count_q >= 3`) **lệch nhau một mẫu** — và cả hai đều đúng. Xem
`control.md` §2.3.

Nếu muốn **viết lại G01 dưới dạng FSM tường minh**, chỉ cần hai trạng thái và
**1 flip-flop** thay cho `count_q` 3 bit — nhưng vẫn cần đếm 4 mẫu đầu, nên thực tế sẽ
thành FSM 2 trạng thái **cộng** một bộ đếm 2 bit ⇒ vẫn 3 FF. **Không tiết kiệm được gì**,
và mã sẽ dài hơn. Đây là lý do chính đáng để RTL **không** dùng FSM.

## 4. Khi nào một bộ lọc trung bình trượt **sẽ** cần FSM thật

| Tình huống | FSM xuất hiện vì |
|---|---|
| Dùng **một** bộ cộng dùng chung cho nhiều tap (chia sẻ tài nguyên) | Cần trạng thái để biết đang ở bước cộng thứ mấy |
| Cửa sổ dài (ví dụ 64 điểm) hiện thực bằng **SRAM** thay vì flip-flop | Cần FSM điều khiển chu kỳ đọc / tính / ghi của RAM |
| Có giao thức bắt tay `ready/valid` hai chiều | Cần trạng thái cho backpressure |
| Có chế độ cấu hình (nạp hệ số, đổi độ dài cửa sổ lúc chạy) | Cần FSM cho chuỗi nạp cấu hình |
| Xử lý nhiều kênh xen kẽ (time-multiplex) | Cần trạng thái chọn kênh |

Không tình huống nào trong số đó thuộc phạm vi G01: Charter mục 3 loại "cửa sổ dài hơn, hệ
số có trọng số, lọc IIR" ra khỏi phạm vi, và giao diện chỉ có `valid_in`/`valid_out` một
chiều.

## 5. So sánh với hai đề cùng đợt

| | F09 | F10 | **G01** |
|---|---|---|---|
| Có `typedef enum` trạng thái? | ✅ | ✅ | ❌ |
| Có `case` hàm chuyển? | ✅ | ✅ | ❌ |
| Số trạng thái tường minh | 4 | 4 | — (2 chế độ ẩn) |
| FF cho điều khiển | 2/5 = 40 % | 6/22 = 27 % | **8/58 = 14 %** |
| FF cho dữ liệu | 3/5 (đầu ra) | 16/22 | **50/58 = 86 %** |
| Bản chất | Điều khiển thuần | Điều khiển + đếm giờ | **Dữ liệu thuần** |

Bảng này cho thấy rõ vì sao Charter xếp F09/F10 vào nhóm F (FSM) còn G01 vào nhóm G (xử lý
tín hiệu số): **tỷ lệ ô nhớ dành cho dữ liệu là dấu hiệu phân loại đáng tin hơn tên đề.**

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
