# Android Bypass VPN Whitelist 

> Dokumentasi ringkas, visual, dan profesional untuk **whitelist trafik VPN** pada perangkat Android.  
> ⚠️ **Penting:** README ini **tidak** berisi langkah teknis untuk melewati kebijakan jaringan, mengelabui pemantauan, atau melakukan aktivitas ilegal. Semua contoh bersifat *struktur data* dan **NON-OPERATIONAL**.

![Scope: Split-Tunnel](https://img.shields.io/badge/Scope-Split--Tunnel-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green) ![Status: Draft](https://img.shields.io/badge/Status-DRAFT-yellow)

---

## ✨ Sekilas
 'Bypass-vpn-whitelist` adalah skrip shell yang mengelola pengecualian trafik (whitelist) pada perangkat Android — berguna untuk aplikasi yang harus jalan dilayanan gateway router utama,sedangkan android menjalankan vpn yang tidak memiliki whitelist, 
 Tujuan utama: untuk pengguna vpn tanpa whitelist
 'perangkat wajib Root'
 'scrip cuma untuk koneksi wifi wlan0'
 
---

## 🎯 Tujuan Repository
- Menyediakan format scrip shell whitelist yang mudah dibaca.  

---
## penggunaan
- isi nama package aplikasi yang tidak ingin melewati vpn di 'APP-TARGET.txt'
- cukup jalan scrip **su -ic bash novpn.sh** maka aplikasi anda sudah terhubung dikoneksi asli
- untuk kembalikan ke aturan bawaan **su -ic bash undovpn.sh** dan aplikasi anda akan terhubung ke vpn yang anda gunakan.
