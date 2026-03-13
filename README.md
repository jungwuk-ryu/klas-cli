# klas-cli

`klas`는 광운대학교 KLAS를 터미널과 자동화 환경에서 안전하게 사용할 수 있도록 만든 독립형 Dart CLI입니다. 내부적으로는 `klasflow`의 공개 고수준 API 위에 얇은 CLI 계층을 올려서, 사람 사용자에게는 읽기 쉬운 출력과 도움말을 제공하고 AI 에이전트에게는 안정적인 JSON 계약을 제공합니다.

이 저장소는 작은 범위의 truthful v1을 목표로 합니다. 확인된 `klasflow` 기능만 노출하고, 의미를 추측해야 하는 명령은 의도적으로 보류합니다.

## 현재 상태

- 언어: Dart
- 패키지명: `klas_cli`
- 실행 파일명: `klas`
- 업스트림 SDK: pub.dev로 배포된 `klasflow`
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
klas schema [command ...]
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

이 프로젝트는 pub.dev에 배포된 `klas_cli`를 one-line installer로 바로 설치할 수 있습니다.

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.sh | bash
```

Windows PowerShell:

```powershell
iwr -useb https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.ps1 | iex
```

설치기는 다음을 수행합니다.

- `dart`가 없거나 버전이 부족하면 사용자 로컬 경로에 Dart SDK를 bootstrap합니다.
- `dart pub global activate klas_cli --overwrite`로 pub.dev 패키지를 설치합니다.
- Windows PowerShell에서는 현재 세션에서 바로 `klas`를 실행할 수 있게 PATH를 구성하고, Unix 계열에서는 이후 셸도 사용할 수 있게 PATH를 저장합니다.
- 설치가 끝나면 `klas auth login`을 바로 실행하고, 비대화형 세션이라면 정확한 다음 명령만 안내합니다.

주의: `curl ... | bash` 형태의 Unix one-liner는 자식 셸에서 실행되므로, 설치 직후 부모 셸에서 plain `klas`가 바로 보이지 않을 수 있습니다. 이 경우 새 셸을 열거나 설치기가 안내한 `source` 명령을 실행하면 됩니다. 설치기 자체는 설치 확인과 로그인 handoff를 내부에서 바로 수행합니다.

설치 후에는 다음처럼 확인할 수 있습니다.

```bash
klas --help
klas auth status
```

저장소에서 직접 실행하려면 다음처럼 시작합니다.

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
klas courses list
klas --format json tasks list
```

로컬 재사용 세션을 만들려면 다음처럼 로그인합니다.

```bash
klas auth login
klas auth status
```

자동화 환경에서는 셸 `export` 없이 stdin JSON 입력을 사용할 수 있습니다.

```bash
printf '{"id":"your-id","password":"your-password"}' | \
  klas auth login --stdin-json --format json
```

현재 동작은 다음과 같습니다.

- `auth login`은 자격 증명을 검증한 뒤 재사용 가능한 로컬 인증 세션을 만듭니다.
- 이후 `auth status`와 일반 명령은 먼저 이 로컬 세션을 사용합니다.
- 환경변수 `KLAS_ID`와 `KLAS_PASSWORD`는 로컬 세션이 없을 때 fallback으로 사용됩니다.
- `auth logout`은 로컬 인증 세션을 지우지만, 셸 환경변수 자체를 제거하지는 않습니다.
- CLI는 비밀번호를 JSON 출력에 포함하지 않으며, 재사용 가능한 인증 상태는 현재 사용자 로컬 환경 안에서만 관리합니다.

검증된 인증 재사용 동작은 다음과 같습니다.

- 일반 명령은 먼저 로컬 재사용 세션을 확인합니다.
- 로컬 세션이 없으면 `KLAS_ID`와 `KLAS_PASSWORD`를 사용합니다.
- 둘 다 없으면 텍스트 모드 + 대화형 터미널에서만 프롬프트가 마지막 fallback입니다.

`auth login`은 대화형 터미널이라면 프롬프트를 사용할 수 있지만, 자동화에서는 `--stdin-json` 또는 환경변수를 사용하는 편이 안전합니다.

## 출력 계약

기본 출력은 사람이 읽기 쉬운 텍스트입니다.

에이전트나 자동화에서는 `--format json`을 사용하세요.

```bash
klas --format json tasks list
```

JSON 모드 규칙:

- `stdout`에는 구조화된 JSON만 출력됩니다.
- 프롬프트, 경고, 진단 메시지는 `stderr`를 사용합니다.

### Automation-friendly runtime controls

에이전트용으로 다음 제어를 추가 제공합니다.

- `klas schema [command ...]`: 런타임에 명령 계약, 옵션, 출력 필드를 JSON으로 조회
- `--fields a,b,c`: JSON `data`에서 필요한 top-level 필드만 유지
- `--dry-run`: `supports_dry_run: true`인 명령에서만 로컬 입력을 검증하고 KLAS 호출 없이 종료

예외:

- `schema`, `auth login`, `auth logout`은 `--dry-run`을 지원하지 않습니다.

예시:

```bash
klas --format json schema tasks list
klas --format json --fields course_id,title courses list
klas --format json --dry-run tasks show 12 --course CSE101
```

입력 하드닝 규칙:

- course selector는 제어문자, `?`, `#`, `%`를 포함할 수 없습니다.
- stdin JSON 인증 값은 빈 문자열이나 제어문자를 허용하지 않습니다.
- `--fields`는 소문자/숫자/밑줄로 된 top-level JSON 필드명만 허용합니다.

또한 `tasks list`는 truthful v1 범위의 전체 과제 목록 명령입니다. 마감 임박 또는 overdue 전용 의미는 아직 별도 명령으로 정의하지 않습니다.

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

세부 JSON 계약은 `doc/json-contract.md`에 정리되어 있습니다.

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
- `schedule next`: 시간표와 월간 일정 데이터를 함께 보고 다음 항목을 선택

또한 `tasks list`, `notices list`처럼 과목 fan-out이 필요한 명령은 일부 과목 조회에 실패해도 전체를 실패시키는 대신 `warnings`와 함께 부분 결과를 반환할 수 있습니다.

## 검증 명령

로컬에서 사용한 대표 검증 명령은 다음과 같습니다.

```bash
dart analyze
dart test
dart run bin/klas.dart --help
dart run bin/klas.dart auth --help
dart run bin/klas.dart --format json schema tasks list
dart run bin/klas.dart --format json --dry-run courses list
dart run bin/klas.dart --format json --fields path,description schema tasks list
dart run bin/klas.dart --format json --dry-run tasks show 12 --course CSE101
```

## 관련 문서

- `doc/json-contract.md`
- `CHANGELOG.md`
