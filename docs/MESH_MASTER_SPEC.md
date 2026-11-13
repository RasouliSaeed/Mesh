# MESH
## Master Engineering Specification
### Baseline: v1.8.0

---

# 0. Mission
Mesh یک پلتفرم ارتباطی Local-first / Private-first / Serverless-first برای ارتباط مستقیم بین دستگاه‌های نزدیک است.
شعار محصول:
**Mesh — Nearby. Instant. Private.**
Mesh باید بتواند بدون وابستگی اجباری به Cloud، Account، سرویس ثالث یا Internet، بین دستگاه‌های مختلف ارتباط برقرار کند.
قابلیت‌های اصلی:
- Device Discovery
- Secure Pairing
- File Transfer
- Folder Transfer
- Shared Folders
- Messaging
- Clipboard
- Device Presence
- Background Transfer
- Cross-platform Communication

---

# 1. Current Baseline
نسخه فعلی پروژه: **v1.8.0**
نسخه 1.8.0 یک پروژه موجود و فعال است و نباید به‌عنوان پروژه خام یا قابل بازنویسی کامل در نظر گرفته شود.
قبل از هرگونه تغییر:
1. کل repository را بررسی کن.
2. معماری فعلی را استخراج کن.
3. قابلیت‌های موجود را شناسایی کن.
4. dependencyها را بررسی کن.
5. Rust Core را بررسی کن.
6. Flutter architecture را بررسی کن.
7. Refena state management را بررسی کن.
8. Android native layer را بررسی کن.
9. Desktop integrations را بررسی کن.
10. Protocol compatibility را بررسی کن.
11. Build configurations را بررسی کن.
12. Test coverage موجود را بررسی کن.
هیچ implementation جدیدی قبل از این Audit شروع نشود.

---

# 2. Non-Negotiable Product Principles
## 2.1 Simplicity
Mesh نباید از نظر UI/UX پیچیده یا شلوغ شود.
اصل: **Complexity behind the scenes, simplicity in the interface.**
کاربر نباید مجبور شود مفاهیم زیر را برای استفاده عادی بداند:
- TCP, QUIC, TLS, IPv4, IPv6, WebRTC, Chunk, Stream, Hash, Session Key, Interface Binding
این اطلاعات فقط در Advanced / Diagnostics نمایش داده شوند.

---

# 3. Primary User Model
کاربر عادی باید بتواند در کوتاه‌ترین مسیر:
Open Mesh -> See nearby device -> Select device -> Select file -> Send
Primary actions: Send, Receive, Devices
Secondary actions: Messages, Shared, Clipboard
Advanced: Security, Network, Transfer settings, Diagnostics
System: Appearance, Notifications, Privacy, Startup, Updates

---

# 4. Progressive Disclosure
Technical information باید Progressive Disclosure داشته باشد.
Default UI: Project.zip / 72% / 84 MB/s
Advanced Details: Transport: QUIC, Encryption: TLS 1.3, Peer: Verified, Latency: 4 ms, Streams: 4, Chunk size: 4 MB, Integrity: SHA-256
اطلاعات Advanced نباید در صفحه اصلی نمایش داده شوند.

---

# 5. UI/UX Guardrails
هر Feature جدید باید این قوانین را رعایت کند:
1. قابلیت جدید بدون دلیل Navigation اصلی را افزایش ندهد.
2. قابلیت‌های مرتبط در یک صفحه یا Context قرار بگیرند.
3. از duplicate controls اجتناب شود.
4. از پنل‌های متعدد و popupهای غیرضروری استفاده نشود.
5. UI باید برای کاربر جدید بدون آموزش قابل استفاده باشد.
6. Technical details فقط در Details / Advanced باشند.
7. UI باید روی سیستم ضعیف نیز روان باشد.
8. Animation فقط برای انتقال وضعیت استفاده شود.
9. Animation دائمی و غیرضروری ممنوع است.
10. قابلیت‌های جدید نباید باعث افزایش محسوس حجم برنامه شوند مگر ضرورت فنی داشته باشند.
11. Design System مرکزی استفاده شود (رنگ، spacing، typography و... نباید اختصاصی باشند).

