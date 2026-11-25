# BatchSnap

사진 일괄 용량 줄이기 & 포맷 변환 (100% 오프라인, 전면 광고 없음) — Flutter / Android.

## 실행 방법

이 저장소에는 `lib/`와 `pubspec.yaml`만 있고 `android/` 플랫폼 폴더는 없습니다. 최초 1회 생성하세요.

```bash
flutter create --platforms=android --org com.batchsnap --project-name batchsnap .
flutter pub get
```

그 다음 `android/app/build.gradle(.kts)`에서 `minSdk`를 **24 이상**으로 올리고 (`gal` 요구사항),
`android/app/src/main/AndroidManifest.xml`의 `<manifest>` 안에 아래를 추가합니다
(Android 9 이하에서만 필요한 갤러리 저장 권한이며, 전체 저장소 권한은 쓰지 않습니다).

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
```

```bash
flutter run
```

## 구조

| 경로 | 역할 |
| :-- | :-- |
| `lib/services/compress_service.dart` | 목표 용량 이진 탐색 + 해상도 다운스케일, 순차 처리 |
| `lib/services/app_state.dart` | Pro 상태, 변환 기록, 임시 캐시 정리 |
| `lib/services/picker.dart` | 시스템 포토 피커 다중 선택 |
| `lib/screens/` | 홈 / 일괄 설정 / 진행·결과 / 비포·애프터 비교 |

## 아직 구현되지 않은 항목

- 실제 AdMob 배너 (`AdBannerPlaceholder` 자리) 및 `in_app_purchase` 결제 (현재 Pro는 테스트용 토글)
- 변환 후 원본 삭제 (시스템 피커는 갤러리 에셋 ID를 주지 않아, `wechat_assets_picker`로 교체 필요)
- 다국어(i18n) — 현재 한국어 고정
