//+------------------------------------------------------------------+
//| LuoiVang_XAU.mq5                                                 |
//| Bot luoi (grid) cho XAUUSDm - MT5 Exness                         |
//|                                                                  |
//| Cach chay:                                                       |
//|  - Vao lenh dau theo xu huong EMA50 khung M1.                    |
//|  - Gia di nguoc -> nhoi them lenh, khoang cach nhan doi dan      |
//|    (5 -> 10 -> 20 ... gia), lot cong them 0.01 moi tang.         |
//|  - Chot ca chuoi khi gia cach gia trung binh 100 pip (1 gia),    |
//|    hoac lai du so tien, hoac khi lai bi hut lai (bao ve lai).    |
//|  - Lo cua chuoi cham X% so du -> mo lenh nguoc chieu de KHOA     |
//|    (hedge). Khoa thong minh: lenh khoa co lai thi chot, gia di    |
//|    tiep thi khoa lai; tong (chuoi + khoa + da chot) >= 0 -> dong.|
//|  - Them so voi ban mau: cat lo cung theo % so du (mac dinh 40%). |
//| Moi chuoi BUY / SELL co Magic rieng. Khong dat SL/TP tren san    |
//| (bot tu dong lenh) -> khong bi loi "bad stops".                  |
//| 1 pip = 0.01 gia vang (500 pip = 5 gia).                          |
//| v1.20: DCA toi da 3 lenh, KHONG gap lot (moi lenh 0.01),         |
//|        gia chay nhanh -> nghi 1 tieng roi chay tiep,             |
//|        lo 20 USD hoac lai 30 USD trong ngay -> dong het, dung     |
//|        den ngay hom sau.                                         |
//| v1.10 toi uu:                                                    |
//|  - Loc xu huong lon EMA200 H1: lenh dau phai thuan ca M1 va H1.  |
//|  - Khoang luoi tu gian theo bien dong (ATR H1) khi vang chay manh.|
//|  - Khong vao lenh khi spread cao, gio qua dem (doi phi), toi T6. |
//|  - Khoa som hon (20%), cat lo cung 35%, toi da 8 lenh/chuoi.      |
//+------------------------------------------------------------------+
#property copyright "LuoiVang_XAU"
#property version   "1.20"
#property description "Grid XAUUSDm: vao theo EMA50 M1, nhoi luoi gian cach nhan doi, khoa hedge thong minh."

#include <Trade/Trade.mqh>

//--- CHUNG
input group "=== CHUNG ==="
input long   InpMagicBuy      = 230001;  // Magic chuoi BUY
input long   InpMagicSell     = 230002;  // Magic chuoi SELL
input double InpPipPrice      = 0.01;    // 1 pip = bao nhieu gia (vang: 0.01)
input int    InpSlippagePts   = 50;      // Truot gia toi da (points)
input bool   InpAllowBuy      = true;    // Cho phep chuoi BUY
input bool   InpAllowSell     = true;    // Cho phep chuoi SELL

//--- XU HUONG
input group "=== XU HUONG / LENH DAU ==="
input ENUM_TIMEFRAMES InpTrendTF   = PERIOD_M1; // Khung xu huong
input int             InpEmaPeriod = 50;        // Chu ky EMA
input double          InpStartLot  = 0.01;      // Lot lenh dau
input bool            InpUseHTF    = true;      // Loc them xu huong lon
input ENUM_TIMEFRAMES InpHTF       = PERIOD_H1; // Khung xu huong lon
input int             InpHTFEma    = 200;       // EMA xu huong lon

//--- BO LOC THOI GIAN / SPREAD
input group "=== BO LOC VAO LENH DAU ==="
input double InpMaxSpreadPips = 40;      // Spread toi da (pip) = 0.40 gia
input bool   InpUseSession    = true;    // Tranh gio qua dem (spread rong)
input int    InpSkipFromHour  = 23;      // Khong vao lenh dau tu gio (gio may chu)
input int    InpSkipToHour    = 1;       // ... den gio
input int    InpFridayStop    = 20;      // Thu 6 tu gio nay khong mo chuoi moi (-1 = tat)

