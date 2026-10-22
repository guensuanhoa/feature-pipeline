# Feature pipeline v0

Pipeline tự động cho một feature, chạy trên máy local bằng workflow engine của Spec Kit:

```
dò lệnh test (lần đầu) → specify (Opus) → tự clarify tối đa 3 vòng (Opus)
→ [hỏi bạn nếu vẫn còn câu hỏi] → [bạn duyệt spec] → plan → tasks (Opus)
→ implement (Sonnet) → kiểm tra độc lập → tự sửa tối đa 2 lần (Sonnet)
→ [hỏi bạn nếu vẫn fail] → tóm tắt
```

Bạn chỉ tham gia ở: duyệt spec (luôn có), xác nhận lệnh test (chỉ lần đầu), khi spec vẫn còn câu hỏi sau 3 vòng clarify, và khi kiểm tra vẫn fail sau 2 lần sửa.

**Clarify tự động.** Sau specify, pipeline chạy `/speckit-clarify` headless tối đa 3 vòng. Vòng 1 luôn chạy, vì `specify` thường tự đoán quyết định product và ghi vào `## Assumptions` thay vì để marker. Vòng 2 và 3 tự bỏ qua nếu spec đã hết `NEEDS CLARIFICATION`. Agent chỉ tự chốt câu hỏi có bằng chứng trong repo; quyết định product không có bằng chứng (kể cả assumption) thì thành marker kèm gợi ý. Nếu sau vòng 3 vẫn còn marker, gate `questions-importance` hỏi bạn (danh sách ở `.specify/pipeline/open-questions.md`):

- `continue`: câu hỏi không quan trọng, chạy tiếp tới gate duyệt spec.
- `important`: mở phiên Claude interactive để bạn trả lời từng câu. Câu trả lời được ghi vào file yêu cầu gốc (hoặc `.specify/pipeline/requirement-updated.md` nếu yêu cầu là mô tả trực tiếp). Sau đó pipeline dừng (`aborted`); bạn chạy lại lệnh `run` từ đầu.

Mục đích của v0 là kiểm chứng cơ chế, chưa phải bản đầy đủ. Review Opus → Sonnet, kiểm tra contract và tạo PR sẽ thêm ở v1 bằng overlay (chèn trước bước `summary`), không cần sửa `workflow.yml`.

## Cấu trúc

```
feature-pipeline/
├── workflow.yml                       # định nghĩa pipeline
├── scripts/
│   ├── detect-commands.sh             # dò lệnh build/lint/test, ghi commands.env
│   ├── locate-feature.sh              # tìm thư mục spec vừa tạo, đếm câu hỏi mở
│   ├── clarify-auto.sh                # một vòng clarify headless, đếm lại câu hỏi mở
│   ├── update-requirement.sh          # phiên Claude interactive ghi câu trả lời vào yêu cầu gốc
│   ├── require-artifact.sh            # dừng run khi agent không tạo plan/tasks hoặc chưa hoàn tất implement
│   ├── accept-suggestions.sh          # gate chọn continue: ghi gợi ý thành quyết định trong spec
│   ├── run-checks.sh                  # kiểm tra độc lập bằng exit code
│   ├── fix-and-recheck.sh             # gọi Claude headless sửa lỗi, rồi kiểm tra lại
│   └── summary.sh                     # tóm tắt cuối
├── prompts/fix-checks.md              # prompt cố định cho bước sửa
├── prompts/clarify-auto.md            # prompt cho clarify không có người trả lời
├── prompts/update-requirement.md      # prompt cho phiên trả lời câu hỏi
└── templates/settings.local.json.example  # danh sách quyền khởi đầu
```

Các file pipeline sinh ra khi chạy nằm trong `.specify/pipeline/` của repo.

## Cài đặt

1. Nâng Spec Kit và kiểm tra Claude CLI:

   ```bash
   uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git@v1.0.3
   claude --version
   ```

   Pipeline gọi `claude` trong terminal, không đi qua extension VS Code. CLI phải đăng nhập bằng tài khoản công ty.

2. Tạo bản thử tách riêng để không ảnh hưởng thư mục đang làm:

   ```bash
   git worktree add ../<ten-project>-pipeline -b pipeline-test
   cd ../<ten-project>-pipeline
   ```