---

# 6. Architecture
معماری کلی: Flutter -> Thin Bridge -> Rust Core
Flutter مسئول: UI, Rendering, User interaction, Localization, Presentation State
Rust مسئول: Networking, Discovery, Protocol, Cryptography, Identity, Sessions, Transfer, Resume, Integrity, Retry, Transport, Network diagnostics

---

# 7. Zero-Dart Networking
Networking باید در Rust باقی بماند.
Flutter نباید مستقیماً HTTP request, WebSocket, TCP socket, UDP discovery, WebRTC networking را مدیریت کند مگر در مواردی که Platform API صراحتاً نیاز داشته باشد. Flutter باید فقط از Bridge استفاده کند.

---

# 8. Transport Abstraction
Transport نباید مستقیماً در Transfer Engine hard-code شود.
Interface مفهومی باید Transport-agnostic باشد: connect(), send(), receive(), pause(), resume(), cancel(), close()

---

# 9. Transport Selection
ترتیب انتخاب پیشنهادی: Direct LAN -> Direct local transport -> Wi-Fi Direct / Hotspot -> WebRTC
WebRTC نباید برای انتقال داخل یک LAN به‌صورت غیرضروری استفاده شود.

---

# 10. Discovery
Discovery Manager باید مستقل و adaptive باشد: IPv4, IPv6, mDNS, BLE, QR
Foreground: Active discovery / Background: Low-frequency discovery / Hidden: Discovery disabled

---

# 11. IPv6
پشتیبانی فعلی IPv6 حفظ شود. Link-local IPv6 مانند fe80::xxxx%interface باید به‌درستی مدیریت شود. Interface scope نباید در parsing از بین برود.

---

# 12. Device Identity
هر نصب Mesh باید Device Identity مستقل داشته باشد (Device ID, Public Key, Private Key).
Private Key نباید از دستگاه خارج شود. Display Name از Identity جدا باشد. Device ID در UI عادی نمایش داده نشود.

---

# 13. Device Trust
دستگاه‌ها باید بتوانند Trusted شوند. Trust باید قابل حذف باشد. Trusted بودن نباید به معنی استفاده از Session Key دائمی باشد.

---

# 14. Pairing
سه سطح: Quick Pair, Verified Pair, Trusted Pair

---

# 15. Session Security
Identity دائمی نباید با Session Key یکی باشد. Ephemeral Session Key پس از پایان Session از بین برود.

---

# 16. TLS
TLS 1.3 فعلی حفظ شود. Mandatory client authentication حفظ شود. TLS Certificate نباید جایگزین Device Identity شود. Identity و Transport Security دو لایه جدا باشند.

---

# 17. Transfer Engine
Transfer Engine باید یک subsystem مستقل باشد (Queue, Scheduler, Chunk Manager, Resume, Retry, Integrity, Speed, Storage, Cancellation).

---

# 18. Chunk Transfer
فایل‌های بزرگ باید Chunk-based منتقل شوند. هر Chunk دارای ID, Offset, Length, Hash, State است.

---

# 19. Resume
Resume باید Persistent باشد. در صورت قطع ارتباط به هر دلیلی، فقط Chunkهای ناقص دوباره منتقل شوند.

---

# 20. Atomic File Commit
فایل ناقص نباید فایل نهایی محسوب شود. ile.ext.mesh.part -> Transfer Complete -> Hash Verification -> Atomic Rename -> file.ext

---

# 21. Integrity
دو سطح: Chunk SHA-256 + Full File SHA-256. فقط بعد از تأیید Integrity وضعیت Completed ثبت شود.

---

# 22. Retry
Retry باید adaptive باشد. Retryهای بی‌نهایت ممنوع.

---

# 23. Concurrency
باید در صورت امکان به Global concurrency limit + Per-peer concurrency limit تبدیل شود (بر اساس CPU/RAM/Network/Storage speed تنظیم شود).

---

# 24. Compression
Compression باید Adaptive باشد. برای متون مفید است، برای فایل‌های فشرده و مدیا غیرفعال باشد.

---

