//+------------------------------------------------------------------+
//|                                           VisualRiskCalc.mq5     |
//|                                      Copyright 2026, Arnaud.     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Automated Solution"
#property version   "2.04"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input double DefRiskPercent = 1.0; // Default Risk %
input double DefRewardRatio = 2.0; // Default Risk:Reward (1:X)
input int    PanelYOffset   = 60;  // Distance from top
input color  ThemeColor     = clrMidnightBlue; // Panel Background

//--- Global Variables
CTrade trade;
string PREFIX = "VRC_";
bool   LinesActive = false; 
bool   MouseIsDown = false;

// Object Names
string ObjPanel     = PREFIX + "Panel";
string ObjEditRisk  = PREFIX + "EditRisk";
string ObjEditRR    = PREFIX + "EditRR";
string ObjEditSL    = PREFIX + "EditSL";
string ObjBtnTrade  = PREFIX + "BtnTrade";
string ObjBtnReset  = PREFIX + "BtnReset";
string ObjLineSL    = PREFIX + "LineSL";
string ObjLineTP    = PREFIX + "LineTP";

// separate labels for multiline support
string ObjLblRiskVal = PREFIX + "InfoRisk";
string ObjLblLotsVal = PREFIX + "InfoLots";
string ObjLblPipsVal = PREFIX + "InfoPips";
string ObjLblRRVal   = PREFIX + "InfoRR";

// State
double calculatedLots = 0;
ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   CreateGUI();
   
   // Create the passive SL line immediately
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   CreateHLine(ObjLineSL, clrRed, bid, STYLE_DOT);
   
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); 
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PREFIX);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(MouseIsDown) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(!LinesActive)
   {
      if(ObjectFind(0, ObjLineSL) >= 0)
      {
         ObjectSetDouble(0, ObjLineSL, OBJPROP_PRICE, bid);
      }
      else
      {
         CreateHLine(ObjLineSL, clrRed, bid, STYLE_DOT);
      }
   }
   else
   {
      RecalculateLogic();
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // --- MOUSE MOVE ---
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      MouseIsDown = (sparam == "1");

      if(ObjectFind(0, ObjLineSL) >= 0)
      {
         double slPrice = ObjectGetDouble(0, ObjLineSL, OBJPROP_PRICE);
         double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double point   = _Point;

         // Check drag distance to activate
         if(!LinesActive && MathAbs(slPrice - bid) > 5 * point)
         {
            if(MouseIsDown) ActivateTool();
         }
         
         if(LinesActive) RecalculateLogic();
      }
   }
   
   // --- CLICKS ---
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == ObjBtnReset)
      {
         ResetTool();
         ObjectSetInteger(0, ObjBtnReset, OBJPROP_STATE, false);
      }
      
      if(sparam == ObjBtnTrade)
      {
         ExecuteTrade();
         ObjectSetInteger(0, ObjBtnTrade, OBJPROP_STATE, false);
      }
   }
   
   // --- EDITS ---
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == ObjEditRisk || sparam == ObjEditRR || sparam == ObjEditSL)
      {
         // 1. Get raw text and replace commas with dots
         string rawTxt = ObjectGetString(0, sparam, OBJPROP_TEXT);
         StringReplace(rawTxt, ",", ".");
         double val = StringToDouble(rawTxt);
         
         // 2. Validate and apply
         if(sparam == ObjEditRisk)
         {
            if(val <= 0) val = DefRiskPercent; // Fallback if letters or 0
            ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(val, 1));
            RecalculateLogic();
         }
         else if(sparam == ObjEditRR)
         {
            if(val <= 0) val = DefRewardRatio; // Fallback if letters or 0
            ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(val, 1));
            RecalculateLogic();
         }
         else if(sparam == ObjEditSL)
         {
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            if(val > 0)
            {
               ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(val, digits));
               if(!LinesActive) ActivateTool(); 
               if(ObjectFind(0, ObjLineSL) >= 0) ObjectSetDouble(0, ObjLineSL, OBJPROP_PRICE, val);
               RecalculateLogic();
            }
            else
            {
               // Fallback if invalid: Reset text box to the current SL line price
               double sl = ObjectGetDouble(0, ObjLineSL, OBJPROP_PRICE);
               ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(sl, digits));
            }
         }
      }
   }
   
   if(id == CHARTEVENT_OBJECT_DRAG && LinesActive)
   {
      RecalculateLogic();
   }
}