3. Cài workflow từ GitHub Releases (xem README gốc của repo `feature-pipeline` nếu gặp lỗi):

   ```bash
   specify workflow catalog add https://github.com/guensuanhoa/feature-pipeline/releases/latest/download/catalog.json --name feature-pipeline
   specify workflow add feature-pipeline
   specify workflow list
   ```

   Lên bản mới: `specify workflow update`.

4. Cấp quyền cho agent. Chép mẫu rồi chỉnh theo project:

   ```bash
   mkdir -p .claude
   cp .specify/workflows/feature-pipeline/templates/settings.local.json.example .claude/settings.local.json
   ```

   Danh sách này đang viết sẵn cho project Go. Nếu project dùng ngôn ngữ khác, thay các dòng `go ...` bằng lệnh tương ứng. Tên các script `.specify/scripts/bash/...` đã khớp với Spec Kit 1.0.3; nếu bạn dùng bản khác, kiểm tra lại trong thư mục đó. Nếu đã có `.claude/settings.local.json` thì gộp tay, đừng ghi đè.

5. Thêm vào `.gitignore` các file chạy tạm:

   ```
   .specify/pipeline/*.log
   .specify/pipeline/*.status
   .specify/pipeline/current-feature
   .specify/pipeline/fix-notes.md
   .specify/pipeline/implement-report.md
   .specify/pipeline/tasks-done.before
   .specify/pipeline/clarify.log
   .specify/pipeline/open-questions.md
   .specify/pipeline/requirement-updated.md
   ```

   `commands.env` nên được commit để cả team dùng chung.

## Chạy

```bash
specify workflow run feature-pipeline \
  -i spec="Đọc yêu cầu trong docs/handoffs/<file-handoff>.md"
```

Có thể truyền mô tả trực tiếp thay cho đường dẫn file. Đổi model nếu cần: `-i plan_model=sonnet` hoặc `-i impl_model=opus`. Chỉ nhận các giá trị trong danh sách cho phép.

**Không truyền `spec_verdict` khi chạy lệnh `run`.** Nếu truyền sẵn `approve`, gate duyệt spec sẽ tự thông qua mà bạn chưa đọc. Chỉ dùng các input `*_verdict` khi `resume`.

Khi pipeline dừng ở gate:

- Nếu chạy trong terminal bình thường, nó sẽ hỏi trực tiếp approve hay reject.
- Nếu đã thoát, xem `specify workflow status` để lấy `run_id`, rồi tiếp tục:

  ```bash
  specify workflow resume <run_id> --input spec_verdict=approve
  ```

  Tên input theo từng gate: `commands_verdict` (lần đầu), `questions_verdict` (`continue` hoặc `important`), `spec_verdict`, `checks_verdict`.

Gate duyệt spec: đọc `spec.md` theo đường dẫn mà bước `locate-feature` in ra ngay trước gate. Nếu có cảnh báo `NEEDS CLARIFICATION`, xử lý trước khi approve, ví dụ sửa trực tiếp trong spec.md.

## Guard và gate "continue"

- **Guard artifact.** Sau `plan`, `tasks`, `implement`, script `require-artifact.sh` kiểm tra artifact chuẩn Spec Kit trong thư mục feature: `plan.md` (khác template), `tasks.md` có dòng `- [ ] T001`, và `implement` đạt đủ: mọi task trong `tasks.md` là `[X]`; mỗi task mới xong trong run này có dòng bằng chứng `- T001: <bằng chứng>` (task điều kiện không xảy ra ghi `- T005: N/A - <lý do>`) trong `.specify/pipeline/implement-report.md`; report có dòng `TESTS: not-run|passed|failed|blocked - <lệnh/lý do>`. Không cần diff code: task chỉ xác minh vẫn đạt. Task bị chặn giữ `[ ]` và guard dừng run, in danh sách task còn mở. Thiếu thì in `GUARD_FAIL stage=<bước> reason=<lý do>` và run dừng ở trạng thái `FAILED`. Lý do cần guard: Spec Kit coi bước `command:` là xong khi agent thoát với mã 0, kể cả khi agent từ chối làm.
- **Gate câu hỏi mở chọn `continue`.** `accept-suggestions.sh` lấy phần `— gợi ý:` của từng marker `[NEEDS CLARIFICATION: ...]`, ghi thành `- Q: … → A: …` trong `## Clarifications` (session "accepted at pipeline gate"), rồi xóa marker nằm riêng một dòng. Marker nằm giữa câu được thay bằng chính câu gợi ý. Marker không có gợi ý hoặc sai định dạng thì spec giữ nguyên và run dừng.
- **`agent_preamble`.** Câu mở đầu ghép trước `spec` cho `plan`, `tasks`, `implement`, báo agent rằng không có người trả lời. `specify` dùng `spec` nguyên bản vì đó là mô tả feature. Đổi nội dung bằng `-i agent_preamble="..."`.
- Chạy lại trên feature đã xong mọi task: `snapshot-tasks` ghi lại các task đã xong và xóa report cũ, nên `guard-implement` chỉ cần report mới (có dòng `TESTS:`), không đòi tick thêm task. Hợp đồng agent (tick `tasks.md`, ghi report) nằm trong input `implement_contract`; đổi bằng `-i implement_contract=...`.
- Test script: `bash feature-pipeline/tests/run-tests.sh` (không nằm trong bundle).

