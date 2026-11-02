<div align="center">

<img src="assets/logo.png" alt="โลโก้ KeepTang" width="128" />

# เก็บตัง · KeepTang

**จดรายรับรายจ่ายให้เป็นเรื่องง่าย แล้วมองเห็นภาพการเงินของตัวเองชัดขึ้น**

แอปจัดการการเงินส่วนบุคคลที่เริ่มใช้ได้ทันที ไม่ต้องสมัครสมาชิก

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)

</div>

---

## เกี่ยวกับโปรเจกต์

KeepTang (เก็บตัง) เป็นแอปบันทึกรายรับและรายจ่ายที่พัฒนาด้วย Flutter โปรเจกต์นี้ตั้งใจทำให้การจดบันทึกประจำวันไม่ยุ่งยาก: เปิดแอป ตั้งชื่อที่ใช้แสดงผล แล้วเริ่มบันทึกรายการได้เลย โดยไม่ต้องสร้างบัญชี

ข้อมูลรายการจัดเก็บใน Cloud Firestore ส่วนการตั้งค่าที่ใช้ในแอป เช่น ภาษาและธีม บันทึกไว้ในอุปกรณ์

## จุดเด่น

- 💸 เพิ่ม แก้ไข และลบรายการรายรับ–รายจ่าย พร้อมยกเลิกการลบ
- 📊 ดูสรุปและกราฟค่าใช้จ่ายแยกตามหมวดหมู่
- 🔎 ค้นภาพรวมรายการด้วยตัวกรองช่วงเวลา ประเภทรายการ และช่องทางชำระเงิน
- 🎨 สร้างหมวดหมู่และช่องทางชำระเงิน พร้อมเลือกไอคอนและสี
- 🆔 ใช้งานแบบ Guest โดยมี ID แยกตามอุปกรณ์ และเปลี่ยนชื่อแสดงผลได้
- 🌐 สลับภาษาไทยและอังกฤษ พร้อมเลือกธีมสว่างหรือมืด
- 📤 ส่งออกรายการเป็น CSV และเอกสาร PDF

## เทคโนโลยีและแนวทางที่ใช้

| เทคโนโลยี | บทบาทในโปรเจกต์ |
|---|---|
| Flutter / Dart | สร้างหน้าจอและแอปสำหรับหลายแพลตฟอร์ม |
| Firebase Core | เริ่มต้นการเชื่อมต่อ Firebase |
| Cloud Firestore | จัดเก็บรายการรายรับ–รายจ่าย |
| SharedPreferences | จดจำการตั้งค่าภายในอุปกรณ์ |
| FL Chart | แสดงกราฟสรุปค่าใช้จ่าย |
| CSV / PDF | สร้างไฟล์ส่งออกข้อมูล |

โค้ดปัจจุบันแยกตามหน้าที่ เพื่อให้ค้นหาและแก้ไขส่วนต่าง ๆ ได้สะดวก:

```text
lib/
├── main.dart                    # จุดเริ่มต้นและตั้งค่าแอป
├── firebase_options.dart        # สร้างในเครื่องด้วย FlutterFire CLI
├── models/
│   └── transaction_model.dart   # แบบจำลองรายการ
├── screens/                     # หน้าจอหลักและหน้าตั้งค่า
├── services/                    # Guest, ส่งออกข้อมูล และรายงานภาษี
└── utils/                       # ธีมและข้อความสองภาษา

assets/                          # โลโก้และทรัพยากรภาพ
firestore.rules                  # กฎ Firestore
```

## เริ่มต้นใช้งาน

### เตรียมเครื่องมือ

- ติดตั้ง [Flutter SDK](https://docs.flutter.dev/get-started/install) ที่รองรับ Dart 3
- สร้าง Firebase project และเปิดใช้ Cloud Firestore
- ติดตั้ง FlutterFire CLI

### ติดตั้งและรันแอป

```bash
git clone https://github.com/thanakorn-official/KeepTang.git
cd KeepTang
flutter pub get

dart pub global activate flutterfire_cli
flutterfire configure

flutter run
```

ในขั้นตอน `flutterfire configure` ให้เลือกแพลตฟอร์มที่ต้องการใช้งาน คำสั่งจะสร้างไฟล์ Firebase config ในเครื่อง ซึ่งไม่ได้เก็บไว้ใน Git จากนั้นตรวจสอบว่า Firebase project เปิดใช้ Cloud Firestore แล้ว

### สร้างไฟล์แอป

```bash
flutter build apk --release
flutter build web
```

## หมายเหตุเรื่องข้อมูล

Guest ID ถูกเก็บไว้ในอุปกรณ์ ขณะนี้แอปไม่มีระบบบัญชีสำหรับกู้คืนข้อมูลข้ามอุปกรณ์ การล้างข้อมูลแอปหรือเปลี่ยนอุปกรณ์จึงอาจทำให้เข้าถึงข้อมูลเดิมไม่ได้

ไฟล์ `firestore.rules` ในโปรเจกต์นี้เปิดสิทธิ์อ่านและเขียนสำหรับการทำงานแบบ Guest โดยไม่มีการยืนยันตัวตน ควรใช้เพื่อการทดลองเท่านั้น และต้องออกแบบระบบยืนยันตัวตนพร้อมปรับกฎก่อนใช้กับข้อมูลจริงหรือเผยแพร่บริการสู่สาธารณะ

---

<div align="center">

ทำด้วย Flutter และความตั้งใจอยากให้การจดเงินเป็นเรื่องง่าย 💙

</div>
