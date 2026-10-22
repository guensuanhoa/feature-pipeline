# Feature pipeline v0 (Codex)

Bản Codex của `feature-pipeline/`. Cùng luồng, nhưng mọi bước agent gọi Codex CLI thay cho Claude CLI. Bản Claude giữ nguyên, hai bản cài song song được.

```
dò lệnh test (lần đầu) → specify (gpt-6-luna) → tự clarify tối đa 3 vòng
→ [hỏi bạn nếu vẫn còn câu hỏi] → [bạn duyệt spec] → plan → tasks (gpt-6-luna)
→ implement (gpt-6-luna) → kiểm tra độc lập → tự sửa tối đa 2 lần (gpt-6-luna)
→ [hỏi bạn nếu vẫn fail] → tóm tắt
```

Bạn chỉ tham gia ở: duyệt spec (luôn có), xác nhận lệnh test (chỉ lần đầu), khi spec vẫn còn câu hỏi sau 3 vòng clarify, và khi kiểm tra vẫn fail sau 2 lần sửa.

**Clarify tự động.** Sau specify, pipeline chạy `$speckit-clarify` headless tối đa 3 vòng. Vòng 1 luôn chạy. Vòng 2 và 3 tự bỏ qua nếu spec đã hết `NEEDS CLARIFICATION`. Nếu sau vòng 3 vẫn còn marker, gate `questions-importance` hỏi bạn (danh sách ở `.specify/pipeline/open-questions.md`):

- `continue`: câu hỏi không quan trọng, chạy tiếp tới gate duyệt spec.
- `important`: mở phiên Codex interactive để bạn trả lời từng câu. Câu trả lời được ghi vào file yêu cầu gốc (hoặc `.specify/pipeline/requirement-updated.md`). Sau đó pipeline dừng; bạn chạy lại lệnh `run` từ đầu. Thoát phiên bằng Ctrl+C hoặc `/quit`.

## Khác bản Claude

| Điểm | Bản Claude | Bản Codex |
|---|---|---|
| Lệnh agent (bước `command:`) | `claude -p /speckit-<step>` | `codex exec "$speckit-<step> ..."` |
| Lệnh agent (script) | `claude -p ...` | `codex exec ... --sandbox workspace-write` |
| Quyền | `.claude/settings.local.json` allowlist | Sandbox `workspace-write` (ghi trong repo, không có mạng) |
| Model | `opus` / `sonnet` / `haiku` | `gpt-6-luna` (plan), `gpt-6-luna` (impl), `gpt-5.6-terra`, `gpt-6-astra` |
| Effort | không có | `plan_effort` (high), `impl_effort` (medium) |
| Tìm thư mục feature | thư mục khớp tên nhánh | `.specify/feature.json` trước, rồi fallback cũ |

Hệ quả của sandbox: `git push`, `curl` tự bị chặn vì không có mạng. `.git` cũng bị chặn ghi, nên agent không commit được (đúng với v0: pipeline không tự commit/push).

`plan_effort` / `impl_effort` chỉ áp dụng cho bước script (clarify, tự sửa, phiên trả lời câu hỏi). Các bước `command:` (specify, plan, tasks, implement) do Spec Kit gọi nên dùng effort mặc định trong `~/.codex/config.toml`; muốn đặt riêng, thêm `-c model_reasoning_effort=<e>` vào `SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS`.

## Cấu trúc

