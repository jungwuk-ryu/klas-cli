# klas-cli

`klas-cli`는 광운대학교 KLAS를 터미널과 에이전트와 함께 사용할 수 있게 만든 Dart CLI입니다.


## 설치

가장 빠른 설치 방법은 아래의 One-liner를 이용하세요.

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.sh | bash
```

Windows PowerShell:

```powershell
iwr -useb https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.ps1 | iex
```

설치가 끝난 뒤에는 다음처럼 확인할 수 있습니다.

```bash
klas --help
klas auth status
```

## 제공하는 명령어

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

## 로그인 방법

가장 쉬운 방법으로는 `auth login` 명령을 이용하시면 됩니다.

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

환경변수 대신 stdin JSON도 사용할 수 있습니다.

```bash
printf '{"id":"your-id","password":"your-password"}' | \
  klas auth login --stdin-json --format json
```

## 출력 형식

기본 출력은 사람이 읽기 쉬운 텍스트입니다. 에이전트는 `--format json`을 사용하면 됩니다.

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

`tasks list`는 현재 범위에서 과제 목록을 그대로 보여주는 명령입니다.

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

## 시간표와 일정 명령어

- `timetable week`: 반복 수업 시간표 기준
- `calendar month`: 월간 일정 테이블 항목을 월 기준으로 조회

`tasks list`, `notices list`처럼 여러 과목을 한 번에 훑는 명령은 일부 과목 조회에 실패해도 전체를 중단하지 않고 `warnings`와 함께 부분 결과를 돌려줄 수 있습니다.

## 종료 코드

- `0`: 성공
- `64`: 사용법 오류
- `65`: 인증 오류
- `66`: 찾을 수 없음
- `69`: 네트워크 또는 서비스 오류
- `70`: 내부 CLI 오류

## 확인용 명령어

```bash
dart run tool/check_all.dart
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

- `doc/engineering_quality_baseline.md`
- `doc/release_checklist.md`
- `doc/json-contract.md`
- `CHANGELOG.md`
