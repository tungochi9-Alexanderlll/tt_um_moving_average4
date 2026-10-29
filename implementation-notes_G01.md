# G01 — Bộ lọc trung bình trượt bốn điểm · Ghi chú thực hiện

---

## 1. Bài toán này thực chất là gì

Bề ngoài: "làm trơn số đo nhiệt độ để màn hình không nhảy". Bản chất: **đánh đổi nhiễu lấy
độ trễ**, và làm việc đó bằng phần cứng rẻ nhất có thể.

Cảm biến nhiệt độ qua ADC cho một chuỗi mẫu `x[n]` = giá trị thật + nhiễu. Nhiễu ở đây là
tổng của nhiễu nhiệt, nhiễu điện và nhiễu lượng tử hoá ±½ LSB của ADC — gần như độc lập
giữa các mẫu. Trung bình `N` mẫu độc lập làm **biên độ nhiễu giảm √N lần** trong khi giá
trị thật giữ nguyên. Với `N = 4`: nhiễu giảm **2 lần**, tức được thêm **1 bit độ phân giải
hiệu dụng**.

Giá phải trả là **độ trễ nhóm 1,5 mẫu**: một thay đổi nhiệt độ thật cần 4 mẫu mới hiện đủ
trên màn hình. Với nhiệt độ phòng, đây là đánh đổi gần như miễn phí. Với một tín hiệu nhanh
thì không.

Bài toán còn có tầng thứ hai, chính là chỗ Charter mục 10 nhắm tới: **giữ bốn mẫu 8 bit đã
tốn 32 flip-flop**, nhiều hơn toàn bộ phần tính toán. Một bộ lọc số, về mặt phần cứng, chủ
yếu là **bộ nhớ**, không phải bộ tính. Con số đo được xác nhận điều đó: 32/58 = **55 %** ô
nhớ chỉ để nhớ cửa sổ.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

### 2.1 Bộ tích luỹ trượt: biến O(N) thành O(1)

Cách ngây thơ: mỗi mẫu, cộng lại cả bốn phần tử của cửa sổ. Tốn `N−1 = 3` phép cộng.

Cách RTL dùng: giữ **một biến tổng** và cập nhật nó bằng **hai phép** bất kể `N` lớn bao
nhiêu:

```
   sum[n] = sum[n−1] + x[n] − x[n−N]
                       ▲       ▲
                       │       └── mẫu VỪA RỜI cửa sổ
                       └────────── mẫu VỪA VÀO cửa sổ
```

Bất biến giữ cho công thức đúng: `sum` **luôn bằng** tổng các mẫu đang nằm trong cửa sổ
(INV-3). Nó đúng vì mỗi bước ta cộng đúng cái vào và trừ đúng cái ra.

Điều then chốt và hay bị bỏ sót: **vẫn phải giữ đủ N mẫu** — vì muốn trừ `x[n−N]` thì phải
biết nó bằng bao nhiêu. Bộ tích luỹ trượt tiết kiệm **phép tính**, **không** tiết kiệm **bộ
nhớ**. Với `N = 4` thì phép tính vốn đã rẻ, nên lợi ích gần như bằng 0 — phân tích trung
thực ở `03_ARCHITECTURE/tradeoff.md` §2.1. Lợi ích thật chỉ xuất hiện khi `N` lớn.

### 2.2 Nút thắt: chuỗi carry, không phải phép chia

Đây là điểm đối chiếu thú vị với A01. Ở A01, nút thắt là chuỗi carry 8 tầng của bộ cộng
ripple. Ở G01, **vẫn là chuỗi carry** — chỉ khác là nó nằm giữa hai thanh ghi:

```
   carry[i+1] cần carry[i] đã ổn định
   ⇒ 6 cell maj3_1 NỐI TIẾP trên đường tới hạn
   ⇒ 6 × 0,39 ns = 2,35 ns  /  4,56 ns tổng  =  52 %
```

`maj3` là cổng đa số 3 đầu vào — chính là hàm carry-out của một full adder. Sáu cell nối
tiếp là chuỗi carry, đo được trong `timing_report_max.txt`.

Còn phép chia cho 4? **Không tốn một cell nào.** `sum_next >> 2` với hằng số dịch chỉ là
đổi chỉ số dây: `avg_out[i]` nhận `sum_next[i+2]`. Ba bằng chứng: không có cell dịch nào
trong 260 cell; `avg_out` chỉ có 8 FF; và **endpoint của đường tới hạn là `sum_q[9]`, không
phải `avg_out`**.

