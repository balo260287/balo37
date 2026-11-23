//+------------------------------------------------------------------+
//| XauWickBot.mq5  v1.0                                             |
//| Bot scalp VANG M1 theo mo hinh RUT RAU + DCA - CHI CHAY DEMO     |
//| Symbol: XAUUSDm (Exness)   Magic: 290001                         |
//|                                                                  |
//| Cach chay:                                                       |
//|  1. Nen tin hieu (da dong): rau dai mot phia                     |
//|       - rau duoi dai  -> phe mua dap lai  -> tin hieu BUY        |
//|       - rau tren dai  -> phe ban dap lai  -> tin hieu SELL       |
//|  2. Nen xac nhan (nen ngay sau): choc lai vao vung rau do,       |
//|     CUNG rut rau, KHONG pha day/dinh cua rau truoc.              |
//|  3. Vao lenh o dau nen tiep theo, theo huong rau.                |
//|  4. Gia di nguoc InpDcaStep USD -> nhoi them (toi da MaxLayers). |
//|  5. Ca chum lai >= InpBasketTP -> dong. Lo >= InpBasketSL -> cat.|
//|  Loc: gio phien London/NY, gio chuyen ngay, tin USD manh,        |
//|       spread, toi Thu 6. Co SL that tren san cho ca chum.        |
//|  Dung: lo ngay / thua lien tiep / sut von / dat muc tieu.        |
//+------------------------------------------------------------------+
#property copyright "XauWickBot"
#property version   "1.00"

#include <Trade\Trade.mqh>

input group "=== Von & rui ro ==="
input double InpLot           = 0.01;   // Lot moi lenh (vang: 0.01 lot ~ 1 USD / 1 USD gia)
input double InpBasketTP      = 0.5;    // Chot lai ca chum (USD)
input double InpBasketSL      = 0.5;    // Chot lo ca chum (USD)
input double InpHardSLMult    = 2.0;    // SL that tren san = BasketSL x he so (du phong mat mang)
input int    InpMaxLayers     = 1;      // So lenh toi da trong chum (1 = khong DCA). Bat DCA: 2 + SL >= 1.0
input double InpDcaStep       = 0.30;   // Gia di nguoc bao nhieu USD thi nhoi them
input double InpDailyLoss     = 5.0;    // Lo toi da trong ngay (USD) -> nghi den mai
input int    InpMaxConsecLoss = 5;      // Thua lien tiep bao nhieu chum thi nghi het ngay (0 = tat)
input double InpMaxDrawdown   = 10.0;   // Lai bot tut tu dinh qua X USD -> DUNG HAN (0 = tat)
input double InpTarget        = 50.0;   // Lai cua bot dat muc nay -> dung (USD)
input bool   InpResetStats    = false;  // true = tinh lai tu dau (bat 1 lan roi tat)
input bool   InpAllowReal     = false;  // Cho phep chay tai khoan THAT (de false)

input group "=== Mo hinh rut rau (M1) ==="
input double InpMinRange      = 0.40;   // Nen tin hieu phai dai it nhat (USD gia)
input double InpWickRatio     = 0.50;   // Rau nen tin hieu >= % do dai nen (0.5 = 50%)
input double InpWickBody      = 1.5;    // Rau nen tin hieu >= X lan than nen
input double InpConfirmRatio  = 0.30;   // Rau nen xac nhan >= % do dai nen
input double InpBreakTol      = 0.10;   // Nen xac nhan duoc choc qua day/dinh rau toi da (USD)
input bool   InpUseTrend      = true;   // Chi danh rau CUNG xu huong EMA M5 (khuyen bat)
input int    InpEmaPeriod     = 50;     // EMA M5

