# CalmMap (무던한 지도)

발달장애 아동 가족의 외출을 돕는 장소·시간대별 감각부하(소음·혼잡) 지도 iOS 앱

iOS app that maps sensory load (noise, crowds) by place and time to help families of children with developmental disabilities plan outings.

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
Put the new KV namespace id in `wrangler.toml`. For local runs, copy `.dev.vars.example` to `.dev.vars` and use `npx wrangler dev`. The privacy policy is served at `/privacy`.

## Data
- 서울특별시 실시간 도시데이터 (서울 열린데이터광장, 공공누리 제1유형)
- 스마트서울 도시데이터 센서(S-DoT) 환경정보 (서울 열린데이터광장, 공공누리 제1유형)
