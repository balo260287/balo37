//+------------------------------------------------------------------+
//|                                                 WyckoffGold.mq5  |
//|  EA giao dich vang (XAUUSD) theo phuong phap Wyckoff:            |
//|   - Tim vung tich luy / phan phoi (Trading Range)                 |
//|   - BUY khi co SPRING  : rau nen xuyen thung day range, dong cua  |
//|                          quay lai trong range, volume tang         |
//|   - SELL khi co UPTHRUST: rau nen xuyen thung dinh range, dong cua|
//|                          quay lai trong range, volume tang         |
//|  Chi danh gia tren nen DA DONG (khong ve lai tin hieu).          |
//+------------------------------------------------------------------+
#property copyright "balo37"
#property version   "1.00"

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
input int    InpMinTouches             = 2;         // So lan cham moi bien toi thieu
input int    InpATRPeriod              = 14;        // Chu ky ATR

//--- Tin hieu Spring / Upthrust
input group "=== Spring / Upthrust ==="
input bool   InpAllowBuy               = true;      // Cho phep BUY (Spring)
input bool   InpAllowSell              = true;      // Cho phep SELL (Upthrust)
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

//--- Bo loc
input group "=== Bo loc ==="
input int    InpMaxSpreadPoints        = 50;        // Spread toi da (points)
input int    InpStartHour              = 1;         // Gio bat dau giao dich (gio server)
input int    InpEndHour                = 22;        // Gio ket thuc giao dich (gio server)
input int    InpMaxTradesPerDay        = 2;         // So lenh toi da moi ngay
input ulong  InpMagic                  = 26021987;  // Magic number
input bool   InpDrawRange              = true;      // Ve range len bieu do

CTrade   trade;
int      atrHandle = INVALID_HANDLE;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpRangeBars < 10 || InpVolMAPeriod < 2 || InpATRPeriod < 2)
     {
      Print("Tham so khong hop le");
      return INIT_PARAMETERS_INCORRECT;
     }
   atrHandle = iATR(_Symbol, InpTF, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("Khong tao duoc ATR, loi ", GetLastError());
      return INIT_FAILED;
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
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
   lastBarTime = barTime;

   if(HasOpenPosition())       return;
   if(!InTradingHours())       return;
   if(TradesToday() >= InpMaxTradesPerDay) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;

   CheckSignal();
  }

//+------------------------------------------------------------------+
//| Phan tich range va tim Spring / Upthrust tren nen vua dong (1)   |
//+------------------------------------------------------------------+
void CheckSignal()
  {
   int needBars = InpRangeBars + InpVolMAPeriod + 5;
   if(Bars(_Symbol, InpTF) < needBars)
      return;

   double atrBuf[];
   if(CopyBuffer(atrHandle, 0, 2, 1, atrBuf) != 1)
      return;
   double atr = atrBuf[0];
   if(atr <= 0)
      return;

   //--- Range tu nen 2 den nen InpRangeBars+1 (khong tinh nen tin hieu)
   int hiIdx = iHighest(_Symbol, InpTF, MODE_HIGH, InpRangeBars, 2);
   int loIdx = iLowest(_Symbol, InpTF, MODE_LOW, InpRangeBars, 2);
   if(hiIdx < 0 || loIdx < 0)
      return;
   double rangeHigh = iHigh(_Symbol, InpTF, hiIdx);
   double rangeLow  = iLow(_Symbol, InpTF, loIdx);
   double width     = rangeHigh - rangeLow;

   if(width < InpMinRangeATR * atr || width > InpMaxRangeATR * atr)
      return; // khong phai vung di ngang

   //--- Dem so lan gia cham 2 bien -> xac nhan la range that
   double tol = InpTouchTolATR * atr;
   int touchHigh = 0, touchLow = 0;
   for(int i = 2; i < InpRangeBars + 2; i++)
     {
      if(iHigh(_Symbol, InpTF, i) >= rangeHigh - tol) touchHigh++;
      if(iLow(_Symbol, InpTF, i)  <= rangeLow + tol)  touchLow++;
     }
   if(touchHigh < InpMinTouches || touchLow < InpMinTouches)
      return;

   if(InpDrawRange)
      DrawRange(rangeHigh, rangeLow);

   //--- Nen tin hieu (nen 1, da dong)
   double o = iOpen(_Symbol, InpTF, 1);
   double h = iHigh(_Symbol, InpTF, 1);
   double l = iLow(_Symbol, InpTF, 1);
   double c = iClose(_Symbol, InpTF, 1);
   double barRange = h - l;
   if(barRange <= 0)
      return;

   //--- Volume (tick volume) so voi trung binh
   double volSum = 0;
   for(int i = 2; i < InpVolMAPeriod + 2; i++)
      volSum += (double)iVolume(_Symbol, InpTF, i);
   double volAvg = volSum / InpVolMAPeriod;
   double vol    = (double)iVolume(_Symbol, InpTF, 1);
   bool volOK    = (volAvg > 0 && vol >= InpVolMult * volAvg);
   if(!volOK)
      return;

   //--- SPRING -> BUY
   if(InpAllowBuy &&
      l < rangeLow &&
      rangeLow - l <= InpMaxPenetrationATR * atr &&
      c > rangeLow && c < rangeHigh &&
      (c - l) / barRange >= InpCloseStrength)
     {
      double sl = l - InpSLBufferATR * atr;
      OpenTrade(ORDER_TYPE_BUY, sl, rangeHigh, "Spring");
      return;
     }

   //--- UPTHRUST -> SELL
   if(InpAllowSell &&
      h > rangeHigh &&
      h - rangeHigh <= InpMaxPenetrationATR * atr &&
      c < rangeHigh && c > rangeLow &&
      (h - c) / barRange >= InpCloseStrength)
     {
      double sl = h + InpSLBufferATR * atr;
      OpenTrade(ORDER_TYPE_SELL, sl, rangeLow, "Upthrust");
      return;
     }
  }

