//+------------------------------------------------------------------+
//|                                           StarRiskCalculator.mq5 |
//|                       Copyright 2022, Nkondog Anselme Venceslas. |
//|                              https://www.linkedin.com/in/nkondog |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Nkondog Anselme Venceslas."
#property link      "https://www.linkedin.com/in/nkondog"
#property version   "1.10"

//1.1 -> Add XAU lot computation and TP

#define KEY_B             66
#define KEY_S             83


//Parameters
MqlTick last_tick;
//Enumerative for the base used for risk calculation
enum ENUM_RISK_BASE
  {
   RISK_BASE_EQUITY=1,        //EQUITY
   RISK_BASE_BALANCE=2,       //BALANCE
   RISK_BASE_FREEMARGIN=3,    //FREE MARGIN
  };

//Enumerative for the default risk type
enum ENUM_RISK_DEFAULT_TYPE
  {
   FIXED=1,      //FIXED
   Percent=2,       //AMOUNT BASE
  };

//Enumerative for the default risk size
enum ENUM_RISK_DEFAULT_SIZE
  {
   RISK_DEFAULT_FIXED=1,      //FIXED SIZE
   RISK_DEFAULT_AUTO=2,       //AUTOMATIC SIZE BASED ON RISK
  };

input ENUM_RISK_DEFAULT_SIZE InpRiskDefaultSize=RISK_DEFAULT_AUTO;      //Position Size Mode
input double InpDefaultLotSize=0.01;                                    //Lot Size if fixed Position Size Mode =  FIXED
input ENUM_RISK_BASE InpRiskBase=RISK_BASE_BALANCE;                     //Risk Base
input ENUM_RISK_DEFAULT_TYPE InpRiskDefaultType=FIXED;                  //Risk Type
input double InpFixRiskAmount=10;                                       //Max Account Risk ($) if risk type = FIXED
input double InpMaxLossPercent=1.0;                                     //Max Account Risk (%)
input double InpTPMultiple=1;                                           //TP multiple
input double InpMinLotSize=0.01;                                              //Minimum Position Size Allowed
input double InpMaxLotSize=100;                                               //Maximum Position Size Allowed
input int InpSlippage=1;                                                //Slippage

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//input double InpMaxRiskPerTrade=0.5;                                    //Percentage To Risk Each Trade
double RiskBaseAmount=InpFixRiskAmount;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Symb = Symbol();
string AccountCurr = AccountInfoString(ACCOUNT_CURRENCY);
double MaxRiskPerTrade=0.0;                                    //Percentage To Risk Each Trade
double LotSize=InpDefaultLotSize;
double StopLoss=0.0;
double TakeProfit=0.0;
double risk=0.0;
double StoplossPips=0.0;
double riskDiff=0.0;
double initialLoss=0.0;
double totalLoss=0.0;
double maxRiskPerLife=0.0;

//TickValue is the value of the individual price increment for 1 lot of the instrument, expressed in the account currenty
double TickValue=SymbolInfoDouble(Symb,SYMBOL_TRADE_TICK_VALUE);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("The Expert Advisor with name ",MQLInfoString(MQL_PROGRAM_NAME)," is running");
//--- enable object create events
   ChartSetInteger(ChartID(),CHART_EVENT_OBJECT_CREATE,true);
//--- enable object delete events
   ChartSetInteger(ChartID(),CHART_EVENT_OBJECT_DELETE,true);
      //--- create a horizontal line
   if(!HLineCreate())
     {
      return(INIT_FAILED);
     }
//--- redraw the chart and wait for 1 second
   ChartRedraw();
   Sleep(1000);
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0);
   Comment("");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   StopLoss  = NormalizeDouble(ObjectGetDouble(0, "sl", OBJPROP_PRICE), _Digits);

//Define the base for the risk calculation depending on the parameter chosen
   if(InpRiskBase==RISK_BASE_BALANCE)
      RiskBaseAmount=AccountInfoDouble(ACCOUNT_BALANCE);
   if(InpRiskBase==RISK_BASE_EQUITY)
      RiskBaseAmount=AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpRiskBase==RISK_BASE_FREEMARGIN)
      RiskBaseAmount=AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   displayOnChart();
  }

