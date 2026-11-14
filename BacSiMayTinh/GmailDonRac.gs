/**
 * GMAIL DỌN RÁC TỰ ĐỘNG — dán vào https://script.google.com
 *
 * Thư bị chuyển vào Thùng rác (KHÔNG xoá vĩnh viễn ngay):
 * trong 30 ngày vẫn khôi phục được nếu lỡ xoá nhầm.
 * Thư có gắn sao ⭐ hoặc đánh dấu Quan trọng sẽ KHÔNG bao giờ bị xoá.
 */

// ====== TUỲ CHỈNH Ở ĐÂY ======
const QUY_TAC = [
  'in:spam',                                  // Thư rác (spam)
  'category:promotions older_than:14d',       // Quảng cáo cũ hơn 14 ngày
  'category:social older_than:30d',           // Thông báo mạng xã hội cũ hơn 30 ngày
  'category:updates older_than:60d',          // Thông báo/cập nhật cũ hơn 60 ngày
  // Thêm người gửi muốn xoá, ví dụ:
  // 'from:noreply@shopee.vn older_than:7d',
];
const BAO_VE = ' -is:starred -is:important';  // không đụng thư gắn sao / quan trọng
const GUI_BAO_CAO = true;                       // gửi email tóm tắt cho chính bạn
// =============================

/** Chạy hàm này để dọn ngay. */
function donRacGmail() {
  const batDau = Date.now();
  const ketQua = [];
  let tong = 0;

  for (const quyTac of QUY_TAC) {
    const query = quyTac === 'in:spam' ? quyTac : quyTac + BAO_VE;
    let dem = 0;
    while (Date.now() - batDau < 5 * 60 * 1000) {   // giới hạn ~5 phút/lần chạy
      const threads = GmailApp.search(query, 0, 100);
      if (threads.length === 0) break;
      GmailApp.moveThreadsToTrash(threads);
      dem += threads.length;
    }
    ketQua.push(`${quyTac}: ${dem} thư`);
    tong += dem;
  }

  const noiDung = `Bác sĩ Gmail đã dọn ${tong} cuộc hội thoại:\n\n` + ketQua.join('\n') +
    '\n\n(Thư nằm trong Thùng rác 30 ngày, có thể khôi phục.)';
  console.log(noiDung);
  if (GUI_BAO_CAO && tong > 0) {
    GmailApp.sendEmail(Session.getActiveUser().getEmail(), `🧹 Đã dọn ${tong} thư rác`, noiDung);
  }
}

/** Chạy hàm này 1 LẦN để Gmail tự dọn mỗi ngày lúc ~3 giờ sáng. */
function batTuDongMoiNgay() {
  tatTuDong();
  ScriptApp.newTrigger('donRacGmail').timeBased().everyDays(1).atHour(3).create();
  console.log('Đã bật: Gmail sẽ tự dọn rác mỗi ngày.');
}

/** Chạy hàm này nếu muốn tắt tự động. */
function tatTuDong() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'donRacGmail')
    .forEach(t => ScriptApp.deleteTrigger(t));
}
