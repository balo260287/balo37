//+------------------------------------------------------------------+
//|                                                 WyckoffGold.mq5  |
//|  EA giao dich vang (XAUUSD) theo phuong phap Wyckoff:            |
//|   - Tim vung tich luy / phan phoi (Trading Range)                 |
//|   - BUY khi co SPRING  : rau nen xuyen thung day range, dong cua  |
//|                          quay lai trong range, volume tang         |
//|   - SELL khi co UPTHRUST: rau nen xuyen thung dinh range, dong cua|
//|                          quay lai trong range, volume tang         |
//|  Chi danh gia tren nen DA DONG (khong ve lai tin hieu).          |
//|                                                                  |
//|  v1.10:                                                          |
//|   - Dem so lan cham bien theo TUNG LAN RIENG BIET (khong dem    |
//|     nhieu nen lien tiep o cung mot dinh/day)                      |
//|   - Kiem tra SL dung phia gia vao lenh (chong gap gia)            |
//|   - Bo qua nen "outside bar" xuyen ca 2 bien                      |
//|   - Spread tinh theo gia thuc (Ask-Bid), cho phep vao tre khi     |
//|     spread cao trong InpEntryWindowSec giay                       |
//|   - Hoa von co khoa lai mot phan R (bu spread)                    |
//|   - Gioi han lo toi da trong ngay                                 |
//|   - Kiem tra ky quy, chuan hoa lot/gia theo buoc cua san          |
//+------------------------------------------------------------------+
#property copyright "balo37"
#property version   "1.10"

#include <Trade\Trade.mqh>

enum ENUM_LOT_MODE
  {
   LOT_FIXED   = 0,   // Lot co dinh
   LOT_RISK    = 1    // Lot theo % rui ro tai khoan
  };

enum ENUM_TP_MODE
  {
   TP_RANGE_OPPOSITE = 0, // TP o canh doi dien cua range (kieu Wyckoff)
   TP_FIXED_RR       = 1  // TP = SL x he so RR
  };

//--- Khung thoi gian & vung tich luy
input group "=== Vung tich luy (Trading Range) ==="
input ENUM_TIMEFRAMES InpTF            = PERIOD_H1; // Khung thoi gian phan tich
input int    InpRangeBars              = 40;        // So nen de xac dinh range
input double InpMinRangeATR            = 2.0;       // Do rong range toi thieu (x ATR)
input double InpMaxRangeATR            = 8.0;       // Do rong range toi da (x ATR)
input double InpTouchTolATR            = 0.3;       // Sai so cham bien range (x ATR)
input int    InpMinTouches             = 2;         // So lan cham RIENG BIET moi bien toi thieu
input int    InpATRPeriod              = 14;        // Chu ky ATR

//--- Tin hieu Spring / Upthrust
input group "=== Spring / Upthrust ==="
input bool   InpAllowBuy               = true;      // Cho phep BUY (Spring)
input bool   InpAllowSell              = true;      // Cho phep SELL (Upthrust)
input double InpMinPenetrationATR      = 0.0;       // Rau xuyen bien toi thieu (x ATR)
input double InpMaxPenetrationATR      = 1.0;       // Rau xuyen bien toi da (x ATR)
input double InpCloseStrength          = 0.5;       // Vi tri dong cua trong than nen (0-1)
input int    InpVolMAPeriod            = 20;        // Chu ky trung binh volume
input double InpVolMult                = 1.3;       // Volume nen tin hieu >= x lan trung binh

//--- Quan ly lenh
input group "=== Quan ly von ==="
input ENUM_LOT_MODE InpLotMode         = LOT_RISK;  // Cach tinh lot
input double InpFixedLot               = 0.01;      // Lot co dinh
input double InpRiskPercent            = 1.0;       // % rui ro moi lenh
input double InpMaxLot                 = 1.0;       // Lot toi da
input double InpSLBufferATR            = 0.3;       // Khoang dem SL ngoai rau nen (x ATR)
input ENUM_TP_MODE InpTPMode           = TP_RANGE_OPPOSITE; // Cach dat TP
input double InpRR                     = 2.0;       // He so RR (khi TP_FIXED_RR)
input double InpMinRR                  = 1.5;       // RR toi thieu de vao lenh
input double InpBreakevenR             = 1.0;       // Doi SL ve hoa von khi lai >= x R (0 = tat)
input double InpBreakevenLockR         = 0.1;       // Khi hoa von, khoa lai x R (bu spread)
input double InpMaxDailyLossPct        = 3.0;       // Ngung giao dich khi lo trong ngay >= x% (0 = tat)