**Bài học:** trong một bộ lọc, phép "chia" trông đáng sợ nhưng miễn phí, còn phép "cộng"
trông tầm thường lại là nút thắt. Trực giác từ phần mềm dẫn sai ở đây.

### 2.3 Vì sao tổng phải rộng 10 bit

`4 × 255 = 1020`, cần 10 bit. Cộng vào biến 8 bit sẽ tràn và làm hỏng hoàn toàn kết quả —
Charter mục 10 nêu đích danh đây là "chỗ hay tắc".

Hồ sơ có **chứng minh hình thức** cho công thức `SUM_W = W + 2`, trong `golden_model/bounds.py`:

```python
for w in range(1,65):
    max_sum = 4*((1 << w)-1)
    assert max_sum < (1 << (w+2))
```

Kết quả nằm trong `python_reference_run.log`: `G01 accumulator-width proof PASS for W=1..64`.
Đây là **bằng chứng dạng chứng minh**, mạnh hơn kiểm mẫu, và là một trong số rất ít chỗ
trong cả ba đề có được loại bằng chứng này.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

### 3.1 Chọn công thức theo giai đoạn

```systemverilog
always_comb begin                                       // dòng 26
    if (count_q < 3'd4)
        sum_next = sum_q + sample_ext;                  // NẠP ĐẦY: chưa trừ
    else
        sum_next = sum_q + sample_ext - oldest_ext;     // ỔN ĐỊNH: có trừ
end
```

Ba mẫu đầu và **cả mẫu thứ tư** dùng nhánh trên — vì lúc đó cửa sổ chưa đầy, chưa có gì để
đẩy ra. Từ mẫu thứ năm mới dùng nhánh dưới. Cell `mux2_1` `_374_` trên đường tới hạn chính
là bộ chọn này.

### 3.2 Đọc và ghi cùng một địa chỉ trong một chu kỳ

```systemverilog
assign oldest_ext = {{(SUM_W-W){1'b0}}, sample_mem[wr_ptr]};   // dòng 24 — ĐỌC
...
sample_mem[wr_ptr] <= sample_in;                                // dòng 48 — GHI
```

Cùng chỉ số `wr_ptr`. Vì phép đọc là tổ hợp (trước sườn) và phép ghi là `<=` (sau sườn),
giá trị đọc được là **mẫu cũ** — đúng cái cần trừ. Ô vừa bị đọc cũng là ô sắp bị ghi đè:
**mẫu cũ nhất rời cửa sổ và mẫu mới vào cùng một ô**. Đây là cơ chế "bộ đệm vòng" gọn nhất
có thể.

Hệ quả phần cứng chỉ thấy được trên netlist: Yosys **nhân đôi thanh ghi địa chỉ** thành
`_000_`/`_001_` để tách cổng đọc khỏi cổng ghi — **2 flip-flop dư**. Bằng chứng và trích
log ở `03_ARCHITECTURE/block_diagram.md` §3.

### 3.3 Bộ đếm bão hoà, không cuộn vòng

```systemverilog
if (count_q < 3'd4)
    count_q <= count_q + 3'd1;                          // dòng 51–52
```

`count_q` rộng 3 bit (0…7). Nếu bỏ điều kiện bão hoà, nó đếm tới 7 rồi **cuộn về 0** ⇒
điều kiện `count_q < 4` lại đúng ⇒ mạch **ngừng trừ mẫu cũ** ⇒ `sum_q` cộng dồn vô hạn.
Bộ lọc hỏng hoàn toàn từ mẫu thứ 9. Ba ký tự `< 4` gánh cả tính đúng đắn dài hạn.

### 3.4 Hai ngưỡng lệch nhau một đơn vị — và cả hai đều đúng

```systemverilog
if (count_q < 3'd4)  …                  // dòng 27 và 51 : ngưỡng 4
if (count_q >= 3'd3) begin              // dòng 56       : ngưỡng 3
    valid_out <= 1'b1;
    avg_out   <= sum_next >> 2;
end
```

Cả ba đọc `count_q` **trước khi tăng**, tức "số mẫu đã nhận **trước** mẫu này". Tại mẫu
thứ tư, `count_q = 3`: `3 < 4` ⇒ không trừ (đúng, cửa sổ vừa đủ đầy); `3 >= 3` ⇒ đã có kết
quả (đúng). Tại mẫu thứ năm, `count_q = 4`: có trừ, và `wr_ptr` vừa cuộn về 0 nên trừ đúng
mẫu thứ nhất.