//+------------------------------------------------------------------+
//| Logic: Activate Tool                                             |
//+------------------------------------------------------------------+
void ActivateTool()
{
   LinesActive = true;
   
   ObjectSetInteger(0, ObjLineSL, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, ObjLineSL, OBJPROP_WIDTH, 2);
   
   if(ObjectFind(0, ObjLineTP) < 0)
   {
      double slPrice = ObjectGetDouble(0, ObjLineSL, OBJPROP_PRICE);
      CreateHLine(ObjLineTP, clrDodgerBlue, slPrice); 
   }
   
   // Reset Info Text
   ObjectSetString(0, ObjLblRiskVal, OBJPROP_TEXT, "Calculating...");
   ObjectSetString(0, ObjLblLotsVal, OBJPROP_TEXT, "...");
   ObjectSetString(0, ObjLblPipsVal, OBJPROP_TEXT, "...");
   ObjectSetString(0, ObjLblRRVal,   OBJPROP_TEXT, "...");
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Core Logic: Recalculate Everything                               |
//+------------------------------------------------------------------+
void RecalculateLogic()
{
   if(ObjectFind(0, ObjLineSL) < 0) return;

   double slPrice = ObjectGetDouble(0, ObjLineSL, OBJPROP_PRICE);
   
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   ObjectSetString(0, ObjEditSL, OBJPROP_TEXT, DoubleToString(slPrice, digits));
   
   double riskPerc = StringToDouble(ObjectGetString(0, ObjEditRisk, OBJPROP_TEXT));
   double rrRatio  = StringToDouble(ObjectGetString(0, ObjEditRR, OBJPROP_TEXT));
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double entryPrice = 0;
   double tpPrice = 0;
   double distPoints = 0;
   
   if(slPrice < currentBid) 
   {
      orderType = ORDER_TYPE_BUY;
      entryPrice = currentAsk; 
      distPoints = (entryPrice - slPrice);
      tpPrice = entryPrice + (distPoints * rrRatio);
      
      ObjectSetString(0, ObjBtnTrade, OBJPROP_TEXT, "BUY");
      ObjectSetInteger(0, ObjBtnTrade, OBJPROP_BGCOLOR, clrSeaGreen);
   }
   else
   {
      orderType = ORDER_TYPE_SELL;
      entryPrice = currentBid;
      distPoints = (slPrice - entryPrice);
      tpPrice = entryPrice - (distPoints * rrRatio);
      
      ObjectSetString(0, ObjBtnTrade, OBJPROP_TEXT, "SELL");
      ObjectSetInteger(0, ObjBtnTrade, OBJPROP_BGCOLOR, clrFireBrick);
   }
   
   if(ObjectFind(0, ObjLineTP) >= 0)
      ObjectSetDouble(0, ObjLineTP, OBJPROP_PRICE, tpPrice);
   else
      CreateHLine(ObjLineTP, clrDodgerBlue, tpPrice); 
   
   // --- Risk Calculation ---
   double riskMoney = balance * (riskPerc / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(distPoints < tickSize) distPoints = tickSize;
   
   // Calculate risk using proper MT5 Ticks
   double ticksAtRisk = distPoints / tickSize;
   double rawLots = riskMoney / (ticksAtRisk * tickValue);
   
   // Keep Pips calculation for the visual label
   double distInPointsInt = distPoints / _Point; 
   
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   calculatedLots = MathFloor(rawLots / step) * step;
   if(calculatedLots < min) calculatedLots = min;
   if(calculatedLots > max) calculatedLots = max;
   
   // Calculate actual exact loss using ticks
   double actualLoss = calculatedLots * ticksAtRisk * tickValue;
   
   // Update Separate Labels
   string accCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   ObjectSetString(0, ObjLblRiskVal, OBJPROP_TEXT, StringFormat("Loss: %.2f %s", actualLoss, accCurrency));
   ObjectSetString(0, ObjLblLotsVal, OBJPROP_TEXT, StringFormat("Lots: %.2f", calculatedLots));
   ObjectSetString(0, ObjLblPipsVal, OBJPROP_TEXT, StringFormat("Pips: %.1f", distInPointsInt/10.0));
   ObjectSetString(0, ObjLblRRVal,   OBJPROP_TEXT, StringFormat("R:R:  1:%.1f", rrRatio));

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Logic: Reset Tool                                                |
//+------------------------------------------------------------------+
void ResetTool()
{
   LinesActive = false;
   ObjectDelete(0, ObjLineTP);
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(ObjectFind(0, ObjLineSL) < 0) CreateHLine(ObjLineSL, clrRed, bid, STYLE_DOT);
   else {
      ObjectSetDouble(0, ObjLineSL, OBJPROP_PRICE, bid);
      ObjectSetInteger(0, ObjLineSL, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, ObjLineSL, OBJPROP_WIDTH, 1);
   }

   ObjectSetString(0, ObjLblRiskVal, OBJPROP_TEXT, "Drag Red Line");
   ObjectSetString(0, ObjLblLotsVal, OBJPROP_TEXT, "To Start");
   ObjectSetString(0, ObjLblPipsVal, OBJPROP_TEXT, " ");
   ObjectSetString(0, ObjLblRRVal,   OBJPROP_TEXT, " ");
   ObjectSetString(0, ObjEditSL, OBJPROP_TEXT, "0.00000");

   ObjectSetString(0, ObjBtnTrade, OBJPROP_TEXT, "WAITING");
   ObjectSetInteger(0, ObjBtnTrade, OBJPROP_BGCOLOR, clrGray);
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Logic: Execute Trade                                             |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   if(!LinesActive) { Alert("Please drag the line first."); return; }
   if(calculatedLots <= 0) { Alert("Invalid Lot Size"); return; }
   
   double sl = ObjectGetDouble(0, ObjLineSL, OBJPROP_PRICE);
   double tp = ObjectGetDouble(0, ObjLineTP, OBJPROP_PRICE);
   
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   bool res = false;
   if(orderType == ORDER_TYPE_BUY)
      res = trade.Buy(calculatedLots, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, "VRC Algo");
   else
      res = trade.Sell(calculatedLots, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, "VRC Algo");
      
   if(res)
   {
      ResetTool();
      Alert("Trade Executed Successfully");
   }
   else
   {
      Alert("Trade Failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| GUI Functions                                                    |
//+------------------------------------------------------------------+
void CreateGUI()
{
   int x = 30;
   int y = PanelYOffset;
   int w = 300;
   int h = 420;
   
   // Main Panel
   ObjectCreate(0, ObjPanel, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjPanel, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, ObjPanel, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, ObjPanel, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, ObjPanel, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, ObjPanel, OBJPROP_BGCOLOR, ThemeColor);
   ObjectSetInteger(0, ObjPanel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, ObjPanel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, ObjPanel, OBJPROP_COLOR, ThemeColor); 
   ObjectSetInteger(0, ObjPanel, OBJPROP_BACK, false);

   // Header
   CreateLabel(PREFIX+"Title", x+15, y+10, "RISK CALCULATOR", 10, clrWhite, true);
   
   // Inputs
   int rowY = y + 60;
   CreateLabel(PREFIX+"LblRisk", x+15, rowY, "Risk %:", 9, clrLightGray);
   CreateEdit(ObjEditRisk, x+135, rowY, 100, DoubleToString(DefRiskPercent, 1));
   
   rowY += 40;
   CreateLabel(PREFIX+"LblRR", x+15, rowY, "Reward:", 9, clrLightGray);
   CreateEdit(ObjEditRR, x+135, rowY, 100, DoubleToString(DefRewardRatio, 1));
   
   rowY += 40;
   CreateLabel(PREFIX+"LblSL", x+15, rowY, "Stop Loss:", 9, clrLightGray);
   CreateEdit(ObjEditSL, x+135, rowY, 100, "0.00000");
   
   // Info Display - Stacked Labels
   rowY += 50;
   CreateLabel(ObjLblRiskVal, x+15, rowY, "Drag Red Line", 9, clrYellow);
   ObjectSetString(0, ObjLblRiskVal, OBJPROP_FONT, "Consolas");
   
   rowY += 30;
   CreateLabel(ObjLblLotsVal, x+15, rowY, "To Start", 9, clrYellow);
   ObjectSetString(0, ObjLblLotsVal, OBJPROP_FONT, "Consolas");

   rowY += 30;
   CreateLabel(ObjLblPipsVal, x+15, rowY, " ", 9, clrYellow);
   ObjectSetString(0, ObjLblPipsVal, OBJPROP_FONT, "Consolas");

   rowY += 30;
   CreateLabel(ObjLblRRVal,   x+15, rowY, " ", 9, clrYellow);
   ObjectSetString(0, ObjLblRRVal,   OBJPROP_FONT, "Consolas");
   
   // Action Buttons
   int btnY = y + h - 85;
   CreateButton(ObjBtnReset, x+10, btnY, w-20, 25, "Reset / Clear", clrDimGray);
   
   btnY += 35;
   CreateButton(ObjBtnTrade, x+10, btnY, w-20, 35, "WAITING", clrGray);
   
   ChartRedraw(0);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bg)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Calibri");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
}

void CreateEdit(string name, int x, int y, int w, string text)
{
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y-2);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 24);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Calibri");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhiteSmoke);
}

void CreateLabel(string name, int x, int y, string text, int size, color c, bool bold=false)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Calibri");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   if(bold) ObjectSetString(0, name, OBJPROP_FONT, "Calibri Bold");
}

void CreateHLine(string name, color c, double price, ENUM_LINE_STYLE style=STYLE_SOLID)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, true); 
}
//+------------------------------------------------------------------+