//--- LUOI
input group "=== LUOI (GRID) ==="
input bool   InpUseGrid        = true;   // Bat luoi (nhoi lenh nguoc gia)
input double InpGridPips       = 400;    // Khoang cach lenh (pip) = 4 gia
input double InpGridMult       = 1.0;    // He so nhan khoang cach moi lenh
input double InpGridATRMult    = 0.0;    // Khoang luoi toi thieu = ATR(H1) x he so (0 = tat)
input int    InpMaxOrders      = 3;      // So lenh toi da moi chuoi (DCA)
input int    InpGridMinMinutes = 0;      // Cach nhau toi thieu giua 2 lenh luoi (phut)
input double InpLotAdd         = 0.0;    // Lot cong them moi tang (0 = khong gap lot)
input int    InpOrdersPerLevel = 1;      // So lenh moi tang truoc khi tang lot
input double InpMaxLot         = 0.10;   // Lot toi da 1 lenh

//--- CHOT LOI
input group "=== CHOT LOI CHUOI ==="
input double InpBasketTPPips    = 100;   // Chot khi cach gia TB (pip) = 1 gia
input double InpBasketTPMoney   = 20.0;  // Chot khi lai du (USD), 0 = tat
input double InpProtectFrom     = 2.0;   // Bao ve lai tu (USD), 0 = tat
input double InpProtectRetrace  = 1.0;   // Lai bi hut lai bao nhieu thi chot (USD)

//--- ATR
input group "=== LOC BIEN DONG (ATR) ==="
input bool   InpUseATR      = false;     // Chi vao lenh dau khi ATR thap
input int    InpATRPeriod   = 14;        // Chu ky ATR (khung M1)
input double InpATRMaxPips  = 80;        // ATR toi da (pip)

//--- KHOA
input group "=== KHOA LENH (HEDGE) ==="
input bool   InpUseLock           = false;  // Bat khoa khi lo nang
input double InpLockDDPct         = 20.0;   // Lo chuoi cham % so du -> khoa
input double InpLockCloseResult   = 0.0;    // Tong ket qua de dong ca chuoi bi khoa (USD)
input int    InpLockMaxHours      = 0;      // Khoa toi da bao nhieu gio roi dong het (0 = khong gioi han)
input bool   InpSmartLock         = true;   // Khoa thong minh (chot lai lenh khoa roi khoa lai)
input double InpLockRealizeFrom   = 1.0;    // Chot lenh khoa khi lai tu (USD moi 0.01 lot)
input double InpLockRealizeBack   = 0.5;    // ... va lai bi hut lai (USD moi 0.01 lot)
input double InpReLockPips        = 350;    // Sau khi chot, gia di nguoc them X pip thi khoa lai
input double InpCloseProfitInLock = 1.0;    // Dang khoa: dong lenh chuoi co lai tu (USD moi 0.01 lot), 0 = tat

//--- AN TOAN
input group "=== AN TOAN ==="
input double InpBasketStopPct = 35.0;    // Cat lo cung: tong lo chuoi cham % so du (0 = tat - KHONG nen)
input double InpDailyGoal     = 30.0;    // Lai du X USD trong ngay -> dong het, dung den mai (0 = tat)
input double InpDailyMaxLoss  = 20.0;    // Lo X USD trong ngay (tinh ca lenh dang mo) -> dong het, dung den mai (0 = tat)

//--- GIA CHAY NHANH
input group "=== NGHI KHI GIA CHAY NHANH ==="
input bool   InpUseFastPause   = true;   // Bat nghi khi gia chay nhanh
input double InpFastMovePips   = 500;    // Gia chay qua X pip (= 5 gia) ...
input int    InpFastMoveMinutes = 15;    // ... trong vong X phut
input int    InpPauseMinutes   = 60;     // -> nghi vao lenh moi / nhoi lenh X phut
input string InpCloseAllTime  = "";      // Dong het luc HH:MM (gio may chu), trong = tat
input bool   InpShowPanel     = true;    // Hien bang thong tin

//+------------------------------------------------------------------+
struct Basket
  {
   int      count;
   double   lots;
   double   avg;
   double   extreme;   // BUY: gia thap nhat, SELL: gia cao nhat
   double   profit;
   datetime lastTime;
  };

struct SideState
  {
   bool     isBuy;
   long     magic;
   long     lockMagic;
   double   peak;        // dinh lai cua chuoi (bao ve lai)
   double   lockPeak;    // dinh lai lenh khoa / 0.01 lot
   double   realized;    // lai/lo da chot trong chu ky khoa
   double   unlockPrice; // gia luc chot lenh khoa
   datetime lockStart;
  };

