Bạn đang chạy trong một pipeline tự động, không có người trả lời câu hỏi. KHÔNG hỏi người dùng và KHÔNG chờ câu trả lời; tự xử lý hết trong một lượt.

Thư mục feature nằm trong `.specify/pipeline/current-feature`. Chỉ làm việc với `spec.md` trong thư mục đó.

Trước tiên, xem lại mục `## Assumptions` (và mọi chỗ spec ghi "mặc định", "default" hoặc tự chọn phương án). Assumption nào là quyết định product/business mà yêu cầu gốc, docs hoặc code trong repo không có bằng chứng thì coi là một câu hỏi. Assumption là sự thật đã kiểm tra trong repo thì giữ nguyên.

Với từng câu hỏi bạn định hỏi, gồm các assumption ở trên và mọi chỗ `[NEEDS CLARIFICATION: ...]` đang có trong spec.md:

1. Nếu yêu cầu gốc, spec, docs hoặc code trong repo đủ bằng chứng để chọn đáp án: chọn phương án recommended, ghi vào spec đúng cách clarify ghi câu trả lời (mục Clarifications và sửa phần liên quan), rồi xóa marker tương ứng.
2. Nếu đó là quyết định product/business mà repo không đủ bằng chứng: KHÔNG tự đoán. Giữ hoặc thêm marker đúng chỗ trong spec.md (với assumption: đặt marker ngay trên dòng assumption đó) theo dạng `[NEEDS CLARIFICATION: <câu hỏi> — gợi ý: <phương án recommended>]`.

Ràng buộc bắt buộc:

- Chỉ sửa spec.md của feature hiện tại. Không sửa code, không sửa file yêu cầu gốc, không tạo nhánh mới.
- Không chạy `git push`, không cài dependency, không truy cập mạng.

<!-- Marker format above is parsed by scripts/accept-suggestions.sh; keep " — gợi ý: " unchanged. -->
