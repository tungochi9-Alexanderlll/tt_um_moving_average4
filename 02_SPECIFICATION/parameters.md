# G01 · Tham số và cấu hình (Parameters)

---

## 1. Tham số thiết kế chốt từ Charter

| Tham số | Giá trị | Có được đổi không | Nguồn |
|---|---|---|---|
| Loại mạch | **Tuần tự** | ❌ | Charter metadata |
| Nhóm đề | G · Xử lý tín hiệu số đơn giản | ❌ | Charter metadata |
| Độ khó | Trung bình (nhẹ) | — | Charter metadata |
| Quy mô ước lượng | ~200–280 cell · 1×1 tile | — | Charter metadata |
| Top module | `g01_moving_average4` | ❌ | RTL |
| Số flip-flop mong đợi | > 0 | ❌ | Charter mục 10 |

## 2. Môi trường công cụ đã dùng để sinh bằng chứng

| Hạng mục | Giá trị |
|---|---|
| Hệ điều hành | Ubuntu 22.04 LTS (x86-64) |
| Mô phỏng | **Icarus Verilog 12.0 (stable)** (cờ `-g2012`) |
| Tổng hợp | **Yosys 0.33 (git sha1 2584903a060)** |
| STA + công suất | **OpenSTA 3.1.0** |
| Thư viện standard cell | `sky130_fd_sc_hd` |
| File Liberty | `sky130_fd_sc_hd__tt_025C_1v80.lib` |
| Góc PVT | **typical · 25 °C · 1,80 V** |
| Nguồn Liberty | OpenROAD-flow-scripts · flow/platforms/sky130hd/lib/ |
| PDK đích cho P&R | **sky130A** (chưa chạy) |
| Flow P&R đích | **LibreLane / OpenROAD** (chưa chạy) |

> ⚠️ Mọi con số cell, diện tích, timing, công suất trong hồ sơ này gắn chặt với **đúng** tổ
> hợp trên. Đổi bất kỳ thành phần nào thì số liệu đổi theo. Charter mục 6 yêu cầu nêu
> **điều kiện tạo ra bằng chứng** — bảng này chính là điều kiện đó.
>
> **Không so sánh chéo** số liệu giữa các đề nếu chúng chạy trên môi trường khác nhau.

## 3. Số liệu đo được

| Chỉ số | Giá trị | Nguồn |
|---|---:|---|
| Số cell sau tổng hợp | 260 | `06_GDSII/synthesis/synth_stat.txt` |
| Flip-flop | 58 | như trên |
| Diện tích | 2623,7664 µm² | như trên |
| Độ trễ đường tới hạn | 4,56 ns | `06_GDSII/sta/timing_report_max.txt` |
| Tổng công suất (ước lượng) | 3.28e-04 W | `06_GDSII/power/power_report.txt` |
| Tỷ lệ công suất tổ hợp | 22.7 % | như trên |
| Tỷ lệ công suất tuần tự | 77.3 % | như trên |

## 4. Cấu hình máy đọc được

Xem `04_IMPLEMENTATION/scripts/config.json`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
