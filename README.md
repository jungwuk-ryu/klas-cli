# klas-cli

`klas`는 광운대학교 KLAS를 터미널과 자동화 환경에서 안전하게 사용할 수 있도록 만든 독립형 Dart CLI입니다. 내부적으로는 `klasflow`의 공개 고수준 API 위에 얇은 CLI 계층을 올려서, 사람 사용자에게는 읽기 쉬운 출력과 도움말을 제공하고 AI 에이전트에게는 안정적인 JSON 계약을 제공합니다.

이 저장소는 작은 범위의 truthful v1을 목표로 합니다. 확인된 `klasflow` 기능만 노출하고, 의미를 추측해야 하는 명령은 의도적으로 보류합니다.

## 현재 상태

- 언어: Dart
- 패키지명: `klas_cli`
- 실행 파일명: `klas`
- 업스트림 SDK: 고정 git 의존성으로 연결된 `klasflow`
- 범위: 읽기 중심, 에이전트 친화적 CLI

## 기본 명령어 트리

```text
klas auth login
klas auth status
klas auth logout
klas me profile
klas courses list
klas courses show --course <course>
klas tasks list [--course <course>]
klas tasks show <task-no> [--course <course>]
klas notices list [--course <course>]
klas schedule today
klas schedule week
klas schedule next
```

## 의도적으로 보류한 명령

아래 명령은 업스트림 데이터 의미가 충분히 검증되기 전까지 v1에서 제외합니다.

- `tasks due`
- `tasks overdue`
- `notices show`
- `progress by-course`
- `progress show`
- `files list`
- `files download`

## 설치와 실행

`klasflow`는 pub.dev에 배포되어 있지 않기 때문에 이 프로젝트는 고정된 git 의존성을 사용합니다.

```bash
dart pub get
dart run bin/klas.dart --help
```

빌드된 실행 파일이 필요하면 다음처럼 만들 수 있습니다.

```bash
dart compile exe bin/klas.dart -o build/klas
./build/klas --help
```

## 인증 모델

현재 CLI는 세 가지 인증 경로를 가집니다.

1. `auth login`으로 만드는 재사용 가능한 로컬 인증 세션
2. 환경변수를 이용한 비대화형 fallback 인증
3. 대화형 터미널에서의 프롬프트 입력

환경변수 방식은 여전히 사용할 수 있습니다.

```bash
export KLAS_ID="your-id"
export KLAS_PASSWORD="your-password"
```

설정 후에는 일반 명령을 바로 실행하면 됩니다.

```bash
dart run bin/klas.dart courses list
dart run bin/klas.dart --format json tasks list
```

로컬 재사용 세션을 만들려면 다음처럼 로그인합니다.

```bash
dart run bin/klas.dart auth login
dart run bin/klas.dart auth status
```

OpenClaw 같은 에이전트는 셸 `export` 없이 stdin JSON 입력을 사용할 수 있습니다.

```bash
printf '{"id":"your-id","password":"your-password"}' | \
  dart run bin/klas.dart auth login --stdin-json --format json
```

환경변수와 로컬 세션이 모두 없고 텍스트 모드 + 대화형 터미널에서 실행 중이면, 필요한 경우 `stderr`로 자격 증명 입력 프롬프트를 표시합니다.

### 중요한 인증 제한

이 CLI는 비밀번호를 로컬 디스크에 저장하지 않습니다. 대신 현재 사용자 세션 안에서만 살아 있는 로컬 인증 데몬에 자격 증명을 메모리로 유지하고, 디스크에는 연결용 메타데이터만 기록합니다. `klasflow`는 로그인 이후 같은 프로세스 안에서는 세션 자동 연장을 지원하지만, 프로세스 간에 그대로 재사용할 수 있는 안전한 공개 세션 복구 API는 제공하지 않기 때문에 이 재사용 계층은 CLI가 직접 관리합니다.

즉, 현재 동작은 다음과 같습니다.

- `auth login`은 자격 증명을 검증한 뒤 재사용 가능한 로컬 인증 세션을 만듭니다.
- 이후 `auth status`와 일반 명령은 먼저 이 로컬 세션을 사용합니다.
- 환경변수 `KLAS_ID`와 `KLAS_PASSWORD`는 로컬 세션이 없을 때 fallback으로 사용됩니다.
- `auth logout`은 로컬 인증 세션을 지우지만, 셸 환경변수 자체를 제거하지는 않습니다.

