# Art Bible — "Mời Bạn Ra Đây"

## 3. Định hướng hình ảnh (sẽ ghi vào `docs/ART_BIBLE.md`)

**Nguyên tắc chống "AI slop":**
1. **Mọi vật thể phải có ảnh tham khảo thật,** lưu trong thư mục `refs/` kèm nguồn. Không có ảnh tham khảo thì không dựng.
2. **Hình khối lấy từ ảnh thật, bề mặt lấy từ scan thật.**
   - Đồ đặc thù Việt Nam: mình vẽ lại profile và tỷ lệ từ ảnh thật (Wikimedia Commons, ảnh bảo tàng), rồi dựng bằng Blender Python.
   - Bề mặt dùng vật liệu PBR scan thật, như gỗ mục, men gốm, đồng xỉn, đất trộn rơm, đá ong.
   - Mỗi model có một dòng trong `refs/REFERENCES.md` ghi ảnh tham khảo đã dùng.
   - Góc nhìn của chuột rất gần vật, nên cần **texture độ phân giải cao (4K–8K)** cộng **detail normal map** (thớ gỗ, rạn men, sợi rơm).
3. **Dùng thư viện CC0 để bổ sung:** Poly Haven và ambientCG cho gỗ mục, vôi bong, gạch, đất. Sketchfab chỉ lấy model CC0 hoặc CC-BY, có ghi công.
4. **Kiểm tra license:**
   - Megascans/Fab chỉ miễn phí khi dùng trong Unreal, nên **không dùng trong Godot**.
   - Mixamo chỉ có rig người, không dùng cho mèo và chuột.
   - Model trên Poly Pizza (kéo qua Blender MCP) theo CC-BY, cần ghi công.
5. **Vật dụng phải có dấu vết sử dụng:** muội đèn trên trần quanh bàn thờ, vết ố nước trên vách, mạng nhện, bụi rơi trong tia sáng, men chum mẻ, giấy tiền vàng mã ẩm cong. Làm bằng decal và vertex paint.

**Ánh sáng (Godot 4):**
| Nguồn | Nhiệt độ màu | Thiết lập |
|---|---|---|
| Đèn dầu Hoa Kỳ | ~1800K, hổ phách | `OmniLight3D` có bóng đổ, lửa rung theo noise, kèm mesh ngọn lửa phát sáng |
| Đầu nhang | Đỏ cam | Đèn rất nhỏ không bóng đổ, cường độ nhấp nhô theo nhịp thở, tàn dần; khói hương dùng `FogVolume` cộng particles |
| Đèn tuýp | ~4000K, ngả xanh | `SpotLight3D`/vùng sáng chập chờn, tiếng rè, đôi khi tắt hẳn |
| Trăng rằm | Xanh lạnh | `DirectionalLight3D` chiếu qua kẽ liếp, kẽ ngói, kết hợp **volumetric fog** để thành tia sáng có bụi |

- **Ánh sáng tĩnh:** mỗi gian có một `VoxelGI` bake bằng CPU ngay trong container. Đèn dầu và đèn tuýp để chế độ Dynamic. Nếu sau này có máy GPU thì có thể chuyển sang `LightmapGI` cho đẹp hơn.
- **Môi trường:** ambient gần như đen, mỗi gian có `ReflectionProbe`, tonemap AgX.
- **Hậu kỳ:** film grain nhẹ, vignette, DOF vừa phải (cảm giác ống kính macro nhưng không giả mô hình thu nhỏ), quang sai màu khi tim đập nhanh.
- **Tùy chọn giảm chớp sáng** cho người nhạy cảm.

**Giải phẫu và chuyển động thật:**
- **Chuột** là chuột nhắt *Mus musculus*, **mèo** là mèo ta lông mướp. Dựng theo tỷ lệ thật, có xương rig đúng khớp (tham khảo ảnh xương thật).
- **Tham khảo chuyển động:**
  - Ảnh chụp liên tiếp của **Eadweard Muybridge** (phạm vi công cộng; có mèo đi, chạy nước kiệu, phi nước đại).
  - **Video slow-motion tự quay** mèo và chuột thật ở 120–240 fps.
  - Video nghiên cứu dáng đi của chuột trong phòng lab, chỉ để tham khảo.
