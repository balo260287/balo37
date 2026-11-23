//+------------------------------------------------------------------+
//| BtcScalpBot.mq5  v1.25                                           |
//| Bot luoi (nhoi lenh) BTC CO CHOT LO - CHI CHAY TAI KHOAN DEMO    |
//| Symbol: BTCUSDm (Exness)   Magic: 280001                         |
//|                                                                  |
//| Cach chay:                                                       |
//|  - Moi lan chi 1 chum lenh, cung 1 huong. KHONG gap thep lot.    |
//|  - Huong: EMA nhanh/cham M15 (bat buoc).                         |
//|  - Diem vao: can >= InpMinScore / 4 tin hieu hop luu:            |
//|      1. EMA200 H1 cung huong   (xu huong lon)                    |
//|      2. ADX M15 du manh + DI cung huong (co xu huong that)       |
//|      3. RSI M1 qua ban/qua mua roi quay dau (hoi xong)           |
//|      4. Gia cham dai Bollinger M1 nguoc huong (mua re/ban dat)   |
//|  - Loc: ATR M15 khong qua thap (chet) / qua cao (tin, quet),     |
//|    spread, gio giao dich, cuoi tuan.                             |
//|  - Nhoi lenh: cach max(InpGridStepPct %, ATR x InpGridAtrMult).  |
//|  - Chot lai co doi lai (trailing), giu lau -> dong hoa von.      |
//|  - SL CHUNG tren san cho ca chum (mat mang van an toan).         |
//|  - Chot lo chum / lo ngay / thua lien tiep / sut von tu dinh     |
//|    -> nghi hoac dung han.                                        |
//|  - Lai cua RIENG bot (tu luc gan) >= InpTarget -> dung han.      |
//+------------------------------------------------------------------+
#property copyright "BtcScalpBot"
#property version   "1.25"

#include <Trade\Trade.mqh>

enum ENUM_HUONG
  {
   HUONG_TU_DONG = 0, // Tu dong theo EMA
   CHI_SELL      = 1, // Chi Sell
   CHI_BUY       = 2, // Chi Buy
   HAI_CHIEU     = 3  // Ca Buy lan Sell (theo tin hieu)
  };

input group "=== Von & rui ro ==="
input double InpLot           = 0.01;   // Lot moi lenh
input int    InpMaxLayers     = 1;      // So lenh toi da cung luc (1 = khong nhoi lenh)
input double InpBasketSL      = 4.0;    // Lo TOI DA 1 chum (USD). TP/SL co gian vuot muc nay -> bo lenh
input double InpHardSLMult    = 1.3;    // SL that tren san = BasketSL x he so nay
input double InpDailyLoss     = 12.0;   // Lo toi da trong ngay (USD)
input int    InpMaxConsecLoss = 4;      // Thua lien tiep bao nhieu chum thi nghi het ngay (0 = tat)
input double InpMaxDrawdown   = 25.0;   // Lai bot tut tu dinh qua X USD -> DUNG HAN (0 = tat)
input double InpTarget        = 100.0;  // Lai cua bot dat muc nay -> dung (USD)
input bool   InpResetStats    = false;  // true = tinh lai muc tieu tu dau (bat 1 lan roi tat)
input bool   InpAllowReal     = false;  // Cho phep chay tai khoan THAT (de false)

input group "=== Vao lenh ==="
input ENUM_HUONG      InpDirection   = HAI_CHIEU;     // Huong vao lenh
input ENUM_TIMEFRAMES InpTrendTF     = PERIOD_M15;    // Khung xem xu huong
input int             InpEmaFast     = 20;            // EMA nhanh
input int             InpEmaSlow     = 50;            // EMA cham
input int             InpRsiPeriod   = 7;             // RSI M1 - chu ky
input double          InpRsiBuy      = 30;            // Buy khi RSI M1 da xuong duoi muc nay roi quay len
input double          InpRsiSell     = 70;            // Sell khi RSI M1 da len tren muc nay roi quay xuong
input double          InpGridStepPct = 0.10;          // Khoang cach nhoi lenh toi thieu (% gia)
input double          InpGridAtrMult = 1.0;           // Khoang cach nhoi lenh toi thieu = ATR M15 x he so nay
input double          InpMaxSpreadPct= 0.04;          // Spread toi da (% gia)
input int             InpCooldownMin = 15;            // Nghi sau khi chot lo (phut)
input bool            InpTestOrder   = false;         // Vao 1 lenh thu (chi demo)

input group "=== Bo loc ky thuat (hop luu) ==="
input int             InpMinScore    = 2;             // Can it nhat bao nhieu / 4 tin hieu dong thuan
input ENUM_TIMEFRAMES InpHtfTF       = PERIOD_H1;     // Khung lon
input int             InpHtfEma      = 200;           // EMA khung lon
input int             InpAdxPeriod   = 14;            // ADX (khung xu huong) - chu ky
input double          InpAdxMin      = 20;            // ADX toi thieu (duoi muc nay = di ngang)
input int             InpBbPeriod    = 20;            // Bollinger M1 - chu ky
input double          InpBbDev       = 2.0;           // Bollinger M1 - do lech
input int             InpAtrPeriod   = 14;            // ATR (khung xu huong) - chu ky
input double          InpMinAtrPct   = 0.05;          // ATR toi thieu (% gia) - thap hon = cho chet
input double          InpMaxAtrPct   = 0.60;          // ATR toi da (% gia) - cao hon = tin/quet, dung xa
input bool            InpSkipWeekend = true;          // Khong mo chum moi Thu 7, CN (thanh khoan mong)
input int             InpStartHour   = 0;             // Gio bat dau mo chum moi (gio server)
input int             InpEndHour     = 24;            // Gio ket thuc mo chum moi (gio server)

