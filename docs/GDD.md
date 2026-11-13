# GDD — "Mời Bạn Ra Đây"

> Tài liệu thiết kế game. Nguồn gốc: kế hoạch đã duyệt ngày 2026-11-13.

## 1. Câu chuyện & bối cảnh

**Thời gian và địa điểm:** đêm rằm tháng Bảy (tháng cô hồn), một làng Bắc Bộ bỏ hoang, khoảng cuối thập niên 1980–1990. Ngôi nhà tham chiếu làng cổ Đường Lâm: nhà ba gian hai chái, tường đá ong và vách đất trộn rơm, mái ngói mũi hài, sân gạch, có bể nước mưa. Nhà có một bóng đèn tuýp chập chờn, còn lại vẫn thắp đèn dầu Hoa Kỳ.

**Người chơi:** một con chuột nhắt. Mâm cúng cô hồn ngoài sân (cháo trắng, bỏng ngô, gạo muối) dụ nó vào nhà.

**Con mèo:** con mèo mướp của bà cụ chủ nhà, người đã mất một mình trong căn nhà này. Cốt truyện dựa trên tín ngưỡng dân gian có thật: *mèo nhảy qua người chết thì xác "quỷ nhập tràng"*. Game lật ngược niềm tin ấy: thứ bị nhập chính là con mèo, nó "không còn là mèo".
- **Nhìn gần như bình thường.** Chỉ có chi hơi dài, khớp gập trễ nhịp, đầu xoay quá góc.
- **Bóng của nó trên vách không phải bóng mèo.** Trong 3D làm được rất rẻ: một mesh thứ hai méo mó, đặt chế độ `cast_shadow = SHADOWS_ONLY`, chỉ đổ bóng và không bao giờ hiện ra. Ánh đèn dầu chiếu vào thì vách hiện hình thù khác.
- **Mắt phản quang** dưới ánh đèn. Đây là đặc điểm thật của mắt mèo (lớp tapetum lucidum), nên đáng sợ mà không cần bịa.
- **Kích thước như núi:** ở góc nhìn của chuột, con mèo cao gấp khoảng 6 lần. Chỉ cần thấy một bàn chân hay một bên ria là đủ sợ.

**Bài đồng dao làm khung chương.** Giọng trẻ con hát vọng từ ngoài sân. *Khi tiếng hát ngừng là lúc mèo săn.*
> Mèo đuổi chuột / Mời bạn ra đây / Tay nắm chặt tay / Đứng thành vòng rộng / **Chuột luồn lỗ hổng** / Chạy vội chạy mau / Mèo đuổi đằng sau / Trốn đâu cho thoát / **Thế rồi chú chuột / Lại đóng vai mèo** / Co cẳng chạy theo / Bắt mèo hú hí

Lời bài có nhiều dị bản, cần đối chiếu. Hai câu in đậm gắn thẳng vào cơ chế chơi:
- "Chuột luồn lỗ hổng" thành khả năng chui lỗ của chuột.
- "Lại đóng vai mèo" thành màn đảo vai ở cuối game.

**Kết thúc:**
- Chuột gom đủ thứ để thắp lại nén hương trên bàn thờ bà cụ: diêm, nhang và chén nước thờ.
- Hương cháy lên thì vong được yên. Con mèo trở lại làm mèo và nằm xuống cạnh ảnh thờ.
- Màn đảo vai như bài đồng dao: chuột đuổi theo con mèo đã hiền lại ra khỏi nhà.
- Kết thúc buồn và nhẹ, không giật mình rẻ tiền.

### Nguyên tắc tôn trọng tâm linh (sẽ ghi vào `docs/CULTURE_NOTES.md`)
- **Bàn thờ tổ tiên là vùng an toàn,** không bao giờ là nguồn quái vật. Bà cụ là nạn nhân và là người được giải thoát.
- **Không thể làm đổ** bát hương, ảnh thờ hay đồ cúng. Các vật này được khóa vật lý.
- **Ăn vụng mâm cúng cô hồn tạo căng thẳng** theo niềm tin "giành ăn với vong": đèn chập chờn, mèo nghe thấy. Game không chế giễu tục cúng.
- **Chữ trên đồ thờ phải chuẩn.** Hoành phi và câu đối phải là câu thật, có người đọc Hán Nôm kiểm tra. Không dùng ký tự ngẫu nhiên.
- **Không pha trộn văn hóa:** không cổng torii, không đèn lồng đỏ kiểu Trung Hoa. Chỉ dùng đồ thờ Bắc Bộ: hoành phi, câu đối, cửa võng, đỉnh đồng, hạc thờ, chân nến, mâm bồng, lọ lục bình, bát hương, ống hương, ảnh thờ.
- **Kịch bản cần được duyệt:** bạn đọc `CULTURE_NOTES.md` và kịch bản trước khi mình làm art chi tiết. Nếu có thể, nhờ thêm một người lớn tuổi trong nhà xem phần bàn thờ.

