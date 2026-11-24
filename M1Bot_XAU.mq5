//+------------------------------------------------------------------+
//| M1Bot_XAU.mq5                                                  |
//| Bot DCA khung M1 cho XAUUSDm (vang) - MT5 Exness                      |
//|                                                                |
//| Y tuong lay tu:                                                |
//|  - ZacksBot Matrix (.set): lot cong them, khoang cach nhoi,    |
//|    TP theo gia trung binh, trailing, loc xu huong MA200 H1,    |
//|    gioi han lai/lo trong ngay.                                 |
//|  - Kiep Do Den v3 (.set): loc EMA nhanh/cham, AutoMoveTP,      |
//|    he so nhan lot (tuy chon), delay giua cac lenh, loc gio.    |
//|  - EA cua Phu (.mq4): chi quan ly lenh co dau hieu rieng cua EA.|
//|                                                                |
//| Khac biet quan trong: CO CAT LO cho ca chuoi lenh              |
//| (mac dinh 1% so du) va lo toi da trong ngay.                   |
//| v1.10: them vao lenh khi gia HOI VE EMA nhanh (nhieu lenh hon), |
//|        SL that tren san cho ca chuoi (mat mang van co cat lo), |
//|        bang hien ly do dang cho tin hieu.                      |
//| v1.11: sua loi "bad stops": SL/TP luon cach gia du xa (spread + |
//|        muc toi thieu cua san), kiem tra lai bang gia moi nhat  |
//|        ngay truoc khi gui, bi tu choi thi nghi 15 giay.        |
//| Gan vao chart XAUUSDm (chart khung nao                         |
//| cung duoc, bot luon tinh tin hieu tren M1).                    |
//+------------------------------------------------------------------+
#property copyright "M1Bot_XAU"
#property version   "1.11"
#property description "DCA khung M1 cho XAUUSDm, co cat lo chuoi lenh va gioi han lo ngay."

#include <Trade/Trade.mqh>

enum ENUM_LOT_MODE
  {
   LOT_CONG = 0,   // Cong them moi tang (an toan hon)
   LOT_NHAN = 1    // Nhan he so moi tang (martingale - rui ro cao)
  };

enum ENUM_ENTRY_MODE
  {
   ENTRY_CROSS    = 0, // Chi khi EMA cat nhau (it lenh)
   ENTRY_PULLBACK = 1, // Chi khi gia hoi ve EMA nhanh roi bat len
   ENTRY_BOTH     = 2  // Ca hai (nhieu lenh nhat)
  };

enum ENUM_DIR_MODE
  {
   DIR_BUY  = 0,   // Chi BUY
   DIR_SELL = 1,   // Chi SELL
   DIR_BOTH = 2    // Ca hai chieu
  };

//--- CHUNG
input group "=== CHUNG ==="
input long          InpMagic          = 280003;    // Magic (khac cac bot cu)
input ENUM_DIR_MODE InpDirection      = DIR_BOTH;  // Chieu giao dich
input bool          InpOneSide        = true;      // Chi giu 1 chieu tai 1 thoi diem
input int           InpSlippagePts    = 50;        // Truot gia toi da (points)
input string        InpComment        = "M1XAU";   // Comment lenh

//--- VON & RUI RO
input group "=== VON & RUI RO ==="
input double InpRiskPct         = 1.0;    // Lo toi da moi chuoi DCA (% so du) -> cat ca chuoi
input double InpDailyLossUSD    = 15.0;   // Lo toi da trong ngay (USD) -> nghi den mai
input double InpDailyProfitUSD  = 50.0;   // Lai muc tieu trong ngay (USD), 0 = tat
input double InpHardSLMult      = 1.2;    // SL that tren san = muc cat lo chuoi x he so (du phong mat mang)

