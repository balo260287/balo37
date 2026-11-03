# Hướng dẫn cài "30 thứ nên cài vào Claude"

> Đã kiểm tra trên GitHub ngày 03/11/2026: tất cả repo dưới đây đều có thật. Tên đúng (owner/repo) được ghi rõ.

## 0. Trước khi bắt đầu: đọc kỹ 4 điều này

1. **Cài trên máy tính, không phải trên điện thoại.** Những thứ này chạy với **Claude Code** (bản CLI hoặc app desktop). Bạn cần một máy Windows/Mac/Linux đã có:
   - Node.js 18+ (`node -v`)
   - Git (`git --version`)
   - Claude Code: `npm install -g @anthropic-ai/claude-code`, rồi gõ `claude` để đăng nhập.
2. **ĐỪNG cài cả 30 cùng lúc.** Nhóm *Harness* (superpowers, ECC, gstack, karpathy-skills…) đều sửa cách Claude làm việc, cài chồng lên nhau sẽ xung đột, Claude bị rối và tốn token hơn. Chọn **1 harness** là đủ.
3. **Mỗi skill/plugin/MCP đều được nạp vào ngữ cảnh**, càng cài nhiều thì càng tốn token và càng chậm.
4. **Bảo mật:** skill/plugin của bên thứ ba có thể chạy lệnh trên máy bạn. Chỉ cài cái bạn thật sự cần và đọc README trước.

## 1. Cách cài chung (dễ nhất, áp dụng cho mọi repo)

Mở terminal trong thư mục dự án, gõ `claude`, rồi dán câu này (thay tên repo):

```
Hãy đọc README của https://github.com/obra/superpowers và cài nó cho tôi theo đúng hướng dẫn chính thức. Giải thích từng lệnh trước khi chạy.
```

Claude sẽ tự đọc hướng dẫn mới nhất của repo và cài. Cách này an toàn hơn việc chép lệnh từ video, vì lệnh cài của các repo hay thay đổi.

Các lệnh có sẵn trong Claude Code mà bạn sẽ hay dùng:

| Lệnh | Tác dụng |
|---|---|
| `/plugin` | Mở trình quản lý plugin (xem, cài, gỡ) |
| `/plugin marketplace add owner/repo` | Thêm một "chợ" plugin từ GitHub |
| `/plugin install ten-plugin@ten-cho` | Cài một plugin từ chợ đó |
| `claude mcp add ...` (gõ ngoài Claude) | Thêm một MCP server |
| `/mcp` | Xem các MCP server đang chạy |
| `/skills` hoặc thư mục `~/.claude/skills/` | Nơi chứa skill cá nhân |

## 2. Danh sách đầy đủ, đúng tên repo

### Harness (chỉ chọn 1)
| Tên trong ảnh | Repo thật | Ghi chú |
|---|---|---|
| superpowers | `obra/superpowers` | **Khuyên dùng nếu chỉ chọn 1** |
| ECC | `affaan-m/ECC` (everything-claude-code) | Rất lớn, nặng |
| karpathy-skills | `multica-ai/andrej-karpathy-skills` | Chỉ là 1 file CLAUDE.md, nhẹ nhất |
| gstack | `garrytan/gstack` | |
| ponytail | `DietrichGebert/ponytail` | |
| learn-claude-code | `shareAI-lab/learn-claude-code` | Tài liệu học, **không cần cài** |

### Skills
| Tên | Repo | Ghi chú |
|---|---|---|
| anthropics/skills | `anthropics/skills` | Chính chủ Anthropic. Cài: `/plugin marketplace add anthropics/skills` |
| ui-ux-pro-max | `nextlevelbuilder/ui-ux-pro-max-skill` | Cho làm giao diện web |
| taste-skill | `Leonxlnx/taste-skill` | Cho làm giao diện web |
| awesome-claude-skills | `ComposioHQ/awesome-claude-skills` | Chỉ là danh sách, **không cần cài** |
| wshobson/agents | `wshobson/agents` | Bộ agent dựng sẵn |
| claude-plugins | `anthropics/claude-plugins-official` | Chợ plugin chính chủ, **đã có sẵn** trong `/plugin` |

### Memory
| Tên | Repo |
|---|---|
| graphify | `Graphify-Labs/graphify` |
| claude-mem | `thedotmack/claude-mem` |
| codegraph | `colbymchenry/codegraph` |
| repomix | `yamadashy/repomix` (không cần cài, chạy `npx repomix` là được) |
| planning-with-files | `OthmanAdi/planning-with-files` |

Lưu ý: claude-mem, graphify và codegraph làm những việc gần giống nhau, chọn 1 thôi.

### Tools / MCP
| Tên | Repo | Lệnh cài |
|---|---|---|
| playwright-mcp | `microsoft/playwright-mcp` | `claude mcp add playwright -- npx @playwright/mcp@latest` |
| github-mcp | `github/github-mcp-server` | Xem README (cần GitHub token) |
| firecrawl | `firecrawl/firecrawl` | Cần API key firecrawl.dev |
| cc-switch | `farion1231/cc-switch` | App desktop, tải ở mục Releases |
| awesome-mcp-servers | `punkpeye/awesome-mcp-servers` | Chỉ là danh sách, **không cần cài** |
| multica | `multica-ai/multica` | |
| claude-code-router | `musistudio/claude-code-router` | Dùng model khác thay Claude, không bắt buộc |
| vibe-kanban | `BloopAI/vibe-kanban` | `npx vibe-kanban` |

### Cost (tiết kiệm chi phí)
| Tên | Repo | Ghi chú |
|---|---|---|
| system-prompts-ai | `x1xhlol/system-prompts-and-models-of-ai-tools` | Chỉ để đọc, **không cài** |
| caveman | `JuliusBrussee/caveman` | Trả lời ngắn, tốn ít token |
| best-practice | `shanraisshan/claude-code-best-practice` | Tài liệu, **không cài** |
| codex-plugin-cc | `openai/codex-plugin-cc` | Cần tài khoản OpenAI |
| claude-hud | `jarrodwatts/claude-hud` | Hiện mức dùng token trên thanh trạng thái |

### Ảnh "small-business-skills" và "Cấu trúc một Claude Skill"
- Mình **không tìm thấy** repo chính thức nào của Anthropic tên `small-business-skills` (31 skill) như trong ảnh. Có thể đó là bộ skill tự làm của tác giả video. Trước khi cài thứ gì có tên đó, hãy hỏi tác giả xin link GitHub.
- Ảnh thứ hai là **mẫu để tự viết skill**. Xem mẫu sẵn ở `claude-setup/skill-mau/SKILL.md` trong repo này.

## 3. Gói khuyên dùng cho người mới (cài theo thứ tự)

1. `anthropics/skills` (chính chủ)
2. `obra/superpowers` (1 harness)
3. `microsoft/playwright-mcp`
4. `jarrodwatts/claude-hud` (để theo dõi token)
5. `thedotmack/claude-mem` (nhớ giữa các phiên)

Dùng vài ngày cho quen, thấy thiếu gì thì mới cài thêm.

## 4. Script tải hàng loạt

`claude-setup/tai-ve.sh` chỉ **tải (clone) mã nguồn** các repo về thư mục `~/claude-repos` để bạn đọc trước, **không tự cài gì cả**. Sau khi đọc xong, cài từng cái theo mục 1.

```bash
bash claude-setup/tai-ve.sh
```
