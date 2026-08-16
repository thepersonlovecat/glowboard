# Glowboard — LED Display Simulator cho iOS

App iOS mô phỏng bảng LED (giống bản web tại https://led-monitor.junookyo.workers.dev),
build **unsigned IPA** bằng Codemagic để cài qua AltStore / Sideloadly / eSign / TrollStore.

## Tính năng

- Nhập nội dung tuỳ ý (hỗ trợ nhiều dòng, emoji)
- Hiệu ứng: **Scroll** (chữ chạy), **Static**, **Blink** (nhấp nháy), **Alternate** (luân phiên các dòng)
- **Rainbow colour cycle** — màu chuyển vòng cầu vồng
- Tốc độ (1–10) và cỡ chữ (20–100% chiều cao màn hình)
- Màu chữ + màu nền tuỳ chọn
- Kiểu panel: **Dot matrix** (chấm LED) hoặc **Neon glow** (phát sáng)
- Font: Condensed (Bebas Neue), Grotesk (Space Grotesk), Mono (DM Mono)
- Chạm vào màn hình để ẩn/hiện bảng điều khiển; giữ màn hình luôn sáng

## Cấu trúc

```
Sources/            SwiftUI source code
Resources/Fonts/    Bebas Neue, Space Grotesk, DM Mono (OFL license)
Info.plist
project.yml         Cấu hình XcodeGen (sinh Xcode project)
codemagic.yaml      Workflow build unsigned IPA trên Codemagic
```

## Build unsigned IPA với Codemagic

1. Đẩy repo này lên GitHub/GitLab/Bitbucket.
2. Vào [codemagic.io](https://codemagic.io) → **Add application** → chọn repo.
3. Chọn build bằng **codemagic.yaml** (workflow `Glowboard iOS (unsigned IPA)`).
4. Bấm **Start new build**. Không cần tài khoản Apple Developer, không cần certificate.
5. Sau khi build xong, tải artifact **`Glowboard-unsigned.ipa`**.

Workflow sẽ tự: cài XcodeGen → sinh `Glowboard.xcodeproj` → build với
`CODE_SIGNING_ALLOWED=NO` → đóng gói thành IPA.

## Cài IPA lên iPhone

- **Sideloadly** / **AltStore** / **SideStore**: ký bằng Apple ID thường (dùng 7 ngày).
- **eSign / Scarlet**: ký bằng certificate do bạn tự có.
- **TrollStore** (nếu máy hỗ trợ): cài trực tiếp không cần ký lại.

## Build local (nếu có máy Mac)

```bash
brew install xcodegen
xcodegen
open Glowboard.xcodeproj
```

## Khác biệt so với bản web

- Không có share link / đa ngôn ngữ UI (có thể thêm sau).
- Font Grotesk dùng bản Bold tĩnh thay vì variable font.