//--- LOT & DCA
input group "=== LOT & NHOI LENH (DCA) ==="
input double        InpStartLot       = 0.01;      // Lot lenh dau
input ENUM_LOT_MODE InpLotMode        = LOT_CONG;  // Cach tang lot
input double        InpLotStep        = 0.01;      // Lot cong them moi tang (che do Cong)
input double        InpMultiplier     = 1.5;       // He so nhan (che do Nhan)
input double        InpMaxLot         = 0.10;      // Lot toi da cho 1 lenh
input int           InpMaxLayers      = 5;         // So lenh toi da moi chieu
input int           InpOrderDelaySec  = 5;         // Cach nhau toi thieu giua 2 lenh (giay)
input bool          InpDcaOnBarClose  = true;      // Chi nhoi lenh khi co nen M1 moi

//--- THONG SO VANG
input group "=== VANG - tinh theo % gia (gia 3600 -> 0.01% = 0.36) ==="
input double InpXauGridPct        = 0.10;   // Khoang cach nhoi (%) ~3.6 gia
input double InpXauTPPct          = 0.08;   // Chot loi tu gia trung binh (%) ~2.9 gia
input double InpXauTrailStartPct  = 0.06;   // Bat dau doi SL khi lai (%) ~2.2 gia
input double InpXauTrailDistPct   = 0.04;   // SL cach gia (%) ~1.4 gia
input double InpXauMaxSpreadPct   = 0.015;  // Spread toi da (%) ~0.55 gia

//--- TIN HIEU
input group "=== TIN HIEU VAO LENH (M1) ==="
input ENUM_ENTRY_MODE InpEntryMode = ENTRY_BOTH; // Cach vao lenh dau
input int             InpEmaFast   = 9;          // EMA nhanh M1
input int             InpEmaSlow   = 21;         // EMA cham M1
input bool            InpUseTrend  = true;       // Loc xu huong
input ENUM_TIMEFRAMES InpTrendTF   = PERIOD_H1;  // Khung loc xu huong
input int             InpTrendMA   = 200;        // EMA loc xu huong

//--- GIO
input group "=== GIO GIAO DICH (gio may chu MT5) ==="
input bool InpUseTime        = false;  // Bat loc gio
input int  InpStartHour      = 1;      // Gio bat dau (0-23)
input int  InpEndHour        = 23;     // Gio ket thuc (0-23)
input bool InpDcaOutsideTime = true;   // Van nhoi lenh ngoai gio

//--- HIEN THI
input group "=== HIEN THI ==="
input bool InpShowPanel = true;        // Hien bang thong tin

//+------------------------------------------------------------------+
struct Basket
  {
   int      count;
   double   lots;
   double   avg;
   double   extreme;   // BUY: gia mo thap nhat, SELL: gia mo cao nhat
   double   profit;
   double   lastLot;
   datetime lastTime;
  };

CTrade   trade;
int      hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE, hTrend = INVALID_HANDLE;
double   gGridPct, gTPPct, gTrailStartPct, gTrailDistPct, gMaxSpreadPct;
string   gKind = "";
datetime gLastBar = 0;
datetime gLastOrder = 0;
bool     gStoppedToday = false;
datetime gStopDay = 0;
string   gStatus = "Dang khoi dong...";
string   gStopReason = "";
string   gSignalInfo = "";   // ly do tin hieu, hien tren bang
datetime gModifyPauseUntil = 0; // san tu choi sua SL/TP -> tam nghi

void ShowPanel(const Basket &bb, const Basket &sb, const double dayPL);