input group "=== Bo loc ==="
input double InpMaxSpread     = 0.35;   // Spread toi da (USD gia)
input int    InpStartHour     = 7;      // Gio bat dau mo lenh (gio server) - London
input int    InpEndHour       = 21;     // Gio ket thuc mo lenh (gio server) - het NY
input bool   InpNewsFilter    = true;   // Ne tin USD quan trong (lich kinh te MT5)
input int    InpNewsMin       = 30;     // Nghi truoc/sau tin bao nhieu phut
input int    InpFridayStop    = 20;     // Thu 6: tu gio nay khong mo lenh moi
input int    InpFridayClose   = 21;     // Thu 6: tu gio nay dong het lenh
input int    InpCooldownMin   = 5;      // Nghi sau khi chot lo (phut)
input int    InpMaxHoldMin    = 30;     // Giu chum qua X phut -> dong khi >= hoa von (0 = tat)

input group "=== Khac ==="
input long   InpMagic         = 290001; // Magic number (khac bot BTC)

CTrade   trade;
int      emaH          = INVALID_HANDLE;
datetime lastEntryBar  = 0;
datetime lastFailTime  = 0;
int      lastCount     = -1;
datetime lastHistCheck = 0;
double   cachedClosed  = 0;
double   cachedSince   = 0;
bool     selfClosed    = false;
bool     initOk        = false;
long     myChartKey    = 0;
datetime newsCheck     = 0;
bool     newsBlocked   = false;
string   newsName      = "";