input group "=== TP/SL co gian + lot theo rui ro ==="
input bool   InpFlexExits    = true;   // true = TP/SL co gian theo ATR (false = dung so USD co dinh ben duoi)
input double InpSlAtr        = 1.0;    // SL cach = ATR x he so nay
input double InpRR           = 1.5;    // TP = SL x he so nay (>1 = TP luon lon hon SL)
input double InpTrailPct     = 20;     // Lui bao nhieu % TP tu dinh thi dong
input double InpRiskUSD      = 2.0;    // Rui ro moi lenh (USD) -> bot tu tinh lot. 0 = dung InpLot
input double InpRiskPct      = 0;      // Hoac rui ro % so du (>0 thi dung cai nay thay InpRiskUSD)
input double InpMaxLot       = 0.05;   // Lot toi da bot duoc tu tinh

input group "=== Chot lai (khi tat co gian) ==="
input double InpBasketTP     = 3.0;    // Chot lai ca chum (USD) - moc bat dau doi lai (khi tat co gian)
input double InpTrailGive    = 0.6;    // Lui bao nhieu USD tu dinh thi dong (0 = dong ngay khi dat TP)
input int    InpMaxHoldMin   = 0;      // Giu chum qua X phut -> dong khi >= hoa von (0 = tat)

input group "=== Khac ==="
input long   InpMagic        = 280001; // Magic number

CTrade   trade;
int      emaFastH      = INVALID_HANDLE;
int      emaSlowH      = INVALID_HANDLE;
int      rsiH          = INVALID_HANDLE;
int      htfEmaH       = INVALID_HANDLE;
int      adxH          = INVALID_HANDLE;
int      bbH           = INVALID_HANDLE;
int      atrH          = INVALID_HANDLE;
datetime lastEntryBar  = 0;
datetime lastFailTime  = 0;
double   basketPeak    = 0;
int      lastCount     = -1;
datetime lastHistCheck = 0;
double   cachedClosed  = 0;   // lai/lo da chot hom nay
double   cachedSince   = 0;   // lai/lo da chot tu luc gan bot
bool     testDone      = false;
bool     selfClosed    = false; // true = chum vua do chinh bot dong
bool     initOk        = false; // chi luu trang thai khi khoi dong thanh cong
long     myChartKey    = 0;     // khoa chong 2 bot cung magic + symbol
double   curSL         = 0;     // chot lo chum hien tai (USD)
double   curTP         = 0;     // chot lai chum hien tai (USD)
double   curGive       = 0;     // lui tu dinh (USD)
double   curLot        = 0;     // lot cua chum hien tai

// Trang thai luu lai qua khi tat/bat MT5 (Global Variables)
string   gvPrefix;
datetime cooldownUntil = 0;
bool     targetHit     = false;
int      consecLoss    = 0;
int      stopDayKey    = 0;   // ngay bi dung (yyyymmdd), 0 = khong dung
datetime startTime     = 0;   // luc gan bot (giu nguyen khi khoi dong lai MT5)
double   botPeak       = 0;   // dinh lai cua bot (de tinh sut von)
bool     ddStop        = false;

//+------------------------------------------------------------------+
int DayKey(datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return(d.year * 10000 + d.mon * 100 + d.day);
  }

double GvGet(string name, double def)
  {
   string k = gvPrefix + name;
   if(GlobalVariableCheck(k))
      return(GlobalVariableGet(k));
   return(def);
  }

void GvSet(string name, double v)
  {
   GlobalVariableSet(gvPrefix + name, v);
  }

void SaveState()
  {
   if(!initOk)
      return;
   GvSet("cooldown", (double)cooldownUntil);
   GvSet("target",   targetHit ? 1.0 : 0.0);
   GvSet("consec",   consecLoss);
   GvSet("stopday",  stopDayKey);
   GvSet("botpeak",  botPeak);
   GvSet("ddstop",   ddStop ? 1.0 : 0.0);
   GvSet("cursl",    curSL);
   GvSet("curtp",    curTP);
   GvSet("curgive",  curGive);
   GvSet("curlot",   curLot);
  }