//+------------------------------------------------------------------+
int OnInit()
  {
   string s = _Symbol;
   StringToUpper(s);
   if(StringFind(s, "XAU") < 0 && StringFind(s, "GOLD") < 0)
     {
      Alert("M1Bot_XAU: bot nay chi chay tren XAUUSDm (vang). Chart hien tai: ", _Symbol);
      return(INIT_PARAMETERS_INCORRECT);
     }
   gKind = "XAU";
   gGridPct = InpXauGridPct; gTPPct = InpXauTPPct;
   gTrailStartPct = InpXauTrailStartPct; gTrailDistPct = InpXauTrailDistPct;
   gMaxSpreadPct = InpXauMaxSpreadPct;

   if(InpEmaFast >= InpEmaSlow || InpMaxLayers < 1 || InpRiskPct <= 0)
     {
      Alert("M1Bot_XAU: thong so sai (EMA nhanh phai < EMA cham, MaxLayers >= 1, RiskPct > 0)");
      return(INIT_PARAMETERS_INCORRECT);
     }

   hFast  = iMA(_Symbol, PERIOD_M1, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hSlow  = iMA(_Symbol, PERIOD_M1, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hTrend = iMA(_Symbol, InpTrendTF, InpTrendMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE || hTrend == INVALID_HANDLE)
     {
      Alert("M1Bot_XAU: khong tao duoc chi bao EMA");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints((ulong)InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);

   if(Period() != PERIOD_M1)
      Print("M1Bot_XAU: chart dang o khung ", EnumToString(Period()),
            " - khong sao, bot van tinh tin hieu tren M1.");

   Alert("M1Bot_XAU v1.11 DA CHAY tren ", _Symbol, " (", gKind, ") - OK");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hFast  != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow  != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hTrend != INVALID_HANDLE) IndicatorRelease(hTrend);
   Comment("");
  }

//+------------------------------------------------------------------+
//| Gom cac lenh cua bot theo chieu                                  |
//+------------------------------------------------------------------+
void GetBasket(const ENUM_POSITION_TYPE type, Basket &b)
  {
   b.count = 0; b.lots = 0; b.avg = 0; b.extreme = 0;
   b.profit = 0; b.lastLot = 0; b.lastTime = 0;
   double sumPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;

      double vol   = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      datetime t   = (datetime)PositionGetInteger(POSITION_TIME);

      b.count++;
      b.lots  += vol;
      sumPL   += price * vol;
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(type == POSITION_TYPE_BUY)
        { if(b.extreme == 0 || price < b.extreme) b.extreme = price; }
      else
        { if(price > b.extreme) b.extreme = price; }

      if(t >= b.lastTime) { b.lastTime = t; b.lastLot = vol; }
     }
   if(b.lots > 0) b.avg = sumPL / b.lots;
  }

//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   double cap = MathMin(vmax, MathMax(InpMaxLot, vmin));
   lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < vmin) lot = vmin;
   if(lot > cap)  lot = cap;
   int digits = (int)MathMax(0.0, MathCeil(-MathLog10(step) - 1e-9));
   return NormalizeDouble(lot, digits);
  }

//+------------------------------------------------------------------+
double NextLot(const Basket &b)
  {
   if(b.count == 0) return NormalizeLot(InpStartLot);
   if(InpLotMode == LOT_CONG) return NormalizeLot(b.lastLot + InpLotStep);
   return NormalizeLot(b.lastLot * InpMultiplier);
  }