## Khi chạm giới hạn 5 giờ

Bước đang chạy sẽ fail, trạng thái vẫn được lưu. Đợi cửa sổ reset rồi:

```bash
specify workflow status            # xem run nào đang failed
specify workflow resume <run_id>
```

Mỗi lần chỉ chạy một feature để tránh đốt cửa sổ 5 giờ nhanh.

## Đã kiểm tra trước khi giao

Bộ file đã được cài và chạy thử với Spec Kit 1.0.3, dùng một `claude` giả để kiểm tra luồng điều khiển:

- Workflow hợp lệ, cài được bằng `specify workflow add ./feature-pipeline/dist/feature-pipeline --dev`.
- Spec Kit gọi `claude -p /speckit-specify ... --model opus`, plan và tasks dùng `opus`, implement dùng `sonnet`: model theo từng bước hoạt động.
- Gate dừng đúng chỗ khi chạy không tương tác, `resume` với verdict chạy tiếp hoặc dừng đúng.
- Vòng tự sửa: sửa được thì bỏ qua lần thứ hai; không sửa được thì dừng ở gate ngoại lệ.
- Lần chạy thứ hai không hỏi lại lệnh test.

Chưa kiểm tra được với Claude thật: hành vi của các lệnh Spec Kit khi chạy headless, và danh sách quyền đã đủ chưa.

## Lần chạy đầu: những điểm cần kiểm chứng

| Điểm | Cách kiểm tra | Nếu không được |
|---|---|---|
| Tài khoản cho phép dùng model `opus` và `sonnet` qua CLI | Bước specify chạy không báo lỗi model | Hỏi admin danh sách model được phép; đổi giá trị bằng `-i plan_model=...` |
| Lệnh Spec Kit chạy headless không bị treo | Bước specify kết thúc và có spec.md | Ghi lại bước bị treo; phương án dự phòng là chạy các bước Spec Kit thủ công, chỉ dùng phần kiểm tra và tự sửa của pipeline |
| Agent không bị kẹt vì thiếu quyền | Xem log từng bước có dòng bị từ chối quyền | Thêm đúng lệnh bị chặn vào `allow`, không mở rộng hơn |
| Dò đúng thư mục feature | Dòng `FEATURE_DIR=` khớp spec vừa tạo | Báo lại cấu trúc thư mục specs của bạn |
| Lệnh test đúng | Gate xác nhận lần đầu | Sửa `commands.env` rồi approve |

Ghi lại cho mỗi lần chạy: % cửa sổ 5 giờ trước và sau (lấy từ /usage), thời gian từng bước, bước nào phải can thiệp, và lý do.

## Gỡ bỏ

```bash
specify workflow remove feature-pipeline
cd .. && git worktree remove <ten-project>-pipeline && git branch -D pipeline-test
```

## Lưu ý an toàn

- Bước shell chạy bằng quyền của bạn, không có sandbox. Pipeline chỉ đưa vào lệnh shell các giá trị bị giới hạn sẵn (tên model trong danh sách cho phép). Output của agent không bao giờ được chèn vào lệnh.
- `commands.env` được thực thi khi kiểm tra, nên chỉ ghi lệnh bạn tin tưởng. Gate lần đầu có mục đích để bạn xem file này.
- Agent bị chặn `git push`; v0 không tự đẩy code hay tạo PR.
- Thông điệp gate được viết không dấu để tránh lỗi mã hóa ký tự trong terminal.
