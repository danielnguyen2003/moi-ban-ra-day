# GDD v2: "Mời Bạn Ra Đây": mèo săn chuột, nâng cấp vô hạn

> Bản này thay hướng cũ theo góp ý ngày 2026-11-13. Prototype kinh dị chân thực (M1) được cất vào `prototype_m1/` và không còn nằm trong bản build.

## 1. Tóm tắt
- **Người chơi là mèo.** Mỗi **đêm săn** kéo dài 30 giây (nâng cấp để dài thêm). Chạy và vồ chuột trong làng quê Việt Nam vào đêm rằm tháng Bảy.
- **Bắt chuột được cá khô.** Hết đêm thì mở màn **nâng cấp**: tiêu cá để mèo nhanh hơn, vồ xa hơn, móng rộng hơn, đêm dài hơn, chuột ra nhiều hơn, có thêm mèo con săn giúp…
- **Vòng lặp vô hạn**, theo kiểu *My Fire Is Bigger Than Yours*, *How Many Dudes*, *Pathogenic*:
  - Đêm đầu chỉ bắt được 1–2 con.
  - Về sau mỗi đêm hàng trăm con, con số tăng theo cấp số nhân, bản đồ nở rộng dần.
- **Chín kiếp mèo** (prestige): khi đủ mạnh, mèo "đầu thai". Mọi nâng cấp về 0, đổi lại được **Hồn mèo**, mỗi hồn cộng hệ số cá vĩnh viễn.

## 2. Phong cách
- **Hình:** 3D hoạt hình toon chibi, cute, hợp mọi lứa tuổi; đổ bóng 3 nấc, viền nét, ánh rim.
- **Không khí:** đêm ma mị nhưng không đáng sợ quá mức.
  - Màu chủ đạo: chàm và tím xanh, sương đêm.
  - Điểm sáng: đèn lồng và đèn dầu ấm, trăng rằm.
  - Hiệu ứng: ma trơi xanh lơ lửng, đom đóm.
- **Bối cảnh làng quê Bắc Bộ**, mở rộng dần theo vùng:
  1. Sân gạch và hiên nhà.
  2. Gian thờ và bếp.
  3. Vườn chuối và lũy tre.
  4. Ao làng và giếng.
  5. Đình làng và cây đa.
  6. Bãi tha ma (khu ma mị nhất, chuột ma).
- **Tôn trọng tâm linh:**
  - Bàn thờ và mâm cúng chỉ là bối cảnh, không bị phá.
  - Ma trơi và chuột ma là sinh vật cute, không chế giễu tín ngưỡng.
- **Cảm giác game đắt tiền đến từ độ "juice":**
  - Co giãn khi vồ, rung màn hình nhẹ.
  - Hạt bụi và cá bay lên khi bắt chuột, số bật ra.
  - Âm thanh "pop".
  - Giao diện bo tròn, chữ tiếng Việt đẹp (Be Vietnam Pro).
- **Nhân vật và cảnh** do Claude tự thiết kế bằng code (không dùng AI tạo hình), nên thống nhất phong cách và không vướng bản quyền.

## 3. Điều khiển (PC)
| Phím | Hành động |
|---|---|
| WASD / phím mũi tên | Chạy |
| Space / chuột trái | Vồ: lao nhanh về phía trước |
| Esc | Tạm dừng |
| F9 | Cập nhật |
| − / = | Độ sáng |

## 4. Chuột
| Loại | Mở khi | Cá | Tính cách |
|---|---|---|---|
| Chuột nhắt | Từ đầu | 1 | Chạy tán loạn |
| Chuột cống | Vùng 2 | 4 | To, chậm, cần vồ 2 lần |
| Chuột vàng | Nâng cấp "May mắn" | 25 | Hiếm, chạy rất nhanh |
| Chuột ma | Vùng 6 | 60 | Xuyên tường, chập chờn |

## 5. Nâng cấp (giá tăng theo cấp số nhân, không giới hạn cấp)
| Nâng cấp | Hiệu ứng |
|---|---|
| Chân nhanh | Tốc độ chạy +8%/cấp |
| Móng sắc | Bán kính bắt +10%/cấp |
| Vồ xa | Quãng vồ +12%/cấp, hồi vồ nhanh hơn |
| Đêm dài | +3 giây/cấp |
| Ổ chuột | Chuột sinh ra nhanh hơn +15%/cấp |
| Bội thu | Cá nhận được ×1.15/cấp |
| May mắn | Tỉ lệ chuột vàng |
| Mèo con | Thêm 1 mèo con tự săn/cấp |
| Râu nhạy | Thấy chuột trong bóng tối, nam châm hút chuột |
| Mở vùng | Mở rộng bản đồ sang vùng kế tiếp |

## 6. Vòng lặp một đêm
1. Màn hình làng hiện ra, bắt đầu đếm ngược.
2. Mèo săn chuột; mỗi con bắt được cộng cá và tăng combo.
3. Hết giờ thì hiện màn tổng kết (bắt được bao nhiêu con, được bao nhiêu cá, kỷ lục).
4. Sang màn nâng cấp, rồi bấm "Đêm tiếp theo".

## 7. Kỹ thuật
- Godot 4.7, giữ cơ chế cập nhật F9.
- **Chuột vẽ bằng MultiMesh** (hàng trăm con vẫn nhẹ), di chuyển kiểu bầy đàn bằng GDScript, không dùng vật lý.
- **Logic tách khỏi giao diện** để viết test: `upgrades.gd`, `economy.gd`, `bignum.gd`.
- **Lưu tiến trình** vào `user://save.json`.
