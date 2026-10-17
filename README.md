# AIAWA English Star Academy — MVP Prototype

ภาษา: ไทย / English  
รูปแบบ: MVP (Minimum Viable Product)  
สถานะ: UI prototype + database schema draft; ยังไม่ใช่ production service

## เปิดดูต้นแบบ
1. แตกไฟล์ ZIP
2. เปิด `index.html` ด้วย browser รุ่นใหม่
3. ใช้เมนูเพื่อทดลองหน้าแรก หลักสูตร สมาชิก Referral และ Login
4. การสมัคร/เข้าสู่ระบบ การส่งคำขอชำระเงิน และการผูก Wallet เป็นการจำลองฝั่ง browser เท่านั้น

## สิ่งที่มีในต้นแบบ
- หน้า Landing page และเมนูภาษาไทย/อังกฤษ
- หลักสูตรตัวอย่าง Star 1–5
- ตัวอย่างบทเรียนและ Quiz
- แผนสมาชิกพร้อมราคา placeholder: $1 / $3 / $5 / $8 / $12 ต่อเดือน
- ตัวอย่าง Manual payment request
- ตัวอย่าง referral dashboard: $5 ต่อผู้แนะนำที่ผ่านเงื่อนไข และ $80 เป็นยอดรวมเมื่อครบ 10 คน
- ตัวอย่างสถานะ TrueMoney Wallet
- หน้า Admin preview (ข้อมูลสถิติจำลอง)
- `schema.sql` สำหรับ PostgreSQL

## สิ่งที่ยังไม่ทำงานจริง
- ไม่มี backend, database connection, authentication, email/SMS verification
- ไม่มีการเก็บข้อมูลบัญชีจริงหรือการตรวจสอบ session
- ไม่มีการรับเงิน, ตรวจสลิป, TrueMoney API, payout หรือการโอนเงินจริง
- ไม่มีระบบสิทธิ์บทเรียนที่บังคับใช้ฝั่ง server
- ไม่มี anti-fraud / audit logging ที่ทำงานจริง
- ไม่มี deployment, domain, SSL, backup หรือ monitoring

## สถาปัตยกรรมที่เสนอ
Browser (Next.js frontend) → Backend API (Next.js route handlers / NestJS) → PostgreSQL  
Backend → object storage สำหรับสื่อ/หลักฐานการชำระเงิน  
Backend → email/SMS verification provider  
Backend → manual payment review workflow; ต่อ provider API เมื่อได้รับอนุมัติ  
Backend → referral/reward ledger พร้อม transaction + idempotency key  
Admin portal → role-based access + audit logs

## แผนพัฒนา MVP
1. ยืนยันราคา สกุลเงิน และระยะเวลาสมาชิก
2. พัฒนา backend + authentication ที่ปลอดภัย
3. เชื่อม PostgreSQL และ seed ข้อมูลหลักสูตร
4. ทำระบบ Manual payment review โดยเจ้าหน้าที่ตรวจรายการจากบัญชีผู้รับเงินจริง ไม่ใช้สลิปเพียงอย่างเดียว
5. ทำ referral qualification, reward ledger และการอนุมัติจ่าย
6. ขออนุมัติช่องทาง TrueMoney ที่เหมาะกับ merchant/payout ก่อนเชื่อมเงินจริง
7. ทดสอบสิทธิ์เข้าถึง, duplicate accounts, self-referral, refunds, replay/double payment และ security
8. ตรวจข้อกฎหมาย ภาษี PDPA เงื่อนไขบริการ และนโยบายการคืนเงินก่อนเปิดใช้งาน

## ข้อควรระวัง
- อย่าใส่รหัสผ่าน/PIN/OTP หรือข้อมูลวอลเล็ตจริงในต้นแบบนี้
- อย่าใช้หน้าจอนี้เป็นหลักฐานว่ารับเงินหรือจ่ายรางวัลสำเร็จ
- ก่อน production ให้ผู้เชี่ยวชาญตรวจสอบรูปแบบ referral/bonus และข้อกำหนดทางกฎหมาย
- โบนัส $80 ตั้งค่าตามตัวเลือก “ยอดรวมทั้งหมด $80” ไม่ใช่ $80 เพิ่มจากรางวัล $5 ต่อคน; ต้องกำหนดวิธีจัดสรรยอดรางวัลเมื่อครบ 10 คนอย่างชัดเจน
