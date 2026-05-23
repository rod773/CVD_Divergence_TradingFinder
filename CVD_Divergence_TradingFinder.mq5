//+------------------------------------------------------------------+
//|                                       CVD_Divergence_TradingFinder.mq5 |
//|                     Cumulative Volume Delta Divergence [TradingFinder] |
//+------------------------------------------------------------------+
#property copyright "TradingFinder"
#property link      "https://www.tradingview.com/script/HvOAnchA/"
#property version   "1.00"
#property description "Cumulative Volume Delta Divergence Detector"
#property description "Generates BUY/SELL signals from CVD divergences"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGreen, clrRed
#property indicator_width1  2
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  3
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  3

enum ENUM_CUM_MODE
{
   PERIODIC, // Periodic
   CVD_EMA   // EMA
};

// --- Inputs ---
input int           InpFractalPeriod = 2;       // Divergence Fractal Periods
input int           InpCVDPeriod     = 21;      // CVD Period
input ENUM_CUM_MODE InpCumMode       = PERIODIC; // Cumulative Mode
input bool          InpShowLabel     = true;    // Show Labels

// --- Indicator buffers ---
double HistBuffer[];
double ColorBuffer[];
double BuyBuffer[];
double SellBuffer[];

// --- Dynamic arrays ---
double delta[];
double Buying[];
double Selling[];
double EMATrend[];

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "CVD Divergence [TF]");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);

   SetIndexBuffer(0, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SellBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrGreen);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrRed);

   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetInteger(2, PLOT_ARROW, 234);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
