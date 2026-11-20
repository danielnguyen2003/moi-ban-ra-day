# Game Brief: Mời Bạn Ra Đây: Mèo Survivors

<!-- Written with the Lean Brief flow of Claude-Code-Game-Studios (brainstorm skill, template docs/templates/game-brief.md),
     chipsets: survivors-like (leads run, build, horde) + idle-incremental (leads meta economy and reset). -->

## In your words
- "Mình sẽ vào vai con mèo, mục tiêu của mình là đi bắt chuột, game sẽ thuộc dạng nâng cấp vô hạn. Ban đầu mèo thiếu kỹ năng săn mồi, chỉ bắt được 1-2 con chuột, khi bắt chuột sẽ được tiền, hoặc cá, dùng cá để nâng cấp skill cho mèo, bắt chuột nhiều hơn. Tham khảo thể loại game này ở một số tựa game như: How many dudes, pathogenic, my fire is bigger than yours,..."
- "Về đồ họa, hãy đổi sang phong cách hoạt hình, cute, không mang phong cách realistic nữa, phù hợp với mọi lứa tuổi, nhưng vẫn mang bối cảnh ma mị, u ám, kinh dị, hãy nâng cấp graphics và animation nữa, nhìn giống game đắt tiền chứ không phải game rẻ tiền. Bối cảnh làng quê Việt Nam"
- "Game chán quá, map nhỏ xíu, thời gian thì dài, chuột spawn thì ít, ít nâng cấp."
- "Game chưa đủ hấp dẫn, nội dung quá chán, bạn hãy suy nghĩ như một game developer thực thụ, tham khảo các game đi trước. Brainstorm và phát triển ý tưởng game thêm nhiều nội dung giúp tôi."
- Picked concept A: "Mèo Survivors".

**Pitch:** Một đêm rằm, một con mèo và cả làng chuột: sống sót 5 phút, gom kỹ năng thành combo, rồi hạ Chuột Chúa.

**Genre:** survivors-like + meta nâng cấp vô hạn (incremental)

**Controls:** WASD chạy, Space hoặc chuột trái để vồ, 1/2/3 hoặc click để chọn thẻ lên cấp, Esc tạm dừng.

**Question:** Chạy giữa bầy chuột đông dần, chọn thẻ và ghép tiến hóa có đủ cuốn để chơi "thêm một đêm nữa" không?

**Hooks:** Kỹ năng mang chất đồ chơi và đồ vật quê Việt (đèn ông sao, pháo đùng, nia, cuộn len, ma trơi); sự kiện "Đám cưới chuột" lấy từ tranh Đông Hồ; boss Chuột Chúa.

**Intent:** payoff builds *(provisional)*

## Look and references
- Look: 3D toon chibi, viền nét, đổ bóng 3 nấc; đêm chàm tím, ánh đèn bão ấm, ma trơi xanh; dễ thương nhưng ma mị.
- References: Vampire Survivors (thẻ lên cấp, tiến hóa), Brotato (đêm ngắn, nhân vật có vũ khí riêng), Halls of Torment (đám đông dày), My Fire Is Bigger Than Yours / How Many Dudes / Pathogenic (cảm giác tăng trưởng giữa các lượt), Cult of the Lamb (cute nhưng ma mị).
- View: 3D · Camera: góc nghiêng khoảng 40°, bám theo mèo.

## First minute
Mèo đứng giữa sân dưới trăng rằm. Vài chuột nhắt ló ra, mèo vồ là chúng rơi hạt gạo. Gom đủ gạo thì game dừng lại và hiện 3 thẻ. Người chơi chọn "Đèn ông sao", đèn xoay quanh mèo và tự quật chuột. Đến 0:45 chuột cống đầu tiên lao tới cắn, mất 1 trong 9 mạng: người chơi hiểu rằng phải vừa né vừa săn.

## Challenge
Chuột cống cắn từ khoảng 0:45. Mỗi phút chuột đông hơn, máu trâu hơn, có thêm loại mới (chù, ma). Phút 2:30 có Đám cưới chuột. Phút 5:00 boss Chuột Chúa lao húc và gọi bầy. Hết 9 mạng thì trời sáng sớm: vẫn giữ số cá đã kiếm, nhưng không qua màn.

## Core loop
- Trong đêm: chạy, vồ, gom gạo, chọn thẻ, build mạnh dần, gặp sự kiện, gặp boss.
- Hết đêm: cá khô để mua nâng cấp vĩnh viễn, mở mèo mới, mở màn mới.
- Đêm sau đi xa hơn, nhanh hơn, combo mới.

## Goal & fail state
- Thắng đêm: sống sót tới 5:00 và hạ Chuột Chúa. Thắng màn 5 là phá đảo; về sau có độ khó vô hạn.
- Thua: hết 9 mạng, đêm kết thúc, vẫn giữ cá đã kiếm.

## Features
- [ ] Đêm 5 phút, 9 mạng, chuột có máu, chuột cống cắn
- [ ] Hạt gạo (kinh nghiệm) và thẻ lên cấp: 6 vũ khí tự động, 6 thẻ chỉ số
- [ ] Đạo diễn đợt chuột theo phút, 5 loại chuột
- [ ] Boss Chuột Chúa
- [ ] Sự kiện Đám cưới chuột và rương báu
- [ ] Meta: 8 mèo (mỗi con một vũ khí khởi đầu), nâng cấp vĩnh viễn, 5 màn
- [ ] 6 công thức tiến hóa vũ khí

## Avoid
- Không realistic; không dùng nhân vật có bản quyền
- Không chế giễu tín ngưỡng (bàn thờ, mâm cúng chỉ là bối cảnh)
- Không chờ đợi, không đêm dài lê thê

## Out of scope
- Thành tựu, sổ tay sưu tập, kiếm tiền khi tắt game, bảng xếp hạng online, nhiều người chơi

## Build order
1. Đêm có mạng, chuột có máu, chuột cống cắn, thua khi hết mạng
2. Hạt gạo, thẻ lên cấp và 6 vũ khí
3. Đạo diễn đợt chuột theo phút
4. Boss Chuột Chúa
5. Đám cưới chuột và rương
6. Meta: nhân vật, nâng cấp vĩnh viễn, màn chơi
7. Tiến hóa

---
**Kill condition:** Nếu sau 2 vòng chỉnh mà đêm 5 phút vẫn thấy lặp lại, chuyển sang concept C (mèo lớn dần).

**Who it's for / what they feel:** Người thích Vampire Survivors và đồ chơi dân gian; cảm giác từ "mèo vụng" thành "mèo thần" trong một đêm.

**Games you love / don't:** How Many Dudes, Pathogenic, My Fire Is Bigger Than Yours (bạn nêu); Vampire Survivors, Brotato *(guessed)*.
