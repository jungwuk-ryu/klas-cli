# klas-cli

`klas-cli`는 광운대학교 KLAS를 터미널과 에이전트와 함께 사용할 수 있게 만든 Dart CLI입니다.


## 설치

가장 빠른 설치 방법은 아래의 One-liner를 이용하세요.

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.sh | bash
```

Windows PowerShell:

기본 Windows PowerShell 5.1과 PowerShell 7을 지원합니다. Dart 3.11.1 이상이
필요하며, 설치 스크립트는 기존 Dart가 더 오래됐으면 전용 SDK를 설치하고
PATH에서 먼저 사용하도록 설정합니다.

```powershell
iwr -useb https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.ps1 | iex
```

설치가 끝난 뒤에는 다음처럼 확인할 수 있습니다.

```bash
klas --help
klas auth status
```

## 개발 브랜치 규칙

- `develop`를 통합 브랜치로 사용합니다.
- 기능 개발, 버그 수정, 문서 작업은 모두 `develop`에서 분기한 short-lived branch에서 진행합니다.
- 일상적인 작업은 short-lived branch -> `develop` 흐름으로 병합합니다.
- `main`/`master`는 release-only 브랜치로 유지하고, 릴리스 반영이나 긴급 릴리스 수정에만 사용합니다.

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
klas notices show <board-no> --course <course>
klas timetable week
klas calendar month [--year <year>] [--month <month>]
klas schema [command ...]
```

### 현재 보류된 명령어

아래 명령어는 현재 제공하지 않습니다.

- `klas tasks due`
- `klas tasks overdue`
- `klas progress ...`
- `klas files ...`

### 특정 강의의 공지·과제 본문과 첨부파일

`courses list`에서 강의 ID를 확인하고, 목록에서 공지 번호(`board_no`)나 과제 번호(`task_no`)를 찾으세요. `--course`에는 정확한 강의 ID 또는 강의명을 사용할 수 있습니다.

```bash
klas courses list
klas notices list --course CSE101
klas notices show 7 --course CSE101
klas tasks list --course CSE101
klas tasks show 12 --course CSE101
```

상세 조회는 본문과 첨부파일 이름·크기를 표시합니다. 과제는 교수자가 올린 첨부와 본인이 제출한 첨부를 구분합니다. 공지 상세에는 `--course`가 필수이고, 과제 번호가 여러 강의에서 중복되면 `--course`로 강의를 지정해야 합니다.

첨부파일을 열려면 `--download-dir`로 저장 경로를 지정하세요. 출력의 `saved=` 경로를 로컬 뷰어로 열 수 있습니다. 각 실행은 지정한 경로 아래 새 `klas-...` 폴더를 만들며, 파일명에 번호를 붙여 기존 파일과 이름이 같은 첨부도 덮어쓰지 않습니다. 실제 저장 경로는 JSON의 `local_path`에도 표시됩니다.

```bash
klas notices show 7 --course CSE101 --download-dir ./downloads
klas tasks show 12 --course CSE101 --download-dir ./downloads
klas --format json notices show 7 --course CSE101
klas --format json --fields report_text,attachments,submission_attachments tasks show 12 --course CSE101
```

기본 상세 조회는 파일 목록만 가져옵니다. 파일 저장은 `--download-dir`가 있을 때 수행하며, `--dry-run`은 네트워크 호출이나 폴더 생성을 하지 않습니다. 파일이 없으면 첨부 목록은 빈 배열이고, 첨부 조회에 실패하면 `null`과 `warnings`가 반환됩니다. 일부 다운로드가 실패해도 본문과 나머지 첨부는 유지하며, 저장하지 못한 파일의 `local_path`는 `null`입니다. `--fields`는 출력만 줄이므로 다운로드 옵션의 동작에는 영향을 주지 않습니다.

텍스트 출력은 HTML 본문의 문단·목록·링크·코드 블록을 읽기 쉽게 변환합니다. JSON에는 원본 HTML과 변환된 텍스트를 함께 제공합니다. 첨부파일 내용은 저장 후 파일에 맞는 뷰어로 확인하세요.

