### 1) **main.dart**

* 앱 진입점 (entry point)
* `runApp()` 호출해서 전체 앱 시작
* `MaterialApp` 테마/첫 화면 지정

---

### 2) **models/**

* **데이터 모델 정의**
* 서버(WebSocket)에서 오는 JSON → Dart 객체로 변환
* 예:

  * `YamnetEvent` (소리 감지 이벤트)
  * `WhisperEvent` (음성 인식 결과)
  * `YoloEvent` (카메라 객체 감지)
  * `UnknownEvent` (기타 데이터)

👉 **데이터 구조만 담당** → UI/네트워크 코드와 분리

---

### 3) **services/**

* **비즈니스 로직 / 외부 통신**
* 서버와의 WebSocket 연결 관리
* 자동 재연결, 수신 이벤트 분기, 콜백 전달
* 예: `WsClient`

  * `connect()` → 연결
  * `onEvent` 콜백 → 이벤트 전달
  * `onState` 콜백 → 연결 상태 전달

👉 앱 전반에서 공통으로 쓸 수 있는 "서비스 계층"

---

### 4) **utils/**

* **공용 유틸리티 함수**
* 데이터 후처리, 변환, 포맷팅
* 예: `label_kor.dart` → 영어 라벨 → 한국어 치환

👉 모델/위젯 어디서든 가져다 쓰는 보조 함수

---

### 5) **widgets/**

* **작은 UI 컴포넌트 단위**
* 재사용 가능한 위젯 모음
* 예:

  * `YamnetCard` : 경보/방향 정보 표시
  * `WhisperPanel` : 음성 인식 결과 박스
  * `YoloBottomSheet` : 카메라 인식 결과 리스트

👉 UI를 컴포넌트 단위로 잘게 쪼개서 재사용 + 가독성 ↑

---

### 6) **pages/**

* **실제 화면(페이지 단위)**
* 여러 개의 위젯을 조합해서 앱에서 한 화면 구성
* 예: `EventViewerPage`

  * 상단 앱바 (제목 + 카메라 버튼)
  * `YamnetCard` + `WhisperPanel`
  * 우상단 버튼 → `YoloBottomSheet` 띄우기
  * WebSocket 연결 → 이벤트 수신 → UI 업데이트

👉 앱의 각 **주요 화면을 정의**하는 계층

---

## 정리

* `models/` → 데이터 구조
* `services/` → 서버 통신 / 비즈니스 로직
* `utils/` → 공용 도우미 함수
* `widgets/` → 작은 재사용 UI 조각
* `pages/` → 완성된 화면 (위젯들을 조합)
* `main.dart` → 앱 실행 시작점