- **Animation đặt tay theo tham khảo, không dùng AI.** Trong Godot ghép bằng `AnimationTree` với blend space theo tốc độ, chỉnh chân bám mặt đất bằng raycast (SkeletonModifier3D), đầu và mắt nhìn mục tiêu bằng `LookAtModifier3D`.
  - **Chuột:** đánh hơi, đi, chạy, phóng, leo, chui, nấp, run sợ, đứng hai chân, chải ria.
  - **Mèo:** ngồi chầu, đi, rình, phi, vồ, thò chân vào lỗ, đánh hơi, xoay đầu sai góc.
- **Lông:** shader shell-fur (nhiều lớp vỏ) cộng một lớp hair card ở viền. Mèo có hai phiên bản: "mèo thật" và "không còn là mèo" (shape key kéo dài cổ và chi).
- **Mắt mèo:** shader phản quang ngược, sáng lên khi hướng nhìn của camera và hướng đèn trùng nhau.

---


## 4. Pipeline tài sản

```
tools/fetch/ (polyhaven.py · ambientcg.py · sketchfab.py · freesound.py)  → tải tài sản + tự ghi dòng ASSET_LEDGER.csv
   →  tools/blender/build_*.py (dựng nhà, đồ thờ, đồ gỗ, chum bằng code; dọn mesh, UV, LOD)
   →  tools/blender/render_preview.py (ảnh xem trước từng model để mình tự kiểm tra bằng mắt)
   →  tools/blender/export_gltf.py (xuất .glb, tên vật thể theo quy ước: -col, -nav, -climb, -hide)
   →  Godot import (scale ×10, tự sinh collision từ hậu tố tên, gán vật liệu và tag âm thanh)
```
- **Quy ước hậu tố tên vật thể** để Godot tự xử lý khi import, qua script `import_postprocess.gd`:
  - `-col`: va chạm.
  - `-climb`: bề mặt leo được.
  - `-hide`: chỗ nấp.
  - `-hole`: lối chỉ chuột qua được.
  - `-snd_wood`, `-snd_straw`…: loại âm bước chân.
- **Ngân sách cho mỗi gian:** dưới 1,5 triệu tam giác hiển thị, tối đa khoảng 6 đèn động có bóng đổ trên màn hình.
- **Kiểm tra trước khi nhập:** script Blender quét lỗi tỷ lệ, normal bị ngược, thiếu UV2 cho lightmap.

---


## 5. Âm thanh (quan trọng ngang hình)

- **Nguồn:** Freesound qua API, chỉ lấy CC0/CC-BY và có ghi công. Gói Sonniss GDC rất nặng (hàng chục GB), nên chỉ tải những phần thật cần.
- **Không khí đêm:** ưu tiên bản thu thực địa ở Việt Nam hoặc Đông Nam Á: côn trùng, ếch nhái, gió, chó sủa xa, mõ và chuông chùa.
- **Tiếng vật:** cót két gỗ, sành, rơm. Mình lấy bản thu thật rồi tự dựng tiếng bằng cách cắt ghép, đổi cao độ, thêm reverb, dùng `sox` và `ffmpeg`.
- **Đồng dao, bản mặc định:** nhịp mõ hoặc song lang thật, phụ đề lời hiện theo nhịp. Khi "lỗi", nhịp chậm dần và lệch đi.
- **Đồng dao, bản nâng cấp tùy chọn:** giọng thật do bạn thu. Không dùng giọng AI.
- **Trong Godot:**
  - `AudioStreamPlayer3D` có độ suy giảm theo khoảng cách, đã tính theo `WORLD_SCALE`.
  - Mỗi gian một `Area3D` để chuyển bus reverb: gian thờ vang gỗ, hầm vang đục, gác xép khô.
  - Low-pass khi nấp, thêm chút nghẹt khi có vật chắn giữa nguồn âm và người nghe (dùng raycast).
- **Quy tắc:**
  - Im lặng là công cụ, không có nhạc nền liên tục.
  - Không có cú hù bằng âm thanh to quá −6 dBFS.

---