//--- Bo loc
input group "=== Bo loc ==="
input int    InpMaxSpreadPoints        = 50;        // Spread toi da (points, tinh tu Ask-Bid)
input int    InpEntryWindowSec         = 300;       // Cho spread giam toi da x giay sau khi mo nen
input int    InpStartHour              = 1;         // Gio bat dau giao dich (gio server)
input int    InpEndHour                = 22;        // Gio ket thuc (gio server; = gio bat dau -> 24h)
input int    InpMaxTradesPerDay        = 2;         // So lenh toi da moi ngay
input int    InpDeviationPoints        = 30;        // Do truot gia cho phep (points)
input ulong  InpMagic                  = 26021987;  // Magic number
input bool   InpDrawRange              = true;      // Ve range len bieu do

CTrade   trade;
int      atrHandle = INVALID_HANDLE;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpRangeBars < 10 || InpVolMAPeriod < 2 || InpATRPeriod < 2 || InpMinTouches < 1)
     {
      Print("Tham so khong hop le: RangeBars>=10, VolMAPeriod>=2, ATRPeriod>=2, MinTouches>=1");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpMinRangeATR <= 0 || InpMinRangeATR >= InpMaxRangeATR)
     {
      Print("Tham so khong hop le: 0 < MinRangeATR < MaxRangeATR");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpMinPenetrationATR < 0 || InpMinPenetrationATR >= InpMaxPenetrationATR)
     {
      Print("Tham so khong hop le: 0 <= MinPenetrationATR < MaxPenetrationATR");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpCloseStrength < 0 || InpCloseStrength > 1)
     {
      Print("Tham so khong hop le: CloseStrength phai trong [0,1]");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpLotMode == LOT_RISK && InpRiskPercent <= 0)
     {
      Print("Tham so khong hop le: RiskPercent > 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpTPMode == TP_FIXED_RR && InpRR < InpMinRR)
     {
      Print("Tham so khong hop le: RR < MinRR -> se khong bao gio vao lenh");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpBreakevenR > 0 && (InpBreakevenLockR < 0 || InpBreakevenLockR >= InpBreakevenR))
     {
      Print("Tham so khong hop le: 0 <= BreakevenLockR < BreakevenR");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      PrintFormat("Canh bao: EA duoc thiet ke cho vang, dang chay tren %s", _Symbol);

   atrHandle = iATR(_Symbol, InpTF, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("Khong tao duoc ATR, loi ", GetLastError());
      return INIT_FAILED;
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetMarginMode();
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   ObjectsDeleteAll(0, "WY_");
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   ManageBreakeven();

   datetime barTime = iTime(_Symbol, InpTF, 0);
   if(barTime == 0 || barTime == lastBarTime)
      return;

   //--- Cac bo loc khong thay doi trong nen -> danh dau nen da xu ly
   if(HasOpenPosition() || !InTradingHours())
     {
      lastBarTime = barTime;
      return;
     }
   int    entriesToday = 0;
   double pnlToday     = 0;
   GetDayStats(entriesToday, pnlToday);
   if(entriesToday >= InpMaxTradesPerDay || DailyLossHit(pnlToday))
     {
      lastBarTime = barTime;
      return;
     }

   //--- Spread cao: thu lai o cac tick sau, toi da InpEntryWindowSec giay
   if(!SpreadOK())
     {
      if(TimeCurrent() - barTime >= InpEntryWindowSec)
         lastBarTime = barTime;
      return;
     }

   //--- CheckSignal tra ve false neu du lieu chua san sang -> thu lai tick sau
   if(CheckSignal())
      lastBarTime = barTime;
  }

//+------------------------------------------------------------------+
bool SpreadOK()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
      return false;
   double spreadPts = (tk.ask - tk.bid) / _Point;
   return (spreadPts <= InpMaxSpreadPoints);
  }

//+------------------------------------------------------------------+
//| Dem so lan cham bien RIENG BIET (nhieu nen lien tiep = 1 lan)    |
//| r[] la mang series: r[from] moi nhat, r[to] cu nhat               |
//+------------------------------------------------------------------+
int CountTouches(const MqlRates &r[], int from, int to, double level, double tol, bool upper)
  {
   int  n      = 0;
   bool inZone = false;
   for(int i = to; i >= from; i--)
     {
      bool hit = upper ? (r[i].high >= level - tol) : (r[i].low <= level + tol);
      if(hit && !inZone)
         n++;
      inZone = hit;
     }
   return n;
  }

//+------------------------------------------------------------------+
//| Phan tich range va tim Spring / Upthrust tren nen vua dong (1)   |
//| Tra ve false khi du lieu chua san sang (de thu lai)              |
//+------------------------------------------------------------------+
bool CheckSignal()
  {
   int need = MathMax(InpRangeBars, InpVolMAPeriod) + 2;
   if(Bars(_Symbol, InpTF) < need + InpATRPeriod + 5)
      return false;

   double atrBuf[];
   if(CopyBuffer(atrHandle, 0, 2, 1, atrBuf) != 1)
      return false;
   double atr = atrBuf[0];
   if(atr <= 0)
      return false;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, 0, need, r) != need)
      return false;

   //--- Range tu nen 2 den nen InpRangeBars+1 (khong tinh nen tin hieu)
   int last = InpRangeBars + 1;
   double rangeHigh = r[2].high;
   double rangeLow  = r[2].low;
   for(int i = 3; i <= last; i++)
     {
      if(r[i].high > rangeHigh) rangeHigh = r[i].high;
      if(r[i].low  < rangeLow)  rangeLow  = r[i].low;
     }
   double width = rangeHigh - rangeLow;
   if(width < InpMinRangeATR * atr || width > InpMaxRangeATR * atr)
      return true; // khong phai vung di ngang

   //--- Dem so lan gia cham 2 bien (moi lan rieng biet) -> xac nhan range that
   double tol = InpTouchTolATR * atr;
   int touchHigh = CountTouches(r, 2, last, rangeHigh, tol, true);
   int touchLow  = CountTouches(r, 2, last, rangeLow,  tol, false);
   if(touchHigh < InpMinTouches || touchLow < InpMinTouches)
      return true;

   if(InpDrawRange)
      DrawRange(r[last].time, r[0].time, rangeHigh, rangeLow);

   //--- Nen tin hieu (nen 1, da dong)
   double h = r[1].high;
   double l = r[1].low;
   double c = r[1].close;
   double barRange = h - l;
   if(barRange <= 0)
      return true;

   //--- Nen xuyen ca 2 bien -> mo ho, bo qua
   if(h > rangeHigh && l < rangeLow)
      return true;

   //--- Volume (tick volume) so voi trung binh
   double volSum = 0;
   for(int i = 2; i < InpVolMAPeriod + 2; i++)
      volSum += (double)r[i].tick_volume;
   double volAvg = volSum / InpVolMAPeriod;
   double vol    = (double)r[1].tick_volume;
   if(volAvg <= 0 || vol < InpVolMult * volAvg)
      return true;

   //--- SPRING -> BUY
   double penLow = rangeLow - l;
   if(InpAllowBuy &&
      l < rangeLow &&
      penLow >= InpMinPenetrationATR * atr &&
      penLow <= InpMaxPenetrationATR * atr &&
      c > rangeLow && c < rangeHigh &&
      (c - l) / barRange >= InpCloseStrength)
     {
      double sl = l - InpSLBufferATR * atr;
      OpenTrade(ORDER_TYPE_BUY, sl, rangeHigh, "Spring");
      return true;
     }

   //--- UPTHRUST -> SELL
   double penHigh = h - rangeHigh;
   if(InpAllowSell &&
      h > rangeHigh &&
      penHigh >= InpMinPenetrationATR * atr &&
      penHigh <= InpMaxPenetrationATR * atr &&
      c < rangeHigh && c > rangeLow &&
      (h - c) / barRange >= InpCloseStrength)
     {
      double sl = h + InpSLBufferATR * atr;
      OpenTrade(ORDER_TYPE_SELL, sl, rangeLow, "Upthrust");
      return true;
     }
   return true;
  }