CTrade    trade;
int       hEma = INVALID_HANDLE, hAtr = INVALID_HANDLE, hHtf = INVALID_HANDLE, hAtrH1 = INVALID_HANDLE;
double    gPip;
SideState gBuy, gSell;
datetime  gLastBar = 0;
bool      gStoppedToday = false;
datetime  gStopDay = 0;
datetime  gPauseUntil = 0;   // nghi do gia chay nhanh
string    gStatus = "Dang khoi dong...";

void ShowPanel(const double dayPL);

//+------------------------------------------------------------------+
string GvName(const SideState &s, const string key)
  {
   return "LV_" + _Symbol + "_" + IntegerToString(s.magic) + "_" + key;
  }
void SaveState(const SideState &s)
  {
   GlobalVariableSet(GvName(s, "real"),  s.realized);
   GlobalVariableSet(GvName(s, "unl"),   s.unlockPrice);
   GlobalVariableSet(GvName(s, "start"), (double)s.lockStart);
  }
void LoadState(SideState &s)
  {
   s.realized    = GlobalVariableCheck(GvName(s, "real"))  ? GlobalVariableGet(GvName(s, "real"))  : 0;
   s.unlockPrice = GlobalVariableCheck(GvName(s, "unl"))   ? GlobalVariableGet(GvName(s, "unl"))   : 0;
   s.lockStart   = GlobalVariableCheck(GvName(s, "start")) ? (datetime)GlobalVariableGet(GvName(s, "start")) : 0;
   s.peak = 0; s.lockPeak = 0;
  }
void ResetCycle(SideState &s)
  {
   s.peak = 0; s.lockPeak = 0; s.realized = 0; s.unlockPrice = 0; s.lockStart = 0;
   SaveState(s);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   string s = _Symbol;
   StringToUpper(s);
   if(StringFind(s, "XAU") < 0 && StringFind(s, "GOLD") < 0)
     {
      Alert("LuoiVang_XAU: bot nay chi chay tren XAUUSDm (vang). Chart hien tai: ", _Symbol);
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMagicBuy == InpMagicSell || InpMaxOrders < 1 || InpGridPips <= 0 || InpGridMult < 1.0 || InpPipPrice <= 0)
     {
      Alert("LuoiVang_XAU: thong so sai (Magic BUY/SELL phai khac nhau, MaxOrders >= 1, GridPips > 0, GridMult >= 1)");
      return(INIT_PARAMETERS_INCORRECT);
     }
   gPip = InpPipPrice;

   hEma = iMA(_Symbol, InpTrendTF, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hAtr = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   hHtf   = iMA(_Symbol, InpHTF, InpHTFEma, 0, MODE_EMA, PRICE_CLOSE);
   hAtrH1 = iATR(_Symbol, PERIOD_H1, 14);
   if(hEma == INVALID_HANDLE || hAtr == INVALID_HANDLE || hHtf == INVALID_HANDLE || hAtrH1 == INVALID_HANDLE)
     {
      Alert("LuoiVang_XAU: khong tao duoc chi bao EMA/ATR");
      return(INIT_FAILED);
     }

   trade.SetDeviationInPoints((ulong)InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);

   gBuy.isBuy  = true;  gBuy.magic  = InpMagicBuy;  gBuy.lockMagic  = InpMagicBuy  + 100000;
   gSell.isBuy = false; gSell.magic = InpMagicSell; gSell.lockMagic = InpMagicSell + 100000;
   LoadState(gBuy);
   LoadState(gSell);

   Alert("LuoiVang_XAU v1.20 DA CHAY tren ", _Symbol, " - OK");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(hEma != INVALID_HANDLE) IndicatorRelease(hEma);
   if(hAtr != INVALID_HANDLE) IndicatorRelease(hAtr);
   if(hHtf != INVALID_HANDLE) IndicatorRelease(hHtf);
   if(hAtrH1 != INVALID_HANDLE) IndicatorRelease(hAtrH1);
   Comment("");
  }

//+------------------------------------------------------------------+
void GetBasket(const long magic, Basket &b)
  {
   b.count = 0; b.lots = 0; b.avg = 0; b.extreme = 0; b.profit = 0; b.lastTime = 0;
   double sum = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      bool   buy   = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      b.count++;
      b.lots   += vol;
      sum      += price * vol;
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(buy) { if(b.extreme == 0 || price < b.extreme) b.extreme = price; }
      else    { if(price > b.extreme) b.extreme = price; }
      datetime tm = (datetime)PositionGetInteger(POSITION_TIME);
      if(tm > b.lastTime) b.lastTime = tm;
     }
   if(b.lots > 0) b.avg = sum / b.lots;
  }