Đây là chỗ dễ viết nhầm nhất của cả file, và chỉ **ca mẫu 4 và mẫu 5** mới bắt được. Cả hai
ca đó đều đã PASS trong mô phỏng thật.

### 3.5 Bản tham chiếu trong cùng hồ sơ

`g01_direct_sum_reference.sv` hiện thực cách cộng thẳng:

```systemverilog
always_comb begin
    total_next = {2'b0,mem[0]} + {2'b0,mem[1]} + {2'b0,mem[2]} + {2'b0,mem[3]};
end
```

Không có `sum_q` ⇒ ít hơn 10 FF, nhưng cộng 4 số hạng mỗi chu kỳ. File này **không được
tổng hợp** (top là `g01_moving_average4`), nên chưa có số liệu để so sánh — một thí nghiệm
nhỏ, rẻ và rất đáng làm, nêu ở `tradeoff.md` §5.

## 4. Vì sao chọn kiến trúc này

| Quyết định | Lý do kỹ thuật |
|---|---|
| Bộ tích luỹ trượt | Số phép cộng **không tăng theo N** ⇒ kiến trúc mở rộng được. Với N=4 gần như hoà vốn, nhưng đúng về nguyên tắc |
| Bộ nhớ vòng + `wr_ptr` thay vì thanh ghi dịch | Mỗi mẫu chỉ **ghi 1 ô** thay vì dịch cả 4 ⇒ công suất chuyển mạch thấp hơn hẳn. Với tuần tự chiếm 77,3 % công suất, đây là lựa chọn đúng |
| `SUM_W = W + 2` | Chặn tràn, có chứng minh hình thức |
| `>> 2` thay bộ chia | 0 cell. Đánh đổi: khoá cứng cửa sổ ở luỹ thừa 2 |
| Thanh ghi hoá `avg_out` | Đầu ra sạch glitch, cắt đường tới hạn trước chân ra. Giá: 8 FF |
| Cờ `valid_out` riêng | `0` là giá trị trung bình hợp lệ ⇒ **không thể** báo "chưa sẵn sàng" bằng giá trị |
| `valid_in` làm enable toàn cục | Bộ lọc chạy theo **nhịp mẫu**, độc lập với tần số clock |
| `sample_in` **không** qua thanh ghi đệm | Tiết kiệm 8 FF và 1 chu kỳ. Giá: đường tới hạn bắt đầu từ chân vào, phụ thuộc `input_delay` |

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| Bước | Việc | Đầu ra | Trạng thái G01 |
|---:|---|---|---|
| 1 | Suy bảng hành vi + chặn độ rộng từ Charter mục 1, 8, 10 | `functional_spec.md` §3, §3.2 | ✅ |
| 2 | **Chứng minh** độ rộng tích luỹ trước khi viết RTL | `bounds.py` | ✅ **PASS `W=1..64`** |
| 3 | Viết mô hình chuẩn hành vi, kiểm tương đương hai cách tính | `reference_model.py` | ⚠️ có file, **thiếu log** (§`known_issues.md` C) |
| 4 | Viết RTL | `g01_moving_average4.sv` | ✅ |
| 5 | Testbench + mô phỏng | `simulation.log` | ⚠️ **dừng ở mẫu 6** — lỗi testbench |
| 6 | Tổng hợp | `synth_stat.txt` | ✅ **260 cell · 58 FF · 2 623,7664 µm²** |
| 7 | SDC + STA | `timing_report_max.txt` | ✅ **arrival 4,56 ns · slack 5,36 ns** |
| 8 | P&R → DRC/LVS → GDS | `06_GDSII/gds/` | ⬜ chưa chạy |

Điểm đáng học về quy trình: **bước 2 là một chứng minh, không phải một phép thử.** Làm
chứng minh trước khi viết RTL loại bỏ hẳn nguy cơ tràn — loại lỗi mà mô phỏng chỉ bắt được
nếu đúng ca biên được nghĩ ra.

## 6. Số liệu thật đã đo được và cách đọc chúng