int GetIndSubwindow()
{
   return(ChartWindowFind(0, "CVD Divergence [TF]"));
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
   if (rates_total < InpCVDPeriod + 10) return(0);

   bool newBar = (prev_calculated != rates_total);

   ArrayResize(delta, rates_total);
   ArrayResize(Buying, rates_total);
   ArrayResize(Selling, rates_total);
   ArrayResize(EMATrend, rates_total);

   int start = prev_calculated > 1 ? prev_calculated - 1 : 0;

   // --- Calculate CVD (every tick) ---
   for (int i = start; i < rates_total; i++)
   {
      double vol = (double)tick_volume[i];
      double range = high[i] - low[i];
      if (range == 0) range = 0.001;

      Buying[i] = vol * ((close[i] - low[i]) / range);
      Selling[i] = vol * ((high[i] - close[i]) / range);
      delta[i] = Buying[i] - Selling[i];

      if (InpCumMode == PERIODIC)
      {
         double sum = 0;
         int from = i - InpCVDPeriod + 1;
         if (from < 0) from = 0;
         for (int j = from; j <= i; j++)
            sum += delta[j];
         HistBuffer[i] = sum;
      }
      else
      {
         if (i == 0)
            HistBuffer[i] = delta[i];
         else
            HistBuffer[i] = (2.0 / (InpCVDPeriod + 1)) * delta[i]
                          + (1.0 - 2.0 / (InpCVDPeriod + 1)) * HistBuffer[i - 1];
      }

      ColorBuffer[i] = (HistBuffer[i] >= 0) ? 0 : 1;
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
   }

   // --- EMA for trend (period 50) ---
   for (int i = 0; i < rates_total; i++)
   {
      if (i == 0)
         EMATrend[i] = close[i];
      else
         EMATrend[i] = (2.0 / 51.0) * close[i] + (49.0 / 51.0) * EMATrend[i - 1];
   }

   // --- Divergence & objects: only on first run or new bar ---
   if (prev_calculated == 0 || newBar)
   {
      ObjectsDeleteAll(0, "CVD_");

      int highCount = 0;
      int highBars[];
      double highPrices[];
      double highCVDs[];
      ArrayResize(highBars, rates_total);
      ArrayResize(highPrices, rates_total);
      ArrayResize(highCVDs, rates_total);

      int lowCount = 0;
      int lowBars[];
      double lowPrices[];
      double lowCVDs[];
      ArrayResize(lowBars, rates_total);
      ArrayResize(lowPrices, rates_total);
      ArrayResize(lowCVDs, rates_total);

      for (int i = InpFractalPeriod; i < rates_total - InpFractalPeriod; i++)
      {
         bool isUp = true;
         for (int j = 1; j <= InpFractalPeriod; j++)
            if (high[i] <= high[i - j] || high[i] <= high[i + j]) { isUp = false; break; }

         if (isUp && close[i] > EMATrend[i])
         {
            highBars[highCount] = i;
            highPrices[highCount] = high[i];
            highCVDs[highCount] = HistBuffer[i];
            highCount++;
         }

         bool isDown = true;
         for (int j = 1; j <= InpFractalPeriod; j++)
            if (low[i] >= low[i - j] || low[i] >= low[i + j]) { isDown = false; break; }

         if (isDown && close[i] < EMATrend[i])
         {
            lowBars[lowCount] = i;
            lowPrices[lowCount] = low[i];
            lowCVDs[lowCount] = HistBuffer[i];
            lowCount++;
         }
      }

      int indWin = GetIndSubwindow();
      if (indWin < 0) indWin = 0;

      for (int h = 1; h < highCount; h++)
      {
         int prevB = highBars[h];
         int lastB = highBars[h - 1];
         double prevP = highPrices[h];
         double lastP = highPrices[h - 1];
         double prevC = highCVDs[h];
         double lastC = highCVDs[h - 1];

         if (lastC > 0 && prevC > 0 &&
             (lastB - prevB) < 30 &&
             lastP > prevP && lastC < prevC)
         {
            ObjectCreate(0, "CVD_Bear_Div_" + IntegerToString(lastB), OBJ_TREND, 0, time[prevB], high[prevB], time[lastB], high[lastB]);
            ObjectSetInteger(0, "CVD_Bear_Div_" + IntegerToString(lastB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_Bear_Div_" + IntegerToString(lastB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bear_Div_" + IntegerToString(lastB), OBJPROP_RAY_RIGHT, false);

            ObjectCreate(0, "CVD_Bear_Div_Panel_" + IntegerToString(lastB), OBJ_TREND, indWin, time[prevB], prevC, time[lastB], lastC);
            ObjectSetInteger(0, "CVD_Bear_Div_Panel_" + IntegerToString(lastB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_Bear_Div_Panel_" + IntegerToString(lastB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bear_Div_Panel_" + IntegerToString(lastB), OBJPROP_RAY_RIGHT, false);

            SellBuffer[lastB] = lastC;

            ObjectCreate(0, "CVD_Sell_Arrow_" + IntegerToString(lastB), OBJ_ARROW, 0, time[lastB], high[lastB]);
            ObjectSetInteger(0, "CVD_Sell_Arrow_" + IntegerToString(lastB), OBJPROP_ARROWCODE, 234);
            ObjectSetInteger(0, "CVD_Sell_Arrow_" + IntegerToString(lastB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_Sell_Arrow_" + IntegerToString(lastB), OBJPROP_WIDTH, 3);

            ObjectCreate(0, "CVD_Sell_Lbl_" + IntegerToString(lastB), OBJ_TEXT, 0, time[lastB], high[lastB]);
            ObjectSetString(0, "CVD_Sell_Lbl_" + IntegerToString(lastB), OBJPROP_TEXT, "SELL");
            ObjectSetInteger(0, "CVD_Sell_Lbl_" + IntegerToString(lastB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_Sell_Lbl_" + IntegerToString(lastB), OBJPROP_FONTSIZE, 10);

            if (InpShowLabel)
            {
               ObjectCreate(0, "CVD_Bear_Lbl_" + IntegerToString(lastB), OBJ_TEXT, 0, time[lastB], high[lastB]);
               ObjectSetString(0, "CVD_Bear_Lbl_" + IntegerToString(lastB), OBJPROP_TEXT, "-RD");
               ObjectSetInteger(0, "CVD_Bear_Lbl_" + IntegerToString(lastB), OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, "CVD_Bear_Lbl_" + IntegerToString(lastB), OBJPROP_FONTSIZE, 8);

               ObjectCreate(0, "CVD_Bear_Lbl_Panel_" + IntegerToString(lastB), OBJ_TEXT, indWin, time[lastB], lastC);
               ObjectSetString(0, "CVD_Bear_Lbl_Panel_" + IntegerToString(lastB), OBJPROP_TEXT, "-RD");
               ObjectSetInteger(0, "CVD_Bear_Lbl_Panel_" + IntegerToString(lastB), OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, "CVD_Bear_Lbl_Panel_" + IntegerToString(lastB), OBJPROP_FONTSIZE, 8);
            }
         }
      }

      for (int l = 1; l < lowCount; l++)
      {
         int prevB = lowBars[l];
         int lastB = lowBars[l - 1];
         double prevP = lowPrices[l];
         double lastP = lowPrices[l - 1];
         double prevC = lowCVDs[l];
         double lastC = lowCVDs[l - 1];

         if (lastC < 0 && prevC < 0 &&
             (lastB - prevB) < 30 &&
             lastP < prevP && lastC > prevC)
         {
            ObjectCreate(0, "CVD_Bull_Div_" + IntegerToString(lastB), OBJ_TREND, 0, time[prevB], low[prevB], time[lastB], low[lastB]);
            ObjectSetInteger(0, "CVD_Bull_Div_" + IntegerToString(lastB), OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "CVD_Bull_Div_" + IntegerToString(lastB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bull_Div_" + IntegerToString(lastB), OBJPROP_RAY_RIGHT, false);

            ObjectCreate(0, "CVD_Bull_Div_Panel_" + IntegerToString(lastB), OBJ_TREND, indWin, time[prevB], prevC, time[lastB], lastC);
            ObjectSetInteger(0, "CVD_Bull_Div_Panel_" + IntegerToString(lastB), OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "CVD_Bull_Div_Panel_" + IntegerToString(lastB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bull_Div_Panel_" + IntegerToString(lastB), OBJPROP_RAY_RIGHT, false);

            BuyBuffer[lastB] = lastC;

            ObjectCreate(0, "CVD_Buy_Arrow_" + IntegerToString(lastB), OBJ_ARROW, 0, time[lastB], low[lastB]);
            ObjectSetInteger(0, "CVD_Buy_Arrow_" + IntegerToString(lastB), OBJPROP_ARROWCODE, 233);
            ObjectSetInteger(0, "CVD_Buy_Arrow_" + IntegerToString(lastB), OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, "CVD_Buy_Arrow_" + IntegerToString(lastB), OBJPROP_WIDTH, 3);

            ObjectCreate(0, "CVD_Buy_Lbl_" + IntegerToString(lastB), OBJ_TEXT, 0, time[lastB], low[lastB]);
            ObjectSetString(0, "CVD_Buy_Lbl_" + IntegerToString(lastB), OBJPROP_TEXT, "BUY");
            ObjectSetInteger(0, "CVD_Buy_Lbl_" + IntegerToString(lastB), OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, "CVD_Buy_Lbl_" + IntegerToString(lastB), OBJPROP_FONTSIZE, 10);

            if (InpShowLabel)
            {
               ObjectCreate(0, "CVD_Bull_Lbl_" + IntegerToString(lastB), OBJ_TEXT, 0, time[lastB], low[lastB]);
               ObjectSetString(0, "CVD_Bull_Lbl_" + IntegerToString(lastB), OBJPROP_TEXT, "+RD");
               ObjectSetInteger(0, "CVD_Bull_Lbl_" + IntegerToString(lastB), OBJPROP_COLOR, clrGreen);
               ObjectSetInteger(0, "CVD_Bull_Lbl_" + IntegerToString(lastB), OBJPROP_FONTSIZE, 8);

               ObjectCreate(0, "CVD_Bull_Lbl_Panel_" + IntegerToString(lastB), OBJ_TEXT, indWin, time[lastB], lastC);
               ObjectSetString(0, "CVD_Bull_Lbl_Panel_" + IntegerToString(lastB), OBJPROP_TEXT, "+RD");
               ObjectSetInteger(0, "CVD_Bull_Lbl_Panel_" + IntegerToString(lastB), OBJPROP_COLOR, clrGreen);
               ObjectSetInteger(0, "CVD_Bull_Lbl_Panel_" + IntegerToString(lastB), OBJPROP_FONTSIZE, 8);
            }
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
