# klas-cli

`klas`는 광운대학교 KLAS를 터미널과 자동화 환경에서 읽기 전용으로 사용할 수 있게 만든 Dart CLI입니다. 사람에게는 간단한 텍스트 출력을, 자동화 도구와 AI 에이전트에게는 일관된 JSON 출력을 제공합니다.

v1에는 현재 구현으로 확인된 기능만 담았습니다. 의미를 추정해야 하는 명령은 넣지 않았습니다.

## 설치

가장 빠른 설치 방법은 저장소의 설치 스크립트를 사용하는 것입니다.

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.sh | bash
```

Windows PowerShell:

```powershell
iwr -useb https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.ps1 | iex
```

설치 스크립트는 Dart가 없으면 함께 준비하고, pub.dev의 `klas_cli` 패키지를 설치한 뒤 로그인 단계로 이어집니다.

Unix 계열에서는 `curl ... | bash`가 자식 셸에서 실행되기 때문에, 설치 직후 현재 셸에서 `klas`가 바로 보이지 않을 수 있습니다. 이때는 새 셸을 열거나 설치 안내에 나온 `source` 명령을 실행하면 됩니다.

설치가 끝난 뒤에는 다음처럼 확인할 수 있습니다.

```bash
klas --help
klas auth status
```

저장소에서 직접 실행하려면 아래처럼 시작하면 됩니다.

```bash
dart pub get
dart run bin/klas.dart --help
```

실행 파일이 필요하면 직접 빌드할 수도 있습니다.

```bash
dart compile exe bin/klas.dart -o build/klas
./build/klas --help
```

## 지원하는 명령

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
klas timetable week
klas calendar month [--year <year>] [--month <month>]
klas schema [command ...]
```

아래 명령은 아직 포함하지 않았습니다.

- `tasks due`
- `tasks overdue`
- `notices show`
- `progress by-course`
- `progress show`
- `files list`
- `files download`

## 로그인 방법

인증이 필요한 일반 명령은 다음 순서로 인증 정보를 찾습니다.

1. `auth login`으로 만든 로컬 재사용 인증 상태
2. 환경변수 `KLAS_ID`, `KLAS_PASSWORD`
3. 대화형 터미널에서의 직접 입력

환경변수를 쓰려면 아래처럼 설정하면 됩니다.

```bash
export KLAS_ID="your-id"
export KLAS_PASSWORD="your-password"
```

이후에는 일반 명령을 바로 실행하면 됩니다.

```bash
klas courses list
klas --format json tasks list
```

재사용 인증 상태를 만들려면 한 번 로그인하면 됩니다.

```bash
klas auth login
klas auth status
```

자동화 환경에서는 환경변수 대신 stdin JSON도 사용할 수 있습니다.

```bash
printf '{"id":"your-id","password":"your-password"}' | \
  klas auth login --stdin-json --format json
```

동작 방식은 다음과 같습니다.

- `auth login`은 자격 증명을 확인한 뒤 재사용 가능한 로컬 인증 상태를 만듭니다.
- 저장된 자격 증명은 디스크에 평문으로 두지 않고, 가능하면 운영체제 보안 저장소를 사용하고 그렇지 않으면 로컬 암호화 파일로 보관합니다.
- 실행 중에는 별도 로컬 데몬이 세션 메타데이터를 관리하고, 데몬이 죽었거나 재부팅된 뒤에도 저장된 자격 증명으로 자동 복구를 시도합니다.
- `auth status`는 로컬 인증 상태와 환경변수 상태를 확인해 현재 인증 가능 여부를 보여줍니다.
- 인증이 필요한 일반 명령은 먼저 이 로컬 인증 상태를 확인합니다.
- 로컬 인증 상태가 없으면 `KLAS_ID`, `KLAS_PASSWORD`를 사용합니다.
- 둘 다 없으면 대화형 터미널에서만 직접 입력을 받습니다.
- `auth logout`은 로컬 데몬 세션과 저장된 자격 증명을 함께 지우며, 셸의 환경변수는 그대로 둡니다.
- 비밀번호와 세션 원문은 JSON 출력에 포함하지 않습니다.