double NormLot(double lot, const double cap)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   double c = MathMin(vmax, MathMax(cap, vmin));
   lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < vmin) lot = vmin;
   if(lot > c)    lot = c;
   int digits = (int)MathMax(0.0, MathCeil(-MathLog10(step) - 1e-9));
   return NormalizeDouble(lot, digits);
  }

bool Open(const bool buy, const double lot, const long magic, const string cmt)
  {
   double price = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double margin = 0;
   if(OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      gStatus = "Khong du ky quy de vao lenh " + DoubleToString(lot, 2);
      return false;
     }
   trade.SetExpertMagicNumber((ulong)magic);
   bool ok = buy ? trade.Buy(lot, _Symbol, 0, 0, 0, cmt) : trade.Sell(lot, _Symbol, 0, 0, 0, cmt);
   uint rc = trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
     {
      Print("Loi vao lenh ", cmt, " lot ", lot, ": ", rc, " ", trade.ResultRetcodeDescription());
      return false;
     }
   Print("Vao lenh ", cmt, " lot ", DoubleToString(lot, 2), " gia ", DoubleToString(trade.ResultPrice(), _Digits));
   return true;
  }

void CloseMagic(const long magic, const string why)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(!trade.PositionClose(t, (ulong)InpSlippagePts))
         Print("Loi dong lenh #", t, ": ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
     }
   Print("Dong lenh magic ", magic, ": ", why);
  }

void CloseSide(SideState &s, const string why)
  {
   CloseMagic(s.magic, why);
   CloseMagic(s.lockMagic, why);
   ResetCycle(s);
  }

//+------------------------------------------------------------------+
int Trend()
  {
   double e[];
   if(CopyBuffer(hEma, 0, 1, 1, e) < 1) return 0;
   double c = iClose(_Symbol, InpTrendTF, 1);
   if(c <= 0) return 0;
   int t = (c > e[0]) ? 1 : -1;
   if(InpUseHTF)
     {
      double h[];
      if(CopyBuffer(hHtf, 0, 1, 1, h) < 1) return 0;
      int ht = (c > h[0]) ? 1 : -1;
      if(ht != t) return 0;   // M1 va H1 nguoc nhau -> dung ngoai
     }
   return t;
  }

//+------------------------------------------------------------------+
//| Dieu kien phu de mo chuoi moi: spread, gio qua dem, cuoi tuan     |
//+------------------------------------------------------------------+
bool EntryFilterOk(string &why)
  {
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(InpMaxSpreadPips > 0 && spread > InpMaxSpreadPips * gPip)
     { why = "spread cao (" + DoubleToString(spread, _Digits) + ")"; return false; }
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpUseSession)
     {
      bool skip = (InpSkipFromHour <= InpSkipToHour)
                  ? (dt.hour >= InpSkipFromHour && dt.hour < InpSkipToHour)
                  : (dt.hour >= InpSkipFromHour || dt.hour < InpSkipToHour);
      if(skip) { why = "gio qua dem - nghi mo chuoi moi"; return false; }
     }
   if(InpFridayStop >= 0 && dt.day_of_week == 5 && dt.hour >= InpFridayStop)
     { why = "toi thu 6 - nghi mo chuoi moi"; return false; }
   why = "";
   return true;
  }

