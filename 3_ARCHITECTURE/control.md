# G01 · Phần điều khiển (Control)

---

## 1. G01 có phần điều khiển, nhưng rất nhỏ

| Phần | Thành phần | Số FF | Tỷ lệ |
|---|---|---:|---:|
| Datapath | `sample_mem` 32 + `sum_q` 10 + `avg_out` 8 | 50 | 86,2 % |
| **Điều khiển** | `wr_ptr` 2 + bản sao con trỏ đọc 2 + `count_q` 3 + `valid_out` 1 | **8** | 13,8 % |

Phần điều khiển của G01 **không phải là một FSM** (xem `fsm.md`), mà là **hai bộ đếm** kèm
một cờ. Đây là dạng điều khiển đơn giản nhất của mạch tuần tự: điều khiển bằng **bộ đếm**
thay vì bằng **trạng thái**.

```
   valid_in ──┬──────────────────────────────────────────────┐
              │                                              │
              │   ┌──────────────────────┐                   │
              ├──▶│ wr_ptr[1:0]  (2 FF)  │──▶ địa chỉ GHI    │
              │   │ +1 mod 4             │──▶ địa chỉ ĐỌC    │
              │   └──────────────────────┘                   │
              │                                              │
              │   ┌──────────────────────┐                   │
              └──▶│ count_q[2:0] (3 FF)  │─┬─▶ count_q < 4 ──┼──▶ CHỌN "cộng" hay
                  │ +1, BÃO HOÀ ở 4      │ │   (dòng 27)     │     "cộng−trừ"
                  └──────────────────────┘ │                 │
                                           └─▶ count_q >= 3 ─┴──▶ CHO PHÉP valid_out
                                               (dòng 56)           và nạp avg_out
```

## 2. Bảng tín hiệu điều khiển và tác dụng

### 2.1 Tín hiệu điều khiển từ ngoài

| Tín hiệu | Tác dụng | Dòng RTL |
|---|---|---:|
| `valid_in` | **Enable toàn cục.** Không có nó thì `sample_mem`, `sum_q`, `wr_ptr`, `count_q`, `avg_out` đều đứng yên | 47 |
| `rst_n` | Reset đồng bộ toàn bộ | 34–43 |

`valid_in` là tín hiệu điều khiển **quan trọng nhất** của khối: nó biến G01 từ "mạch chạy
theo clock" thành "mạch chạy theo mẫu". Toàn bộ 12 cell `mux2i_1` và phần lớn 16 cell
`a32o_1` trong netlist là hiện thân của enable này.

### 2.2 Tín hiệu điều khiển nội bộ

Chúng không có tên trong RTL (được viết dưới dạng điều kiện), nhưng phần cứng thì có:

| Tín hiệu ngầm | Biểu thức | Điều khiển cái gì | Dòng |
|---|---|---|---:|
| `win_not_full` | `count_q < 3'd4` | Chọn `sum_q + x` (chưa trừ) thay vì `sum_q + x − oldest` | 27 |
| `win_ready` | `count_q >= 3'd3` | Cho phép `valid_out <= 1` và nạp `avg_out` | 56 |
| `cnt_en` | `valid_in && (count_q < 3'd4)` | Cho phép `count_q` tăng (bão hoà) | 51 |
| `ptr_inc` | `valid_in` | `wr_ptr ← wr_ptr + 1` (mod 4, tự cuộn vì 2 bit) | 54 |
| `mem_we[wr_ptr]` | `valid_in` | Ghi `sample_in` vào đúng một ô | 48 |

### 2.3 Chi tiết tinh tế: `count_q < 4` và `count_q >= 3` dùng **cùng một** `count_q` **trước** khi tăng

```systemverilog
always_comb begin
    if (count_q < 3'd4)  sum_next = sum_q + sample_ext;            // dòng 27–28
    else                 sum_next = sum_q + sample_ext - oldest_ext;
end
...
if (count_q < 3'd4) count_q <= count_q + 3'd1;                     // dòng 51–52
...
if (count_q >= 3'd3) begin                                          // dòng 56
    valid_out <= 1'b1;
    avg_out   <= sum_next >> 2;
end
```

Cả ba điều kiện đọc **giá trị `count_q` của chu kỳ hiện tại**, tức **số mẫu đã nhận TRƯỚC
mẫu này**. Kiểm bằng tay với mẫu thứ tư: lúc đó `count_q = 3`.

* `3 < 4` ⇒ **không trừ** ⇒ `sum_next` = tổng của cả 4 mẫu ✅
* `3 >= 3` ⇒ `valid_out = 1`, `avg_out = sum_next >> 2` ✅
* `count_q ← 4`

Với mẫu thứ năm: `count_q = 4`.

* `4 < 4` sai ⇒ **có trừ**, `oldest = sample_mem[wr_ptr]` — và `wr_ptr` lúc này đã cuộn về
  0, trỏ đúng mẫu thứ nhất ✅