//+------------------------------------------------------------------+
//| Tin hieu tren nen M1 vua dong: 1 BUY, -1 SELL, 0 khong           |
//|  - CAT: EMA nhanh cat len/xuong EMA cham.                        |
//|  - HOI: EMA nhanh dang tren EMA cham (xu huong tang), nen vua     |
//|    dong cham/xuyen EMA nhanh roi dong cua tren no va la nen tang  |
//|    -> mua lai nhip hoi. Nguoc lai cho SELL.                      |
//+------------------------------------------------------------------+
int Signal()
  {
   double f[], sl[];
   if(CopyBuffer(hFast, 0, 1, 2, f) < 2) { gSignalInfo = "dang tai EMA"; return 0; }
   if(CopyBuffer(hSlow, 0, 1, 2, sl) < 2) { gSignalInfo = "dang tai EMA"; return 0; }
   // f[0] = nen 2 (cu hon), f[1] = nen 1 (vua dong)
   double o1 = iOpen(_Symbol, PERIOD_M1, 1), h1 = iHigh(_Symbol, PERIOD_M1, 1);
   double l1 = iLow(_Symbol, PERIOD_M1, 1),  c1 = iClose(_Symbol, PERIOD_M1, 1);

   bool crossUp   = (f[0] <= sl[0] && f[1] > sl[1]);
   bool crossDown = (f[0] >= sl[0] && f[1] < sl[1]);
   bool pullUp    = (f[1] > sl[1] && l1 <= f[1] && c1 > f[1] && c1 > o1);
   bool pullDown  = (f[1] < sl[1] && h1 >= f[1] && c1 < f[1] && c1 < o1);

   bool useCross = (InpEntryMode == ENTRY_CROSS || InpEntryMode == ENTRY_BOTH);
   bool usePull  = (InpEntryMode == ENTRY_PULLBACK || InpEntryMode == ENTRY_BOTH);
   bool buy  = (useCross && crossUp)   || (usePull && pullUp);
   bool sell = (useCross && crossDown) || (usePull && pullDown);
   string kind = (crossUp || crossDown) ? "EMA cat" : "hoi ve EMA";

   int trend = 0;
   if(InpUseTrend)
     {
      double t[];
      if(CopyBuffer(hTrend, 0, 1, 1, t) < 1) { gSignalInfo = "dang tai EMA xu huong"; return 0; }
      trend = (c1 > t[0]) ? 1 : -1;
      if(trend > 0) sell = false;
      if(trend < 0) buy  = false;
     }
   string side = (f[1] > sl[1]) ? "EMA tang" : "EMA giam";
   string tr   = (trend > 0) ? ", tren EMA" + IntegerToString(InpTrendMA) + " -> chi BUY"
                 : (trend < 0) ? ", duoi EMA" + IntegerToString(InpTrendMA) + " -> chi SELL" : "";
   if(buy == sell)
     {
      gSignalInfo = side + tr + " | cho " + ((f[1] > sl[1]) ? "nen hoi ve EMA" + IntegerToString(InpEmaFast) + " roi tang"
                                                            : "nen hoi len EMA" + IntegerToString(InpEmaFast) + " roi giam");
      return 0;
     }
   gSignalInfo = (buy ? "BUY (" : "SELL (") + kind + ")";
   return buy ? 1 : -1;
  }

//+------------------------------------------------------------------+
double TodayClosedPL()
  {
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(dayStart == 0) return 0;
   if(!HistorySelect(dayStart, TimeCurrent() + 60)) return 0;
   double pl = 0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic) continue;
      pl += HistoryDealGetDouble(d, DEAL_PROFIT)
          + HistoryDealGetDouble(d, DEAL_SWAP)
          + HistoryDealGetDouble(d, DEAL_COMMISSION);
     }
   return pl;
  }

//+------------------------------------------------------------------+
void CloseBasket(const ENUM_POSITION_TYPE type, const string why)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
      if(!trade.PositionClose(ticket, (ulong)InpSlippagePts))
         Print("Loi dong lenh #", ticket, ": ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
     }
   Print("Dong chuoi ", (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), ": ", why);
  }

//+------------------------------------------------------------------+
//| Khoang cach an toan toi thieu giua gia va SL/TP                   |
//| Exness thuong bao StopsLevel = 0 nhung van tu choi SL/TP qua sat   |
//| -> cong them spread hien tai va 1 khoang dem nho.                 |
//+------------------------------------------------------------------+
double SafeDist(const MqlTick &tk)
  {
   double lvl = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;
   double spread = tk.ask - tk.bid;
   return lvl + spread + 10 * _Point;
  }

//+------------------------------------------------------------------+
//| SL/TP co hop le voi gia hien tai khong (0 = khong dat -> hop le)  |
//+------------------------------------------------------------------+
bool StopsValid(const bool isBuy, const double sl, const double tp, const MqlTick &tk)
  {
   double d  = SafeDist(tk);
   double px = isBuy ? tk.bid : tk.ask;   // SL/TP cua BUY so voi Bid, SELL so voi Ask
   if(sl > 0 && (isBuy ? (px - sl < d) : (sl - px < d))) return false;
   if(tp > 0 && (isBuy ? (tp - px < d) : (px - tp < d))) return false;
   return true;
  }

