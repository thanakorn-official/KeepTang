# 💚 KeepTang

<p align="center">
  <img src="https://img.shields.io/badge/KeepTang-Personal%20Finance-16A34A?style=flat-square" alt="KeepTang Personal Finance" />
  <img src="https://img.shields.io/badge/Status-Development-blue?style=flat-square" alt="Development status" />
  <img src="https://img.shields.io/badge/Version-1.4.5-0A665E?style=flat-square" alt="Version 1.4.5" />
</p>

<p align="center">
  แอปพลิเคชันสำหรับบันทึกรายรับและรายจ่ายส่วนบุคคล<br />
  ช่วยให้การจัดการเงินในแต่ละวันเป็นเรื่องง่ายขึ้น
</p>

---

## 📌 About

KeepTang เป็นแอปบันทึกรายรับรายจ่ายที่ช่วยติดตามเงินในชีวิตประจำวัน ดูรายการย้อนหลัง ยอดคงเหลือ และภาพรวมการใช้จ่าย แยกข้อมูลตามบัญชี หมวดหมู่ และช่องทางชำระเงินได้

แอปอยู่ระหว่างพัฒนา โหมด Guest ยังไม่มีบัญชีสำหรับกู้คืนข้อมูลข้ามเครื่อง และ [กฎ Firestore](./firestore.rules) ยังเปิดให้เข้าถึงข้อมูล Guest โดยไม่ยืนยันตัวตน จึงเหมาะสำหรับการทดลองหรือสาธิตมากกว่าการเก็บข้อมูลการเงินจริง

## ✨ Features

- 💰 บันทึกรายรับและรายจ่าย พร้อมกำหนดวันและเวลา
- 📊 ดูยอดคงเหลือและกราฟสรุปแยกตามหมวดหมู่
- 📅 ค้นหา กรอง และดูประวัติรายการย้อนหลัง
- 🧾 อ่านข้อมูลจากภาพสลิป แล้วตรวจแก้ก่อนบันทึก
- 💳 แยกยอดตามบัญชีและบันทึกการโอนเงินระหว่างบัญชี
- 🗂️ จัดการหมวดหมู่ ไอคอน และช่องทางชำระเงิน
- 📤 ส่งออกข้อมูลเป็น CSV และรายงาน PDF
- 🌗 เลือกธีมสว่างหรือมืด และภาษาไทยหรืออังกฤษ

## 🖥️ Screenshots

<p align="center"><i>Application Preview</i></p>

<div align="center">
<table>
  <tr>
    <td align="center"><a href="./screenshot/Dashboard.png"><img src="./screenshot/Dashboard.png" width="250" alt="หน้า Dashboard" /></a><br /><strong>Dashboard</strong></td>
    <td align="center"><a href="./screenshot/AddTransaction.png"><img src="./screenshot/AddTransaction.png" width="250" alt="หน้าเพิ่มรายการ" /></a><br /><strong>เพิ่มรายการ</strong></td>
  </tr>
  <tr>
    <td align="center"><a href="./screenshot/SlipAdd.png"><img src="./screenshot/SlipAdd.png" width="250" alt="หน้าเพิ่มรายการจากสลิป" /></a><br /><strong>เพิ่มจากสลิป</strong></td>
    <td align="center"><a href="./screenshot/Search.png"><img src="./screenshot/Search.png" width="250" alt="หน้าค้นหารายการ" /></a><br /><strong>ค้นหารายการ</strong></td>
  </tr>
</table>
</div>

## 🛠️ Tech Stack

- **Frontend:** Flutter และ Dart
- **Backend / Database:** Firebase Cloud Firestore
- **อ่านข้อความจากสลิป:** Google ML Kit Text Recognition
- **กราฟ:** FL Chart
- **การตั้งค่าในเครื่อง:** SharedPreferences

## 📂 Project Structure

```text
KeepTang/
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── utils/
│   └── widgets/
├── assets/branding/
├── screenshot/
├── test/
├── tool/
├── android/
├── ios/
├── web/
├── windows/
├── macos/
├── linux/
├── pubspec.yaml
└── README.md
```

## 👨‍💻 Developer

Developed by **[thanakorn-official](https://github.com/thanakorn-official)** · [Source code](https://github.com/thanakorn-official/KeepTang)

---

<p align="center">
  Made with 💚<br />
  <b>KeepTang — Keep Track of Your Money.</b>
</p>