* `4 >= 3` ⇒ vẫn hợp lệ ✅
* `count_q` giữ nguyên 4 (bão hoà)

Ranh giới `3` và `4` khác nhau **một đơn vị** và cả hai đều đúng — đây là chỗ rất dễ viết
nhầm, và là loại lỗi mà chỉ ca **mẫu thứ 4 và thứ 5** mới bắt được (`corner_cases.md` §2).

## 3. Vì sao `count_q` phải bão hoà, không được cuộn vòng

`count_q` rộng 3 bit (0…7). Nếu không có `if (count_q < 3'd4)` ở dòng 51, nó sẽ đếm tiếp
tới 7 rồi **cuộn về 0** — và khi đó điều kiện `count_q < 4` lại đúng ⇒ mạch **ngừng trừ mẫu
cũ** ⇒ `sum_q` cộng dồn vô hạn và tràn. Bộ lọc hỏng hoàn toàn sau mẫu thứ 8.

Bão hoà tại 4 làm `count_q` trở thành một **cờ hai trạng thái có trễ**: "đang nạp đầy" /
"đã đầy". Ba flip-flop cho một thông tin 2 trạng thái là **hơi phí** — xem `tradeoff.md` §3.

## 4. `wr_ptr` vừa là địa chỉ ghi vừa là địa chỉ đọc

```systemverilog
assign oldest_ext = {{(SUM_W-W){1'b0}}, sample_mem[wr_ptr]};   // dòng 24 — ĐỌC
...
sample_mem[wr_ptr] <= sample_in;                                // dòng 48 — GHI
```

Cùng một địa chỉ, cùng một chu kỳ. Vì `oldest_ext` là tổ hợp (đọc **trước** sườn) còn phép
ghi là `<=` (có hiệu lực **sau** sườn), nên giá trị đọc được là **mẫu cũ** — đúng cái cần
trừ. Đây là thành ngữ "read-before-write" chuẩn.

Hệ quả về phần cứng, **chỉ thấy được trên netlist**: Yosys đã **nhân đôi thanh ghi địa
chỉ** để tách cổng đọc khỏi cổng ghi, tạo ra hai flip-flop `_000_`/`_001_` lái 8 cell
`mux4_2`. Bằng chứng và trích log: `block_diagram.md` §3.

## 5. Vì sao `valid_out` là bắt buộc — trả lời Charter mục 2 câu 3

> *"Trước khi đủ bốn mẫu thì đầu ra là gì, và vì sao cần cờ 'kết quả hợp lệ'?"*

**Trước khi đủ bốn mẫu, `avg_out` giữ giá trị cũ** — sau reset là `8'd0` (dòng 43). Nó
**không** phải giá trị rác, nhưng cũng **không** phải trung bình của gì cả.

Vấn đề cốt lõi: **`0` là một giá trị trung bình hoàn toàn hợp lệ.** Nếu bốn mẫu đầu đều là
`0` thì trung bình đúng bằng `0`. Không có cách nào phân biệt "chưa sẵn sàng" với "trung
bình bằng 0" **chỉ bằng cách nhìn `avg_out`**. Miền giá trị của `avg_out` là `0…255` và
**mọi giá trị đều có nghĩa** ⇒ không còn mã nào dư để làm "mã không hợp lệ".

Đây là lý do phải có **một bit riêng** báo tính hợp lệ. Cùng một lập luận áp dụng cho ba
tình huống khác:

| Tình huống | Không có `valid_out` thì sao |
|---|---|
| Ba mẫu đầu sau reset | Hiển thị `0 °C` trong khi cảm biến chưa đọc xong |
| `valid_in` ngắt quãng | Tầng hiển thị tưởng có mẫu mới, cập nhật lặp lại giá trị cũ |
| Sau reset giữa chừng | Bộ lọc phải nạp lại 4 mẫu; nếu không báo, tầng ngoài dùng số sai trong 4 nhịp |

Chi phí: **1 flip-flop** (1,7 % ô nhớ) — rẻ hơn rất nhiều so với một số hiển thị sai.

## 6. Quan hệ với tầng ngoài

| Tầng | Trách nhiệm điều khiển | Có trong hồ sơ? |
|---|---|---|
| Tầng giao tiếp ADC | Sinh **một xung `valid_in` cho mỗi mẫu mới** | ❌ ngoài phạm vi — nhưng đây là nghĩa vụ **quan trọng nhất**: giữ `valid_in` cao nhiều chu kỳ sẽ nạp trùng mẫu và G01 **không phát hiện được** |
| **G01** | Trượt cửa sổ, tích luỹ, chia, báo hợp lệ | ✅ |
| Tầng hiển thị | Chỉ cập nhật khi `valid_out = 1` | ❌ ngoài phạm vi |
| Tầng ánh xạ chân Tiny Tapeout | Nối `ui_in`/`uo_out`/`uio_*` | ❌ **CHƯA CÓ** — `functional_spec.md` cảnh báo |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