//+------------------------------------------------------------------+
//| Dat TP chung va doi SL (trailing) cho ca chuoi                    |
//+------------------------------------------------------------------+
void ManageStops(const ENUM_POSITION_TYPE type, const Basket &b, const MqlTick &tk)
  {
   if(b.count == 0) return;
   int    dg      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minDist = SafeDist(tk);
   bool   isBuy   = (type == POSITION_TYPE_BUY);
   double px      = isBuy ? tk.bid : tk.ask;          // gia dong lenh

   double tpDist  = b.avg * gTPPct / 100.0;
   double tp      = NormalizeDouble(isBuy ? b.avg + tpDist : b.avg - tpDist, dg);

   // Neu gia da vuot TP ma TP chua kip dat -> dong luon
   if((isBuy && px >= tp) || (!isBuy && px <= tp))
     {
      CloseBasket(type, "cham TP trung binh");
      return;
     }

   // TP co hop le voi khoang cach toi thieu?
   bool tpOk = isBuy ? (tp - px > minDist) : (px - tp > minDist);

   // Trailing
   double newSL = 0;
   double gain  = isBuy ? (px - b.avg) : (b.avg - px);
   if(gain >= b.avg * gTrailStartPct / 100.0)
     {
      double d = b.avg * gTrailDistPct / 100.0;
      if(d < minDist + _Point) d = minDist + _Point;
      newSL = NormalizeDouble(isBuy ? px - d : px + d, dg);
      // chi doi SL khi van dang co lai (SL nam phia co loi so voi gia TB)
      if(isBuy && newSL <= b.avg) newSL = 0;
      if(!isBuy && newSL >= b.avg) newSL = 0;
     }
   double slStep = b.avg * gTrailDistPct / 100.0 * 0.2;

   // SL that tren san cho ca chuoi: gia cham muc nay thi chuoi lo ~ cat lo x InpHardSLMult
   double hardSL = 0;
   double pu = 0;
   if(OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, b.lots, b.avg, b.avg + 1.0, pu) && pu > 0)
     {
      double riskUSD = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0 * InpHardSLMult;
      hardSL = NormalizeDouble(isBuy ? b.avg - riskUSD / pu : b.avg + riskUSD / pu, dg);
      if(isBuy && hardSL >= tk.bid - minDist) hardSL = 0;
      if(!isBuy && hardSL <= tk.ask + minDist) hardSL = 0;
     }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;

      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      double wantSL = curSL;
      double wantTP = tpOk ? tp : curTP;

      if(newSL > 0)
        {
         bool better = (curSL == 0) ||
                       (isBuy  && newSL > curSL + slStep) ||
                       (!isBuy && newSL < curSL - slStep);
         if(better) wantSL = newSL;
        }
      // Chua co SL hoac SL dang xa hon muc an toan -> keo ve SL that
      if(hardSL > 0 &&
         (wantSL == 0 || (isBuy && hardSL > wantSL + _Point) || (!isBuy && hardSL < wantSL - _Point)))
         wantSL = hardSL;

      bool chSL = MathAbs(wantSL - curSL) > _Point / 2;
      bool chTP = MathAbs(wantTP - curTP) > _Point / 2;
      if(!(chSL || chTP)) continue;
      if(TimeCurrent() < gModifyPauseUntil) continue;

      // Kiem tra lai bang gia MOI NHAT ngay truoc khi gui
      MqlTick now;
      if(!SymbolInfoTick(_Symbol, now)) continue;
      if(chSL && !StopsValid(isBuy, wantSL, 0, now)) { wantSL = curSL; chSL = false; }
      if(chTP && !StopsValid(isBuy, 0, wantTP, now)) { wantTP = curTP; chTP = false; }
      if(!(chSL || chTP)) continue;
      // SL/TP cu ma da qua sat gia thi san cung tu choi ca lenh sua -> bo qua lan nay
      if(!StopsValid(isBuy, wantSL, wantTP, now)) continue;

      if(!trade.PositionModify(ticket, NormalizeDouble(wantSL, dg), NormalizeDouble(wantTP, dg)))
        {
         Print("Loi sua SL/TP #", ticket, ": ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription(),
               " (SL ", DoubleToString(wantSL, dg), " TP ", DoubleToString(wantTP, dg),
               " Bid ", DoubleToString(now.bid, dg), " Ask ", DoubleToString(now.ask, dg), ") -> nghi 15 giay");
         gModifyPauseUntil = TimeCurrent() + 15;
        }
     }
  }