//+------------------------------------------------------------------+
//| Create the horizontal line                                       |
//+------------------------------------------------------------------+
bool HLineCreate(const long            chart_ID=0,        // chart's ID
                 const string          name="sl",      // line name
                 const int             sub_window=0,      // subwindow index
                 const color           clr=clrRed,        // line color
                 const ENUM_LINE_STYLE style=STYLE_SOLID, // line style
                 const int             width=1,           // line width
                 const bool            back=false,        // in the background
                 const bool            selection=true,    // highlight to move
                 const bool            hidden=true,       // hidden in the object list
                 const long            z_order=0)         // priority for mouse click
  {
//--- if the price is not set, set it at 15 pips below the current Bid price level
   double price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- reset the error value
   ResetLastError();
//--- create a horizontal line
   if(!ObjectCreate(chart_ID,name,OBJ_HLINE,sub_window,0,price))
     {
      Print(__FUNCTION__,
            ": failed to create a horizontal line! Error code = ",GetLastError());
      return(false);
     }
//--- set line color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set line display style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set line width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the line by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,         // Event identifier
                  const long& lparam,   // Event parameter of long type
                  const double& dparam, // Event parameter of double type
                  const string& sparam) // Event parameter of string type
  {
//--- the object has been deleted
   if(id==CHARTEVENT_OBJECT_DELETE)
     {
      Print("The object with name ",sparam," has been deleted");
     }
//--- the object has been created
   if(id==CHARTEVENT_OBJECT_CREATE)
     {
      Print("The object with name ",sparam," has been created");
     }

   /*--- the object has been moved or its anchor point coordinates has been changed
      if(id==CHARTEVENT_OBJECT_DRAG)
        {
         StopLoss = ObjectGetDouble(0, sparam, OBJPROP_PRICE, 0);
         Print("The anchor point coordinates of the object with name ",sparam," has been changed. Price ", StopLoss);
         displayOnChart();
        }*/

   if(id==CHARTEVENT_KEYDOWN)
     {

      switch((int)lparam)
        {
         case  KEY_B:
            SendOrder(ORDER_TYPE_BUY,Symb,last_tick.ask,StopLoss,TakeProfit,LotSize);
            Alert("Buy " + (string)LotSize + " lot " + Symb + " at " + (string)last_tick.ask + " SL at " + (string)StopLoss + " TP at " + (string)TakeProfit);
            break;
         case  KEY_S:
            SendOrder(ORDER_TYPE_SELL,Symb,last_tick.bid,StopLoss,TakeProfit,LotSize);
            Alert("Sell " + (string)LotSize + " lot " + Symb + " at " + (string)last_tick.bid + " SL at " + (string)StopLoss + " TP at " + (string)TakeProfit);
            break;
         default:
            //Print("Do nothing");
            break;
        }
     }
  }


