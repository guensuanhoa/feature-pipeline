Bạn đang chạy trong một pipeline tự động, không có người theo dõi trực tiếp. Bước kiểm tra độc lập (build/lint/test) vừa FAIL.

Việc cần làm:

1. Đọc `.specify/pipeline/last-check.log` để biết lỗi cụ thể.
2. Đọc `.specify/pipeline/current-feature` để biết thư mục feature, rồi đọc spec.md, plan.md, tasks.md trong thư mục đó để hiểu hành vi mong muốn.
3. Sửa code để build/lint/test pass, đúng với spec.
4. Tự chạy lại các lệnh trong `.specify/pipeline/commands.env` để xác nhận.

Ràng buộc bắt buộc:

- Không xóa, bỏ qua (skip), hay làm yếu test. Không sửa assertion để khớp với hành vi sai. Nếu bạn tin một test sai so với spec, KHÔNG sửa test, mà ghi lý do vào file ghi chú bên dưới.
- Không sửa `.specify/pipeline/commands.env`, không sửa spec.md hay plan.md.
- Không chạy `git push`, không cài thêm dependency mới, không truy cập mạng.
- Nếu lỗi do môi trường (database chưa chạy, thiếu biến môi trường, thiếu tool) thì không sửa code. Ghi dòng `ENVIRONMENT_ISSUE: <mô tả>` vào file ghi chú.
- Chỉ sửa trong phạm vi feature hiện tại.

Cuối cùng, ghi thêm (append) vào `.specify/pipeline/fix-notes.md`: thời gian, nguyên nhân lỗi, những file đã sửa, và các điểm cần con người xem lại.
