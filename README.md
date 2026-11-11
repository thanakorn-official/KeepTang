<div align="center">

<img src="./assets/branding/readme_banner.svg" width="100%" alt="KeepTang — บันทึกรายรับรายจ่าย" />

<br />

**บันทึกง่าย เห็นภาพเงินชัดขึ้น**

แอปจัดการรายรับรายจ่ายส่วนตัว สำหรับบันทึกรายการ ดูยอดเงิน และทบทวนการใช้จ่ายในที่เดียว

<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&amp;logo=flutter&amp;logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&amp;logo=dart&amp;logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&amp;logo=firebase&amp;logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/version-1.4.5-0A665E?style=for-the-badge" alt="Version 1.4.5" />
</p>

[ความสามารถ](#features) · [ภาพหน้าจอ](#screenshots) · [เริ่มต้นใช้งาน](#getting-started) · [เทคโนโลยี](#stack)

</div>

---

<a id="features"></a>
## ความสามารถ

| | ทำอะไรได้ | รายละเอียด |
|:---:|---|---|
| 📊 | **ดูภาพรวมการเงิน** | ดูรายรับ รายจ่าย ยอดคงเหลือ และกราฟแยกตามหมวดหมู่ |
| ✍️ | **บันทึกรายการ** | เพิ่ม แก้ไข ลบ และเรียกคืนรายการ พร้อมกำหนดวันและเวลา |
| 🧾 | **อ่านข้อมูลจากสลิป** | ดึงข้อมูลจากภาพสลิป แล้วตรวจแก้ก่อนบันทึก |
| 🔎 | **ค้นหาและกรอง** | ค้นหารายการตามหมวดหมู่ ช่องทางชำระเงิน และช่วงเวลา |
| ☑️ | **แก้ไขหลายรายการ** | เลือกหลายรายการเพื่อปรับวันเวลา หมวดหมู่ หรือช่องทางชำระเงินพร้อมกัน |
| 💳 | **จัดการบัญชี** | แยกยอดตามบัญชีและบันทึกการโอนเงินระหว่างบัญชี |
| 🎨 | **ปรับแต่งได้** | ตั้งหมวดหมู่ ไอคอน ช่องทางชำระเงิน ภาษา และธีม |
| 📤 | **ส่งออกข้อมูล** | ส่งออกรายการและรายงานเป็น CSV หรือ PDF |

<a id="screenshots"></a>
## ภาพหน้าจอ

<div align="center">
<table>
  <tr>
    <td align="center"><a href="./screenshot/Dashboard.png"><img src="./screenshot/Dashboard.png" width="250" alt="หน้า Dashboard" /></a><br /><strong>ภาพรวมการเงิน</strong></td>
    <td align="center"><a href="./screenshot/AddTransaction.png"><img src="./screenshot/AddTransaction.png" width="250" alt="หน้าเพิ่มรายการ" /></a><br /><strong>เพิ่มรายการ</strong></td>
  </tr>
  <tr>
    <td align="center"><a href="./screenshot/SlipAdd.png"><img src="./screenshot/SlipAdd.png" width="250" alt="หน้าเพิ่มรายการจากสลิป" /></a><br /><strong>เพิ่มจากสลิป</strong></td>
    <td align="center"><a href="./screenshot/Search.png"><img src="./screenshot/Search.png" width="250" alt="หน้าค้นหารายการ" /></a><br /><strong>ค้นหารายการ</strong></td>
  </tr>
</table>
</div>

<a id="getting-started"></a>
## เริ่มต้นใช้งาน

ติดตั้ง [Flutter SDK](https://docs.flutter.dev/get-started/install) และ Android SDK จากนั้นรันคำสั่งในโฟลเดอร์โปรเจกต์:

```sh
flutter pub get
flutter run
```

สร้าง APK สำหรับ Android:

```sh
flutter clean
flutter pub get
flutter build apk --release
```

ไฟล์ที่ได้อยู่ที่ `build/app/outputs/flutter-apk/app-release.apk` เวอร์ชันของแอปกำหนดไว้ใน [`pubspec.yaml`](./pubspec.yaml)

### ปรับไอคอนและโลโก้

ต้นฉบับไอคอนคือ [`app_icon.svg`](./assets/branding/app_icon.svg) (พื้นหลังโปร่งใส วงแดง เขียว ฟ้า) ส่วน [`logo.svg`](./assets/branding/logo.svg) เป็นโลโก้สีขาวที่ใช้ภายในแอปและหน้าเปิดแอป เมื่อแก้ต้นฉบับแล้วให้สร้างไฟล์ PNG และไอคอนแพลตฟอร์มใหม่:

```sh
python -m pip install -r tool/branding-requirements.txt
python tool/generate_branding.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

<a id="stack"></a>
## เทคโนโลยี

**Flutter + Dart** สำหรับแอป · **Cloud Firestore** สำหรับข้อมูล · **Google ML Kit** สำหรับอ่านข้อความจากสลิป · **FL Chart** สำหรับกราฟ · **SharedPreferences** สำหรับการตั้งค่าบนอุปกรณ์

## ข้อควรทราบเกี่ยวกับข้อมูล

โหมด Guest ใช้ ID ของอุปกรณ์และยังไม่มีระบบบัญชีสำหรับกู้คืนข้อมูลข้ามเครื่อง กฎ [Firestore Security Rules](./firestore.rules) ในโปรเจกต์ยังอนุญาตการอ่านและเขียนข้อมูลในคอลเลกชัน Guest โดยไม่ยืนยันตัวตน **โปรเจกต์นี้เหมาะสำหรับการทดลองหรือสาธิต และยังไม่ควรใช้เก็บข้อมูลการเงินจริง** จนกว่าจะเพิ่มระบบยืนยันตัวตนและปรับกฎความปลอดภัย

---

<div align="center">

พัฒนาโดย [thanakorn-official](https://github.com/thanakorn-official) · [ซอร์สโค้ด](https://github.com/thanakorn-official/KeepTang)

</div>