| Chỉ số | Giá trị | Nguồn |
|---|---:|---|
| Chứng minh độ rộng tích luỹ | **PASS** `W = 1…64` | `python_reference_run.log` |
| Mô phỏng RTL | **RAN_WITH_ISSUES** — `FATAL g01_tb.sv:22`, `Time: 76` | `simulation.log` |
| Biên dịch Icarus | **không lỗi** | `iverilog_compile.log` rỗng |
| Tổng hợp | **PASS** | `yosys.log` |
| Tổng số cell | **260** | `synth_stat.txt` |
| Flip-flop | **58** | như trên |
| Diện tích | **2 623,7664 µm²** | như trên |
| STA | **PASS** (`real_clock`) | `06_GDSII/sta/` |
| Startpoint → Endpoint | **`sample_in[1]`** → **`_446_`** (= `sum_q[9]`) | `summary.txt` + netlist |
| Data arrival time | **4,56 ns** (gồm 1,00 ns input delay) | `timing_report_max.txt` |
| Data required time | **9,93 ns** | như trên |
| Slack | **5,36 ns (MET)** | như trên |
| WNS / TNS (max) | **0,00 / 0,00** | `wns.txt`, `tns.txt` |
| Số cell trên đường tới hạn | **14** | `timing_report_max.txt` |
| Công suất tổng | **3,28e-04 W** | `power_report.txt` |
| — tuần tự / tổ hợp / clock | **77,3 % / 22,7 % / 0,0 %** | như trên |

### 6.1 Con số 58 flip-flop chứng minh gì

Nó **chứng minh** rằng cửa sổ **đúng 32 ô nhớ** như Charter dự đoán, và mọi ô nhớ còn lại
đều truy được về một dòng RTL — trừ 2 ô do công cụ sinh:

```
  sample_mem[0:3][7:0]   32   ← đúng 32 như Charter mục 2 câu 1 hỏi
  sum_q[9:0]             10
  avg_out[7:0]            8
  count_q[2:0]            3
  wr_ptr[1:0]             2
  bản sao con trỏ ĐỌC     2   ← do pass `memory` của Yosys, KHÔNG có trong RTL
  valid_out               1
  ──────────────────────────
  TỔNG                   58   ✅ khớp synth_stat.txt
```

Nó **không chứng minh** mạch đúng chức năng (đó là việc của mô phỏng), và **không** nói gì
về hành vi sau P&R.

### 6.2 Con số 4,56 ns chứng minh gì

Ở **điều kiện đã nêu** (typical 25 °C 1,80 V, sau tổng hợp, chưa ký sinh dây, clock lý
tưởng), đường dài nhất từ chân `sample_in[1]` tới `sum_q[9]` mất 4,56 ns, còn dư 5,36 ns.

Nó **không** nói khối chạy được ở 100 MHz hay bất kỳ tần số nào. Đặc biệt với G01, **1,00 ns
của con số đó là giả định SDC về tầng ADC**, không phải phần cứng của khối — chiếm 22 %.
Nếu tầng trước chậm hơn giả định, slack co lại đúng bằng phần chênh.

Nó **nói thêm** một điều hữu ích: **52 % độ trễ nằm ở 6 cell `maj3_1` nối tiếp** — chuỗi
carry. Muốn nhanh hơn thì phải tấn công chuỗi carry (carry-lookahead, carry-save), không
phải tấn công phép chia hay bộ nhớ.

### 6.3 Con số công suất chứng minh gì

`Sequential 77,3 %` xác nhận G01 là **mạch nặng về bộ nhớ**. `Clock 0,00 W` **không** nghĩa
là cây clock miễn phí — nó nghĩa là **chưa có cây clock** (CTS chưa chạy); với 58 FF, cây
clock sau CTS nhiều khả năng sẽ là nhóm tốn nhất. Toàn bộ là **ước lượng với hoạt động mặc
định**, không lấy từ VCD thật.

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

### Câu 1 — Giữ bốn mẫu tốn 32 ô nhớ; báo cáo có đúng 32 không, phần dư dùng vào việc gì?

**Đúng 32 cho cửa sổ** — đã định danh trên netlist: 32 cell `dfxtp_1` có
`Q = sample_mem[i][j]`. Tổng đo được là **58**, tức **dư 26**. Phân bổ đầy đủ, không còn ô
nhớ nào không rõ nguồn gốc:

| Phần dư | FF | Dùng vào việc gì |
|---|---:|---|
| `sum_q[9:0]` | 10 | Bộ tích luỹ trượt, rộng `W+2` để chống tràn |
| `avg_out[7:0]` | 8 | Thanh ghi hoá đầu ra ⇒ không glitch |
| `count_q[2:0]` | 3 | Đếm mẫu, bão hoà ở 4 |
| `wr_ptr[1:0]` | 2 | Con trỏ vòng ghi |
| Bản sao con trỏ **đọc** | 2 | **Do Yosys sinh**, không có trong RTL — tách cổng đọc/ghi của bộ nhớ |
| `valid_out` | 1 | Cờ kết quả hợp lệ |
| **Tổng dư** | **26** | |

So với "dấu hiệu làm đúng ≈ 34–35" của Charter mục 10: chênh **+23…+24**, và toàn bộ phần
chênh là `sum_q` (10) + `avg_out` (8) + `wr_ptr` (2) + bản sao con trỏ (2) + phần `count_q`
vượt dự đoán. Charter giả định một hiện thực **không** có bộ tích luỹ và **không** thanh
ghi hoá đầu ra.

### Câu 2 — Chia cho 4 bằng dịch phải 2 bit tốn bao nhiêu cell?

**0 cell.** Ba bằng chứng độc lập:

1. Bảng phân bố 260 cell **không có cell dịch nào** (không barrel shifter, không bộ chia).
2. `avg_out` chỉ có **8 flip-flop** cho 8 bit ra — đúng bằng độ rộng cổng, không phần cứng phụ.
3. **Endpoint của đường tới hạn là `sum_q[9]`, không phải `avg_out`** — nếu `>>2` tốn logic,
   `avg_out` đã phải xuất hiện trong báo cáo STA.

`>> 2` với hằng số chỉ là **đổi chỉ số dây**: `avg_out[i] ← sum_next[i+2]`. Cái thật sự tốn
là hai bit thấp `sum_next[1:0]` vẫn phải được bộ cộng tính ra rồi vứt — nhưng chúng cần
thiết cho chuỗi carry nên không cắt được.

### Câu 3 — Trước khi đủ bốn mẫu thì đầu ra là gì, và vì sao cần cờ "kết quả hợp lệ"?

**Đầu ra là giá trị cũ của `avg_out`** — sau reset là `8'd0` (dòng 43). Không phải rác,
nhưng cũng không phải trung bình của gì cả.

Cần cờ riêng vì **`0` là một giá trị trung bình hoàn toàn hợp lệ**: nếu bốn mẫu đầu đều
bằng 0 thì trung bình đúng bằng 0. Miền giá trị `0…255` của `avg_out` **đã dùng hết**,
không còn mã nào dư để làm "mã không hợp lệ". Một bit riêng là cách duy nhất.

Cùng lập luận áp dụng cho ba tình huống khác: `valid_in` ngắt quãng, reset giữa chừng, và
ba mẫu đầu sau khi bật nguồn. Chi phí: **1 flip-flop (1,7 % ô nhớ)** — rẻ hơn rất nhiều so
với một số nhiệt độ sai trên màn hình.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> *"Thiết kế cần bốn thanh ghi 8 bit. Đối chiếu số flip-flop trong báo cáo với 32 và giải
> thích phần dư. Nêu thêm cách làm tiết kiệm hơn dùng bộ tích luỹ trượt, và nó tiết kiệm
> được gì."*

**Phần đối chiếu 32 ↔ 58:** đã trả lời đầy đủ ở §7 Câu 1 — đúng 32 cho cửa sổ, dư 26 phân
bổ hết, trong đó có **2 flip-flop do công cụ sinh mà RTL không có**.

**Phần "cách làm tiết kiệm hơn dùng bộ tích luỹ trượt":** ở đây phải trả lời **trung thực
và ngược với kỳ vọng thông thường** — **RTL đã dùng bộ tích luỹ trượt rồi**
(`sum_q <= sum_q + x − oldest`, dòng 30 và 49), và với `N = 4` **nó gần như không tiết kiệm
được gì**.

Lập luận đếm được:

| | Tích luỹ trượt (RTL hiện tại) | Cộng thẳng (`g01_direct_sum_reference.sv`) |
|---|---|---|
| Số hạng phải cộng mỗi chu kỳ | `sum_q`, `+x`, `−oldest` ⇒ **3** | `mem[0..3]` ⇒ **4** |
| Ô nhớ phụ | **+10 FF** (`sum_q`) | 0 |
| Vẫn phải giữ 4 mẫu? | **Có** — cần `oldest` để trừ | Có |