bool IsDemo()
  {
   return(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_REAL);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!IsDemo() && !InpAllowReal)
     {
      Alert("BtcScalpBot: day la tai khoan THAT. Bot chi chay DEMO -> DA DUNG.");
      return(INIT_FAILED);
     }
   if(InpMaxLayers < 1 || InpLot <= 0 || InpBasketSL <= 0 || InpGridStepPct <= 0 ||
      InpBasketTP <= 0 || InpHardSLMult < 1.0 || InpEmaFast >= InpEmaSlow || InpTrailGive < 0 ||
      InpMinScore < 0 || InpMinScore > 4 || InpSlAtr <= 0 || InpRR <= 0 || InpTrailPct < 0 || InpTrailPct >= 100 || InpStartHour < 0 || InpEndHour > 24 || InpStartHour >= InpEndHour)
     {
      Alert("BtcScalpBot: tham so khong hop le (lot/so lenh/chot lo/chot lai/khoang cach > 0, "
            "EMA nhanh < EMA cham, HardSLMult >= 1, MinScore 0..4, gio 0..24).");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpFlexExits && InpRR <= 1.0)
      Print("BtcScalpBot: CANH BAO - InpRR <= 1, TP se khong lon hon SL.");
   if(!InpFlexExits && InpBasketTP - InpTrailGive <= InpBasketSL)
      Print("BtcScalpBot: CANH BAO - lai toi thieu (TP - TrailGive) khong lon hon chot lo (SL).");
   if(InpTrailGive >= InpBasketTP)
      Print("BtcScalpBot: CANH BAO - InpTrailGive >= InpBasketTP, lai chot ra se rat nho.");

   emaFastH = iMA(_Symbol, InpTrendTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowH = iMA(_Symbol, InpTrendTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   rsiH     = iRSI(_Symbol, PERIOD_M1, InpRsiPeriod, PRICE_CLOSE);
   htfEmaH  = iMA(_Symbol, InpHtfTF, InpHtfEma, 0, MODE_EMA, PRICE_CLOSE);
   adxH     = iADX(_Symbol, InpTrendTF, InpAdxPeriod);
   bbH      = iBands(_Symbol, PERIOD_M1, InpBbPeriod, 0, InpBbDev, PRICE_CLOSE);
   atrH     = iATR(_Symbol, InpTrendTF, InpAtrPeriod);
   if(emaFastH == INVALID_HANDLE || emaSlowH == INVALID_HANDLE || rsiH == INVALID_HANDLE ||
      htfEmaH == INVALID_HANDLE || adxH == INVALID_HANDLE || bbH == INVALID_HANDLE || atrH == INVALID_HANDLE)
     {
      Alert("BtcScalpBot: khong tao duoc chi bao (EMA/RSI/ADX/Bollinger/ATR).");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFillingBySymbol(_Symbol);

   // Doc trang thai cu
   gvPrefix      = StringFormat("BSB_%s_%I64d_%I64d_", _Symbol, InpMagic, AccountInfoInteger(ACCOUNT_LOGIN));

   // Chong chay trung: 2 bot cung Magic tren cung symbol se dong lenh cua nhau
   myChartKey = (long)(ChartID() % 1000000007);
   if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(gvPrefix + "lock"))
     {
      long     other = (long)GlobalVariableGet(gvPrefix + "lock");
      datetime hb    = (datetime)(long)GvGet("hb", 0);
      if(other != myChartKey && TimeLocal() - hb < 60)
        {
         Alert(StringFormat("BtcScalpBot: DA CO 1 BOT KHAC dang chay %s voi Magic %I64d tren chart khac. "
                            "Go bot kia ra, hoac doi InpMagic. -> DA DUNG.", _Symbol, InpMagic));
         return(INIT_FAILED);
        }
     }
   GvSet("lock", (double)myChartKey);
   GvSet("hb",   (double)TimeLocal());
   cooldownUntil = (datetime)(long)GvGet("cooldown", 0);
   targetHit     = GvGet("target", 0) > 0.5;
   consecLoss    = (int)GvGet("consec", 0);
   stopDayKey    = (int)GvGet("stopday", 0);
   botPeak       = GvGet("botpeak", 0);
   ddStop        = GvGet("ddstop", 0) > 0.5;

   // Moc tinh lai cua bot: luu lai de tat/bat MT5 khong bi dem lai tu 0
   startTime = (datetime)(long)GvGet("start", 0);
   if(InpResetStats || startTime <= 0)
     {
      startTime = TimeCurrent();
      targetHit = false;
      ddStop    = false;
      botPeak   = 0;
      GvSet("start", (double)startTime);
      SaveState();
     }
   lastHistCheck = 0;

   lastCount = -1; // ep dong bo SL chung o tick dau
   curLot  = NormLot(InpLot);
   curSL   = InpBasketSL;
   curTP   = InpFlexExits ? InpBasketSL * InpRR : InpBasketTP;
   curGive = InpFlexExits ? curTP * InpTrailPct / 100.0 : InpTrailGive;
   // Dang co chum tu truoc khi tat MT5 -> dung lai TP/SL/lot da tinh luc vao lenh
   if(InpFlexExits && GvGet("cursl", 0) > 0)
     {
      curSL   = GvGet("cursl", curSL);
      curTP   = GvGet("curtp", curTP);
      curGive = GvGet("curgive", curGive);
      curLot  = GvGet("curlot", curLot);
     }
   initOk    = true;

   Alert(StringFormat("BtcScalpBot v1.25 DA CHAY tren %s | lot %.2f | toi da %d lenh | %s ... OK",
                      _Symbol, NormLot(InpLot), InpMaxLayers,
                      InpFlexExits ? StringFormat("TP/SL co gian ATR, TP = SL x %.2f", InpRR)
                                   : StringFormat("TP %.2f / SL %.2f USD", InpBasketTP, InpBasketSL)));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   SaveState();
   if(initOk && GlobalVariableCheck(gvPrefix + "lock") &&
      (long)GlobalVariableGet(gvPrefix + "lock") == myChartKey)
     {
      GlobalVariableDel(gvPrefix + "lock");
      GlobalVariableDel(gvPrefix + "hb");
     }
   if(emaFastH != INVALID_HANDLE)
      IndicatorRelease(emaFastH);
   if(emaSlowH != INVALID_HANDLE)
      IndicatorRelease(emaSlowH);
   if(rsiH != INVALID_HANDLE)
      IndicatorRelease(rsiH);
   if(htfEmaH != INVALID_HANDLE)
      IndicatorRelease(htfEmaH);
   if(adxH != INVALID_HANDLE)
      IndicatorRelease(adxH);
   if(bbH != INVALID_HANDLE)
      IndicatorRelease(bbH);
   if(atrH != INVALID_HANDLE)
      IndicatorRelease(atrH);
   Comment("");
  }

//+------------------------------------------------------------------+
double NormLot(double lot)
  {
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(st <= 0)
      st = 0.01;
   lot = MathFloor(lot / st + 1e-9) * st;
   if(lot < mn)
      lot = mn;
   if(mx > 0 && lot > mx)
      lot = mx;
   int digits = (int)MathMax(0.0, MathCeil(-MathLog10(st) - 1e-9));
   return(NormalizeDouble(lot, digits));
  }

//+------------------------------------------------------------------+
// Dem lenh cua bot. dir: 1 = Buy, -1 = Sell, 0 = khong co lenh.
// extreme: Sell -> gia vao cao nhat; Buy -> gia vao thap nhat.
// firstTime: thoi diem lenh dau tien cua chum.
int CountPos(int &dir, double &profit, double &extreme, datetime &firstTime)
  {
   int n = 0;
   dir = 0;
   profit = 0;
   extreme = 0;
   firstTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      n++;
      double   op = PositionGetDouble(POSITION_PRICE_OPEN);
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(firstTime == 0 || ot < firstTime)
         firstTime = ot;
      profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         dir = -1;
         if(extreme == 0 || op > extreme)
            extreme = op;
        }
      else
        {
         dir = 1;
         if(extreme == 0 || op < extreme)
            extreme = op;
        }
     }
   return(n);
  }

