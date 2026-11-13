# Mời Bạn Ra Đây

Game 3D kinh dị dân gian Việt Nam, lấy cảm hứng từ trò chơi "Mèo đuổi chuột". Bối cảnh là đêm rằm tháng Bảy, trong một nhà cổ Bắc Bộ. Bạn là con chuột; con mèo của bà cụ quá cố thì *không còn là mèo* nữa.

> Đây là **bản thử M1, dựng bằng khối xám**. Hình khối còn tạm, riêng chuột và mèo đã dùng model thật.

## Cách chơi (M1)
| Phím | Hành động |
|---|---|
| W A S D | Di chuyển (theo hướng camera) |
| Chuột máy tính | Xoay camera |
| Shift | Chạy (ồn hơn) |
| Space | Nhảy / bật khỏi tường khi đang leo |
| E | Nhặt hoặc đặt đồ |
| F3 | Hiện FPS |
| Esc | Thả hoặc khóa con trỏ chuột |

Mục tiêu M1: lẻn vào gian thờ, lấy **hộp diêm trên nóc tủ chè**, rồi mang tới **bát hương trên bàn thờ**.

Một vài mẹo:
- **Leo:** đi thẳng vào cột gỗ, chân sập, mặt tủ chè hoặc sợi dây thừng là leo lên được.
- **Nấp:** đứng yên dưới gầm sập, sau hàng chum hoặc trong ổ rơm. Ổ rơm nông, mèo lục lâu sẽ thò được chân vào.
- **Lỗ chuột:** vách đất bên trái có hai lỗ dẫn vào một khe giữa hai lớp tường. Mèo không vào được.
- **Tiếng đồng dao:** khi tiếng hát vang lên (có phụ đề), mèo ngồi chầu trước bàn thờ. Khi tiếng hát dứt, mèo bắt đầu đi săn.
- **Tiếng động:** mảnh sành gần cửa và ổ rơm rất ồn, còn đi trên đất thì êm.

## Cho người phát triển
- Engine: Godot 4.7 (Forward+, Jolt). Mở `project.godot`.
- Chạy test: `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Kiểm tra license tài sản: `python3 tools/check_ledger.py`
- Tài liệu thiết kế: `docs/GDD.md`, `docs/ART_BIBLE.md`, `docs/CULTURE_NOTES.md` (có danh sách mục **cần người Việt xác nhận**).
- Nguồn và license của tài sản: `docs/ASSET_LEDGER.csv`.