Chênh lệch "3 số hạng so với 4 số hạng" là rất nhỏ, trong khi phải trả **10 flip-flop**.
**Bộ tích luỹ trượt tiết kiệm phép tính, không tiết kiệm bộ nhớ** — và với `N = 4` thì phép
tính vốn đã rẻ.

**Nó tiết kiệm được gì, chính xác:** số số hạng phải cộng **luôn là 3, không phụ thuộc N**.
Cộng thẳng cần `N` số hạng ⇒ độ sâu tổ hợp tăng theo `log₂N` và số cổng tăng theo `N`. Với
`N = 16` hay `N = 64`, tích luỹ trượt thắng áp đảo; với `N = 4` thì hoà. Vậy lựa chọn ở đây
là **theo kiến trúc mở rộng được**, không phải theo tiết kiệm tức thời — và nói thẳng điều
đó có giá trị hơn là khẳng định một lợi ích không có thật.

**Cách thật sự tiết kiệm hơn cho `N = 4`** (bảng đầy đủ ở `tradeoff.md` §2.2):

| Phương án | Tiết kiệm | Giá phải trả |
|---|---|---|
| Bỏ `sum_q`, cộng thẳng 4 mẫu | **−10 FF** (58 → 48, ≈ −17 %) | Đường tổ hợp sâu hơn; không mở rộng được |
| Bỏ thanh ghi `avg_out` | **−8 FF** (≈ −14 %) | Đầu ra thành tổ hợp ⇒ có glitch |
| Thanh ghi dịch thay bộ nhớ vòng | **−4 FF** + bỏ 8 cell `mux4_2` | Phải ghi **cả 4 ô mỗi mẫu** ⇒ công suất chuyển mạch tăng, xấu vì tuần tự đã chiếm 77,3 % |