//+------------------------------------------------------------------+
//| Gia chay qua X pip trong Y phut gan nhat -> nghi Z phut           |
//+------------------------------------------------------------------+
bool FastMovePause()
  {
   if(!InpUseFastPause) return false;
   if(TimeCurrent() < gPauseUntil) return true;
   int bars = MathMax(1, InpFastMoveMinutes);
   int hi = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, bars, 0);
   int lo = iLowest(_Symbol, PERIOD_M1, MODE_LOW, bars, 0);
   if(hi < 0 || lo < 0) return false;
   double range = iHigh(_Symbol, PERIOD_M1, hi) - iLow(_Symbol, PERIOD_M1, lo);
   if(range >= InpFastMovePips * gPip)
     {
      gPauseUntil = TimeCurrent() + InpPauseMinutes * 60;
      Print("Gia chay nhanh: ", DoubleToString(range, _Digits), " trong ", bars,
            " phut -> nghi den ", TimeToString(gPauseUntil, TIME_DATE | TIME_MINUTES));
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Khoang cach luoi co ban: max(GridPips, ATR H1 x he so)            |
//+------------------------------------------------------------------+
double GridBase()
  {
   double base = InpGridPips * gPip;
   if(InpGridATRMult > 0)
     {
      double a[];
      if(CopyBuffer(hAtrH1, 0, 1, 1, a) == 1 && a[0] * InpGridATRMult > base)
         base = a[0] * InpGridATRMult;
     }
   return base;
  }

bool AtrOk()
  {
   if(!InpUseATR) return true;
   double a[];
   if(CopyBuffer(hAtr, 0, 1, 1, a) < 1) return false;
   return (a[0] <= InpATRMaxPips * gPip);
  }

double TodayClosedPL()
  {
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(dayStart == 0 || !HistorySelect(dayStart, TimeCurrent() + 60)) return 0;
   double pl = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      long m = HistoryDealGetInteger(d, DEAL_MAGIC);
      if(m != gBuy.magic && m != gSell.magic && m != gBuy.lockMagic && m != gSell.lockMagic) continue;
      pl += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP)
          + HistoryDealGetDouble(d, DEAL_COMMISSION);
     }
   return pl;
  }

bool IsCloseAllTime()
  {
   if(StringLen(InpCloseAllTime) < 4) return false;
   string parts[];
   if(StringSplit(InpCloseAllTime, ':', parts) != 2) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour == (int)StringToInteger(parts[0]) && dt.min == (int)StringToInteger(parts[1]));
  }