//Lot Size Calculator
void LotSizeCalculate(double stopLoss)
  {
   SymbolInfoTick(_Symbol,last_tick);
   double SL=0;
   double PriceAsk=last_tick.ask;
   double PriceBid=last_tick.bid;
   double pipDiff = 0.0;
   double spread = (SymbolInfoInteger(Symb, SYMBOL_SPREAD) * _Point);

   if(stopLoss < PriceAsk)
     {
      pipDiff = PriceAsk-stopLoss;
      SL = pipDiff/_Point;
      //Print("PriceAsk ", PriceAsk, " pipDiff mult ", (pipDiff * InpTPMultiple), " point ", (SymbolInfoInteger(Symb, SYMBOL_SPREAD) * _Point));
      TakeProfit = PriceAsk + (pipDiff * InpTPMultiple) + (spread*2);
     }
   if(stopLoss > PriceAsk)
     {
      pipDiff = stopLoss-PriceBid;
      SL = pipDiff/_Point;
      //Print("PriceAsk ", PriceAsk, " pipDiff mult ", (pipDiff * InpTPMultiple), " point ", (SymbolInfoInteger(Symb, SYMBOL_SPREAD) * _Point));
      TakeProfit = PriceBid - (pipDiff * InpTPMultiple) - (spread*2);
     }
//Print("Stop loss distance ", SL);
   StoplossPips = SL;

//If the position size is dynamic
   if(InpRiskDefaultSize==RISK_DEFAULT_AUTO)
     {
      //If the stop loss is not zero then calculate the lot size
      if(SL!=0)
        {
         tickDifferenceHandler();

         //Print("tickvalue", TickValue);
         //Calculate the Position Size
         //Print("RiskBaseAmount ", RiskBaseAmount, " MaxRiskPerTrade ", MaxRiskPerTrade, "Stop loss ", SL, " TickValue ", TickValue);

         LotSize=((RiskBaseAmount*MaxRiskPerTrade/100)/(SL*TickValue));

        }
      //If the stop loss is zero then the lot size is the default one
      if(SL==0)
        {
         LotSize=InpDefaultLotSize;
        }
     }
//Normalize the Lot Size to satisfy the allowed lot increment and minimum and maximum position size
   LotSize=MathFloor(LotSize/SymbolInfoDouble(Symb,SYMBOL_VOLUME_STEP))*SymbolInfoDouble(Symb,SYMBOL_VOLUME_STEP);

//Limit the lot size in case it is greater than the maximum allowed by the user
   if(LotSize>InpMaxLotSize)
      LotSize=InpMaxLotSize;
//Limit the lot size in case it is greater than the maximum allowed by the broker
   if(LotSize>SymbolInfoDouble(Symb,SYMBOL_VOLUME_MAX))
      LotSize=SymbolInfoDouble(Symb,SYMBOL_VOLUME_MAX);
//Print("Lot ", LotSize, " Max lot ", SymbolInfoDouble(Symb,SYMBOL_VOLUME_MAX));
//If the lot size is too small then set it to 0 and don't trade
   if(LotSize < SymbolInfoDouble(Symb,SYMBOL_VOLUME_MIN))
     {
      LotSize=SymbolInfoDouble(Symb,SYMBOL_VOLUME_MIN);
      //Print("Lot size too small");
     }

  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Delete a text label                                              |
//+------------------------------------------------------------------+
bool LabelDelete(const long   chart_ID=0,   // chart's ID
                 const string name="Label") // label name
  {
//--- reset the error value
   ResetLastError();
//--- delete the label
   if(!ObjectDelete(chart_ID,name))
     {
      Print(__FUNCTION__,
            ": failed to delete a text label! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  }


//Send Order Function adjusted to handle errors and retry multiple times
void SendOrder(int Command, string Instrument, double OpenPrice, double SLPrice, double TPPrice, double lot, datetime Expiration=0)
  {
   MqlTradeRequest request= {};
   MqlTradeResult  result= {};

   if(lot==0)
      return;

   request.action       =TRADE_ACTION_DEAL;                       // type de l'opération de trading
   request.symbol       =Instrument;                              // symbole
   request.volume       =NormalizeDouble(lot,2);                  // volume de 0.1 lot
   request.type         =(ENUM_ORDER_TYPE)Command;                                 // type de l'ordre
   request.price        =OpenPrice;                               // prix d'ouverture
   request.sl           =NormalizeDouble(SLPrice,Digits());
   request.tp           =NormalizeDouble(TPPrice, Digits());
   request.deviation    =InpSlippage;
   request.expiration   =Expiration;                              // déviation du prix autorisée
   
   Print(request.sl + " - " + request.tp + " - "  + request.volume + " - "  + Digits());

   if(!OrderSend(request,result))
     {
      PrintFormat("OrderSend erreur %d",GetLastError());         // en cas d'erreur d'envoi de la demande, affiche le code d'erreur
      request.type_filling =SYMBOL_FILLING_FOK;
      if(!OrderSend(request,result))
        {
         PrintFormat("OrderSend erreur %d",GetLastError());      // en cas d'erreur d'envoi de la demande, affiche le code d'erreur
         if(GetLastError() == 4752)
           {
            Alert("Please enable EA trading");
           }
        }
     }
//--- informations de l'opération
   PrintFormat("retcode=%u  transaction=%I64u  ordre=%I64u",result.retcode,result.deal,result.order);

   if(result.retcode == TRADE_RETCODE_DONE && result.order != 0)
     {
      Alert("Ordre placed successfully");
     }
   return;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void displayOnChart()
  {

//Print("Take profit ", TakeProfit);
   initialLoss = (RiskBaseAmount * InpMaxLossPercent) / 100;

   if(InpRiskDefaultType == FIXED)
     {
      initialLoss = InpFixRiskAmount;
     }
   initialLoss = NormalizeDouble(initialLoss, 2);
   MaxRiskPerTrade = NormalizeDouble((initialLoss * 100) / RiskBaseAmount, 2);

   LotSizeCalculate(StopLoss);

   double StopAmount = (StoplossPips * LotSize * TickValue);

   if(InpRiskDefaultSize == RISK_DEFAULT_FIXED)
     {
      MaxRiskPerTrade = NormalizeDouble((StopAmount * 100) / RiskBaseAmount, 2);
     }

   Comment("Star Risk Calculator \nLoss: " + (string)initialLoss + " " + AccountCurr + "\nMaxRiskPerTrade: " + (string)MaxRiskPerTrade +"%");

   string text ="Lot size for "+ (string)MaxRiskPerTrade +"% = " + DoubleToString(LotSize,2) + " lot (" + (string)NormalizeDouble(StopAmount, 2) + " " + AccountCurr + ")";
   string name = "Lot";
   string name2 = "risk";
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
//ObjectSetText(name,text, 36, "Corbel Bold", YellowGreen);
   ObjectSetInteger(0,name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name, OBJPROP_XDISTANCE, 550);
   ObjectSetInteger(0,name, OBJPROP_YDISTANCE, 10);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,14);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrYellowGreen);

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void tickDifferenceHandler()
  {
   if(StringFind(Symb, "XAU") != -1 && TickValue == 0.01)
     {
      TickValue = 1.0;
     }
  }
//TODO: Tickvalue is different. The problem might be there
//+------------------------------------------------------------------+