// Trang thai luu qua khi tat/bat MT5
string   gvPrefix;
datetime cooldownUntil = 0;
bool     targetHit     = false;
int      consecLoss    = 0;
int      stopDayKey    = 0;
datetime startTime     = 0;
double   botPeak       = 0;
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
      Alert("XauWickBot: day la tai khoan THAT. Bot chi chay DEMO -> DA DUNG.");
      return(INIT_FAILED);
     }
   if(InpLot <= 0 || InpBasketTP <= 0 || InpBasketSL <= 0 || InpMaxLayers < 1 || InpDcaStep <= 0 ||
      InpHardSLMult < 1.0 || InpMinRange <= 0 || InpWickRatio <= 0 || InpWickRatio >= 1 ||
      InpStartHour < 0 || InpEndHour > 24 || InpStartHour >= InpEndHour)
     {
      Alert("XauWickBot: tham so khong hop le.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(StringFind(_Symbol, "XAU") < 0)
      Print("XauWickBot: CANH BAO - bot viet cho VANG (XAUUSDm), dang gan vao ", _Symbol);

   emaH = iMA(_Symbol, PERIOD_M5, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(emaH == INVALID_HANDLE)
     {
      Alert("XauWickBot: khong tao duoc EMA.");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);

   gvPrefix = StringFormat("XWB_%s_%I64d_%I64d_", _Symbol, InpMagic, AccountInfoInteger(ACCOUNT_LOGIN));

   // Chong chay trung 2 bot cung Magic + symbol
   myChartKey = (long)(ChartID() % 1000000007);
   if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(gvPrefix + "lock"))
     {
      long     other = (long)GlobalVariableGet(gvPrefix + "lock");
      datetime hb    = (datetime)(long)GvGet("hb", 0);
      if(other != myChartKey && TimeLocal() - hb < 60)
        {
         Alert(StringFormat("XauWickBot: DA CO 1 BOT KHAC chay %s voi Magic %I64d. Go bot kia hoac doi InpMagic. -> DA DUNG.",
                            _Symbol, InpMagic));
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

   startTime = (datetime)(long)GvGet("start", 0);
   if(InpResetStats || startTime <= 0)
     {
      startTime = TimeCurrent();
      targetHit = false;
      ddStop    = false;
      botPeak   = 0;
      consecLoss = 0;
      stopDayKey = 0;
      GvSet("start", (double)startTime);
     }
   lastHistCheck = 0;
   lastCount     = -1;
   initOk        = true;
   SaveState();

   Alert(StringFormat("XauWickBot v1.0 DA CHAY tren %s | lot %.2f | TP +%.2f / SL -%.2f USD | DCA %d lenh, cach %.2f ... OK",
                      _Symbol, NormLot(InpLot), InpBasketTP, InpBasketSL, InpMaxLayers, InpDcaStep));
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
   if(emaH != INVALID_HANDLE)
      IndicatorRelease(emaH);
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
// Dem lenh cua bot. dir: 1 = Buy, -1 = Sell. extreme: gia vao xau nhat.
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
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic)
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic)
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
   Print("XauWickBot: dong ca chum - ", why, allClosed ? "" : " (CON LENH CHUA DONG, se thu lai)");
   lastHistCheck = 0;
   selfClosed    = true;
   return(allClosed);
  }

//+------------------------------------------------------------------+
// Lai/lo da chot cua RIENG bot: hom nay va tu luc gan (moi 5 giay)
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
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
         continue;
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      double v = HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
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
// MO HINH RUT RAU: nen 2 = nen tin hieu, nen 1 = nen xac nhan (deu da dong).
// dir 1 = Buy (rau duoi), -1 = Sell (rau tren). info: mo ta cho bang.
bool WickSignal(int dir, string &info)
  {
   double o2 = iOpen(_Symbol, PERIOD_M1, 2), h2 = iHigh(_Symbol, PERIOD_M1, 2);
   double l2 = iLow(_Symbol, PERIOD_M1, 2),  c2 = iClose(_Symbol, PERIOD_M1, 2);
   double o1 = iOpen(_Symbol, PERIOD_M1, 1), h1 = iHigh(_Symbol, PERIOD_M1, 1);
   double l1 = iLow(_Symbol, PERIOD_M1, 1),  c1 = iClose(_Symbol, PERIOD_M1, 1);
   if(o2 <= 0 || o1 <= 0)
      return(false);

   double r2 = h2 - l2, r1 = h1 - l1;
   if(r2 < InpMinRange || r1 <= 0)
     {
      info = StringFormat("nen nho (%.2f < %.2f)", r2, InpMinRange);
      return(false);
     }
   double body2 = MathAbs(c2 - o2);

   if(dir > 0)
     {
      double w2 = MathMin(o2, c2) - l2;       // rau duoi nen tin hieu
      double u2 = h2 - MathMax(o2, c2);
      if(!(w2 >= InpWickRatio * r2 && w2 >= InpWickBody * body2 && w2 > u2))
        {
         info = StringFormat("chua co rau duoi (%.0f%%)", w2 / r2 * 100);
         return(false);
        }
      double w1 = MathMin(o1, c1) - l1;       // rau duoi nen xac nhan
      bool retest  = (l1 <= MathMin(o2, c2));  // choc lai vao vung rau
      bool hold    = (l1 >= l2 - InpBreakTol) && (c1 > l2);  // khong pha day rau
      bool wick1   = (w1 >= InpConfirmRatio * r1);
      info = StringFormat("rau duoi %.0f%% | xac nhan: choc %s, giu day %s, rut rau %s",
                          w2 / r2 * 100, retest ? "OK" : "-", hold ? "OK" : "-", wick1 ? "OK" : "-");
      return(retest && hold && wick1);
     }
   else
     {
      double w2 = h2 - MathMax(o2, c2);       // rau tren nen tin hieu
      double d2 = MathMin(o2, c2) - l2;
      if(!(w2 >= InpWickRatio * r2 && w2 >= InpWickBody * body2 && w2 > d2))
        {
         info = StringFormat("chua co rau tren (%.0f%%)", w2 / r2 * 100);
         return(false);
        }
      double w1 = h1 - MathMax(o1, c1);
      bool retest  = (h1 >= MathMax(o2, c2));
      bool hold    = (h1 <= h2 + InpBreakTol) && (c1 < h2);
      bool wick1   = (w1 >= InpConfirmRatio * r1);
      info = StringFormat("rau tren %.0f%% | xac nhan: choc %s, giu dinh %s, rut rau %s",
                          w2 / r2 * 100, retest ? "OK" : "-", hold ? "OK" : "-", wick1 ? "OK" : "-");
      return(retest && hold && wick1);
     }
  }

// Xu huong EMA M5: 1 tang, -1 giam, 0 chua ro
int TrendM5()
  {
   double e[1];
   if(CopyBuffer(emaH, 0, 1, 1, e) != 1)
      return(0);
   double c = iClose(_Symbol, PERIOD_M5, 1);
   if(c <= 0)
      return(0);
   return(c > e[0] ? 1 : (c < e[0] ? -1 : 0));
  }

//+------------------------------------------------------------------+
// Tin USD quan trong trong khoang +-InpNewsMin phut (kiem tra moi 60s)
bool NewsBlocked()
  {
   if(!InpNewsFilter || MQLInfoInteger(MQL_TESTER))
      return(false);
   if(newsCheck != 0 && TimeCurrent() - newsCheck < 60)
      return(newsBlocked);
   newsCheck   = TimeCurrent();
   newsBlocked = false;
   newsName    = "";
   MqlCalendarValue vals[];
   datetime from = TimeCurrent() - InpNewsMin * 60;
   datetime to   = TimeCurrent() + InpNewsMin * 60;
   if(CalendarValueHistory(vals, from, to, NULL, "USD"))
     {
      for(int i = 0; i < ArraySize(vals); i++)
        {
         MqlCalendarEvent ev;
         if(CalendarEventById(vals[i].event_id, ev) && ev.importance == CALENDAR_IMPORTANCE_HIGH)
           {
            newsBlocked = true;
            newsName    = ev.name;
            break;
           }
        }
     }
   return(newsBlocked);
  }

//+------------------------------------------------------------------+
double PerUnit(double lot, double price)
  {
   double p = 0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, lot, price, price + 1.0, p))
      return(0);
   return(p);
  }