//+------------------------------------------------------------------+
// Dong het chum. Tra ve true neu khong con lenh nao cua bot.
bool CloseAll(string why)
  {
   for(int pass = 0; pass < 3; pass++)
     {
      int left = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
            continue;
         if(!trade.PositionClose(t))
           {
            left++;
            Print("Dong lenh ", t, " loi: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
           }
        }
      if(left == 0)
         break;
      Sleep(300);
     }
   int dir;
   double fl, ext;
   datetime ft;
   bool allClosed = (CountPos(dir, fl, ext, ft) == 0);
   Print("BtcScalpBot: dong ca chum - ", why, allClosed ? "" : " (CON LENH CHUA DONG, se thu lai)");
   lastHistCheck = 0; // tinh lai lai/lo trong ngay ngay lap tuc
   basketPeak    = 0;
   selfClosed    = true;
   return(allClosed);
  }

//+------------------------------------------------------------------+
// Cap nhat lai/lo da chot cua RIENG bot (moi 5 giay):
// cachedClosed = hom nay, cachedSince = tu luc gan bot.
void UpdateClosedPL()
  {
   if(lastHistCheck != 0 && TimeCurrent() - lastHistCheck < 5)
      return;
   lastHistCheck = TimeCurrent();

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime dayStart = StructToTime(dt);
   datetime from = (startTime < dayStart) ? startTime : dayStart;
   if(!HistorySelect(from, TimeCurrent() + 60))
      return;

   double today = 0, since = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic)
         continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
         continue;
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      long e = HistoryDealGetInteger(d, DEAL_ENTRY);
      double v = HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      if(e != DEAL_ENTRY_IN)
         v += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP);
      if(t >= dayStart)
         today += v;
      if(t >= startTime)
         since += v;
     }
   cachedClosed = today;
   cachedSince  = since;
  }

//+------------------------------------------------------------------+
// 1 = Buy, -1 = Sell, 0 = chua ro
int TrendDir()
  {
   if(InpDirection == CHI_SELL)
      return(-1);
   if(InpDirection == CHI_BUY)
      return(1);
   double f[1], s[1];
   if(CopyBuffer(emaFastH, 0, 1, 1, f) != 1 || CopyBuffer(emaSlowH, 0, 1, 1, s) != 1)
      return(0);
   double c = iClose(_Symbol, InpTrendTF, 1);
   if(c <= 0)
      return(0);
   if(f[0] < s[0] && c < s[0])
      return(-1);
   if(f[0] > s[0] && c > s[0])
      return(1);
   return(0);
  }

//+------------------------------------------------------------------+
// Doc 1 gia tri chi bao o nen da dong (shift 1). Tra ve false neu chua co du lieu.
bool Buf(int h, int buffer, int shift, double &v)
  {
   double a[1];
   if(CopyBuffer(h, buffer, shift, 1, a) != 1)
      return(false);
   v = a[0];
   return(true);
  }

// ATR khung xu huong (USD gia), 0 neu chua co
double AtrNow()
  {
   double v = 0;
   if(!Buf(atrH, 0, 1, v))
      return(0);
   return(v);
  }

