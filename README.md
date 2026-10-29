# CalmMap (무던한 지도)

[한국어](#한국어) · [English](#english)

## 한국어

발달장애 아동 가족이 덜 붐비고 덜 시끄러운 장소와 시간을 미리 고를 수 있도록, 서울 121곳의 감각부하(사람 붐빔·소리)를 지금과 앞으로 12시간 동안 아이 기준으로 다시 계산해 보여 주는 iOS 앱입니다.

### 프로젝트 소개
- **2026 AI 라이프 솔루션 챌린지**(한국산업기술기획평가원) 출품작으로, 2026 AI 라이프 아이디어 챌린지 수상 후보작 "무던한 지도(Calm Map)" 아이디어를 바탕으로 만들었습니다.
- 서비스 아이디어의 원저작자는 제안자입니다. 이 저장소에는 그 아이디어를 구체화한 제품 기획, UI 디자인, iOS 앱과 서버 구현이 담겨 있습니다.
- 출품작의 권리는 대회 규정(아이디어 제안자와 공동 소유)을 따릅니다.

### 주요 기능
- **감각 지도:** 서울시 실시간 도시데이터로 121곳을 무던함 · 보통 · 붐빔으로 표시하고, 앞으로 12시간 예측과 점수의 근거를 함께 보여 줍니다.
- **아이 프로필:** 사람 붐빔과 큰 소리에 대한 민감도, 힘들어하는 소리 종류(갑작스러운 큰 소리, 안내음·벨, 사람 소리·웅성임, 아이 울음, 교통·기계 소리, 음악), 조명 민감도를 설정하면 모든 점수와 예측, 추천이 그 아이 기준으로 다시 계산됩니다.
- **온디바이스 소리 측정:** 60초 동안 Apple SoundAnalysis로 주변 소리의 *종류*를 기기 안에서 분류합니다. 녹음 파일은 만들거나 저장·전송하지 않습니다.
- **측정 기록 반영:** 121곳 근처에서 측정하면 그 장소의 같은 시간대 점수에 반영되고, 그 밖의 곳(서울 밖 포함)에서 측정하면 "내가 측정한 곳" 핀으로 지도에 남습니다.
- **접근성:** VoiceOver 라벨과 안내, 큰 글씨(Dynamic Type), 동작 줄이기, 다크 모드를 지원합니다.

### 기술
- SwiftUI, Observation, SwiftData, MapKit, Swift Charts (iOS 17 이상)
- SoundAnalysis + AVAudioEngine 기반 온디바이스 소리 분류
- CoreLocation과 역지오코딩으로 측정 위치 표시
- Cloudflare Workers + KV 프록시가 서울시 데이터를 주기적으로 받아 두어, 서울시 API 키가 앱에 포함되지 않습니다.

### 개인정보
- 회원가입이 없고, 서버에 개인정보를 저장하지 않습니다.
- 측정 기록, 측정 위치, 아이 프로필은 사용자의 기기에만 저장됩니다.
- 개인정보처리방침은 프록시의 `/privacy` 경로에서 제공합니다.

### 실행 방법
Xcode 26 이상, iOS 17.0 이상이 필요합니다. 설정 방법은 아래 [Setup](#setup)을 참고해 주세요.

### 데이터 출처
- 서울특별시 실시간 도시데이터 (서울 열린데이터광장, 공공누리 제1유형)
- 스마트서울 도시데이터 센서(S-DoT) 환경정보 (서울 열린데이터광장, 공공누리 제1유형)

감각부하 지수는 확률적 예측이며 진단이나 보장이 아닙니다.

---

## English

An iOS app that shows how crowded and noisy places in Seoul are right now and over the next 12 hours, rescored for a child's own sensory triggers, so families of children with developmental disabilities can pick a calmer place and time to go out.

### About this project
- Built for the **2026 AI Life Solution Challenge** (KEIT), based on the idea proposal "무던한 지도 (Calm Map)" selected as a candidate in the 2026 AI Life Idea Challenge.
- The original service idea belongs to its proposer. This repository contains my product design, UI design and iOS/back-end implementation of that idea.
- Rights to the contest entry follow the challenge rules (co-owned with the idea proposer).

### Features
- **Sensory map:** 121 Seoul places marked 무던함 · 보통 · 붐빔 from real-time city data, with a 12-hour forecast and the reasoning behind each score.
- **Child profiles:** sensitivity to crowds and loud sounds, specific sound triggers (sudden loud sounds, chimes and announcements, crowd chatter, crying, traffic, music) and lighting. Every score, forecast and recommendation is recalculated for the selected child.
- **On-device sound measurement:** a 60-second measurement classifies sound *types* with Apple SoundAnalysis on the device. No audio is recorded, stored or sent.
- **Measured places:** measurements at one of the 121 places feed that place's score around the same hour. Measurements elsewhere, including outside Seoul, become "my measured spot" pins.
- **Accessibility:** VoiceOver labels and announcements, Dynamic Type, Reduce Motion and dark mode.

### Tech
- SwiftUI, Observation, SwiftData, MapKit, Swift Charts (iOS 17+)
- SoundAnalysis + AVAudioEngine for on-device sound classification
- CoreLocation with reverse geocoding for measured spots
- Cloudflare Workers + KV as a proxy that caches Seoul city data on a schedule, so the Seoul API key never ships in the app

```
CalmMap/
  Domain/     sensory index, child profile weighting, forecast advice
  Features/   Map, PlaceDetail, Measure, Child (one folder per tab or sheet)
  Models/     SwiftData models and city data decoding
  Services/   sound meter, location, city data client
worker/       Cloudflare Worker proxy and privacy policy page
```

### Privacy
- No sign-up and no personal data on any server.
- Measurements, measured-spot coordinates and child profiles stay on the device.
- The privacy policy is served by the proxy at `/privacy`.

### Requirements
- Xcode 26+
- iOS 17.0+

### Setup
```sh
cp Secrets.example.xcconfig Secrets.xcconfig
```
Fill in the proxy host and app token in `Secrets.xcconfig`. This file is git-ignored.

#### Proxy (Cloudflare Workers)
The app reads Seoul city data through a small proxy in `worker/`, so the Seoul API key never ships in the app.
```sh
cd worker
npm install
npx wrangler kv namespace create SNAPSHOT
npx wrangler secret put SEOUL_API_KEY
npx wrangler secret put APP_TOKEN
npx wrangler secret put ADMIN_TOKEN
npx wrangler deploy
```
Put the new KV namespace id in `wrangler.toml`. For local runs, copy `.dev.vars.example` to `.dev.vars` and use `npx wrangler dev`.

### Data
- 서울특별시 실시간 도시데이터 (서울 열린데이터광장, 공공누리 제1유형)
- 스마트서울 도시데이터 센서(S-DoT) 환경정보 (서울 열린데이터광장, 공공누리 제1유형)

The sensory index is a probabilistic estimate, not a diagnosis or a guarantee.
