//+------------------------------------------------------------------+
//|                                             ZigZag_Fib_Golden_Zone.mq5 |
//|                                          Converted from Pine Script |
//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script"
#property link      ""
#property version   "1.00"
#property indicator_plots   0
#property indicator_chart_window

input int      ZigZagLength    = 13;    // Zig Zag Length
input bool     ShowPrices      = true;  // Show Prices
input color    ZZTopColor      = clrWhite; // Zig Zag Top Color
input color    ZZColor         = clrWhite; // Zig Zag Color
input color    ZZBotColor      = clrWhite; // Zig Zag Bottom Color
input bool     ShowBuySell     = false; // Show Buy / Sell Signals

double   gValTop, gValBtm;
double   gValTopDraw, gValBtmDraw;
datetime gLastPlTime, gLastPhTime;
double   gLastPlPrice, gLastPhPrice;
string   gPrefix;

//+------------------------------------------------------------------+
int OnInit()
{
   gValTop = EMPTY_VALUE; gValBtm = EMPTY_VALUE;
   gValTopDraw = EMPTY_VALUE; gValBtmDraw = EMPTY_VALUE;
   gLastPlTime = 0; gLastPhTime = 0;
   gLastPlPrice = 0; gLastPhPrice = 0;
   gPrefix = "ZZFG_" + IntegerToString(ChartID()) + "_";
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = ObjectsTotal(ChartID(), -1, -1) - 1; i >= 0; i--)
   {
      string n = ObjectName(ChartID(), i, -1, -1);
      if(StringFind(n, gPrefix) == 0)
         ObjectDelete(ChartID(), n);
   }
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < ZigZagLength + 5) return 0;

   static int   osArr[];
   static bool  buyArr[], sellArr[];
   ArrayResize(osArr, rates_total);
   ArrayResize(buyArr, rates_total);
   ArrayResize(sellArr, rates_total);

   int start = prev_calculated > 0 ? prev_calculated - 1 : ZigZagLength;
   if(prev_calculated == 0)
      for(int j = 0; j < ZigZagLength; j++) osArr[j] = 0;

   for(int i = start; i < rates_total; i++)
   {
      double upper = high[i];
      double lower = low[i];
      for(int k = 1; k < ZigZagLength; k++)
      {
         if(i - k >= 0)
         {
            if(high[i - k] > upper) upper = high[i - k];
            if(low[i - k]  < lower) lower  = low[i - k];
         }
      }

      int prevOs = (i > 0) ? osArr[i - 1] : 0;
      int curOs = prevOs;
      if(i >= ZigZagLength)
      {
         if(high[i - ZigZagLength] >= upper)
            curOs = 0;
         else if(low[i - ZigZagLength] <= lower)
            curOs = 1;
      }
      osArr[i] = curOs;

      bool pl = (curOs == 1 && prevOs == 0);
      bool ph = (curOs == 0 && prevOs == 1);

      if(pl)
      {
         gValBtm = low[i - ZigZagLength];

         if(gValTop != EMPTY_VALUE && gLastPhTime > 0)
         {
            string ln = gPrefix + "zz_" + IntegerToString(i);
            ObjectDelete(ChartID(), ln);
            ObjectCreate(ChartID(), ln, OBJ_TREND, 0,
               gLastPhTime, gLastPhPrice,
               time[i - ZigZagLength], low[i - ZigZagLength]);
            ObjectSetInteger(ChartID(), ln, OBJPROP_COLOR, ZZColor);
            ObjectSetInteger(ChartID(), ln, OBJPROP_WIDTH, 1);
            ObjectSetInteger(ChartID(), ln, OBJPROP_RAY_RIGHT, false);
         }

         gValBtmDraw = gValBtm;
         if(gValTopDraw != EMPTY_VALUE)
         {
            DeleteFibLevels();
            DrawFibLevels(time[i - ZigZagLength], gValTopDraw, gValBtmDraw);
            DrawGoldenZoneLabel(time[i - ZigZagLength], gValTopDraw, gValBtmDraw, false);
         }

         if(ShowPrices)
         {
            string lb = gPrefix + "p_" + IntegerToString(i);
            ObjectCreate(ChartID(), lb, OBJ_TEXT, 0,
               time[i - ZigZagLength], low[i - ZigZagLength]);
            ObjectSetString(ChartID(), lb, OBJPROP_TEXT,
               DoubleToString(low[i - ZigZagLength], (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
            ObjectSetInteger(ChartID(), lb, OBJPROP_COLOR, ZZBotColor);
            ObjectSetInteger(ChartID(), lb, OBJPROP_FONTSIZE, 8);
         }

         gLastPlTime = time[i - ZigZagLength];
         gLastPlPrice = low[i - ZigZagLength];
      }

      if(ph)
      {
         gValTop = high[i - ZigZagLength];

         if(gValBtm != EMPTY_VALUE && gLastPlTime > 0)
         {
            string ln = gPrefix + "zz_" + IntegerToString(i);
            ObjectDelete(ChartID(), ln);
            ObjectCreate(ChartID(), ln, OBJ_TREND, 0,
               gLastPlTime, gLastPlPrice,
               time[i - ZigZagLength], high[i - ZigZagLength]);
            ObjectSetInteger(ChartID(), ln, OBJPROP_COLOR, ZZColor);
            ObjectSetInteger(ChartID(), ln, OBJPROP_WIDTH, 1);
            ObjectSetInteger(ChartID(), ln, OBJPROP_RAY_RIGHT, false);
         }

         gValTopDraw = gValTop;
         if(gValBtmDraw != EMPTY_VALUE)
         {
            DeleteFibLevels();
            DrawFibLevels(time[i - ZigZagLength], gValTopDraw, gValBtmDraw);
            DrawGoldenZoneLabel(time[i - ZigZagLength], gValTopDraw, gValBtmDraw, true);
         }

         if(ShowPrices)
         {
            string lb = gPrefix + "p_" + IntegerToString(i);
            ObjectCreate(ChartID(), lb, OBJ_TEXT, 0,
               time[i - ZigZagLength], high[i - ZigZagLength]);
            ObjectSetString(ChartID(), lb, OBJPROP_TEXT,
               DoubleToString(high[i - ZigZagLength], (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
            ObjectSetInteger(ChartID(), lb, OBJPROP_COLOR, ZZTopColor);
            ObjectSetInteger(ChartID(), lb, OBJPROP_FONTSIZE, 8);
         }

         gLastPhTime = time[i - ZigZagLength];
         gLastPhPrice = high[i - ZigZagLength];
      }

      // --- signals ---
      buyArr[i] = false;
      sellArr[i] = false;

      if(gValTopDraw != EMPTY_VALUE && gValBtmDraw != EMPTY_VALUE && i >= 2)
      {
         double rng = gValTopDraw - gValBtmDraw;
         double f236 = gValBtmDraw + rng * 0.236;
         double f382 = gValBtmDraw + rng * 0.382;
         double f618 = gValBtmDraw + rng * 0.618;
         double f786 = gValBtmDraw + rng * 0.786;

         if(close[i-1] < f786 && close[i-1] > f618 &&
            curOs == 0 && close[i-1] < open[i-1] && close[i] < open[i])
         {
            if((i-1 < 0 || !sellArr[i-1]) && (i-2 < 0 || !sellArr[i-2]))
            {
               sellArr[i] = true;
               if(ShowBuySell)
               {
                  double atr = CalcATR(high, low, close, 14, i);
                  string lb = gPrefix + "sell_" + IntegerToString(i);
                  ObjectCreate(ChartID(), lb, OBJ_TEXT, 0,
                     time[i], high[i] + atr);
                  ObjectSetString(ChartID(), lb, OBJPROP_TEXT, "Sell Pullback");
                  ObjectSetInteger(ChartID(), lb, OBJPROP_COLOR, clrOrangeRed);
                  ObjectSetInteger(ChartID(), lb, OBJPROP_FONTSIZE, 8);
               }
            }
         }

         if(close[i-1] > f236 && close[i-1] < f382 &&
            curOs == 1 && close[i-1] > open[i-1] && close[i] > open[i])
         {
            if((i-1 < 0 || !buyArr[i-1]) && (i-2 < 0 || !buyArr[i-2]))
            {
               buyArr[i] = true;
               if(ShowBuySell)
               {
                  double atr = CalcATR(high, low, close, 14, i);
                  string lb = gPrefix + "buy_" + IntegerToString(i);
                  ObjectCreate(ChartID(), lb, OBJ_TEXT, 0,
                     time[i], low[i] - atr);
                  ObjectSetString(ChartID(), lb, OBJPROP_TEXT, "Buy Pullback");
                  ObjectSetInteger(ChartID(), lb, OBJPROP_COLOR, clrLimeGreen);
                  ObjectSetInteger(ChartID(), lb, OBJPROP_FONTSIZE, 8);
               }
            }
         }
      }
   }
   return rates_total;
}

//+------------------------------------------------------------------+
double CalcATR(const double &high[], const double &low[], const double &close[],
               int period, int index)
{
   if(index < period) return 0;
   double sum = 0;
   for(int j = 0; j < period; j++)
   {
      int idx = index - j;
      double tr = high[idx] - low[idx];
      if(idx > 0)
      {
         double tr1 = fabs(high[idx] - close[idx-1]);
         double tr2 = fabs(low[idx] - close[idx-1]);
         if(tr1 > tr) tr = tr1;
         if(tr2 > tr) tr = tr2;
      }
      sum += tr;
   }
   return sum / period;
}

//+------------------------------------------------------------------+
void DeleteFibLevels()
{
   ObjectDelete(ChartID(), gPrefix + "fib_500");
   ObjectDelete(ChartID(), gPrefix + "fib_618");
   ObjectDelete(ChartID(), gPrefix + "fib_786");
   ObjectDelete(ChartID(), gPrefix + "golden_zone");
}

//+------------------------------------------------------------------+
void DrawFibLevels(datetime t, double top, double bottom)
{
   double r = top - bottom;
   double f500 = (top + bottom) / 2.0;
   double f618 = bottom + r * 0.618;
   double f786 = bottom + r * 0.786;

   ObjectCreate(ChartID(), gPrefix + "fib_500", OBJ_HLINE, 0, 0, f500);
   ObjectSetInteger(ChartID(), gPrefix + "fib_500", OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(ChartID(), gPrefix + "fib_500", OBJPROP_WIDTH, 1);
   ObjectSetInteger(ChartID(), gPrefix + "fib_500", OBJPROP_STYLE, STYLE_SOLID);

   ObjectCreate(ChartID(), gPrefix + "fib_618", OBJ_HLINE, 0, 0, f618);
   ObjectSetInteger(ChartID(), gPrefix + "fib_618", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(ChartID(), gPrefix + "fib_618", OBJPROP_WIDTH, 1);
   ObjectSetInteger(ChartID(), gPrefix + "fib_618", OBJPROP_STYLE, STYLE_SOLID);

   ObjectCreate(ChartID(), gPrefix + "fib_786", OBJ_HLINE, 0, 0, f786);
   ObjectSetInteger(ChartID(), gPrefix + "fib_786", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(ChartID(), gPrefix + "fib_786", OBJPROP_WIDTH, 1);
   ObjectSetInteger(ChartID(), gPrefix + "fib_786", OBJPROP_STYLE, STYLE_SOLID);
}

//+------------------------------------------------------------------+
void DrawGoldenZoneLabel(datetime t, double top, double bottom, bool isTopPivot)
{
   if(!ShowPrices) return;

   ObjectDelete(ChartID(), gPrefix + "golden_zone");

   double price;
   if(isTopPivot)
      price = top;
   else
      price = bottom + (top - bottom) * 0.236;

   ObjectCreate(ChartID(), gPrefix + "golden_zone", OBJ_TEXT, 0, t, price);
   ObjectSetString(ChartID(), gPrefix + "golden_zone", OBJPROP_TEXT, "Golden Zone");
   ObjectSetInteger(ChartID(), gPrefix + "golden_zone", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(ChartID(), gPrefix + "golden_zone", OBJPROP_FONTSIZE, 8);
}
