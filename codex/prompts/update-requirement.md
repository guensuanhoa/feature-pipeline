Pipeline vừa dừng vì spec còn câu hỏi mở mà người dùng đánh giá là quan trọng. Danh sách câu hỏi ở `.specify/pipeline/open-questions.md`. Thư mục feature nằm trong `.specify/pipeline/current-feature`.

Việc cần làm:

1. Đọc dòng `**Input**:` ở đầu spec.md để tìm yêu cầu gốc.
   - Nếu yêu cầu gốc trỏ tới một file (ví dụ "Đọc yêu cầu trong prompt.md"), cập nhật file đó.
   - Nếu yêu cầu gốc là mô tả trực tiếp, ghi lại toàn bộ mô tả đó cùng các câu trả lời vào `.specify/pipeline/requirement-updated.md`.
2. Hỏi người dùng từng câu một, kèm phương án gợi ý. Người dùng có thể trả lời "bỏ qua" cho câu không cần chốt.
3. Hỏi xong, thêm câu trả lời vào file yêu cầu ở bước 1, dưới heading `## Làm rõ (YYYY-MM-DD)`, mỗi dòng dạng `- Hỏi: ... → Đáp: ...`. Không sửa phần còn lại của yêu cầu. Không sửa spec.md, không sửa code, không chạy `git push`.
4. In ra lệnh để chạy lại pipeline từ đầu, ví dụ `specify workflow run feature-pipeline-codex -i spec="Đọc yêu cầu trong <file>"`, rồi nhắc người dùng thoát phiên (Ctrl+C hoặc `/quit`) để quay lại pipeline.