// SL chung tren san cho ca chum (du phong mat mang)
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
   double dist = InpBasketSL * InpHardSLMult / pu;
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
      if(MathAbs(PositionGetDouble(POSITION_SL) - sl) < _Point * 2)
         continue;
      if(!trade.PositionModify(t, sl, PositionGetDouble(POSITION_TP)))
         Print("XauWickBot: dat SL chung loi ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
bool OpenOrder(int dir, string cmt)
  {
   if(TimeCurrent() - lastFailTime < 10)
      return(false);
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
      return(false);
   double lot   = NormLot(InpLot);
   double price = (dir > 0) ? tk.ask : tk.bid;

   double margin = 0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9)
     {
      Print("XauWickBot: khong du ky quy.");
      lastFailTime = TimeCurrent();
      return(false);
     }
   double pu = PerUnit(lot, price);
   if(pu <= 0)
     {
      Print("XauWickBot: khong tinh duoc rui ro, bo qua lenh.");
      lastFailTime = TimeCurrent();
      return(false);
     }
   double dist    = InpBasketSL * InpHardSLMult / pu;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(dist < minDist * 1.5)
      dist = minDist * 1.5;
   double sl = NormalizeDouble((dir > 0) ? price - dist : price + dist, _Digits);

   bool ok = (dir > 0) ? trade.Buy(lot, _Symbol, 0, sl, 0, cmt)
             : trade.Sell(lot, _Symbol, 0, sl, 0, cmt);
   uint rc = trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
     {
      Print("XauWickBot: vao lenh loi ", rc, " ", trade.ResultRetcodeDescription());
      lastFailTime = TimeCurrent();
      return(false);
     }
   Print("XauWickBot: da vao ", cmt, " lot ", DoubleToString(lot, 2), " gia ", DoubleToString(price, _Digits));
   SyncBasketSL();
   return(true);
  }

