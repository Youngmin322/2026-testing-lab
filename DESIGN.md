# ConcurrencyImageGallery — 설계 문서

> Swift Concurrency를 한 개념씩 직접 만들며 학습하기 위한 iOS 앱.

---

## 1. 목적

- **학습 목표**: Swift Concurrency의 핵심 개념을 "한 번에 하나씩" 체득한다.
- **방식**: 각 개념을 독립된 **탭**으로 구현해, 같은 작업(picsum 이미지 다운로드)을 다른 방식으로 풀면서 차이를 직접 비교한다.
- **비목표**: 프로덕션 수준 앱 아님. 디자인/완성도보다 **개념 이해**가 우선.

---

## 2. 타겟 환경

| 항목 | 값 |
| --- | --- |
| 플랫폼 | iOS 26 |
| 언어 | Swift 6 (strict concurrency) |
| UI | SwiftUI |
| 상태 관리 | `@Observable` 매크로 |
| 이미지 소스 | [picsum.photos](https://picsum.photos) |

### picsum API
- 리스트: `GET https://picsum.photos/v2/list?page={page}&limit={limit}`
- 이미지: 각 항목의 `download_url` 직접 다운로드

---

## 3. 전체 구조

```
TabView (RootTabView)
 ├─ Tab 1. Sequential   — async/await 기본 (순차)
 ├─ Tab 2. Parallel     — async let / TaskGroup (병렬)
 ├─ Tab 3. Grid+Cancel  — Task 취소, .task 자동 취소
 ├─ Tab 4. Actor Cache  — actor, 데이터 격리
 └─ Tab 5. (선택) Stream — AsyncStream, 진행률
```

각 탭은 **독립 모듈**이며 같은 공통 인프라(`PicsumImage`, `ImageService`)를 공유한다.

---

## 4. 폴더 구조

```
ConcurrencyImageGallery/
├── ConcurrencyImageGalleryApp.swift   # @main 진입점
├── TabView.swift                       # RootTabView (탭 컨테이너)
├── Models/
│   └── PicsumImage.swift               # picsum 응답 모델
├── Service/
│   └── ImageService.swift              # 네트워크 호출 (공통)
└── Features/
    ├── Sequential/
    ├── Parallel/
    ├── GridCancel/
    └── ActorCache/
```

각 Feature 폴더에는 `*View.swift` + `*ViewModel.swift` 가 들어간다.

---

## 5. 공통 인프라

### 5.1 `PicsumImage` (Model)

| 필드 | 타입 | 출처 |
| --- | --- | --- |
| `id` | `String` | JSON `id` |
| `author` | `String` | JSON `author` |
| `width` | `Int` | JSON `width` |
| `height` | `Int` | JSON `height` |
| `downloadURL` | `URL` | JSON `download_url` (CodingKeys로 매핑) |

채택 프로토콜: `Decodable`, `Identifiable`, (자동) `Sendable`.

### 5.2 `ImageService` (Service)

`struct ImageService` — 상태 없음, 순수 네트워크 호출.

```swift
func fetchImageList(page: Int, limit: Int) async throws -> [PicsumImage]
func fetchImageData(from url: URL) async throws -> Data
```

- 둘 다 `URLSession.shared.data(from:)` 기반
- 에러는 그냥 throw (커스텀 에러 X)

---

## 6. 탭별 상세 설계

### 🟢 Tab 1. Sequential

| 항목 | 내용 |
| --- | --- |
| **핵심 개념** | `async/await`, `for await`, `@MainActor`, `.task` |
| **시나리오** | 버튼 → 10장을 **순차적으로** 다운로드 |
| **측정값** | 진행률 (`3 / 10`), 경과 시간 (`ContinuousClock`) |
| **체감 포인트** | "왜 비동기인데 느릴까?" → for 루프 안의 `await` |

ViewModel 상태:
- `images: [LoadedImage]`
- `isLoading: Bool`
- `progress: String`
- `elapsedSeconds: Double`
- `errorMessage: String?`

### 🟡 Tab 2. Parallel

| 항목 | 내용 |
| --- | --- |
| **핵심 개념** | `async let`, `withTaskGroup`, 구조적 동시성 |
| **시나리오** | Tab 1과 **동일한 작업**을 병렬로 |
| **체감 포인트** | 시간이 N배 빨라짐. 자식 태스크 라이프사이클 |

### 🟠 Tab 3. Grid + Cancel

| 항목 | 내용 |
| --- | --- |
| **핵심 개념** | `Task` 취소, `.task` 자동 취소, `Task.isCancelled` |
| **시나리오** | `LazyVGrid` 50~100셀, 각 셀이 자기 이미지 로드 |
| **체감 포인트** | 빠르게 스크롤하면 화면 밖 다운로드가 자동 취소됨 |

### 🔵 Tab 4. Actor Cache

| 항목 | 내용 |
| --- | --- |
| **핵심 개념** | `actor`, 데이터 격리, in-flight deduplication |
| **시나리오** | `ImageCache` actor가 중복 다운로드 방지 |
| **체감 포인트** | 같은 이미지 동시 요청 시 다운로드 1회만 발생 |

### 🟣 Tab 5. (선택) AsyncStream

| 항목 | 내용 |
| --- | --- |
| **핵심 개념** | `AsyncStream`, `for await` |
| **시나리오** | 큰 이미지 다운로드 진행률 0% → 100% 스트리밍 |

---

## 7. 학습 체크포인트

각 탭을 마치면 다음 질문에 답할 수 있어야 한다.

### Tab 1
1. `async` 함수와 일반 함수의 호출 차이는?
2. `await` 줄에서 정확히 무슨 일이 일어나는가?
3. `for` 루프 + `await` 가 왜 순차인가?
4. `@MainActor` 를 떼면 어떤 에러가 나는가?
5. `.task` vs `Task { }` 의 차이는?

### Tab 2
1. `async let` 과 `TaskGroup` 의 차이는?
2. 자식 태스크는 부모보다 오래 살 수 있는가?
3. 병렬화로 빨라지는 이유는?

### Tab 3
1. 구조적 동시성에서 취소는 어떻게 전파되는가?
2. `Task.isCancelled` 를 언제 체크해야 하는가?
3. `.task` 가 자동 취소되는 정확한 시점은?

### Tab 4
1. `actor` 와 `class` 의 차이는?
2. `@MainActor` 와 일반 `actor` 는 어떻게 다른가?
3. in-flight 요청을 어떻게 재사용할 수 있는가?

---

## 8. 진행 규칙

1. **한 탭씩만 작업.** 미리 다음 탭 파일 만들지 않는다.
2. **사용자가 직접 작성.** 막힐 때만 힌트를 받는다.
3. **컴파일 에러는 학습 도구.** Swift 6 strict concurrency의 경고를 무시하지 않는다.
4. **빌드 통과 → 동작 확인 → 코드 리뷰** 순으로 탭을 마무리한다.

---

## 9. 진행 상황

- [x] 공통 모델 `PicsumImage`
- [ ] 공통 서비스 `ImageService`  ← **진행 중**
- [ ] Tab 1. Sequential
- [ ] Tab 2. Parallel
- [ ] Tab 3. Grid + Cancel
- [ ] Tab 4. Actor Cache
- [ ] Tab 5. (선택) AsyncStream
