# 🎬 Tabattal Cloud Video Export Service (FFmpeg Microservice)

خدمة سحابية خفيفة وفائقة السرعة لتوليد وتصدير فيديوهات القرآن الكريم بدقة 1080p وصوت AAC نقي 100% لتطبيق فلاتر ويب، مطابقة تمامًا لتطبيق الموبايل.

---

## 🚀 طريقة التشغيل محليًا (Local Testing):
1. تأكد من تثبيت [Node.js](https://nodejs.org) و [FFmpeg](https://ffmpeg.org) على جهازك.
2. افتح موجه الأوامر في هذا المجلد:
   ```bash
   cd server/video_export_service
   npm install
   npm start
   ```
3. سيعمل السيرفر على: `http://localhost:8080`
4. شغّل اختبار سياسة CORS قبل النشر:
   ```bash
   npm test
   ```

---

## ☁️ النشر على Google Cloud Run:

### الخطوات:
1. ادخل على [Google Cloud Console](https://console.cloud.google.com).
2. قم بإنشاء مشروع جديد (مجاني).
3. افتح **Cloud Run** ثم اضغط **Create Service**.
4. اختر **Continuously deploy from a repository** (واربط هذا المستودع من GitHub).
5. حدد مسار الـ Dockerfile: `server/video_export_service/Dockerfile`.
6. اضغط **Deploy**.
7. ستمنحك جوجل رابطًا مباشرًا مثل: `https://tabattal-video-export-xxxxx.a.run.app`.
8. احتفظ بواجهة التطبيق وخدمة المعالجة منفصلتين، واستخدم نطاق API الخاص ببيئة النشر لديك.
9. أعد نشر الخدمة بعد أي تعديل في `cors_policy.js` حتى تقبل النسخة الجديدة من الموقع.

قيمة بناء Flutter Web الإنتاجية:

```text
VIDEO_EXPORT_API_URL=https://YOUR_VIDEO_API_DOMAIN/api/export-video
```

---

## ⚡ طريقة الرفع الفوري المجاني على Render.com (في دقيقتين):
1. ادخل على [Render.com](https://render.com) وسجل حسابًا مجانيًا.
2. اضغط **New +** ثم **Web Service**.
3. اربط مستودع GitHub الخاص بك.
4. في **Root Directory** اكتب: `server/video_export_service`
5. في **Environment** اختر: `Docker`
6. في **Instance Type** اختر: `Free`
7. اضغط **Create Web Service**.
8. سيعطيك Render رابطًا مثل: `https://tabattal-video-service.onrender.com`