//+------------------------------------------------------------------+
// Cham diem hop luu cho huong dir (0..4). 'info' de hien tren bang.
int EntryScore(int dir, string &info, bool &timing)
  {
   int score = 0;
   info = "";

   // 1. Xu huong lon: gia dong cua H1 cung phia EMA200
   double e200 = 0, cH = iClose(_Symbol, InpHtfTF, 1);
   bool ok1 = Buf(htfEmaH, 0, 1, e200) && cH > 0 && ((dir > 0 && cH > e200) || (dir < 0 && cH < e200));
   if(ok1)
      score++;
   info += ok1 ? "H1+ " : "H1- ";

   // 2. ADX du manh va DI cung huong
   double adx = 0, pdi = 0, mdi = 0;
   bool ok2 = Buf(adxH, 0, 1, adx) && Buf(adxH, 1, 1, pdi) && Buf(adxH, 2, 1, mdi) &&
              adx >= InpAdxMin && ((dir > 0 && pdi > mdi) || (dir < 0 && mdi > pdi));
   if(ok2)
      score++;
   info += StringFormat("ADX%.0f%s ", adx, ok2 ? "+" : "-");

   // 3. RSI M1 vua hoi xong: da qua ban/qua mua roi quay dau
   bool ok3 = false;
   double r[];
   ArraySetAsSeries(r, true);
   double rsiNow = 0;
   if(CopyBuffer(rsiH, 0, 1, 3, r) == 3) // r[0] = nen vua dong
     {
      rsiNow = r[0];
      if(dir > 0)
         ok3 = MathMin(r[1], r[2]) <= InpRsiBuy && r[0] > r[1];
      else
         ok3 = MathMax(r[1], r[2]) >= InpRsiSell && r[0] < r[1];
     }
   if(ok3)
      score++;
   info += StringFormat("RSI%.0f%s ", rsiNow, ok3 ? "+" : "-");

   // 4. Bollinger M1: 3 nen gan nhat co cham dai nguoc huong (mua o day, ban o dinh)
   bool ok4 = false;
   for(int i = 1; i <= 3 && !ok4; i++)
     {
      double up = 0, lo = 0;
      if(!Buf(bbH, 1, i, up) || !Buf(bbH, 2, i, lo))
         break;
      if(dir > 0 && iLow(_Symbol, PERIOD_M1, i) <= lo)
         ok4 = true;
      if(dir < 0 && iHigh(_Symbol, PERIOD_M1, i) >= up)
         ok4 = true;
     }
   if(ok4)
      score++;
   info += ok4 ? "BB+" : "BB-";
   timing = (ok3 || ok4); // phai co it nhat 1 tin hieu canh diem vao (RSI hoac Bollinger)
   return(score);
  }

//+------------------------------------------------------------------+
// Co duoc MO CHUM MOI vao luc nay khong (gio, cuoi tuan)
bool SessionOK(string &why)
  {
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   if(InpSkipWeekend && (d.day_of_week == 0 || d.day_of_week == 6))
     {
      why = "Cuoi tuan - khong mo chum moi";
      return(false);
     }
   if(d.hour < InpStartHour || d.hour >= InpEndHour)
     {
      why = StringFormat("Ngoai gio giao dich (%d-%dh server)", InpStartHour, InpEndHour);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
// Lai/lo (USD) cua 'lot' khi gia di 1.0 (1 USD gia BTC)
double PerUnit(double lot, double price)
  {
   double p = 0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, lot, price, price + 1.0, p))
      return(0);
   return(p);
  }