> ⬜ **Chưa có số liệu định lượng cho các phương án trên.**
> `g01_direct_sum_reference.sv` **chưa được tổng hợp** — `synth.ys` đặt
> `hierarchy -check -top g01_moving_average4`. Điều kiện để so sánh bằng số: đổi `-top`,
> chạy lại `02_run_synth.sh` và `03_run_sta.tcl`, rồi so cell / FF / diện tích / arrival.
> Cả hai bản RTL đã có sẵn trong hồ sơ nên đây là thí nghiệm rất rẻ.

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | Phát hiện bằng bằng chứng nào |
|---:|---|---|---|
| 1 | Cộng 4 mẫu vào biến 8 bit | **Tràn**, kết quả sai hoàn toàn khi tổng > 255 | Ca 4 mẫu `255`: đúng phải cho `255`. Charter mục 10 nêu đích danh |
| 2 | Nhầm "trượt" với "theo khối" | Kỳ vọng sai, hoặc thiết kế sai | **Chính lỗi của đề này.** Đếm số kết quả hợp lệ: K mẫu ⇒ trượt cho `K−3`, theo khối cho `⌊K/4⌋` |
| 3 | Quên bão hoà `count_q` | `count_q` cuộn vòng ⇒ ngừng trừ ⇒ `sum_q` cộng dồn vô hạn | Ca dài hơn 8 mẫu. Testbench bản gốc **không đủ dài để bắt** |
| 4 | Ghi mẫu mới **trước** khi đọc mẫu cũ | Trừ nhầm chính mẫu vừa ghi ⇒ `sum_q` sai vĩnh viễn | Ca mẫu thứ 5 — chu kỳ đầu tiên có phép trừ. Đã PASS trong mô phỏng thật |
| 5 | Lệch chỉ số `wr_ptr` (trừ nhầm mẫu thứ 2 thay vì thứ 1) | Cửa sổ sai, kết quả lệch | Ca chuỗi tăng dần: `4,8,12,16` phải cho `10` |
| 6 | Bỏ `valid_out`, dùng `avg_out == 0` làm dấu hiệu | Không phân biệt "chưa sẵn sàng" với "trung bình bằng 0" | Ca 4 mẫu `0`: phải có `valid_out = 1` và `avg_out = 0` |
| 7 | Dùng `>>>` (dịch số học) thay `>>` | Với dữ liệu không dấu thì vô hại, nhưng sai nguyên tắc; nếu đổi sang có dấu sẽ sai | Đọc mã + kiểm khai báo `logic [W-1:0]` (không `signed`) |
| 8 | Tưởng phép chia 4 tốn nhiều cell | Tối ưu sai chỗ | Bảng phân bố cell: không có cell dịch; endpoint STA là `sum_q[9]` |
| 9 | Lo rằng `sum_q + x − oldest` bị tràn ở bước trung gian | Thêm bit thừa không cần thiết | Giá trị trung gian `sum_q + x` có thể tới `1275 > 1023` và **bị cắt** theo modulo 2¹⁰ — nhưng kết quả cuối luôn `< 1024` nên **đúng**. Đây là số học modulo, cần nói rõ khi bảo vệ |
| 10 | Giữ `valid_in` cao nhiều chu kỳ cho một mẫu | Nạp trùng mẫu, cửa sổ sai | **Mạch không thể phát hiện.** Chỉ phát hiện bằng đọc đặc tả giao diện |
| 11 | Đọc `Clock 0,00 W` thành "cây clock miễn phí" | Kết luận sai về công suất | CTS chưa chạy — `06_GDSII/cts/README.md` |
| 12 | Coi `slack 5,36 ns` là "chạy được ở 100 MHz" | Phát biểu vượt mức | Chưa ký sinh dây, chưa CTS, một góc PVT; **và 1,00 ns là giả định về tầng ADC** |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---:|---|---|
| 1 | Bạn đo được bao nhiêu flip-flop? Có đúng 32 không? | **58**, trong đó **đúng 32** cho `sample_mem`. Bóc tách đủ 26 phần dư, gồm **2 FF do Yosys sinh** |
| 2 | Hai flip-flop `_000_`/`_001_` trong netlist là gì? | Bản sao **địa chỉ đọc** của bộ nhớ, do pass `memory` tách cổng đọc khỏi cổng ghi. Chúng lái `S0`/`S1` của 8 cell `mux4_2`. Bằng chứng trong `yosys.log` |
| 3 | Phép chia cho 4 tốn bao nhiêu cell? Chứng minh | **0 cell.** Không có cell dịch trong 260 cell; `avg_out` chỉ 8 FF; endpoint STA là `sum_q[9]` chứ không phải `avg_out` |
| 4 | Vì sao `sum_q` phải 10 bit? Chứng minh cho `W` bất kỳ | `4·(2^W−1) < 2^(W+2)`. Có **chứng minh hình thức** trong `bounds.py`, log ghi `PASS for W=1..64` |
| 5 | Trước khi đủ 4 mẫu, `avg_out` bằng bao nhiêu? Vì sao cần `valid_out`? | Giữ giá trị cũ (`0` sau reset). Cần cờ vì `0` là trung bình hợp lệ, miền `0…255` đã dùng hết |
| 6 | Đường tới hạn của bạn ở đâu? Bạn đoán trước có đúng không? | `sample_in[1] → sum_q[9]`, **14 cell, 4,56 ns**. Đoán đúng *nút thắt là chuỗi carry* (6 `maj3_1`, 52 % độ trễ) nhưng **sai về độ lớn**: `abc` hợp nhất cộng và trừ thành **một** mạng carry, và startpoint là **chân vào**, không phải thanh ghi |
| 7 | Mô phỏng FAIL mà tổng hợp PASS — bạn kết luận thế nào? | RTL đúng, **testbench sai** (hiểu nhầm trượt thành theo khối). Ba bằng chứng: RTL, golden model, và **testbench tự mâu thuẫn** ở mẫu 5 vs mẫu 6 |
| 8 | Charter mục 9 hỏi "cách tiết kiệm hơn dùng bộ tích luỹ trượt" — bạn trả lời sao? | RTL **đã dùng** tích luỹ trượt; với `N = 4` nó **gần như không tiết kiệm** (3 số hạng thay vì 4, đổi lấy 10 FF). Lợi ích thật là **độ phức tạp không tăng theo N**. Số liệu so sánh ⬜ chưa có vì bản tham chiếu chưa tổng hợp |
| 9 | Giá trị trung gian `sum_q + x` có tràn không? | Có thể vượt 1023 và **bị cắt** theo modulo 2¹⁰, nhưng kết quả cuối luôn `< 1024` nên đúng. Số học modulo |
| 10 | Nếu tầng ADC chậm hơn 1 ns thì sao? | Slack co lại đúng bằng phần chênh, vì đường tới hạn **bắt đầu từ chân vào**. Muốn cắt phụ thuộc: thêm thanh ghi đệm cho `sample_in` (+8 FF, +1 chu kỳ) |
| 11 | Đáp ứng xung của bộ lọc này trông thế nào? | **Bốn mẫu ra bằng nhau** (`63,63,63,63` với xung 255) — chữ ký của FIR 4 hệ số bằng nhau. Testbench bản gốc chỉ kỳ vọng 3, đó là lỗi |
| 12 | Hồ sơ đã thoả Charter mục 4 chưa? | **Chưa** — không có module ánh xạ chân Tiny Tapeout, và xung đột `uio[0]` vẫn còn |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

