<div align="center">

<img src="assets/logo.png" alt="โลโก้ KeepTang" width="112" />

# 💰 เก็บตัง | KeepTang

**แอปบันทึกรายรับ–รายจ่ายส่วนบุคคล ใช้งานง่าย เริ่มต้นได้โดยไม่ต้องสมัครบัญชี**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Version](https://img.shields.io/badge/version-1.3.0-4C8BF5)](pubspec.yaml)
[![License](https://img.shields.io/badge/license-not%20specified-lightgrey)](#)

</div>

---

## 📖 เกี่ยวกับ KeepTang

KeepTang เป็นแอปจัดการการเงินส่วนบุคคล พัฒนาด้วย Flutter และใช้ Cloud Firestore จัดเก็บรายการ ผู้ใช้เริ่มต้นใช้งานด้วย Guest ID ประจำอุปกรณ์ โดยไม่ต้องสร้างบัญชีหรือเข้าสู่ระบบ

## ✨ ฟีเจอร์

- 💵 บันทึก แก้ไข และลบรายการรายรับ–รายจ่าย พร้อมยกเลิกการลบได้
- 📊 ดูสรุปและกราฟค่าใช้จ่ายแยกตามหมวดหมู่
- 🗓️ จัดกลุ่มและกรองรายการตามช่วงเวลา ประเภท และช่องทางชำระเงิน
- 🏷️ ปรับแต่งหมวดหมู่และช่องทางชำระเงิน พร้อมไอคอนและสี
- 🆔 ใช้งานแบบ Guest พร้อมชื่อแสดงผลที่แก้ไขได้
- 🌐 รองรับภาษาไทยและภาษาอังกฤษ
- 🌗 เลือกธีมสว่างหรือธีมมืด
- 📄 ส่งออกข้อมูลเป็น CSV และ PDF

## 🧰 เทคโนโลยี

| เทคโนโลยี | การใช้งาน |
|---|---|
| Flutter และ Dart | พัฒนาแอปหลายแพลตฟอร์ม |
| Firebase Core | เริ่มต้นการเชื่อมต่อ Firebase |
| Cloud Firestore | จัดเก็บและซิงค์ข้อมูลรายการ |
| SharedPreferences | บันทึกการตั้งค่าบนอุปกรณ์ |
| FL Chart | แสดงกราฟสรุปค่าใช้จ่าย |
| CSV และ PDF | ส่งออกข้อมูล |

## 🗂️ โครงสร้างโปรเจกต์

โครงสร้างปัจจุบันแยกหน้าจอ โมเดล บริการ และส่วนช่วยใช้งานออกจากกัน เหมาะกับขนาดโปรเจกต์ในตอนนี้:

```text
KeepTang/
├── android/                  # ไฟล์โปรเจกต์ Android
├── ios/                      # ไฟล์โปรเจกต์ iOS
├── assets/                   # โลโก้และทรัพยากรของแอป
├── lib/
│   ├── main.dart             # จุดเริ่มต้นและตั้งค่าแอป
│   ├── firebase_options.dart # การตั้งค่า Firebase ที่สร้างด้วย FlutterFire
│   ├── models/               # แบบจำลองข้อมูล
│   ├── screens/              # หน้าจอของแอป
│   ├── services/             # งาน Firestore, Guest และส่งออกข้อมูล
│   └── utils/                # ธีมและคำแปล
├── firestore.rules           # กฎการเข้าถึง Cloud Firestore
├── pubspec.yaml              # Dependencies และการตั้งค่า Flutter
└── README.md
```

เมื่อฟีเจอร์เพิ่มขึ้น แนะนำให้จัดกลุ่มโค้ดตามฟีเจอร์เพื่อให้ดูแลและทดสอบง่ายขึ้น เช่น:

```text
lib/
├── app/                      # แอปหลัก, routing และธีม
├── core/                     # ส่วนกลาง เช่น localization และส่วนประกอบร่วม
├── features/
│   ├── dashboard/            # หน้าหลักและสรุปยอด
│   ├── transactions/         # รายการและแบบฟอร์มธุรกรรม
│   ├── settings/             # การตั้งค่า
│   └── tax_export/           # ส่งออกรายงานภาษี
├── data/                     # แหล่งข้อมูลและการเชื่อมต่อ Firebase
└── main.dart
```

ภายในแต่ละฟีเจอร์สามารถแยก `models/`, `services/` หรือ `widgets/` เมื่อมีโค้ดมากพอ โดยค่อยย้ายจากโครงสร้างปัจจุบันตามความจำเป็น

## 🚀 เริ่มต้นใช้งาน

### สิ่งที่ต้องมี

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ที่รองรับ Dart SDK 3
- โปรเจกต์ Firebase ที่เปิดใช้ Cloud Firestore
- FlutterFire CLI สำหรับสร้างการตั้งค่าแพลตฟอร์ม

### ติดตั้งและรัน

```bash
git clone https://github.com/thanakorn-official/KeepTang.git
cd KeepTang
flutter pub get

# เชื่อมแอปกับ Firebase ของคุณ และสร้าง/อัปเดต lib/firebase_options.dart
dart pub global activate flutterfire_cli
flutterfire configure

flutter run
```

เลือกแพลตฟอร์มที่ต้องการในขั้นตอน `flutterfire configure` คำสั่งนี้จะสร้างไฟล์ตั้งค่า Firebase ในเครื่อง ซึ่งไม่ได้เก็บไว้ใน Git เพื่อให้แต่ละคนใช้ Firebase project ของตนเอง ตรวจสอบว่าเปิดใช้ Cloud Firestore แล้วก่อนรันแอป

### ติดตั้งกฎ Firestore

ติดตั้ง Firebase CLI และเลือกโปรเจกต์ Firebase ก่อน จากนั้นใช้คำสั่ง:

```bash
firebase deploy --only firestore:rules
```

### สร้างไฟล์สำหรับเผยแพร่

```bash
flutter build apk --release
flutter build web
```

> **หมายเหตุ:** ระบบ Guest ใช้ Guest ID ที่เก็บไว้ในอุปกรณ์ การล้างข้อมูลแอปหรือเปลี่ยนอุปกรณ์อาจทำให้ไม่สามารถเข้าถึงข้อมูลเดิมได้ โปรดตรวจสอบและกำหนด Firestore Security Rules ให้เหมาะกับการใช้งานจริงก่อนนำขึ้น Production

---

<div align="center">

สร้างด้วย Flutter 💙

</div>