//+------------------------------------------------------------------+
// Dat 1 SL CHUNG cho ca chum: neu gia cham SL nay thi ca chum lo ~ BasketSL x HardSLMult.
// Day la luoi an toan khi mat mang / tat may; binh thuong bot tu chot lo truoc.
void SyncBasketSL()
  {
   double sumLot = 0, sumLP = 0;
   int    dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      double v = PositionGetDouble(POSITION_VOLUME);
      sumLot += v;
      sumLP  += v * PositionGetDouble(POSITION_PRICE_OPEN);
      dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ? -1 : 1;
     }
   if(sumLot <= 0)
      return;
   double avg = sumLP / sumLot;
   double pu  = PerUnit(sumLot, avg);
   if(pu <= 0)
      return;
   double dist = curSL * InpHardSLMult / pu;

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
      return;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point * 1.5;
   double sl;
   if(dir > 0)
     {
      sl = avg - dist;
      if(sl > tk.bid - minDist)
         sl = tk.bid - minDist;
     }
   else
     {
      sl = avg + dist;
      if(sl < tk.ask + minDist)
         sl = tk.ask + minDist;
     }
   sl = NormalizeDouble(sl, _Digits);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      double cur = PositionGetDouble(POSITION_SL);
      if(MathAbs(cur - sl) < _Point * 2)
         continue;
      if(!trade.PositionModify(t, sl, PositionGetDouble(POSITION_TP)))
         Print("BtcScalpBot: dat SL chung loi ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
// Tinh lot + TP/SL (USD) cho chum moi. Tra ve false (kem ly do) neu khong nen vao.
//  - Co gian: SL cach gia = ATR x InpSlAtr, TP = SL x InpRR -> thi truong manh dat xa, yeu dat gan.
//  - Lot: rui ro co dinh (USD hoac % so du) / khoang SL. Lot san toi thieu ma van qua rui ro -> bo.
bool PlanBasket(double price, double atr, string &why)
  {
   double riskUsd = (InpRiskPct > 0) ? AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0 : InpRiskUSD;
   double pu1 = PerUnit(1.0, price); // USD cua 1 lot khi gia di 1.0
   if(pu1 <= 0)
     {
      why = "Khong tinh duoc gia tri lot";
      return(false);
     }
   if(!InpFlexExits)
     {
      curLot  = NormLot(InpLot);
      curSL   = InpBasketSL;
      curTP   = InpBasketTP;
      curGive = InpTrailGive;
      return(true);
     }
   double dist = atr * InpSlAtr;             // khoang SL theo gia
   if(dist <= 0)
     {
      why = "Chua co ATR";
      return(false);
     }
   double lot = NormLot(InpLot);
   if(riskUsd > 0)
      lot = NormLot(MathMin(riskUsd / (dist * pu1), InpMaxLot));
   double slUsd = lot * dist * pu1;           // lo thuc te neu cham SL
   if(slUsd > InpBasketSL)
     {
      why = StringFormat("SL can %.2f USD > toi da %.2f (bien dong lon / lot toi thieu qua to)", slUsd, InpBasketSL);
      return(false);
     }
   curLot  = lot;
   curSL   = slUsd;
   curTP   = slUsd * InpRR;
   curGive = curTP * InpTrailPct / 100.0;
   return(true);
  }

//+------------------------------------------------------------------+
bool OpenOrder(int dir, string cmt)
  {
   if(TimeCurrent() - lastFailTime < 10) // vua loi -> doi 10s, tranh spam lenh
      return(false);
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
      return(false);
   double lot   = (curLot > 0) ? curLot : NormLot(InpLot);
   double price = (dir > 0) ? tk.ask : tk.bid;

   // Kiem tra ky quy truoc khi vao
   double margin = 0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9)
     {
      Print("BtcScalpBot: khong du ky quy de vao lenh.");
      lastFailTime = TimeCurrent();
      return(false);
     }

   // SL tam cho rieng lenh nay; ngay sau do SyncBasketSL() se dat SL chung cho ca chum
   double pu = PerUnit(lot, price);
   if(pu <= 0)
     {
      Print("BtcScalpBot: khong tinh duoc rui ro, bo qua lenh.");
      lastFailTime = TimeCurrent();
      return(false);
     }
   double dist    = curSL * InpHardSLMult / pu;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(dist < minDist * 1.5)
      dist = minDist * 1.5;
   double sl = NormalizeDouble((dir > 0) ? price - dist : price + dist, _Digits);

   bool ok = (dir > 0) ? trade.Buy(lot, _Symbol, 0, sl, 0, cmt)
             : trade.Sell(lot, _Symbol, 0, sl, 0, cmt);
   uint rc = trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
     {
      Print("BtcScalpBot: vao lenh loi ", rc, " ", trade.ResultRetcodeDescription());
      lastFailTime = TimeCurrent();
      return(false);
     }
   Print("BtcScalpBot: da vao ", cmt, " lot ", DoubleToString(lot, 2), " SL ", DoubleToString(sl, _Digits));
   SyncBasketSL();
   return(true);
  }