---


## 2. Gameplay

### Tỷ lệ thế giới (quyết định kỹ thuật quan trọng)
- Blender dựng theo **tỷ lệ thật tính bằng mét**. Khi nhập vào Godot, toàn bộ thế giới được **nhân 10** qua thông số scale lúc import:
  - Chuột dài khoảng 0,8 đơn vị.
  - Mèo dài khoảng 4,5 đơn vị.
  - Ngôi nhà rộng khoảng 120 đơn vị.
- Lý do: vật lý Jolt và bóng đổ hoạt động kém ổn định với vật quá nhỏ (vài centimet).
- Một hằng số duy nhất `WORLD_SCALE = 10` trong `game_state.gd` để mọi script dùng chung.

### Chuột (người chơi)
- **Điều khiển:** `CharacterBody3D`.
  - Đi, chạy, phóng nhảy.
  - **Leo bề mặt nhám:** cột gỗ, vách đất, rèm tre, dây thừng. Khi leo, hướng "lên" của chuột xoay theo pháp tuyến bề mặt.
  - Đi thăng bằng trên xà và chui qua lỗ hổng. Lỗ hổng dùng collision layer riêng mà mèo không qua được.
- **Camera:** `SpringArm3D` có va chạm, đặt sát lưng chuột, kết hợp Phantom Camera.
  - Khi vào khe hẹp, camera tự kéo sát lại.
  - Khi bị đuổi, camera hạ thấp và rung nhẹ.
  - Khi đứng yên, chuột ngẩng đầu đánh hơi và camera nhìn theo.
- **Ẩn nấp:** trong chum, gầm sập gụ, ổ rơm, sau tủ chè, kẽ ngói. Khi nấp, âm thanh bị lọc trầm (low-pass) và người chơi nghe tiếng mèo đánh hơi bên ngoài.
- **Tiếng động theo bề mặt:** mỗi vật liệu có tag âm thanh và độ ồn riêng.
  - Ồn: gỗ mục cót két, rơm khô, mảnh sành.
  - Êm: nền đất nện.
- **Độ lộ diện:** lấy mẫu ánh sáng tại vị trí chuột. Game cộng cường độ từng đèn theo khoảng cách, có raycast kiểm tra vật che. Không có thanh HUD; người chơi cảm nhận qua tiếng tim đập, viền tối màn hình co lại, ria chuột rung.
- **Tương tác:** đẩy hoặc làm rơi vật nhỏ để đánh lạc hướng mèo, kéo que diêm hay nén nhang. Vật lớn mà chuột mang sẽ làm nó chậm lại.
- **Bị bắt:** màn hình tối, vang lên một câu đồng dao, rồi chơi lại từ checkpoint. Không có máu me.

### AI con mèo (LimboAI: behavior tree + máy trạng thái)
- **Các trạng thái:** Ngồi chầu (nhìn bàn thờ khi đang có tiếng hát), Tuần tra, Điều tra tiếng động, Rình (hạ thấp người, tiến chậm), Đuổi, Lục tìm (thò chân vào lỗ, đánh hơi chỗ nấp), Mất dấu.
- **Giác quan:**
  - **Thị giác:** hình nón với nhiều raycast, nhân với độ lộ diện của chuột.
  - **Thính giác:** nhận sự kiện tiếng động, âm suy giảm khi đi qua tường.
  - **Khứu giác:** chuột để lại vệt mùi mờ dần theo thời gian.
- **Tìm đường:**
  - `NavigationRegion3D` nướng sẵn navmesh cho kích thước của mèo.
  - `NavigationLink3D` tạo các bước nhảy lên sập, tủ, gác xép.
  - Lỗ hổng tự động nằm ngoài navmesh vì quá hẹp. Mèo chỉ **thò chân vào** được qua animation riêng kết hợp kiểm tra va chạm.
- **Director** (lấy cảm hứng từ Alien: Isolation):
  - Một chỉ số "đe dọa" ngầm điều chỉnh nhịp: cho mèo bỏ đi nếu người chơi bị dồn quá lâu, kéo mèo lại gần nếu người chơi an toàn quá lâu.
  - Timeline bài đồng dao là đồng hồ công khai mà người chơi nghe được.
- **Vùng hương:** nén hương đang cháy trên bàn thờ tạo một vùng mèo không vào. Hương tàn sau khoảng 90 giây, nên người chơi phải tính đường.

