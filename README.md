# PHẦN 1: CÀI ĐẶT MÔI TRƯỜNG (FLUTTER & ANDROID STUDIO)

### Bước 1: Tải và Cài đặt Flutter SDK

1.  **Tải về:** Truy cập [trang chủ Flutter](https://flutter.dev/) và tải file `.zip` bản Stable mới nhất.
2.  **Giải nén:**
    * Giải nén file zip vào một thư mục dễ nhớ (Ví dụ: `C:\src\flutter`).
    * > ⚠️ **Lưu ý:** Không giải nén vào `C:\Program Files` (vì sẽ bị lỗi quyền Admin).
3.  **Cấu hình biến môi trường (PATH):**
    * Gõ vào thanh tìm kiếm Windows: **"Edit the system environment variables"** -\> Enter.
    * Bấm nút **Environment Variables**.
    * Trong mục **User variables** (khung trên), tìm dòng `Path` -\> Bấm **Edit**.
    * Bấm **New** -\> Dán đường dẫn thư mục `bin` của Flutter vào (Ví dụ: `C:\src\flutter\bin`).
    * Bấm **OK** liên tục để lưu.

### Bước 2: Cài đặt Android Studio

Android Studio cung cấp các công cụ SDK cần thiết để biên dịch app cho Android.

1.  **Tải về:** Vào trang chủ Android Studio tải bản mới nhất.
2.  **Cài đặt:** Chạy file `.exe`. Bấm **Next** liên tục (giữ nguyên các tùy chọn mặc định như Android Virtual Device).
3.  **Cấu hình lần đầu (Quan trọng):**
    * Mở Android Studio lên.
    * Vào **More Actions** (dấu 3 chấm) \> **SDK Manager**.
    * Tab **SDK Platforms**: Chọn **Android 13** hoặc **14** (API 33/34).
    * Tab **SDK Tools** (Quan trọng): Tích chọn thêm mục **Android SDK Command-line Tools (latest)**.
    * Bấm **Apply** để nó tải về.

### Bước 3: Kiểm tra và Đồng ý Giấy phép

Mở CMD hoặc PowerShell và chạy lệnh kiểm tra sức khỏe hệ thống:

```bash
flutter doctor
```

Nếu nó báo thiếu Android toolchain, hãy chạy lệnh sau để đồng ý điều khoản:

```bash
flutter doctor --android-licenses
```

*(Gõ `y` và `Enter` liên tục cho đến hết).*

-----

# PHẦN 2: CÀI ĐẶT DỰ ÁN (UMT.FreeFireFlies-frontend)

Sau khi môi trường đã xanh (các dấu tích V trong `flutter doctor`), giờ ta cài dự án.

### Bước 1: Clone Code về máy

Mở CMD/Terminal tại thư mục bạn muốn lưu code:

```bash
git clone https://github.com/tannguyen1129/UMT.FreeFireFlies-frontend.git
cd UMT.FreeFireFlies-frontend
```

*(Lưu ý: Nếu code nằm trong thư mục con, hãy `cd` vào đúng thư mục có file `pubspec.yaml`).*

### Bước 2: Tải thư viện

```bash
flutter pub get
```

### Bước 3: Tạo file cấu hình môi trường (.env) ⚠️ QUAN TRỌNG

Dự án này cần biết Backend nằm ở đâu.

1.  Trong thư mục gốc dự án (ngang hàng với `pubspec.yaml`), tạo file tên là `.env`.
2.  Dán nội dung sau (Chọn 1 trong 2 tùy cách bạn chạy):

**Cách A: Dùng Máy ảo (Emulator) Android:**

```env
# 10.0.2.2 là localhost của máy tính khi nhìn từ Emulator
API_BASE_URL=http://10.0.2.2:3000
TIMEOUT_SECONDS=60
```

**Cách B: Dùng Điện thoại thật (Cắm cáp):**

```env
# Thay 192.168.1.X bằng IP máy tính của bạn (xem bằng lệnh ipconfig)
API_BASE_URL=http://192.168.1.5:3000
TIMEOUT_SECONDS=60
```

### Bước 4: Thêm file google-services.json (Bắt buộc)

Do dự án dùng Firebase, nếu thiếu file này app sẽ bị Crash ngay khi mở.

1.  Vào Firebase Console, tạo một dự án mới (hoặc dùng dự án có sẵn).
2.  Thêm ứng dụng Android với package name: `com.example.frontend_citizen` (Kiểm tra file `android/app/build.gradle` để biết package name chính xác).
3.  Tải file `google-services.json` về.
4.  Copy file đó vào thư mục: `android/app/`.

-----

# PHẦN 3: CHẠY ỨNG DỤNG

### Cách 1: Chạy trên Android Emulator (Máy ảo)

1.  Mở Android Studio.
2.  Vào **Device Manager** -\> **Create Device**.
3.  Chọn một máy (ví dụ Pixel 7) -\> **Next** -\> Chọn hệ điều hành (ví dụ Android 13 Tiramisu) -\> **Finish**.
4.  Bấm nút **Play** (▶) để bật máy ảo lên.
5.  **Quan trọng:** Làm theo hướng dẫn ở bài trước để chỉnh GPS máy ảo về TP.HCM (`10.7769`, `106.7009`).
6.  Quay lại Terminal dự án, gõ:

<!-- end list -->

```bash
flutter run
```

### Cách 2: Chạy trên Điện thoại thật (Khuyên dùng)

1.  Bật chế độ **USB Debugging** (Gỡ lỗi USB) trên điện thoại.
2.  Cắm cáp vào máy tính.
3.  Chạy lệnh:

<!-- end list -->

```bash
flutter run
```

-----

# ❓ XỬ LÝ LỖI THƯỜNG GẶP

**Lỗi: SDK location not found:**

* Mở file `android/local.properties` (nếu chưa có thì tạo mới).
* Thêm dòng: `sdk.dir=C:\\Users\\TEN_USER\\AppData\\Local\\Android\\Sdk` (Thay `TEN_USER` bằng tên máy bạn).

**Lỗi kết nối Backend (Connection Refused):**

* Kiểm tra xem Docker Backend đã chạy chưa (`sudo docker ps`).
* Kiểm tra xem file `.env` đã đúng IP chưa.
* Tắt tường lửa Windows (Firewall) nếu dùng điện thoại thật.

**Chúc bạn cài đặt thành công\!**