//+------------------------------------------------------------------+
void Panel(string st, int n, double fl, double dayPL, double spreadPct)
  {
   Comment(StringFormat(
              "BtcScalpBot v1.25 (%s)\n"
              "Trang thai: %s\n"
              "So lenh: %d / %d   (lot %.2f)\n"
              "Lai/lo dang mo: %.2f USD   (chot lai +%.2f, lui %.2f | chot lo -%.2f)\n"
              "Dinh lai chum: %.2f USD\n"
              "Lai/lo hom nay: %.2f USD   (dung o -%.2f)\n"
              "Thua lien tiep: %d / %d\n"
              "Spread: %.3f%%   (toi da %.3f%%)\n"
              "Bot lai tu luc gan: %.2f USD   (muc tieu +%.2f)\n"
              "Sut tu dinh: %.2f USD   (dung han o %.2f)",
              IsDemo() ? "DEMO" : "THAT", st, n, InpMaxLayers, curLot, fl, curTP, curGive, curSL,
              basketPeak, dayPL, InpDailyLoss, consecLoss, InpMaxConsecLoss, spreadPct, InpMaxSpreadPct,
              cachedSince + fl, InpTarget,
              MathMax(0.0, botPeak - (cachedSince + fl)), InpMaxDrawdown));
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   GvSet("hb", (double)TimeLocal()); // bao "toi dang chay" cho khoa chong trung
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.bid <= 0 || tk.ask <= 0)
      return;
   double mid       = (tk.bid + tk.ask) / 2.0;
   double spreadPct = (tk.ask - tk.bid) / mid * 100.0;

   int      dir;
   double   fl, ext;
   datetime firstTime;
   int      n = CountPos(dir, fl, ext, firstTime);

   // So lenh thay doi (vao them / san cat SL / khoi dong lai) -> dong bo SL chung
   if(n != lastCount)
     {
      if(n > 0)
         SyncBasketSL();
      else
        {
         basketPeak = 0;
         // Chum bien mat ma bot khong tu dong (san cat SL khi mat mang, hoac dong tay)
         // -> coi nhu 1 lan thua: nghi + tinh thua lien tiep, khong vao lai ngay.
         if(lastCount > 0 && !selfClosed)
           {
            cooldownUntil = TimeCurrent() + InpCooldownMin * 60;
            consecLoss++;
            if(InpMaxConsecLoss > 0 && consecLoss >= InpMaxConsecLoss)
               stopDayKey = DayKey(TimeCurrent());
            SaveState();
            Print("BtcScalpBot: chum bi dong ben ngoai (SL san / dong tay) -> nghi ", InpCooldownMin, " phut.");
           }
        }
      selfClosed = false;
      lastCount = n;
     }

   UpdateClosedPL();
   double dayPL = cachedClosed + fl;
   double botPL = cachedSince + fl;   // chi tinh lenh cua bot, khong tinh lenh tay
   int    today = DayKey(TimeCurrent());

   // Sang ngay moi -> mo khoa
   if(stopDayKey != 0 && stopDayKey != today)
     {
      stopDayKey = 0;
      consecLoss = 0;
      SaveState();
     }

   // 1. Dat muc tieu -> dung han
   if(!targetHit && botPL >= InpTarget)
     {
      CloseAll("DA DAT MUC TIEU");
      targetHit = true;
      SaveState();
      Alert(StringFormat("BtcScalpBot: bot da lai %.2f USD, DAT MUC TIEU -> dung. "
                         "Muon chay tiep: dat InpResetStats = true (1 lan).", botPL));
     }
   if(targetHit)
     {
      if(n > 0)
         CloseAll("DA DAT MUC TIEU (dong not)");
      Panel("DA DAT MUC TIEU - bot dung", n, fl, dayPL, spreadPct);
      return;
     }

   // 1b. Sut von tu dinh (chong chay tai khoan) -> dung han
   if(botPL > botPeak)
     {
      botPeak = botPL;
      if(n == 0)
         GvSet("botpeak", botPeak);
     }
   if(!ddStop && InpMaxDrawdown > 0 && botPeak - botPL >= InpMaxDrawdown)
     {
      CloseAll(StringFormat("SUT VON %.2f USD tu dinh", botPeak - botPL));
      ddStop = true;
      SaveState();
      Alert(StringFormat("BtcScalpBot: lai bot tut %.2f USD tu dinh -> DUNG HAN. Xem lai thong so, "
                         "roi dat InpResetStats = true (1 lan) de chay lai.", botPeak - botPL));
     }
   if(ddStop)
     {
      if(n > 0)
         CloseAll("dang dung do sut von (dong not)");
      Panel("DUNG HAN: sut von qua InpMaxDrawdown", n, fl, dayPL, spreadPct);
      return;
     }

   // 2. Chot lo ca chum
   if(n > 0 && fl <= -curSL)
     {
      CloseAll(StringFormat("cham chot lo ca chum (%.2f USD)", fl));
      cooldownUntil = TimeCurrent() + InpCooldownMin * 60;
      consecLoss++;
      if(InpMaxConsecLoss > 0 && consecLoss >= InpMaxConsecLoss)
        {
         stopDayKey = today;
         Print("BtcScalpBot: thua ", consecLoss, " chum lien tiep -> nghi den hom sau.");
        }
      SaveState();
      Panel("Vua chot lo ca chum, dang nghi", n, fl, dayPL, spreadPct);
      return;
     }

   // 3. Lo toi da trong ngay
   if(stopDayKey == 0 && dayPL <= -InpDailyLoss)
     {
      stopDayKey = today;
      SaveState();
     }
   if(stopDayKey != 0)
     {
      if(n > 0)
         CloseAll("dang trong ngay nghi");
      Panel(StringFormat("DUNG HOM NAY: %s (mai chay lai)",
                         (InpMaxConsecLoss > 0 && consecLoss >= InpMaxConsecLoss) ? "thua lien tiep" : "cham lo toi da ngay"),
            n, fl, dayPL, spreadPct);
      return;
     }

   // 4. Chot lai ca chum (co doi lai)
   if(n > 0)
     {
      if(fl > basketPeak)
         basketPeak = fl;
      if(basketPeak >= curTP)
        {
         double lockAt = MathMax(basketPeak - curGive, curTP * 0.5);
         if(curGive <= 0 || fl <= lockAt)
           {
            if(CloseAll(StringFormat("chot lai ca chum (+%.2f USD, dinh %.2f)", fl, basketPeak)))
              {
               consecLoss = 0;
               SaveState();
              }
            Panel("Vua chot lai", n, fl, dayPL, spreadPct);
            return;
           }
         Panel(StringFormat("Dang doi lai: dinh %.2f, dong neu lui ve %.2f", basketPeak, lockAt),
               n, fl, dayPL, spreadPct);
         return; // dang co lai thi khong nhoi them
        }

      // 5. Giu qua lau -> dong khi hoa von
      if(InpMaxHoldMin > 0 && firstTime > 0 &&
         TimeCurrent() - firstTime >= InpMaxHoldMin * 60 && fl >= 0)
        {
         CloseAll(StringFormat("giu qua %d phut, dong hoa von (%.2f USD)", InpMaxHoldMin, fl));
         Panel("Vua dong hoa von do giu lau", n, fl, dayPL, spreadPct);
         return;
        }
     }

   // Kiem tra co duoc phep giao dich khong (nguyen nhan hay gap cua "bot khong vao lenh")
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Panel("CHUA BAT 'Algo Trading' (nut tren thanh cong cu / tick Allow Algo Trading)", n, fl, dayPL, spreadPct);
      return;
     }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
     {
      Panel("San dang dong / han che giao dich symbol nay", n, fl, dayPL, spreadPct);
      return;
     }

   // 6. Lenh thu (chi demo)
   if(InpTestOrder && !testDone && n == 0)
     {
      testDone = true;
      if(!IsDemo())
        {
         Print("BtcScalpBot: bo qua lenh TEST vi khong phai tai khoan demo.");
        }
      else
        {
         int d = TrendDir();
         if(d == 0)
            d = -1;
         OpenOrder(d, "TEST");
         Panel("Da gui lenh TEST", n, fl, dayPL, spreadPct);
         return;
        }
     }

   // Bo loc
   if(TimeCurrent() < cooldownUntil)
     {
      int left = (int)((cooldownUntil - TimeCurrent()) / 60) + 1;
      Panel(StringFormat("Dang nghi sau chot lo (con ~%d phut)", left), n, fl, dayPL, spreadPct);
      return;
     }
   if(spreadPct > InpMaxSpreadPct)
     {
      Panel("Spread qua cao, cho...", n, fl, dayPL, spreadPct);
      return;
     }

   // Loc bien dong: ATR qua cao = tin tuc / quet -> khong vao, khong nhoi
   double atr    = AtrNow();
   double atrPct = (atr > 0) ? atr / mid * 100.0 : 0;
   if(atr <= 0)
     {
      Panel("Dang tai du lieu chi bao...", n, fl, dayPL, spreadPct);
      return;
     }
   if(atrPct > InpMaxAtrPct)
     {
      Panel(StringFormat("Bien dong qua manh (ATR %.2f%% > %.2f%%), dung vao/nhoi", atrPct, InpMaxAtrPct),
            n, fl, dayPL, spreadPct);
      return;
     }

   string st = "Dang cho tin hieu...";
   if(n == 0)
     {
      datetime bar = iTime(_Symbol, PERIOD_M1, 0);
      string why = "";
      if(bar == lastEntryBar)
         st = "Dang cho nen M1 moi...";
      else
         if(!SessionOK(why))
            st = why;
         else
            if(atrPct < InpMinAtrPct)
               st = StringFormat("Thi truong qua im (ATR %.2f%% < %.2f%%), cho...", atrPct, InpMinAtrPct);
            else
              {
               int    d = 0, sc = 0;
               string info = "";
               if(InpDirection == HAI_CHIEU)
                 {
                  // Cham diem ca 2 chieu, chon chieu manh hon (phai co tin hieu canh diem vao)
                  string ib = "", isl = "";
                  bool   tb = false, ts = false;
                  int    sb = EntryScore(1, ib, tb), ss = EntryScore(-1, isl, ts);
                  int    eb = tb ? sb : -1, es = ts ? ss : -1;
                  if(eb >= InpMinScore && eb > es)
                    {
                     d = 1;
                     sc = sb;
                     info = ib;
                    }
                  else
                     if(es >= InpMinScore && es > eb)
                       {
                        d = -1;
                        sc = ss;
                        info = isl;
                       }
                     else
                        st = StringFormat("Cho tin hieu (can %d/4) | BUY %d: %s | SELL %d: %s",
                                          InpMinScore, sb, ib, ss, isl);
                 }
               else
                 {
                  int td = TrendDir();
                  bool tm = false;
                  if(td == 0)
                     st = "Chua ro xu huong (EMA M15), cho...";
                  else
                    {
                     sc = EntryScore(td, info, tm);
                     if(tm && sc >= InpMinScore)
                        d = td;
                     else
                        st = StringFormat("Xu huong %s, diem %d/4 (can %d + RSI/BB): %s",
                                          td > 0 ? "TANG" : "GIAM", sc, InpMinScore, info);
                    }
                 }
               if(d != 0)
                 {
                  string pwhy = "";
                  if(!PlanBasket(d > 0 ? tk.ask : tk.bid, atr, pwhy))
                     st = pwhy;
                  else
                     if(OpenOrder(d, StringFormat("Scalp %s 1 (%d/4)", d > 0 ? "BUY" : "SELL", sc)))
                       {
                        lastEntryBar = bar;
                        basketPeak   = 0;
                        SaveState();
                        st = StringFormat("Da vao %s, diem %d/4: %s", d > 0 ? "BUY" : "SELL", sc, info);
                       }
                 }
              }
     }
   else
      if(n < InpMaxLayers)
        {
         double step = MathMax(mid * InpGridStepPct / 100.0, atr * InpGridAtrMult);
         string num  = IntegerToString(n + 1);
         if(dir < 0 && tk.ask >= ext + step)
            OpenOrder(-1, "Scalp SELL " + num);
         else
            if(dir > 0 && tk.bid <= ext - step)
               OpenOrder(1, "Scalp BUY " + num);
         st = StringFormat("Dang giu %d lenh %s, nhoi tiep neu gia nguoc %.0f USD",
                           n, dir < 0 ? "SELL" : "BUY", step);
        }
      else
         st = "Du so lenh toi da, cho chot lai / chot lo";

   Panel(st, n, fl, dayPL, spreadPct);
  }
//+------------------------------------------------------------------+
