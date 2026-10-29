# CalmMap (무던한 지도)

An iOS app that shows how crowded and noisy places in Seoul are right now and over the next 12 hours, rescored for a child's own sensory triggers, so families of children with developmental disabilities can pick a calmer place and time to go out.

발달장애 아동 가족이 덜 붐비고 덜 시끄러운 장소와 시간을 미리 고를 수 있도록, 서울 121곳의 감각부하(사람 붐빔·소리)를 아이 기준으로 다시 계산해 보여 주는 iOS 앱입니다.

## About this project
- Built for the **2026 AI Life Solution Challenge** (KEIT), based on the idea proposal "무던한 지도 (Calm Map)" selected as a candidate in the 2026 AI Life Idea Challenge.
- The original service idea belongs to its proposer. This repository contains my product design, UI design and iOS/back-end implementation of that idea.
- Rights to the contest entry follow the challenge rules (co-owned with the idea proposer).

## Features
- **Sensory map:** 121 Seoul places marked 무던함 · 보통 · 붐빔 from real-time city data, with a 12-hour forecast and the reasoning behind each score.
- **Child profiles:** sensitivity to crowds and loud sounds, specific sound triggers (sudden loud sounds, chimes and announcements, crowd chatter, crying, traffic, music) and lighting. Every score, forecast and recommendation is recalculated for the selected child.
- **On-device sound measurement:** a 60-second measurement classifies sound *types* with Apple SoundAnalysis on the device. No audio is recorded, stored or sent.
- **Measured places:** measurements at one of the 121 places feed that place's score around the same hour. Measurements elsewhere, including outside Seoul, become "my measured spot" pins.
- **Accessibility:** VoiceOver labels and announcements, Dynamic Type, Reduce Motion and dark mode.

## Tech
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

## Privacy
- No sign-up and no personal data on any server.
- Measurements, measured-spot coordinates and child profiles stay on the device.
- The privacy policy is served by the proxy at `/privacy`.

## Requirements
- Xcode 26+
- iOS 17.0+

## Setup
```sh
cp Secrets.example.xcconfig Secrets.xcconfig
```
Fill in the proxy host and app token in `Secrets.xcconfig`. This file is git-ignored.

### Proxy (Cloudflare Workers)
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

## Data
- 서울특별시 실시간 도시데이터 (서울 열린데이터광장, 공공누리 제1유형)
- 스마트서울 도시데이터 센서(S-DoT) 환경정보 (서울 열린데이터광장, 공공누리 제1유형)

The sensory index is a probabilistic estimate, not a diagnosis or a guarantee.
