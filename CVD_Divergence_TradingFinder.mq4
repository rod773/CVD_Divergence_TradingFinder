//+------------------------------------------------------------------+
//|                                       CVD_Divergence_TradingFinder.mq4 |
//|                     Cumulative Volume Delta Divergence [TradingFinder] |
//+------------------------------------------------------------------+
#property copyright "TradingFinder"
#property link      "https://www.tradingview.com/script/HvOAnchA/"
#property version   "1.00"
#property description "Cumulative Volume Delta Divergence Detector"
#property description "Generates BUY/SELL signals from CVD divergences"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrGreen
#property indicator_width1  2

enum ENUM_CUM_MODE
{
   PERIODIC, // Periodic
   CVD_EMA   // EMA
};

input int      FractalPeriod  = 2;
input int      CVDPeriod      = 21;
input ENUM_CUM_MODE CumMode   = PERIODIC;
input bool     ShowLabel      = true;

double HistBuffer[];
double ColorBuffer[];
double BuyBuffer[];
double SellBuffer[];

double delta[];
double Buying[];
double Selling[];
double EMATrend[];

int OnInit()
{
   IndicatorDigits(Digits + 1);
   SetIndexBuffer(0, HistBuffer);
   SetIndexBuffer(1, ColorBuffer);
   SetIndexBuffer(2, BuyBuffer);
   SetIndexBuffer(3, SellBuffer);
   SetIndexStyle(0, DRAW_HISTOGRAM);
   SetIndexLabel(0, "CVD");
   return(INIT_SUCCEEDED);
}

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
   if (rates_total < CVDPeriod + 10) return(0);

   bool newBar = (prev_calculated != rates_total);

   ArrayResize(delta, rates_total);
   ArrayResize(Buying, rates_total);
   ArrayResize(Selling, rates_total);
   ArrayResize(EMATrend, rates_total);

   int start = prev_calculated > 1 ? prev_calculated - 1 : 0;
   int i, j, ii;
   double vol, range, sum;
   bool isUp, isDown;
   int hc = 0, lc = 0;
   int h, pB, lB, hh;
   double pP, lP, pC, lC;

   for (i = start; i < rates_total; i++)
   {
      vol = (double)tick_volume[i];
      range = high[i] - low[i];
      if (range == 0) range = 0.001;

      Buying[i] = vol * ((close[i] - low[i]) / range);
      Selling[i] = vol * ((high[i] - close[i]) / range);
      delta[i] = Buying[i] - Selling[i];

      if (CumMode == PERIODIC)
      {
         sum = 0;
         int from = i - CVDPeriod + 1;
         if (from < 0) from = 0;
         for (j = from; j <= i; j++) sum += delta[j];
         HistBuffer[i] = sum;
      }
      else
      {
         if (i == 0) HistBuffer[i] = delta[i];
         else HistBuffer[i] = (2.0 / (CVDPeriod + 1)) * delta[i] + (1.0 - 2.0 / (CVDPeriod + 1)) * HistBuffer[i - 1];
      }

      ColorBuffer[i] = (HistBuffer[i] >= 0) ? 0 : 1;
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
   }

   for (ii = 0; ii < rates_total; ii++)
   {
      if (ii == 0) EMATrend[ii] = close[ii];
      else EMATrend[ii] = (2.0 / 51.0) * close[ii] + (49.0 / 51.0) * EMATrend[ii - 1];
   }

   if (prev_calculated == 0 || newBar)
   {
      ObjectsDeleteAll(0, "CVD_");

      int hBars[];   double hPrc[];   double hCVD[];
      int lBars[];   double lPrc[];   double lCVD[];
      ArrayResize(hBars, rates_total); ArrayResize(hPrc, rates_total); ArrayResize(hCVD, rates_total);
      ArrayResize(lBars, rates_total); ArrayResize(lPrc, rates_total); ArrayResize(lCVD, rates_total);
      hc = 0; lc = 0;

      for (i = FractalPeriod; i < rates_total - FractalPeriod; i++)
      {
         isUp = true;
         for (j = 1; j <= FractalPeriod; j++)
            if (high[i] <= high[i - j] || high[i] <= high[i + j]) { isUp = false; break; }
         if (isUp && close[i] > EMATrend[i]) { hBars[hc] = i; hPrc[hc] = high[i]; hCVD[hc] = HistBuffer[i]; hc++; }

         isDown = true;
         for (j = 1; j <= FractalPeriod; j++)
            if (low[i] >= low[i - j] || low[i] >= low[i + j]) { isDown = false; break; }
         if (isDown && close[i] < EMATrend[i]) { lBars[lc] = i; lPrc[lc] = low[i]; lCVD[lc] = HistBuffer[i]; lc++; }
      }

      for (h = 1; h < hc; h++)
      {
         pB = hBars[h]; lB = hBars[h - 1];
         pP = hPrc[h]; lP = hPrc[h - 1]; pC = hCVD[h]; lC = hCVD[h - 1];
         if (lC > 0 && pC > 0 && (lB - pB) < 30 && lP > pP && lC < pC)
         {
            ObjectCreate(0, "CVD_Bear_Div_" + IntegerToString(lB), OBJ_TREND, 0, time[pB], high[pB], time[lB], high[lB]);
            ObjectSetInteger(0, "CVD_Bear_Div_" + IntegerToString(lB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_Bear_Div_" + IntegerToString(lB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bear_Div_" + IntegerToString(lB), OBJPROP_RAY_RIGHT, false);

            ObjectCreate(0, "CVD_Bear_Div_Panel_" + IntegerToString(lB), OBJ_TREND, 1, time[pB], pC, time[lB], lC);
            ObjectSetInteger(0, "CVD_Bear_Div_Panel_" + IntegerToString(lB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_Bear_Div_Panel_" + IntegerToString(lB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bear_Div_Panel_" + IntegerToString(lB), OBJPROP_RAY_RIGHT, false);

            SellBuffer[lB] = lC;

            ObjectCreate(0, "CVD_Sell_" + IntegerToString(lB), OBJ_ARROW, 0, time[lB], high[lB]);
            ObjectSetInteger(0, "CVD_Sell_" + IntegerToString(lB), OBJPROP_ARROWCODE, 234);
            ObjectSetInteger(0, "CVD_Sell_" + IntegerToString(lB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_Sell_" + IntegerToString(lB), OBJPROP_WIDTH, 3);

            ObjectCreate(0, "CVD_SL_" + IntegerToString(lB), OBJ_TEXT, 0, time[lB], high[lB]);
            ObjectSetString(0, "CVD_SL_" + IntegerToString(lB), OBJPROP_TEXT, "SELL");
            ObjectSetInteger(0, "CVD_SL_" + IntegerToString(lB), OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "CVD_SL_" + IntegerToString(lB), OBJPROP_FONTSIZE, 10);

            if (ShowLabel)
            {
               ObjectCreate(0, "CVD_BL_" + IntegerToString(lB), OBJ_TEXT, 0, time[lB], high[lB]);
               ObjectSetString(0, "CVD_BL_" + IntegerToString(lB), OBJPROP_TEXT, "-RD");
               ObjectSetInteger(0, "CVD_BL_" + IntegerToString(lB), OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, "CVD_BL_" + IntegerToString(lB), OBJPROP_FONTSIZE, 8);
               ObjectCreate(0, "CVD_BLP_" + IntegerToString(lB), OBJ_TEXT, 1, time[lB], lC);
               ObjectSetString(0, "CVD_BLP_" + IntegerToString(lB), OBJPROP_TEXT, "-RD");
               ObjectSetInteger(0, "CVD_BLP_" + IntegerToString(lB), OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, "CVD_BLP_" + IntegerToString(lB), OBJPROP_FONTSIZE, 8);
            }
         }
      }

      for (hh = 1; hh < lc; hh++)
      {
         pB = lBars[hh]; lB = lBars[hh - 1];
         pP = lPrc[hh]; lP = lPrc[hh - 1]; pC = lCVD[hh]; lC = lCVD[hh - 1];
         if (lC < 0 && pC < 0 && (lB - pB) < 30 && lP < pP && lC > pC)
         {
            ObjectCreate(0, "CVD_Bull_Div_" + IntegerToString(lB), OBJ_TREND, 0, time[pB], low[pB], time[lB], low[lB]);
            ObjectSetInteger(0, "CVD_Bull_Div_" + IntegerToString(lB), OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "CVD_Bull_Div_" + IntegerToString(lB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bull_Div_" + IntegerToString(lB), OBJPROP_RAY_RIGHT, false);

            ObjectCreate(0, "CVD_Bull_Div_Panel_" + IntegerToString(lB), OBJ_TREND, 1, time[pB], pC, time[lB], lC);
            ObjectSetInteger(0, "CVD_Bull_Div_Panel_" + IntegerToString(lB), OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "CVD_Bull_Div_Panel_" + IntegerToString(lB), OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "CVD_Bull_Div_Panel_" + IntegerToString(lB), OBJPROP_RAY_RIGHT, false);

            BuyBuffer[lB] = lC;

            ObjectCreate(0, "CVD_Buy_" + IntegerToString(lB), OBJ_ARROW, 0, time[lB], low[lB]);
            ObjectSetInteger(0, "CVD_Buy_" + IntegerToString(lB), OBJPROP_ARROWCODE, 233);
            ObjectSetInteger(0, "CVD_Buy_" + IntegerToString(lB), OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, "CVD_Buy_" + IntegerToString(lB), OBJPROP_WIDTH, 3);

            ObjectCreate(0, "CVD_BL_" + IntegerToString(lB + 100000), OBJ_TEXT, 0, time[lB], low[lB]);
            ObjectSetString(0, "CVD_BL_" + IntegerToString(lB + 100000), OBJPROP_TEXT, "BUY");
            ObjectSetInteger(0, "CVD_BL_" + IntegerToString(lB + 100000), OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, "CVD_BL_" + IntegerToString(lB + 100000), OBJPROP_FONTSIZE, 10);

            if (ShowLabel)
            {
               ObjectCreate(0, "CVD_BuL_" + IntegerToString(lB), OBJ_TEXT, 0, time[lB], low[lB]);
               ObjectSetString(0, "CVD_BuL_" + IntegerToString(lB), OBJPROP_TEXT, "+RD");
               ObjectSetInteger(0, "CVD_BuL_" + IntegerToString(lB), OBJPROP_COLOR, clrGreen);
               ObjectSetInteger(0, "CVD_BuL_" + IntegerToString(lB), OBJPROP_FONTSIZE, 8);
               ObjectCreate(0, "CVD_BuLP_" + IntegerToString(lB), OBJ_TEXT, 1, time[lB], lC);
               ObjectSetString(0, "CVD_BuLP_" + IntegerToString(lB), OBJPROP_TEXT, "+RD");
               ObjectSetInteger(0, "CVD_BuLP_" + IntegerToString(lB), OBJPROP_COLOR, clrGreen);
               ObjectSetInteger(0, "CVD_BuLP_" + IntegerToString(lB), OBJPROP_FONTSIZE, 8);
            }
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