//+------------------------------------------------------------------+
void Panel(string st, int n, double fl, double dayPL, double spread)
  {
   Comment(StringFormat(
              "XauWickBot v1.0 (%s) - rut rau M1 + DCA\n"
              "Trang thai: %s\n"
              "So lenh: %d / %d   (nhoi cach %.2f USD)\n"
              "Lai/lo dang mo: %.2f USD   (chot lai +%.2f | chot lo -%.2f)\n"
              "Lai/lo hom nay: %.2f USD   (dung o -%.2f)\n"
              "Thua lien tiep: %d / %d\n"
              "Spread: %.2f USD   (toi da %.2f)\n"
              "Bot lai tu luc gan: %.2f USD   (muc tieu +%.2f)\n"
              "Sut tu dinh: %.2f USD   (dung han o %.2f)",
              IsDemo() ? "DEMO" : "THAT", st, n, InpMaxLayers, InpDcaStep,
              fl, InpBasketTP, InpBasketSL, dayPL, InpDailyLoss, consecLoss, InpMaxConsecLoss,
              spread, InpMaxSpread, cachedSince + fl, InpTarget,
              MathMax(0.0, botPeak - (cachedSince + fl)), InpMaxDrawdown));
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   GvSet("hb", (double)TimeLocal());
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.bid <= 0 || tk.ask <= 0)
      return;
   double spread = tk.ask - tk.bid;

   int      dir;
   double   fl, ext;
   datetime firstTime;
   int      n = CountPos(dir, fl, ext, firstTime);

   if(n != lastCount)
     {
      if(n > 0)
         SyncBasketSL();
      else
         if(lastCount > 0 && !selfClosed)
           {
            // San cat SL (mat mang) hoac dong tay -> coi nhu thua 1 lan
            cooldownUntil = TimeCurrent() + InpCooldownMin * 60;
            consecLoss++;
            if(InpMaxConsecLoss > 0 && consecLoss >= InpMaxConsecLoss)
               stopDayKey = DayKey(TimeCurrent());
            SaveState();
            Print("XauWickBot: chum bi dong ben ngoai (SL san / dong tay) -> nghi ", InpCooldownMin, " phut.");
           }
      selfClosed = false;
      lastCount  = n;
     }

   UpdateClosedPL();
   double dayPL = cachedClosed + fl;
   double botPL = cachedSince + fl;
   int    today = DayKey(TimeCurrent());
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   if(stopDayKey != 0 && stopDayKey != today)
     {
      stopDayKey = 0;
      consecLoss = 0;
      SaveState();
     }

   // 1. Muc tieu
   if(!targetHit && botPL >= InpTarget)
     {
      CloseAll("DA DAT MUC TIEU");
      targetHit = true;
      SaveState();
      Alert(StringFormat("XauWickBot: bot da lai %.2f USD, DAT MUC TIEU -> dung. Dat InpResetStats = true de chay tiep.", botPL));
     }
   if(targetHit)
     {
      if(n > 0)
         CloseAll("DA DAT MUC TIEU (dong not)");
      Panel("DA DAT MUC TIEU - bot dung", n, fl, dayPL, spread);
      return;
     }

   // 2. Sut von tu dinh
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
      Alert("XauWickBot: sut von qua InpMaxDrawdown -> DUNG HAN. Dat InpResetStats = true de chay lai.");
     }
   if(ddStop)
     {
      if(n > 0)
         CloseAll("dang dung do sut von");
      Panel("DUNG HAN: sut von qua InpMaxDrawdown", n, fl, dayPL, spread);
      return;
     }

   // 3. Chot lo chum
   if(n > 0 && fl <= -InpBasketSL)
     {
      CloseAll(StringFormat("chot lo chum (%.2f USD)", fl));
      cooldownUntil = TimeCurrent() + InpCooldownMin * 60;
      consecLoss++;
      if(InpMaxConsecLoss > 0 && consecLoss >= InpMaxConsecLoss)
        {
         stopDayKey = today;
         Print("XauWickBot: thua ", consecLoss, " chum lien tiep -> nghi den hom sau.");
        }
      SaveState();
      Panel("Vua chot lo, dang nghi", n, fl, dayPL, spread);
      return;
     }

   // 4. Lo ngay / thua lien tiep
   if(stopDayKey == 0 && dayPL <= -InpDailyLoss)
     {
      stopDayKey = today;
      SaveState();
     }
   if(stopDayKey != 0)
     {
      if(n > 0)
         CloseAll("dang trong ngay nghi");
      Panel("DUNG HOM NAY (lo ngay / thua lien tiep) - mai chay lai", n, fl, dayPL, spread);
      return;
     }

   // 5. Chot lai chum
   if(n > 0 && fl >= InpBasketTP)
     {
      if(CloseAll(StringFormat("chot lai chum (+%.2f USD)", fl)))
        {
         consecLoss = 0;
         SaveState();
        }
      Panel("Vua chot lai", n, fl, dayPL, spread);
      return;
     }

   // 6. Thu 6 toi: dong het truoc khi dong cua cuoi tuan
   if(now.day_of_week == 5 && now.hour >= InpFridayClose)
     {
      if(n > 0)
         CloseAll("Thu 6 toi - dong truoc cuoi tuan");
      Panel("Thu 6 toi - nghi cuoi tuan", 0, 0, dayPL, spread);
      return;
     }

   // 7. Giu qua lau -> dong khi hoa von
   if(n > 0 && InpMaxHoldMin > 0 && firstTime > 0 &&
      TimeCurrent() - firstTime >= InpMaxHoldMin * 60 && fl >= 0)
     {
      CloseAll(StringFormat("giu qua %d phut, dong hoa von (%.2f USD)", InpMaxHoldMin, fl));
      Panel("Vua dong hoa von do giu lau", n, fl, dayPL, spread);
      return;
     }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Panel("CHUA BAT 'Algo Trading'", n, fl, dayPL, spread);
      return;
     }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
     {
      Panel("San dang dong / han che giao dich", n, fl, dayPL, spread);
      return;
     }
   if(spread > InpMaxSpread)
     {
      Panel(StringFormat("Spread cao (%.2f), cho...", spread), n, fl, dayPL, spread);
      return;
     }
   if(NewsBlocked())
     {
      Panel("Ne tin USD: " + newsName, n, fl, dayPL, spread);
      return;
     }

   string st = "Dang cho tin hieu...";
   if(n == 0)
     {
      datetime bar = iTime(_Symbol, PERIOD_M1, 0);
      if(TimeCurrent() < cooldownUntil)
         st = StringFormat("Nghi sau chot lo (con ~%d phut)", (int)((cooldownUntil - TimeCurrent()) / 60) + 1);
      else
         if(now.hour < InpStartHour || now.hour >= InpEndHour)
            st = StringFormat("Ngoai gio (%d-%dh server)", InpStartHour, InpEndHour);
         else
            if(now.day_of_week == 5 && now.hour >= InpFridayStop)
               st = "Thu 6 toi - khong mo lenh moi";
            else
               if(bar == lastEntryBar)
                  st = "Da xu ly nen nay, cho nen M1 moi...";
               else
                 {
                  int    tr = InpUseTrend ? TrendM5() : 0;
                  string ib = "", isl = "";
                  bool   sb = (!InpUseTrend || tr > 0) && WickSignal(1, ib);
                  bool   ss = (!InpUseTrend || tr < 0) && WickSignal(-1, isl);
                  if(sb && !ss)
                    {
                     if(OpenOrder(1, "Wick BUY 1"))
                       {
                        lastEntryBar = bar;
                        st = "Da BUY: " + ib;
                       }
                    }
                  else
                     if(ss && !sb)
                       {
                        if(OpenOrder(-1, "Wick SELL 1"))
                          {
                           lastEntryBar = bar;
                           st = "Da SELL: " + isl;
                          }
                       }
                     else
                       {
                        if(InpUseTrend && tr == 0)
                           st = "Chua ro xu huong M5, cho...";
                        else
                           st = (InpUseTrend ? (tr > 0 ? "[Xu huong TANG - chi BUY] " : "[Xu huong GIAM - chi SELL] ") : "") +
                                "BUY: " + (ib == "" ? "-" : ib) + " | SELL: " + (isl == "" ? "-" : isl);
                       }
                 }
     }
   else
      if(n < InpMaxLayers)
        {
         string num = IntegerToString(n + 1);
         if(dir < 0 && tk.bid >= ext + InpDcaStep)  // gia SELL moi cao hon lenh truoc
            OpenOrder(-1, "Wick SELL DCA " + num);
         else
            if(dir > 0 && tk.ask <= ext - InpDcaStep)  // gia BUY moi thap hon lenh truoc
               OpenOrder(1, "Wick BUY DCA " + num);
         st = StringFormat("Dang giu %d lenh %s, nhoi tiep neu gia nguoc %.2f USD",
                           n, dir < 0 ? "SELL" : "BUY", InpDcaStep);
        }
      else
         st = "Du so lenh, cho chot lai / chot lo";

   Panel(st, n, fl, dayPL, spread);
  }
//+------------------------------------------------------------------+
