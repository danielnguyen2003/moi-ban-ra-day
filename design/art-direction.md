# Art direction: Mèo Survivors (v4)

Method: Claude-Code-Game-Studios `.claude/genres/art-direction.md` (one direction written for this game) +
the level-designer / world-builder / technical-artist roles.

- **Mood:** đêm rằm làng quê Bắc Bộ, cute nhưng ma mị: đồ chơi dân gian phát sáng giữa màn đêm chàm tím.
- **Camera and scale:** 3D, camera nghiêng khoảng 42° bám mèo; mèo cao khoảng 1/9 màn hình; thế giới 240 × 260 đơn vị (gấp 5 lần bản cũ).
- **Shapes:** mèo tròn mềm; chuột mỗi loại một hình bóng (tai to và đuôi dài, mõm nhọn, mũ nồi và khiên, cánh dơi, bụng tròn, đèn lồng); thế giới khối tròn, mái cong, tre thẳng đứng.
- **Values:** mèo và kỹ năng sáng nhất (ánh rim, phát sáng); chuột hung hăng có mắt đỏ; nền giữ trong dải tối hẹp, chỉ đèn bão và mặt nước sáng lên.
- **Palette:** nền chàm #1a1430, đất tím nâu, cỏ xanh rêu tối; điểm nhấn ấm hổ phách (đèn), xanh ma trơi #6ff, đỏ pháo #e33. Bóng ngả tím lạnh, ánh sáng ngả cam ấm.
- **Detail:** dồn vào mèo, chuột và hiệu ứng; nền dùng mảng lớn đơn giản, chi tiết rải theo cụm quanh điểm mốc.
- **Rules:** shader toon 3 nấc, viền mực đậm cho nhân vật và đạo cụ lớn; cỏ, lúa, hoa không viền; một kiểu đổ bóng.
- **Signature:** **xác pháo giấy đỏ** bay lả tả mỗi khi Pháo đùng nổ, và **đèn ông sao** để lại vệt sáng.

## VFX budget (technical-artist)
- Mỗi khung hình tối đa 6 hiệu ứng nổ hoặc tan xác mới; phần vượt chỉ còn tia lửa nhỏ.
- Hạt dùng CPUParticles one-shot, tự hủy dưới 1,2 giây; vệt kéo dùng ImmediateMesh 12–16 điểm.
- Thực vật (cỏ, lúa, tre, hoa) vẽ bằng MultiMesh, không có va chạm.