# 25. Storage Abstraction
Storage باید abstraction داشته باشد (Windows, Android SAF, Android MediaStore, Linux, macOS). Transfer Engine نباید platform-specific storage logic داشته باشد.

---

# 26. Android
SAF, MediaStore, Gallery save, Share Intent, Background transfer حفظ شوند. Wakelock فقط زمانی فعال شود که واقعاً لازم است.

---

# 27. Desktop
Drag & Drop, System Tray, Background receiving, Windows installer, MSIX, Linux packages حفظ شوند.

---

# 28. Messaging
Messaging باید از File Transfer مستقل باشد، اما هر دو روی Secure Session کار کنند.

---

# 29. Shared Folders
Shared Folder باید: Read-only by default, Permission controlled, Expirable, Revocable باشد.

---

# 30. Clipboard
Clipboard Sync باید: Opt-in, Permission-aware, Local, Encrypted باشد. Mesh نباید بدون فعال‌سازی دائماً Clipboard را monitor کند.

---

# 31. Capability Negotiation
در زمان Handshake باید امکانات تبادل شوند (نسخه‌های مختلف backward compatible باشند).

---

# 32. Protocol Versioning
Protocol باید versioned باشد. هیچ تغییر breaking نباید بدون negotiation انجام شود.

---

# 33. State Management
Refena حفظ شود. State domainها جدا باشند.

---

# 34. Event Throttling
Rust نباید progress event با فرکانس بسیار بالا به Flutter ارسال کند (5-10 updates/sec).

---

# 35. Diagnostics
دو سطح: Normal (کاربر عادی)، Diagnostics (کاربر حرفه‌ای شامل RTT, Chunk failures و...).

---

# 36. Privacy
Core Mesh نباید به Cloud وابسته باشد. Telemetry باید opt-in باشد. هیچ محتوایی بدون اجازه کاربر خارج نشود.

---

# 37. FOSS
Core باید مستقل از commercial dependencies باشد. FOSS build نباید با حذف کدهای حیاتی باعث شکستن Core شود.

---

# 38. Performance
Low CPU/RAM, Low network overhead, Minimal Flutter rebuild/animation, Adaptive concurrency.

---

# 39. UI Performance
UI نباید برای نمایش metrics دائماً rebuild شود. Heavy visualization ضروری نیست (Radar فقط Visualization است).

---

# 40. Feature Flags
Feature flags مرکزی ایجاد شود. قابلیت‌های Experimental UI اصلی را آلوده نکنند.

---

# 41. Design System
یک Design System مرکزی (Colors, Typography, Spacing, Radius...) ایجاد/حفظ شود.

---

# 42. Navigation
Desktop: Home, Transfers, Messages, Shared, Devices, Settings.
Mobile: Home, Transfers, Messages, Settings.

---

# 43. Accessibility
keyboard accessible, screen-reader friendly, contrast, scalable text, focus state.

---

# 44. Localization
i18n architecture (Slang) حفظ شود. تمام متن‌ها خارج از business logic باشند. RTL پشتیبانی شود.

---

# 45. Testing
هر Feature جدید باید Unit, Integration, Error, Regression Test داشته باشد (تحت شرایط قطعی و کرش).

---

# 46. Release Rule
هیچ نسخه‌ای آماده نیست مگر Tests, Security, Performance, UI/UX, Localization پاس شده باشند.

---

# 47. Golden Rule for Antigravity (AI Agent)
1. Repository را جستجو کن. 2. قابلیت مشابه موجود را پیدا کن. 3. Extend/Refactor کن. 4. از duplicate implementation جلوگیری کن.
هر تغییر باید: Existing architecture + Minimal necessary change باشد.

---

# 48. Forbidden Behaviors (AI Agent)
Antigravity نباید: کل پروژه را rewrite کند، بدون دلیل dependency اضافه کند، networking را وارد Dart کند، state architecture را عوض کند، UI navigation را بی‌دلیل افزایش دهد، API بشکند، encryption را عوض کند، telemetry اجباری اضافه کند.

---

# 49. Definition of Done
Code implemented, Existing functionality preserved, Tests passed, No new analyzer errors, Performance/Security/UI/Localization checked, Docs updated.