## 로그인 방법

가장 쉬운 방법으로는 `auth login` 명령을 이용하시면 됩니다.

```bash
klas auth login
```

숫자 캡챠가 필요한 경우 임시 이미지를 기본 이미지 뷰어로 열고 터미널에서 숫자 입력을 받습니다. 이미지를 자동으로 열지 못하면 `stderr`에 표시된 경로를 직접 여세요. 앞자리 0을 포함해 입력하면 같은 로그인 세션으로 이어갑니다. 서버가 답을 거절하면 새 이미지를 받아 최대 3회까지 입력할 수 있고, 빈 입력으로 취소할 수 있습니다. 입력 후 임시 이미지는 삭제합니다. 캡챠 취소나 한도 초과는 저장된 인증 정보를 지우지 않습니다.

일반 명령도 대화형 터미널의 텍스트 모드에서는 필요한 캡챠 입력을 받을 수 있습니다. `auth status`, `--format json`, `auth login --stdin-json`, 입력을 받을 수 없는 터미널은 캡챠를 요청하지 않고 `AUTH_CAPTCHA_REQUIRED`(종료 코드 65)를 반환합니다. 이때 대화형 터미널에서 `klas auth login`을 실행해 숫자를 입력한 뒤 원래 명령을 다시 실행하세요.

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

`tasks list`의 기본 텍스트 출력은 각 과제 줄에 `[course_title | course_id]`를 함께 표시합니다. 따라서 `klas tasks list` 결과에서 확인한 course ID를 그대로 `klas tasks show <task-no> --course <course_id>`에 넘길 수 있습니다.

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
klas --format json --fields course_id,task_no,title tasks list
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
- `calendar month`: 선택한 월에 걸쳐 있는 과제와 학사일정 조회

```bash
klas calendar month --year 2026 --month 10
klas --format json --fields title,starts_at,ends_at,status calendar month --year 2026 --month 10
```

각 일정의 `starts_at`과 `ends_at`은 원래 시작·종료 날짜와 시간을 유지합니다. 10월 일정에 포함된 과제가 9월에 시작하거나 학사일정이 11월에 끝나도 전체 기간을 확인할 수 있습니다. 텍스트 출력에도 시작과 종료가 함께 표시됩니다. 날짜를 알 수 없는 값은 JSON에서 `null`이며, 시간 없이 날짜만 제공된 값은 자정으로 표시됩니다.

`tasks list`, `notices list`처럼 여러 과목을 한 번에 훑는 명령은 일부 과목 조회에 실패해도 전체를 중단하지 않고 `warnings`와 함께 부분 결과를 돌려줄 수 있습니다.

이때 일부 과목만 실패한 경우에는 성공으로 처리하면서 가능한 결과는 `data`에 담고, 실패한 과목은 `warnings`로 알려줍니다. 반대로 선택된 과목 조회가 전부 실패하면 `warnings`만 남긴 채 성공 응답을 만들지 않고, top-level 구조화 오류(`ok: false`)를 반환합니다.

## 종료 코드

- `0`: 성공
- `64`: 사용법 오류
- `65`: 인증 오류
- `66`: 찾을 수 없음
- `69`: 네트워크 또는 서비스 오류
- `70`: 내부 CLI 오류

## 확인용 명령어

현재 개발 버전은 `pubspec.yaml`의 Git override로 검증한 `klasflow` 1.3.0 커밋을 고정합니다. 저장소를 checkout한 뒤 `dart pub get`을 실행하면 SDK를 자동으로 가져오며, 별도의 로컬 SDK 경로 설정은 필요하지 않습니다. `pubspec.lock`에도 같은 Git 커밋을 기록합니다. pub.dev 배포 전에는 SDK 1.3.0을 먼저 게시하고 override를 제거한 뒤 hosted 의존성으로 다시 검증합니다.

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
- `doc/operations_readiness.md`
- `doc/release_checklist.md`
- `doc/json-contract.md`
- `CHANGELOG.md`