검증된 인증 재사용 동작은 다음과 같습니다.

- 일반 명령은 먼저 로컬 재사용 세션을 확인합니다.
- 로컬 세션이 없으면 `KLAS_ID`와 `KLAS_PASSWORD`를 사용합니다.
- 둘 다 없으면 대화형 프롬프트가 마지막 fallback입니다.

## 출력 계약

기본 출력은 사람이 읽기 쉬운 텍스트입니다.

에이전트나 자동화에서는 `--format json`을 사용하세요.

```bash
dart run bin/klas.dart --format json tasks list
```

JSON 모드 규칙:

- `stdout`에는 구조화된 JSON만 출력됩니다.
- 프롬프트, 경고, 진단 메시지는 `stderr`를 사용합니다.

### Agent-safe runtime controls

에이전트용으로 다음 제어를 추가 제공합니다.

- `klas schema [command ...]`: 런타임에 명령 계약, 옵션, 출력 필드를 JSON으로 조회
- `--fields a,b,c`: JSON `data`에서 필요한 top-level 필드만 유지
- `--dry-run`: 로컬 입력만 검증하고 KLAS 호출 없이 종료

예시:

```bash
dart run bin/klas.dart --format json schema tasks list
dart run bin/klas.dart --format json --fields course_id,title courses list
dart run bin/klas.dart --format json --dry-run tasks show 12 --course CSE101
```

입력 하드닝 규칙:

- course selector는 제어문자, `?`, `#`, `%`를 포함할 수 없습니다.
- stdin JSON 인증 값은 빈 문자열이나 제어문자를 허용하지 않습니다.
- `--fields`는 소문자/숫자/밑줄로 된 top-level JSON 필드명만 허용합니다.

### 성공 응답 예시

```json
{
  "ok": true,
  "schema_version": "1.0",
  "command": "tasks list",
  "data": [],
  "meta": {},
  "warnings": []
}
```

### 오류 응답 예시

```json
{
  "ok": false,
  "schema_version": "1.0",
  "command": "me profile",
  "data": null,
  "error": {
    "code": "AUTH_REQUIRED",
    "message": "Authentication is required for this command.",
    "retryable": false,
    "hint": "Set KLAS_ID and KLAS_PASSWORD or run the command in an interactive terminal.",
    "details": {}
  },
  "meta": {},
  "warnings": []
}
```

세부 JSON 계약은 `docs/json-contract.md`에 정리되어 있습니다.

## 종료 코드

- `0`: 성공
- `64`: 사용법 오류
- `65`: 인증 오류
- `66`: 찾을 수 없음
- `69`: 네트워크 또는 서비스 오류
- `70`: 내부 CLI 오류

## 데이터 및 보안 원칙

- 비밀번호, 쿠키, 원시 세션 정보는 출력하지 않습니다.
- 학생 ID는 명령 출력에 노출하지 않습니다.
- JSON 출력은 업스트림 raw payload가 아니라 정규화된 CLI 데이터입니다.
- v1에서는 읽기 전용 흐름만 제공합니다.

## 스케줄 명령 의미

스케줄 계열 명령은 데이터 근거를 명확히 구분합니다.

- `schedule week`: 반복 수업 시간표 기준
- `schedule today`: 오늘의 시간표 + 월간 일정 항목 결합
- `schedule next`: 위 결합 뷰에서 가장 가까운 다음 일정 선택

또한 `tasks list`, `notices list`처럼 과목 fan-out이 필요한 명령은 일부 과목 조회에 실패해도 전체를 실패시키는 대신 `warnings`와 함께 부분 결과를 반환할 수 있습니다.

## 검증 명령

로컬에서 사용한 대표 검증 명령은 다음과 같습니다.

```bash
dart analyze
dart test
dart run bin/klas.dart --help
dart run bin/klas.dart --format json schema tasks list
dart run bin/klas.dart --format json --dry-run courses list
dart run bin/klas.dart --format json tasks list --course 'CSE101?fields=name'
dart run bin/klas.dart auth --help
printf '{"id":"bad","password":"bad"}' | dart run bin/klas.dart auth login --stdin-json --format json
dart run bin/klas.dart --format json auth status
dart run bin/klas.dart --format json me profile
```

## 관련 문서

- `docs/plan.md`
- `docs/decision-log.md`
- `docs/json-contract.md`
- `.agents/skills/klas-student-cli/SKILL.md`