//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double sl, double rangeTarget, string tag)
  {
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double entry  = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double risk   = MathAbs(entry - sl);
   if(risk <= 0)
      return;

   double tp;
   if(InpTPMode == TP_FIXED_RR)
      tp = (type == ORDER_TYPE_BUY) ? entry + InpRR * risk : entry - InpRR * risk;
   else
      tp = rangeTarget;

   double reward = (type == ORDER_TYPE_BUY) ? tp - entry : entry - tp;
   if(reward <= 0 || reward / risk < InpMinRR)
     {
      PrintFormat("%s bo qua: RR=%.2f < %.2f", tag, reward / risk, InpMinRR);
      return;
     }

   //--- Kiem tra khoang cach dung toi thieu cua san
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(risk < minDist || reward < minDist)
      return;

   double lot = CalcLot(type, entry, sl);
   if(lot <= 0)
      return;

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   bool ok = (type == ORDER_TYPE_BUY) ? trade.Buy(lot, _Symbol, 0, sl, tp, "WY " + tag)
                                      : trade.Sell(lot, _Symbol, 0, sl, tp, "WY " + tag);
   if(ok)
      PrintFormat("%s: %s %.2f lot, SL=%.2f TP=%.2f", tag,
                  (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), lot, sl, tp);
   else
      PrintFormat("Loi vao lenh %s: %d %s", tag, trade.ResultRetcode(), trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
double CalcLot(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), InpMaxLot);
   double lot    = InpFixedLot;

   if(InpLotMode == LOT_RISK)
     {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double lossPerLot = 0;
      if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, lossPerLot) || lossPerLot >= 0)
        {
         Print("Khong tinh duoc lot theo rui ro");
         return 0;
        }
      lot = riskMoney / MathAbs(lossPerLot);
     }

   lot = MathFloor(lot / step) * step;
   if(lot < minLot)
     {
      PrintFormat("Lot %.3f nho hon lot toi thieu %.2f -> bo qua lenh (SL qua xa so voi von)", lot, minLot);
      return 0;
     }
   return NormalizeDouble(MathMin(lot, maxLot), 2);
  }

//+------------------------------------------------------------------+
//| Doi SL ve gia vao lenh khi lai >= InpBreakevenR x rui ro ban dau |
//+------------------------------------------------------------------+
void ManageBreakeven()
  {
   if(InpBreakevenR <= 0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long   ptype = PositionGetInteger(POSITION_TYPE);

      if(ptype == POSITION_TYPE_BUY)
        {
         if(sl == 0 || sl >= open) continue;          // da hoa von roi
         double r   = open - sl;
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid - open >= InpBreakevenR * r)
            trade.PositionModify(ticket, open, tp);
        }
      else
        {
         if(sl == 0 || sl <= open) continue;
         double r   = sl - open;
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(open - ask >= InpBreakevenR * r)
            trade.PositionModify(ticket, open, tp);
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
   MqlDateTime t;
   TimeCurrent(t);
   if(InpStartHour <= InpEndHour)
      return (t.hour >= InpStartHour && t.hour < InpEndHour);
   return (t.hour >= InpStartHour || t.hour < InpEndHour); // khung gio qua dem
  }

//+------------------------------------------------------------------+
int TradesToday()
  {
   MqlDateTime t;
   TimeCurrent(t);
   t.hour = 0; t.min = 0; t.sec = 0;
   datetime dayStart = StructToTime(t);
   if(!HistorySelect(dayStart, TimeCurrent()))
      return 0;
   int count = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
void DrawRange(double hi, double lo)
  {
   datetime t1 = iTime(_Symbol, InpTF, InpRangeBars + 1);
   datetime t2 = iTime(_Symbol, InpTF, 0);
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
   ChartRedraw();
  }
//+------------------------------------------------------------------+