//+------------------------------------------------------------------+
bool InTime()
  {
   if(!InpUseTime) return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpStartHour <= InpEndHour) return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
   return (dt.hour >= InpStartHour || dt.hour < InpEndHour); // qua dem
  }

//+------------------------------------------------------------------+
bool OpenOrder(const ENUM_ORDER_TYPE ot, const double lot, const int layer, const MqlTick &tk)
  {
   double price = (ot == ORDER_TYPE_BUY) ? tk.ask : tk.bid;
   double margin = 0;
   if(OrderCalcMargin(ot, _Symbol, lot, price, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      gStatus = "Khong du ky quy de vao lenh " + DoubleToString(lot, 2);
      return false;
     }
   string cmt = InpComment + (ot == ORDER_TYPE_BUY ? " B" : " S") + IntegerToString(layer);
   bool ok = (ot == ORDER_TYPE_BUY) ? trade.Buy(lot, _Symbol, 0, 0, 0, cmt)
                                    : trade.Sell(lot, _Symbol, 0, 0, 0, cmt);
   uint rc = trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
     {
      Print("Loi vao lenh ", cmt, " lot ", lot, ": ", rc, " ", trade.ResultRetcodeDescription());
      gStatus = "Loi vao lenh: " + IntegerToString(rc);
      return false;
     }
   gLastOrder = TimeCurrent();
   Print("Vao lenh ", cmt, " lot ", DoubleToString(lot, 2), " gia ", DoubleToString(trade.ResultPrice(), _Digits));
   return true;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.bid <= 0)
     {
      if(InpShowPanel) Comment("M1Bot_XAU v1.11 | ", _Symbol, "\nTrang thai: Khong co gia moi (thi truong dong / mat ket noi)");
      return;
     }

   // Ngay moi -> mo khoa
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(gStoppedToday && today != gStopDay) { gStoppedToday = false; gStopReason = ""; }

   Basket bb, sb;
   GetBasket(POSITION_TYPE_BUY, bb);
   GetBasket(POSITION_TYPE_SELL, sb);

   // 1) Cat lo chuoi theo % so du
   double riskUSD = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
   if(bb.count > 0 && bb.profit <= -riskUSD) { CloseBasket(POSITION_TYPE_BUY,  "CAT LO chuoi (" + DoubleToString(bb.profit, 2) + " USD)"); GetBasket(POSITION_TYPE_BUY, bb); }
   if(sb.count > 0 && sb.profit <= -riskUSD) { CloseBasket(POSITION_TYPE_SELL, "CAT LO chuoi (" + DoubleToString(sb.profit, 2) + " USD)"); GetBasket(POSITION_TYPE_SELL, sb); }

   // 2) Gioi han lai/lo trong ngay
   double dayPL = TodayClosedPL() + bb.profit + sb.profit;
   if(!gStoppedToday)
     {
      if(dayPL <= -InpDailyLossUSD)
        { gStoppedToday = true; gStopDay = today; gStopReason = "DUNG: cham lo toi da trong ngay"; }
      else if(InpDailyProfitUSD > 0 && dayPL >= InpDailyProfitUSD)
        { gStoppedToday = true; gStopDay = today; gStopReason = "DA DAT MUC TIEU LAI NGAY"; }
      if(gStoppedToday)
        {
         if(bb.count > 0) CloseBasket(POSITION_TYPE_BUY,  gStopReason);
         if(sb.count > 0) CloseBasket(POSITION_TYPE_SELL, gStopReason);
         Print(gStopReason, " | P/L ngay: ", DoubleToString(dayPL, 2));
         GetBasket(POSITION_TYPE_BUY, bb);
         GetBasket(POSITION_TYPE_SELL, sb);
        }
     }

   // 3) TP chung + trailing
   ManageStops(POSITION_TYPE_BUY,  bb, tk);
   ManageStops(POSITION_TYPE_SELL, sb, tk);

   if(gStoppedToday) { gStatus = gStopReason + " - tu chay lai ngay mai"; ShowPanel(bb, sb, dayPL); return; }

   // 4) Nen moi?
   datetime bt = iTime(_Symbol, PERIOD_M1, 0);
   bool newBar = (bt != gLastBar && bt != 0);
   if(newBar) gLastBar = bt;

   // 5) Spread
   double spreadPct = (tk.ask - tk.bid) / tk.bid * 100.0;
   if(spreadPct > gMaxSpreadPct)
     { gStatus = "Spread qua cao (" + DoubleToString(tk.ask - tk.bid, _Digits) + ")"; ShowPanel(bb, sb, dayPL); return; }

   bool delayOk = (TimeCurrent() - gLastOrder) >= InpOrderDelaySec;
   bool timeOk  = InTime();
   bool dcaTime = timeOk || InpDcaOutsideTime;
   bool dcaBar  = (!InpDcaOnBarClose || newBar);

   // 6) Nhoi lenh (DCA)
   if(delayOk && dcaTime && dcaBar)
     {
      if(bb.count > 0 && bb.count < InpMaxLayers)
        {
         double grid = bb.extreme * gGridPct / 100.0;
         if(bb.extreme - tk.ask >= grid)
            OpenOrder(ORDER_TYPE_BUY, NextLot(bb), bb.count + 1, tk);
        }
      if(sb.count > 0 && sb.count < InpMaxLayers)
        {
         double grid = sb.extreme * gGridPct / 100.0;
         if(tk.bid - sb.extreme >= grid)
            OpenOrder(ORDER_TYPE_SELL, NextLot(sb), sb.count + 1, tk);
        }
     }

   // 7) Lenh dau tien cua chuoi
   gStatus = "Dang cho tin hieu...";
   if(!timeOk) gStatus = "Ngoai gio giao dich";
   if(newBar && timeOk && (TimeCurrent() - gLastOrder) >= InpOrderDelaySec)
     {
      int sig = Signal();
      if(sig == 1 && InpDirection != DIR_SELL && bb.count == 0 && !(InpOneSide && sb.count > 0))
         OpenOrder(ORDER_TYPE_BUY, NextLot(bb), 1, tk);
      else if(sig == -1 && InpDirection != DIR_BUY && sb.count == 0 && !(InpOneSide && bb.count > 0))
         OpenOrder(ORDER_TYPE_SELL, NextLot(sb), 1, tk);
     }

   ShowPanel(bb, sb, dayPL);
  }