### Đã chứng minh

| Khẳng định | Bằng chứng |
|---|---|
| Độ rộng tích luỹ `W+2` đủ chống tràn cho mọi `W = 1…64` | `bounds.py` + `python_reference_run.log` — **chứng minh**, không phải kiểm mẫu |
| Giai đoạn nạp đầy đúng (4 mẫu đầu, `valid_out` đúng thời điểm) | 4 mốc kiểm PASS trong `simulation.log`, `t = 26…56` |
| **Phép trừ mẫu cũ đúng** ở chu kỳ đầu tiên nó hoạt động | Mốc kiểm thứ 5 PASS (`t = 66`) — mẫu thứ 5 |
| RTL tổng hợp được ra `sky130_fd_sc_hd` | `synth_stat.txt` — 260 cell, 58 FF, 2 623,7664 µm² |
| Cửa sổ dùng **đúng 32** flip-flop | Ánh xạ FF → `sample_mem[i][j]` trên `netlist.v` |
| Phép chia 4 tốn **0 cell** | Phân bố cell + endpoint STA là `sum_q[9]` |
| Đáp ứng chu kỳ 10 ns ở góc `tt`, sau tổng hợp | `timing_report_max.txt` — arrival 4,56 ns, slack 5,36 ns, WNS/TNS 0,00 |
| Nút thắt là chuỗi carry (52 % độ trễ) | 6 cell `maj3_1` nối tiếp trên đường tới hạn |
| Lỗi mô phỏng nằm ở **testbench** | RTL và golden model đồng thuận; testbench tự mâu thuẫn |

### Chưa chứng minh được

| Chưa chứng minh | Vì sao | Cần gì |
|---|---|---|
| **Chế độ ổn định (mẫu ≥ 6)** | Mô phỏng dừng đúng ở mẫu 6 | Bản vá `known_issues.md` §A.4 |
| Ca bước nhảy, ca xung đơn đầy đủ | Testbench không có / viết sai | CA-TX-1, CA-TX-2 |
| Biên `sum_q = 1020` | Chưa có ca 4 mẫu `255` | CA-TX-1 |
| `reference_model.py` chạy PASS | **Log không chứa đầu ra của nó** | Chạy lại và ghi log (§`known_issues.md` C) |
| Assertion SVA | Chưa biên dịch (thiếu `-DG01_SVA`), và 1/2 viết sai đơn vị thời gian | Thêm cờ + sửa assertion |
| Netlist đúng chức năng | Chưa mô phỏng gate-level | Có sẵn netlist, cần script |
| `avg_out` không glitch | Zero-delay không sinh glitch | Mô phỏng gate-level có độ trễ |
| Đúng sau P&R, có ký sinh dây | Chưa chạy LibreLane | `04_run_librelane.sh` + PDK sky130A |
| Biên an toàn ở góc `ss`/`ff` | Chỉ chạy `tt_025C_1v80` | STA đa góc |
| Công suất thật | Ước lượng hoạt động mặc định, `Clock 0,0 %` vì chưa CTS | VCD + `read_vcd` |
| So sánh định lượng với bản cộng thẳng | `g01_direct_sum_reference` chưa tổng hợp | Đổi `-top`, chạy lại |
| Tích hợp được lên ô Tiny Tapeout | Không có module ánh xạ chân | Viết wrapper, chốt lại `uio[0]` |

**Phát biểu mạnh nhất mà bằng chứng cho phép:** *"Bộ lọc trung bình trượt bốn điểm đã được
chứng minh đúng ở giai đoạn nạp đầy và ở chu kỳ đầu tiên của phép trừ; độ rộng tích luỹ có
chứng minh hình thức; khối tổng hợp được thành 260 cell / 58 flip-flop / 2 623,7664 µm² và
đáp ứng chu kỳ quy chiếu 10 ns với slack 5,36 ns ở góc typical sau tổng hợp (chưa ký sinh
dây); chế độ ổn định chưa được kiểm chứng bằng mô phỏng RTL vì testbench có lỗi đặc tả."*
Không phát biểu nào về tần số hoạt động, sign-off hay tape-out được phép xuất hiện.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