//+------------------------------------------------------------------+
double NormPrice(double p)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts > 0)
      p = MathRound(p / ts) * ts;
   return NormalizeDouble(p, _Digits);
  }

//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double sl, double rangeTarget, string tag)
  {
   bool isBuy = (type == ORDER_TYPE_BUY);
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
      return;
   double entry = isBuy ? tk.ask : tk.bid;

   double tp;
   if(InpTPMode == TP_FIXED_RR)
      tp = isBuy ? entry + InpRR * (entry - sl) : entry - InpRR * (sl - entry);
   else
      tp = rangeTarget;

   sl = NormPrice(sl);
   tp = NormPrice(tp);

   //--- SL phai nam dung phia (gia co the da gap qua SL khi mo nen moi)
   double risk   = isBuy ? entry - sl : sl - entry;
   double reward = isBuy ? tp - entry : entry - tp;
   if(risk <= 0)
     {
      PrintFormat("%s bo qua: gia vao %.2f da vuot SL %.2f", tag, entry, sl);
      return;
     }
   if(reward <= 0 || reward / risk < InpMinRR)
     {
      PrintFormat("%s bo qua: RR=%.2f < %.2f", tag, reward / risk, InpMinRR);
      return;
     }

   //--- Khoang cach dung toi thieu cua san (SL/TP so voi gia dong lenh)
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double slDist  = isBuy ? tk.bid - sl : sl - tk.ask;
   double tpDist  = isBuy ? tp - tk.bid : tk.ask - tp;
   if(slDist <= minDist || tpDist <= minDist)
     {
      PrintFormat("%s bo qua: SL/TP qua gan gia (stops level)", tag);
      return;
     }

   double lot = CalcLot(type, entry, sl);
   if(lot <= 0)
      return;

   bool ok = isBuy ? trade.Buy(lot, _Symbol, 0, sl, tp, "WY " + tag)
                   : trade.Sell(lot, _Symbol, 0, sl, tp, "WY " + tag);
   uint rc = trade.ResultRetcode();
   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
      PrintFormat("%s: %s %.2f lot @%.2f, SL=%.2f TP=%.2f, RR=%.2f", tag,
                  (isBuy ? "BUY" : "SELL"), lot, trade.ResultPrice(), sl, tp, reward / risk);
   else
      PrintFormat("Loi vao lenh %s: %u %s", tag, rc, trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
double CalcLot(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), InpMaxLot);
   if(step <= 0)
      step = 0.01;
   int volDigits = (int)MathMax(0, MathCeil(-MathLog10(step) - 1e-9));
   double lot = InpFixedLot;

   if(InpLotMode == LOT_RISK)
     {
      double riskMoney  = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double lossPerLot = 0;
      if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, lossPerLot) || lossPerLot >= 0)
        {
         Print("Khong tinh duoc lot theo rui ro");
         return 0;
        }
      lot = riskMoney / MathAbs(lossPerLot);
     }

   lot = MathMin(lot, maxLot);
   lot = MathFloor(lot / step + 1e-8) * step;   // +1e-8 chong sai so so thuc
   lot = NormalizeDouble(lot, volDigits);
   if(lot < minLot)
     {
      PrintFormat("Lot %.3f nho hon lot toi thieu %.3f -> bo qua lenh (SL qua xa so voi von)", lot, minLot);
      return 0;
     }

   //--- Kiem tra du ky quy
   double margin = 0;
   if(OrderCalcMargin(type, _Symbol, lot, entry, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      PrintFormat("Khong du ky quy cho %.2f lot (can %.2f)", lot, margin);
      return 0;
     }
   return lot;
  }

