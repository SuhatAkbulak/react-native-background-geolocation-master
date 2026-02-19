# 📦 NPM Yayınlama Kılavuzu

Bu dosya `react-native-background-location` paketini npm'e yayınlamak için adımları içerir.

## 🔧 Yayınlamadan Önce Kontrol Listesi

### 1. package.json Güncellemeleri

```json
{
  "name": "react-native-background-location",
  "version": "1.0.0",  // ✅ Versiyonu güncelle
  "author": "Your Name <your.email@example.com>",  // ✅ Gerçek bilgileri ekle
  "homepage": "https://github.com/yourname/react-native-background-location",  // ✅ GitHub repo URL'i
  "repository": {
    "type": "git",
    "url": "https://github.com/yourname/react-native-background-location.git"  // ✅ Repo URL'i
  }
}
```

### 2. README.md Kontrolü

- ✅ Kurulum talimatları güncel mi?
- ✅ API dokümantasyonu eksiksiz mi?
- ✅ Örnek kodlar çalışıyor mu?

### 3. Test

```bash
# Test uygulamasında test et
cd TestApp
npm install
npm run android
npm run ios
```

## 🚀 Yayınlama Adımları

### 1. NPM Hesabı Oluştur/Giriş Yap

```bash
npm login
# Username, password ve email girin
```

### 2. Paket Adı Kontrolü

```bash
# Paket adının müsait olduğunu kontrol et
npm view react-native-background-location
# Eğer "404 Not Found" dönerse, paket adı müsait demektir
```

### 3. Versiyon Güncelleme

```bash
# package.json'da versiyonu güncelle (örn: 1.0.0 -> 1.0.1)
# Sonra:
npm version patch  # 1.0.0 -> 1.0.1
# veya
npm version minor  # 1.0.0 -> 1.1.0
# veya
npm version major  # 1.0.0 -> 2.0.0
```

### 4. Build ve Test

```bash
# Android build test
cd android && ./gradlew clean build && cd ..

# TypeScript kontrolü
npx tsc --noEmit
```

### 5. Yayınla

```bash
# Dry run (test için, gerçekten yayınlamaz)
npm publish --dry-run

# Gerçek yayınlama
npm publish

# Eğer private registry kullanıyorsanız:
npm publish --registry=https://registry.npmjs.org/
```

### 6. Tag ile Yayınlama (Beta/Alpha)

```bash
# Beta versiyonu
npm version 1.0.0-beta.1
npm publish --tag beta

# Alpha versiyonu
npm version 1.0.0-alpha.1
npm publish --tag alpha
```

## 📋 Yayınlama Sonrası

### 1. GitHub Release Oluştur

```bash
# Git tag oluştur
git tag v1.0.0
git push origin v1.0.0
```

### 2. GitHub'da Release Notları

- Versiyon numarası
- Yeni özellikler
- Bug fix'ler
- Breaking changes (varsa)

### 3. Dokümantasyon Güncelle

- README.md'yi güncelle
- CHANGELOG.md'yi güncelle

## 🔄 Versiyonlama Stratejisi

### Semantic Versioning (SemVer)

- **MAJOR** (1.0.0 -> 2.0.0): Breaking changes
- **MINOR** (1.0.0 -> 1.1.0): Yeni özellikler (geriye uyumlu)
- **PATCH** (1.0.0 -> 1.0.1): Bug fix'ler

### Örnek Versiyonlama

```
1.0.0  -> İlk stabil sürüm
1.0.1  -> Bug fix
1.1.0  -> Yeni özellik (iOS desteği)
1.1.1  -> Bug fix
2.0.0  -> Breaking change (API değişikliği)
```

## ⚠️ Önemli Notlar

1. **Paket adı benzersiz olmalı** - npm'de aynı isimde paket varsa yayınlayamazsınız
2. **Versiyon artırılmalı** - Aynı versiyonla tekrar yayınlayamazsınız
3. **Test edin** - Yayınlamadan önce mutlaka test edin
4. **README güncel olsun** - Kullanıcılar README'ye bakacak

## 🐛 Sorun Giderme

### "Package name already exists" Hatası

```bash
# Paket adını değiştir (package.json)
"name": "react-native-background-location-custom"
```

### "Version already exists" Hatası

```bash
# Versiyonu artır
npm version patch
```

### "Unauthorized" Hatası

```bash
# NPM'e tekrar giriş yap
npm login
```

## 📚 Kaynaklar

- [NPM Publishing Guide](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)
- [Semantic Versioning](https://semver.org/)
- [React Native Autolinking](https://github.com/react-native-community/cli/blob/main/docs/autolinking.md)