```
feature-pipeline-codex/
├── workflow.yml                       # định nghĩa pipeline
├── scripts/
│   ├── check-codex-env.sh             # báo sandbox Codex sẽ dùng và nguồn của nó (không fail)
│   ├── detect-commands.sh             # dò lệnh build/lint/test, ghi commands.env
│   ├── locate-feature.sh              # tìm thư mục spec vừa tạo, đếm câu hỏi mở
│   ├── clarify-auto.sh                # một vòng clarify headless, đếm lại câu hỏi mở
│   ├── update-requirement.sh          # phiên Codex interactive ghi câu trả lời vào yêu cầu gốc
│   ├── require-artifact.sh            # dừng run khi agent không tạo plan/tasks hoặc chưa hoàn tất implement
│   ├── accept-suggestions.sh          # gate chọn continue: ghi gợi ý thành quyết định trong spec
│   ├── run-checks.sh                  # kiểm tra độc lập bằng exit code
│   ├── fix-and-recheck.sh             # gọi Codex headless sửa lỗi, rồi kiểm tra lại
│   └── summary.sh                     # tóm tắt cuối
├── prompts/fix-checks.md              # prompt cố định cho bước sửa
├── prompts/clarify-auto.md            # prompt cho clarify không có người trả lời
├── prompts/update-requirement.md      # prompt cho phiên trả lời câu hỏi
└── templates/codex-config.toml.example  # cấu hình sandbox mẫu cho ~/.codex/config.toml
```

Các file pipeline sinh ra khi chạy nằm trong `.specify/pipeline/` của repo.

## Cài đặt

1. Cài Codex CLI và đăng nhập:

   ```bash
   npm i -g @openai/codex
   codex login
   codex --version
   ```

2. Cài integration Codex cho Spec Kit (skill nằm ở `.agents/skills/speckit-*`). Muốn giữ Claude làm default thì chạy thêm `use`:

   ```bash
   specify integration install codex
   specify integration use claude
   ```

3. Cài workflow từ GitHub Releases (xem README gốc của repo `feature-pipeline` nếu gặp lỗi):

   ```bash
   specify workflow catalog add https://github.com/guensuanhoa/feature-pipeline/releases/latest/download/catalog.json --name feature-pipeline
   specify workflow add feature-pipeline-codex
   specify workflow list
   ```

   Lên bản mới: `specify workflow update`.

4. **Bắt buộc:** đặt cờ sandbox cho các bước `command:`. Thiếu biến này, `codex exec` chạy sandbox read-only và specify không ghi được spec:

   ```bash
   export SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS="--sandbox workspace-write"
   ```

   Bước đầu tiên `check-codex-env` in cảnh báo nếu biến này trống (không dừng pipeline).

5. Tuỳ chọn: chép `.specify/workflows/feature-pipeline-codex/templates/codex-config.toml.example` vào `~/.codex/config.toml` (gộp tay nếu đã có file).

6. `.gitignore`: dùng chung các dòng `.specify/pipeline/*` với bản Claude (xem README của `feature-pipeline/`). `commands.env` nên được commit.

## Chạy

```bash
specify workflow run feature-pipeline-codex \
  -i spec="Đọc yêu cầu trong docs/handoffs/<file-handoff>.md"
```

Đổi model/effort nếu cần: `-i plan_model=gpt-6-astra`, `-i impl_effort=high`.

**Không chạy song song hai pipeline (Claude và Codex) trong cùng worktree.** Cả hai dùng chung `.specify/pipeline/` nên sẽ ghi đè state của nhau. Mỗi lần chỉ chạy một feature.

**Không truyền `spec_verdict` khi chạy lệnh `run`.** Nếu truyền sẵn `approve`, gate duyệt spec tự thông qua mà bạn chưa đọc. Chỉ dùng các input `*_verdict` khi `resume`.

Khi pipeline dừng ở gate:

- Chạy trong terminal bình thường: nó hỏi trực tiếp approve hay reject.
- Đã thoát: `specify workflow status` lấy `run_id`, rồi:

  ```bash
  specify workflow resume <run_id> --input spec_verdict=approve
  ```

  Tên input theo từng gate: `commands_verdict` (lần đầu), `questions_verdict` (`continue` hoặc `important`), `spec_verdict`, `checks_verdict`.

Gate duyệt spec: đọc `spec.md` theo đường dẫn mà bước `locate-feature` in ra ngay trước gate.

## Guard và gate "continue"