//+------------------------------------------------------------------+
//| Doi SL ve hoa von (+ khoa InpBreakevenLockR x R) khi lai du lon  |
//+------------------------------------------------------------------+
void ManageBreakeven()
  {
   if(InpBreakevenR <= 0)
      return;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      long   ptype = PositionGetInteger(POSITION_TYPE);

      if(ptype == POSITION_TYPE_BUY)
        {
         if(sl == 0 || sl >= open) continue;          // da hoa von roi
         double r   = open - sl;
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormPrice(open + InpBreakevenLockR * r);
         if(bid - open >= InpBreakevenR * r && bid - newSL > minDist && newSL > sl)
            trade.PositionModify(ticket, newSL, tp);
        }
      else
        {
         if(sl == 0 || sl <= open) continue;
         double r   = sl - open;
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormPrice(open - InpBreakevenLockR * r);
         if(open - ask >= InpBreakevenR * r && newSL - ask > minDist && newSL < sl)
            trade.PositionModify(ticket, newSL, tp);
        }
     }
  }

//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
bool InTradingHours()
  {
   if(InpStartHour == InpEndHour)
      return true; // giao dich ca ngay
   MqlDateTime t;
   TimeCurrent(t);
   if(InpStartHour < InpEndHour)
      return (t.hour >= InpStartHour && t.hour < InpEndHour);
   return (t.hour >= InpStartHour || t.hour < InpEndHour); // khung gio qua dem
  }

//+------------------------------------------------------------------+
//| So lenh da vao va lai/lo da chot trong ngay (cua EA nay)         |
//+------------------------------------------------------------------+
void GetDayStats(int &entries, double &pnl)
  {
   entries = 0;
   pnl     = 0;
   MqlDateTime t;
   TimeCurrent(t);
   t.hour = 0; t.min = 0; t.sec = 0;
   datetime dayStart = StructToTime(t);
   if(!HistorySelect(dayStart, TimeCurrent() + 86400))
      return;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         entries++;
      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT)
           + HistoryDealGetDouble(deal, DEAL_SWAP)
           + HistoryDealGetDouble(deal, DEAL_COMMISSION);
     }
  }

//+------------------------------------------------------------------+
bool DailyLossHit(double pnlToday)
  {
   if(InpMaxDailyLossPct <= 0 || pnlToday >= 0)
      return false;
   double startBalance = AccountInfoDouble(ACCOUNT_BALANCE) - pnlToday;
   if(startBalance <= 0)
      return true;
   bool hit = (-pnlToday >= startBalance * InpMaxDailyLossPct / 100.0);
   if(hit)
      PrintFormat("Da lo %.2f trong ngay (>= %.1f%%) -> ngung giao dich den mai", -pnlToday, InpMaxDailyLossPct);
   return hit;
  }

//+------------------------------------------------------------------+
void DrawRange(datetime t1, datetime t2, double hi, double lo)
  {
   string name = "WY_RANGE";
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, hi);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkSlateGray);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
