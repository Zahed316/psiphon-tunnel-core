# راهنمای مرحله‌به‌مرحله کار با `psiphon-tunnel-core`

این راهنما یک مسیر عملی، کوتاه و قابل اجرا برای شروع کار در این ریپو است.

## 1) شناخت ساختار پروژه

اول ساختار اصلی را ببین:

```bash
rg --files | head -n 40
```

نکته مهم از `README.md`:
- `ConsoleClient`: کلاینت CLI
- `Server`: باینری سرور
- `psiphon`: هسته کد کلاینت/سرور

## 2) پیش‌نیازها

- Go (نسخه سازگار با `go.mod` پروژه)
- Git
- سیستم‌عامل لینوکسی/مک برای اجرای راحت مثال‌ها

بررسی سریع:

```bash
go version
git --version
```

## 3) گرفتن کد و همگام‌سازی

```bash
git clone https://github.com/Psiphon-Labs/psiphon-tunnel-core.git
cd psiphon-tunnel-core
git checkout staging-client
```

> در README اشاره شده برای مصرف ماژول Go، شاخه `staging-client` شاخهٔ پیشنهادیِ production-ready سمت کلاینت است.

## 4) اجرای سریع تست‌ها (Smoke Test)

قبل از هر تغییر:

```bash
go test ./psiphon/... ./Server/... ./ConsoleClient/... 
```

اگر زمان تست‌ها زیاد بود، از پکیج هدف شروع کن:

```bash
go test ./psiphon/common/values -run Test -count=1
```

## 5) سناریوی عملی: اجرای محلی سرور + کلاینت

مطابق README:

### 5.1 ساخت کانفیگ سرور

```bash
./psiphond -ipaddress 127.0.0.1 -protocol OSSH:9999 generate
```

فایل‌هایی مثل `psiphond.config` و `server-entry.dat` ساخته می‌شوند.

### 5.2 ساخت کانفیگ کلاینت

یک `client.config` بساز و مقدار `TargetServerEntry` را از `server-entry.dat` قرار بده.

نمونه:

```json
{
  "LocalHttpProxyPort": 8080,
  "LocalSocksProxyPort": 1080,
  "PropagationChannelId": "24BCA4EE20BEB92C",
  "SponsorId": "721AE60D76700F5A",
  "TargetServerEntry": "<content-of-server-entry.dat>"
}
```

### 5.3 اجرای سرور

```bash
./psiphond run
```

### 5.4 اجرای کلاینت

```bash
./ConsoleClient -config ./client.config
```

اگر لاگ‌های `ListeningSocksProxyPort` و `ListeningHttpProxyPort` را دیدی، تونل بالا آمده.

## 6) جریان توسعه روزمره (پیشنهادی)

1. ایجاد برنچ فیچر:
   ```bash
   git checkout -b feat/<short-name>
   ```
2. اعمال تغییر کوچک و اتمیک.
3. اجرای تست‌های مرتبط.
4. کامیت واضح:
   ```bash
   git add <files>
   git commit -m "<type>: <summary>"
   ```
5. در صورت نیاز ری‌بیس روی شاخه هدف.
6. پوش و ایجاد PR با توضیح: «چه چیزی»، «چرا»، «چطور تست شد».

## 7) اشتباهات رایج

- تغییر دادن فایل‌های vendored بدون نیاز (`vendor/` یا `replace/webrtc/node_modules/`).
- کامیت کردن فایل‌های موقتی/خروجی محلی.
- اجرای نکردن تست مرتبط قبل از PR.

## 8) چک‌لیست قبل از PR

- [ ] تغییرات حداقلی و مرتبط هستند.
- [ ] تست مرتبط پاس شده.
- [ ] README/داک در صورت تغییر رفتار به‌روز شده.
- [ ] پیام کامیت و PR شفاف است.

---

اگر بخواهی، در قدم بعدی می‌توانم یک **سناریوی واقعی دیباگ** هم اضافه کنم (مثلاً پیدا کردن مشکل در `user agent` انتخابی کلاینت و نوشتن تست هدفمند برایش).