- **Guard artifact.** Sau `plan`, `tasks`, `implement`, script `require-artifact.sh` kiểm tra artifact chuẩn Spec Kit trong thư mục feature: `plan.md` (khác template), `tasks.md` có dòng `- [ ] T001`, và `implement` đạt đủ: mọi task trong `tasks.md` là `[X]`; mỗi task mới xong trong run này có dòng bằng chứng `- T001: <bằng chứng>` (task điều kiện không xảy ra ghi `- T005: N/A - <lý do>`) trong `.specify/pipeline/implement-report.md`; report có dòng `TESTS: not-run|passed|failed|blocked - <lệnh/lý do>`. Không cần diff code: task chỉ xác minh vẫn đạt. Task bị chặn giữ `[ ]` và guard dừng run, in danh sách task còn mở. Thiếu thì in `GUARD_FAIL stage=<bước> reason=<lý do>` và run dừng ở trạng thái `FAILED`. Lý do cần guard: Spec Kit coi bước `command:` là xong khi agent thoát với mã 0, kể cả khi agent từ chối làm.
- **Gate câu hỏi mở chọn `continue`.** `accept-suggestions.sh` lấy phần `— gợi ý:` của từng marker `[NEEDS CLARIFICATION: ...]`, ghi thành `- Q: … → A: …` trong `## Clarifications` (session "accepted at pipeline gate"), rồi xóa marker nằm riêng một dòng. Marker nằm giữa câu được thay bằng chính câu gợi ý. Marker không có gợi ý hoặc sai định dạng thì spec giữ nguyên và run dừng.
- **`agent_preamble`.** Câu mở đầu ghép trước `spec` cho `plan`, `tasks`, `implement`, báo agent rằng không có người trả lời. `specify` dùng `spec` nguyên bản vì đó là mô tả feature. Đổi nội dung bằng `-i agent_preamble="..."`.
- Chạy lại trên feature đã xong mọi task: `snapshot-tasks` ghi lại các task đã xong và xóa report cũ, nên `guard-implement` chỉ cần report mới (có dòng `TESTS:`), không đòi tick thêm task. Hợp đồng agent (tick `tasks.md`, ghi report) nằm trong input `implement_contract`; đổi bằng `-i implement_contract=...`.
- Test script: `bash feature-pipeline/tests/run-tests.sh` (không nằm trong bundle).

## Khi hết quota

`codex exec` thoát mã khác 0. Script ghi exit code vào log rồi tiếp tục (luôn `exit 0`), nên bước kiểm tra sẽ báo FAIL. Đợi quota reset rồi `specify workflow resume <run_id>`.

## Lần chạy đầu: những điểm cần kiểm chứng

| Điểm | Cách kiểm tra | Nếu không được |
|---|---|---|
| Biến sandbox đã đặt | Bước `check-codex-env` in `Codex env OK` | `export SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS="--sandbox workspace-write"` |
| Tài khoản gọi được model | Bước specify không báo lỗi model | Đổi bằng `-i plan_model=...` |
| Lệnh Spec Kit chạy headless không bị treo | Bước specify kết thúc và có spec.md | Ghi lại bước bị treo; chạy tay các bước Spec Kit, chỉ dùng phần kiểm tra và tự sửa |
| Dò đúng thư mục feature | `FEATURE_DIR=` khớp spec vừa tạo | Kiểm tra `.specify/feature.json` |
| Lệnh test đúng | Gate xác nhận lần đầu | Sửa `commands.env` rồi approve |
| Phiên interactive qua `/dev/tty` và lệnh thoát | Chọn `important` ở gate câu hỏi, thử trả lời rồi thoát | Tự trả lời `open-questions.md` vào file yêu cầu gốc |

## Gỡ bỏ

```bash
specify workflow remove feature-pipeline-codex
```

## Lưu ý an toàn

- Bước shell chạy bằng quyền của bạn, không có sandbox. Pipeline chỉ đưa vào lệnh shell các giá trị đã kiểm tra: tên model khớp `^[A-Za-z0-9._-]+$`, effort thuộc `low|medium|high|xhigh`. Output của agent không bao giờ được chèn vào lệnh.
- `commands.env` được thực thi khi kiểm tra, nên chỉ ghi lệnh bạn tin tưởng.
- Agent chạy trong sandbox `workspace-write`: không có mạng, không ghi được `.git`. v0 không tự đẩy code hay tạo PR.
- Thông điệp gate được viết không dấu để tránh lỗi mã hóa ký tự trong terminal.