//+------------------------------------------------------------------+
//| Dong cac lenh cua chuoi dang co lai (khi dang khoa)              |
//+------------------------------------------------------------------+
void CloseProfitableInLock(SideState &s)
  {
   if(InpCloseProfitInLock <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != s.magic) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double pr  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(vol > 0 && pr / (vol / 0.01) >= InpCloseProfitInLock)
        {
         if(trade.PositionClose(t, (ulong)InpSlippagePts))
           {
            s.realized += pr;
            SaveState(s);
            Print("Dang khoa: chot lenh chuoi co lai #", t, " +", DoubleToString(pr, 2));
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Xu ly 1 chuoi (BUY hoac SELL)                                     |
//+------------------------------------------------------------------+
void ProcessSide(SideState &s, const int trend, const bool newBar, const bool canEnter, const bool canGrid)
  {
   Basket b, l;
   GetBasket(s.magic, b);
   GetBasket(s.lockMagic, l);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   string nm  = s.isBuy ? "BUY" : "SELL";

   //--- Khong co lenh chuoi
   if(b.count == 0)
     {
      if(l.count > 0) CloseMagic(s.lockMagic, "chuoi " + nm + " da het lenh -> dong lenh khoa");
      if(s.realized != 0 || s.unlockPrice != 0) ResetCycle(s);
      bool allow = s.isBuy ? InpAllowBuy : InpAllowSell;
      if(allow && canEnter && newBar && trend == (s.isBuy ? 1 : -1) && AtrOk())
         Open(s.isBuy, NormLot(InpStartLot, InpMaxLot), s.magic, "LV " + nm + " 1");
      return;
     }

   bool inLockCycle = (l.count > 0 || s.realized != 0 || s.unlockPrice != 0);
   double total = b.profit + l.profit + s.realized;

   //--- Cat lo cung
   if(InpBasketStopPct > 0 && total <= -bal * InpBasketStopPct / 100.0)
     {
      CloseSide(s, "CAT LO CUNG chuoi " + nm + " (" + DoubleToString(total, 2) + " USD)");
      return;
     }

   if(!inLockCycle)
     {
      //--- Khoa khi lo nang
      if(InpUseLock && b.profit <= -bal * InpLockDDPct / 100.0)
        {
         if(Open(!s.isBuy, NormLot(b.lots, b.lots), s.lockMagic, "LV KHOA " + nm))
           {
            s.lockStart = TimeCurrent(); s.lockPeak = 0;
            SaveState(s);
            Print("KHOA chuoi ", nm, ": lo ", DoubleToString(b.profit, 2));
           }
         return;
        }

      //--- Chot loi
      double tpDist = InpBasketTPPips * gPip;
      bool hitTP = s.isBuy ? (bid >= b.avg + tpDist) : (ask <= b.avg - tpDist);
      if(hitTP) { CloseSide(s, "cham TP gia TB chuoi " + nm); return; }
      if(InpBasketTPMoney > 0 && b.profit >= InpBasketTPMoney) { CloseSide(s, "du tien chot chuoi " + nm); return; }

      //--- Bao ve lai
      if(InpProtectFrom > 0)
        {
         if(b.profit >= InpProtectFrom && b.profit > s.peak) s.peak = b.profit;
         if(s.peak >= InpProtectFrom && s.peak - b.profit >= InpProtectRetrace)
           { CloseSide(s, "bao ve lai chuoi " + nm + " (dinh " + DoubleToString(s.peak, 2) + ")"); return; }
        }

      //--- Nhoi luoi
      if(InpUseGrid && canGrid && b.count < InpMaxOrders &&
         (InpGridMinMinutes <= 0 || TimeCurrent() - b.lastTime >= InpGridMinMinutes * 60))
        {
         int    n    = b.count;   // so lenh hien co -> lenh tiep theo la thu n+1
         double dist = GridBase() * MathPow(InpGridMult, n - 1);
         bool   go   = s.isBuy ? (b.extreme - ask >= dist) : (bid - b.extreme >= dist);
         if(go)
           {
            int    lvl = n / (int)MathMax(1, InpOrdersPerLevel);
            double lot = NormLot(InpStartLot + InpLotAdd * lvl, InpMaxLot);
            Open(s.isBuy, lot, s.magic, "LV " + nm + " " + IntegerToString(n + 1));
           }
        }
      return;
     }

   //=== DANG TRONG CHU KY KHOA ===
   if(total >= InpLockCloseResult)
     { CloseSide(s, "thoat khoa chuoi " + nm + " (tong " + DoubleToString(total, 2) + ")"); return; }

   if(InpLockMaxHours > 0 && s.lockStart > 0 && TimeCurrent() - s.lockStart >= InpLockMaxHours * 3600)
     { CloseSide(s, "khoa qua lau chuoi " + nm); return; }

   CloseProfitableInLock(s);

   if(!InpSmartLock) return;

   if(l.count > 0)
     {
      //--- Lenh khoa co lai -> theo doi dinh, bi hut lai thi chot
      double per001 = l.profit / (l.lots / 0.01);
      if(per001 >= InpLockRealizeFrom && per001 > s.lockPeak) s.lockPeak = per001;
      if(s.lockPeak >= InpLockRealizeFrom && s.lockPeak - per001 >= InpLockRealizeBack)
        {
         double pr = l.profit;
         CloseMagic(s.lockMagic, "chot lai lenh khoa chuoi " + nm);
         Basket chk;
         GetBasket(s.lockMagic, chk);
         if(chk.count == 0)
           {
            s.realized   += pr;
            s.unlockPrice = s.isBuy ? bid : ask;
            s.lockPeak    = 0;
            SaveState(s);
           }
        }
     }
   else
     {
      //--- Da chot lenh khoa: gia di nguoc them X pip -> khoa lai
      double back = InpReLockPips * gPip;
      bool relock = (s.unlockPrice > 0) &&
                    (s.isBuy ? (bid <= s.unlockPrice - back) : (ask >= s.unlockPrice + back));
      if(relock && Open(!s.isBuy, NormLot(b.lots, b.lots), s.lockMagic, "LV KHOA " + nm))
        {
         s.unlockPrice = 0; s.lockPeak = 0;
         SaveState(s);
         Print("KHOA LAI chuoi ", nm);
        }
     }
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.bid <= 0)
     {
      if(InpShowPanel) Comment("LuoiVang_XAU v1.20 | ", _Symbol, "\nKhong co gia moi (thi truong dong / mat ket noi)");
      return;
     }

   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(gStoppedToday && today != gStopDay) gStoppedToday = false;

   datetime bt = iTime(_Symbol, PERIOD_M1, 0);
   bool newBar = (bt != 0 && bt != gLastBar);
   if(newBar) gLastBar = bt;

   //--- Dong het theo gio
   if(IsCloseAllTime())
     {
      CloseSide(gBuy, "dong het theo gio");
      CloseSide(gSell, "dong het theo gio");
     }

   //--- Gioi han ngay
   Basket b1, b2, l1, l2;
   GetBasket(gBuy.magic, b1); GetBasket(gSell.magic, b2);
   GetBasket(gBuy.lockMagic, l1); GetBasket(gSell.lockMagic, l2);
   double dayPL = TodayClosedPL() + b1.profit + b2.profit + l1.profit + l2.profit;
   if(!gStoppedToday)
     {
      string why = "";
      if(InpDailyMaxLoss > 0 && dayPL <= -InpDailyMaxLoss) why = "cham lo toi da ngay";
      else if(InpDailyGoal > 0 && dayPL >= InpDailyGoal)   why = "dat muc tieu lai ngay";
      if(why != "")
        {
         gStoppedToday = true; gStopDay = today;
         CloseSide(gBuy, why);
         CloseSide(gSell, why);
        }
     }

   int  trend    = Trend();
   string fwhy = "";
   bool filterOk = EntryFilterOk(fwhy);
   bool paused   = FastMovePause();
   bool canEnter = !gStoppedToday && !IsCloseAllTime() && filterOk && !paused;
   bool canGrid  = !gStoppedToday && !paused;
   ProcessSide(gBuy,  trend, newBar, canEnter, canGrid);
   ProcessSide(gSell, trend, newBar, canEnter, canGrid);

   gStatus = gStoppedToday ? "DA DUNG HOM NAY - tu chay lai ngay mai"
             : (trend > 0 ? "Xu huong TANG (tren EMA" : trend < 0 ? "Xu huong GIAM (duoi EMA" : "Dang tai EMA (")
               + IntegerToString(InpEmaPeriod) + ")";
   if(trend == 0 && !gStoppedToday) gStatus = "M1 va H1 nguoc chieu - dung ngoai";
   if(!filterOk && !gStoppedToday) gStatus += " | " + fwhy;
   if(paused && !gStoppedToday)
      gStatus = "GIA CHAY NHANH - nghi den " + TimeToString(gPauseUntil, TIME_MINUTES) + " (van quan ly lenh dang mo)";
   if(InpShowPanel) ShowPanel(dayPL);
  }

//+------------------------------------------------------------------+
void ShowPanel(const double dayPL)
  {
   Basket b1, b2, l1, l2;
   GetBasket(gBuy.magic, b1); GetBasket(gSell.magic, b2);
   GetBasket(gBuy.lockMagic, l1); GetBasket(gSell.lockMagic, l2);
   string s = "LuoiVang_XAU v1.20 | " + _Symbol + "\n";
   s += "Trang thai: " + gStatus + "\n";
   s += "BUY : " + IntegerToString(b1.count) + "/" + IntegerToString(InpMaxOrders) + " lenh, "
      + DoubleToString(b1.lots, 2) + " lot, P/L " + DoubleToString(b1.profit, 2)
      + (l1.count > 0 ? " | DANG KHOA " + DoubleToString(l1.profit, 2) : "")
      + (gBuy.realized != 0 ? " | da chot " + DoubleToString(gBuy.realized, 2) : "") + "\n";
   s += "SELL: " + IntegerToString(b2.count) + "/" + IntegerToString(InpMaxOrders) + " lenh, "
      + DoubleToString(b2.lots, 2) + " lot, P/L " + DoubleToString(b2.profit, 2)
      + (l2.count > 0 ? " | DANG KHOA " + DoubleToString(l2.profit, 2) : "")
      + (gSell.realized != 0 ? " | da chot " + DoubleToString(gSell.realized, 2) : "") + "\n";
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   s += "Khoa khi lo: -" + DoubleToString(bal * InpLockDDPct / 100.0, 2)
      + " | Cat lo cung: " + (InpBasketStopPct > 0 ? "-" + DoubleToString(bal * InpBasketStopPct / 100.0, 2) : "TAT") + "\n";
   s += "P/L hom nay: " + DoubleToString(dayPL, 2)
      + " (dung khi lo -" + DoubleToString(InpDailyMaxLoss, 0) + " / lai +" + DoubleToString(InpDailyGoal, 0) + ")";
   Comment(s);
  }
//+------------------------------------------------------------------+