`auth login`은 대화형 터미널이라면 직접 입력을 받을 수 있지만, 자동화에서는 `--stdin-json`이나 환경변수를 사용하는 편이 안전합니다.

## 출력 형식

기본 출력은 사람이 읽기 쉬운 텍스트입니다. 자동화나 에이전트에서는 `--format json`을 사용하면 됩니다.

```bash
klas --format json tasks list
```

JSON 출력에서는 다음 규칙을 지킵니다.

- `stdout`에는 JSON만 출력합니다.
- 프롬프트와 진단 메시지는 `stderr`로 보냅니다.
- 부분 실패나 주의 사항은 JSON 본문의 `warnings` 필드에 담습니다.

자동화에 유용한 옵션도 함께 제공합니다.

- `klas schema [command ...]`: 명령 경로, 옵션, 출력 필드를 JSON으로 확인
- `--fields a,b,c`: JSON `data`에서 필요한 top-level 필드만 남김
- `--dry-run`: `supports_dry_run: true`인 명령에서만 로컬 입력을 검사하고 KLAS 호출 없이 종료

다만 `schema`, `auth login`, `auth logout`은 `--dry-run`을 지원하지 않습니다.

예시는 다음과 같습니다.

```bash
klas --format json schema tasks list
klas --format json --fields course_id,title courses list
klas --format json --dry-run tasks show 12 --course CSE101
```

입력 검증 규칙:

- 과목 선택값에는 제어문자, `?`, `#`, `%`를 넣을 수 없습니다.
- stdin JSON 인증 값에는 빈 문자열이나 제어문자를 넣을 수 없습니다.
- `--fields`에는 소문자, 숫자, 밑줄로 된 top-level 필드명만 사용할 수 있습니다.

`tasks list`는 현재 범위에서 과제 목록을 그대로 보여주는 명령입니다. 마감 임박이나 overdue 전용 의미는 별도 명령으로 나뉘어 있지 않습니다.

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

자세한 JSON 규칙은 `doc/json-contract.md`에서 볼 수 있습니다.

## 시간표와 일정 명령 기준

- `timetable week`: 반복 수업 시간표 기준
- `calendar month`: 월간 일정 테이블 항목을 월 기준으로 조회

`today`처럼 시간표와 월간 일정을 섞은 파생 명령은 제거했습니다. 주간 강의 시간표와 월간 일정은 upstream에서도 서로 다른 기능군이라, CLI도 같은 명령 아래 묶지 않고 분리합니다.

`tasks list`, `notices list`처럼 여러 과목을 한 번에 훑는 명령은 일부 과목 조회에 실패해도 전체를 중단하지 않고 `warnings`와 함께 부분 결과를 돌려줄 수 있습니다.

## 종료 코드

- `0`: 성공
- `64`: 사용법 오류
- `65`: 인증 오류
- `66`: 찾을 수 없음
- `69`: 네트워크 또는 서비스 오류
- `70`: 내부 CLI 오류

## 확인용 명령

```bash
dart analyze
dart test
dart run bin/klas.dart --help
dart run bin/klas.dart auth --help
dart run bin/klas.dart --format json schema tasks list
dart run bin/klas.dart --format json --dry-run courses list
dart run bin/klas.dart --format json --fields path,description schema tasks list
dart run bin/klas.dart --format json --dry-run tasks show 12 --course CSE101
dart run bin/klas.dart --format json schema timetable
dart run bin/klas.dart --format json schema calendar month
dart run bin/klas.dart --format json --dry-run calendar month --year 2026 --month 3
```

## 관련 문서

- `doc/json-contract.md`
- `CHANGELOG.md`