### Cấu trúc màn (khoảng 15–25 phút)
| # | Khu vực | Mục tiêu | Cơ chế giới thiệu | Ánh sáng |
|---|---|---|---|---|
| 0 | Sân & mâm cúng cô hồn | Vào nhà qua khe cửa bức bàn | Di chuyển, tiếng động | Trăng rằm, nhang ngoài sân |
| 1 | Gian thờ | Tìm hộp diêm | Ẩn nấp, vùng hương | Đèn dầu, đầu nhang đỏ |
| 2 | Chái bếp & buồng | Lấy bó nhang trên gác bếp | Đuổi bắt, chui lỗ, mùi | Đèn tuýp chập chờn, tro bếp |
| 3 | Gác xép (kho thóc) | Tìm thư và ảnh bà cụ | Leo xà, bóng mèo sai hình | Tia trăng qua kẽ ngói, bụi |
| 4 | Hầm chum | Lấy chén nước thờ | Nấp trong chum, nghe để đoán vị trí | Gần như tối hẳn |
| 5 | Gian thờ (cao trào) | Thắp hương, kết thúc | Rượt đuổi, rồi đảo vai | Hương bùng sáng ấm |

Câu chuyện được kể qua môi trường, rất ít chữ: giấy báo tử, lịch treo tường xé dở, thư con cháu gửi về, ảnh thờ.

**Thiết kế lối đi tầm chuột:** mỗi gian có lối "đường chuột" chạy song song với không gian của mèo:
- Khe giữa đồ đạc và tường.
- Xà ngang, bên trong vách đất bị thủng.
- Dưới hàng chum, dọc mái hiên.

Mèo đi được ở không gian mở, còn chuột an toàn ở các đường hẹp. Đây là vòng lặp chơi cốt lõi.

---


## 7. Lộ trình

Tính cho một người làm toàn thời gian; làm bán thời gian thì nhân khoảng 2. 3D tốn công hơn 2D.

| Mốc | Thời gian | Kết quả | Điều kiện qua mốc |
|---|---|---|---|
| **M0 Tiền kỳ** | 3 tuần | GDD, Art Bible, Culture Notes, bảng ảnh tham khảo, chuyến đi scan làng cổ, khối thô cả nhà theo tỷ lệ thật | Người am hiểu văn hóa duyệt kịch bản |
| **M1 Prototype xám** | 4 tuần | Chuột di chuyển, leo, chui, nấp, camera; hệ thống tiếng động và độ lộ diện; AI mèo trên navmesh; 1 gian dựng bằng khối | 5 người chơi thử thấy căng thẳng dù chưa có art |
| **M2 Khóa pipeline art** | 5 tuần | Gian thờ hoàn chỉnh (scan, lightmap, sương thể tích); mèo và chuột đã rig, có lông, mỗi con 4 animation; bóng mèo "sai hình", mắt phản quang | Cho người xem mù ảnh chụp màn hình: không ai nghĩ là "AI" hay "asset store" |
| **M3 Nội dung** | 8–10 tuần | Đủ 6 khu vực, câu chuyện qua môi trường, đủ animation, Director, checkpoint và save | Chơi được từ đầu đến cuối |
| **M4 Âm thanh & hoàn thiện** | 4 tuần | Bản thu âm, đồng dao, reverb theo gian, hậu kỳ, tùy chọn trợ năng, phụ đề VN/EN | 60 fps ở 1080p trên GTX 1060 hoặc RX 580 |
| **M5 Thử nghiệm & demo** | 2 tuần | 10+ người chơi thử (đa số người Việt), sửa lỗi, bản build cho itch.io và Steam Next Fest | Không còn lỗi chặn tiến trình |

**Tổng thời gian:** khoảng 26–28 tuần.

**Rủi ro lớn nhất:** animation chuột chân thực (camera luôn nhìn thấy nó) và lông thú. Cách giảm rủi ro:
- Làm bộ chuyển động chuột trước tiên, ngay trong M1, bằng model tạm.
- Mèo xuất hiện chủ yếu qua bóng, bàn chân, đôi mắt và tiếng động. Như vậy vừa đáng sợ hơn, vừa ít phải animate toàn thân.

---


## Luật bổ sung (phát sinh khi làm M1)
- **Con mèo không bước qua ngưỡng cửa.** Sân là vùng an toàn để làm quen điều khiển ở đầu game. Nhưng mâm cúng cô hồn ngoài sân có luật riêng: ăn vụng thì sẽ có tiếng động.
- **Nhân vật chính là chuột nhà** (model "Street Rat" của Poly Haven, CC0), thay cho chuột nhắt.