//+------------------------------------------------------------------+
void ShowPanel(const Basket &bb, const Basket &sb, const double dayPL)
  {
   if(!InpShowPanel) return;
   double px   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
   string s = "M1Bot_XAU v1.11 | " + _Symbol + " (" + gKind + ")\n";
   s += "Trang thai: " + gStatus + "\n";
   if(gSignalInfo != "") s += "Tin hieu: " + gSignalInfo + "\n";
   s += "Khoang nhoi: " + DoubleToString(px * gGridPct / 100.0, _Digits)
      + " | TP: " + DoubleToString(px * gTPPct / 100.0, _Digits) + " (gia)\n";
   s += "BUY : " + IntegerToString(bb.count) + "/" + IntegerToString(InpMaxLayers) + " lenh, "
      + DoubleToString(bb.lots, 2) + " lot, P/L " + DoubleToString(bb.profit, 2) + "\n";
   s += "SELL: " + IntegerToString(sb.count) + "/" + IntegerToString(InpMaxLayers) + " lenh, "
      + DoubleToString(sb.lots, 2) + " lot, P/L " + DoubleToString(sb.profit, 2) + "\n";
   s += "Cat lo moi chuoi: -" + DoubleToString(risk, 2) + " USD\n";
   s += "P/L hom nay: " + DoubleToString(dayPL, 2) + " (lo toi da -" + DoubleToString(InpDailyLossUSD, 0)
      + ", muc tieu " + DoubleToString(InpDailyProfitUSD, 0) + ")";
   Comment(s);
  }
//+------------------------------------------------------------------+
