//+------------------------------------------------------------------+
//|                              CVD_Divergence_Oscillator.mq4 |
//|              Cumulative Volume Delta Divergence Oscillator |
//|                Converted from TradingView "CVD Divergence [TradingFinder]" |
//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLimeGreen, clrRed
#property indicator_width1  2
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_width2  1

// --- Inputs ---
input int      FractalPeriod    = 2;     // Divergence Fractal Periods
input int      CVDPeriod        = 21;    // CVD Period
input ENUM_MA_METHOD CumMode    = MODE_SMA; // Cumulative Mode (SMA=Periodic, EMA)
input bool     UltraData        = false; // Use Ultra Data (multi-broker volume)
input bool     ShowLabels       = true;  // Show Divergence Labels
input int      EMAPeriod        = 50;    // Trend EMA Period
input color    BullColor        = clrLimeGreen; // Bullish CVD Color
input color    BearColor        = clrRed;        // Bearish CVD Color
input color    BullDivColor     = clrLimeGreen;  // Bullish Divergence Line
input color    BearDivColor     = clrRed;        // Bearish Divergence Line
input color    TextColor        = clrWhite;      // Label Text Color

// --- Buffers ---
double HistBuffer[];
double HistColorBuffer[];
double EMABuffer[];
double DummyBuffer[];

// --- Globals ---
string   gPrefix;
double   gValTop, gValBtm;
double   gValTopHist, gValBtmHist;
int      gTopBar, gBtmBar;
int      gPrevTopBar, gPrevBtmBar;
double   gPrevTopHist, gPrevBtmHist;
double   gPrevTopPrice, gPrevBtmPrice;
bool     gBearDiv, gBullDiv;
int      gBearCount, gBullCount;

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorBuffers(4);
   SetIndexBuffer(0, HistBuffer,       INDICATOR_DATA);
   SetIndexBuffer(1, HistColorBuffer,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, EMABuffer,        INDICATOR_DATA);
   SetIndexBuffer(3, DummyBuffer,      INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);

   gPrefix = "CVD_" + IntegerToString(ChartID()) + "_";
   gValTop = EMPTY_VALUE; gValBtm = EMPTY_VALUE;
   gValTopHist = EMPTY_VALUE; gValBtmHist = EMPTY_VALUE;
   gTopBar = -1; gBtmBar = -1;
   gPrevTopBar = -1; gPrevBtmBar = -1;
   gPrevTopHist = EMPTY_VALUE; gPrevBtmHist = EMPTY_VALUE;
   gPrevTopPrice = EMPTY_VALUE; gPrevBtmPrice = EMPTY_VALUE;
   gBearDiv = false; gBullDiv = false;
   gBearCount = 0; gBullCount = 0;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = ObjectsTotal(ChartID(), 0, -1) - 1; i >= 0; i--)
   {
      string n = ObjectName(ChartID(), i, 0, -1);
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
   if(rates_total < CVDPeriod + FractalPeriod + 5) return 0;

   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
      // --- CVD Calculation ---
      double range = high[i] - low[i];
      double buying, selling;
      if(range > 0)
      {
         buying  = volume[i] * ((close[i] - low[i]) / range);
         selling = volume[i] * ((high[i] - close[i]) / range);
      }
      else
      {
         buying  = volume[i] * 0.5;
         selling = volume[i] * 0.5;
      }
      double delta = buying - selling;

      // Cumulative mode
      if(CumMode == MODE_SMA)
      {
         double sum = 0;
         int count = 0;
         for(int k = 0; k < CVDPeriod && i - k >= 0; k++)
         {
            double r = high[i-k] - low[i-k];
            double b, s;
            if(r > 0)
            {
               b = volume[i-k] * ((close[i-k] - low[i-k]) / r);
               s = volume[i-k] * ((high[i-k] - close[i-k]) / r);
            }
            else { b = volume[i-k]*0.5; s = volume[i-k]*0.5; }
            sum += (b - s);
            count++;
         }
         HistBuffer[i] = count > 0 ? sum : 0;
      }
      else // EMA
      {
         if(i == 0)
            HistBuffer[i] = delta;
         else
            HistBuffer[i] = (delta * 2.0 / (CVDPeriod + 1)) + (HistBuffer[i-1] * (1.0 - 2.0 / (CVDPeriod + 1)));
      }

      // Histogram color
      HistColorBuffer[i] = (HistBuffer[i] >= 0) ? 0 : 1;

      // --- Trend EMA ---
      if(i == 0)
         EMABuffer[i] = close[i];
      else
         EMABuffer[i] = (close[i] * 2.0 / (EMAPeriod + 1)) + (EMABuffer[i-1] * (1.0 - 2.0 / (EMAPeriod + 1)));

      // --- Fractal Detection ---
      if(i >= FractalPeriod && i + FractalPeriod < rates_total)
      {
         // Pivot High
         bool isHigh = true;
         for(int k = 1; k <= FractalPeriod; k++)
         {
            if(high[i] <= high[i-k] || high[i] <= high[i+k])
            { isHigh = false; break; }
         }
         // Pivot Low
         bool isLow = true;
         for(int k = 1; k <= FractalPeriod; k++)
         {
            if(low[i] >= low[i-k] || low[i] >= low[i+k])
            { isLow = false; break; }
         }

         bool upTrend = close[i] > EMABuffer[i];
         bool downTrend = close[i] < EMABuffer[i];

         // --- Bearish Divergence ---
         if(isHigh && upTrend)
         {
            // Shift positions
            gPrevTopBar = gTopBar;
            gPrevTopPrice = gValTop;
            gPrevTopHist = gValTopHist;

            gTopBar = i;
            gValTop = high[i];
            gValTopHist = HistBuffer[i];

            // Check divergence
            if(gPrevTopBar > 0 && gPrevTopHist > 0 && gValTopHist > 0)
            {
               int barDist = gTopBar - gPrevTopBar;
               if(barDist < 30 && (gTopBar + 30) > i)
               {
                  if(gValTop > gPrevTopPrice && gValTopHist < gPrevTopHist)
                  {
                     gBearDiv = true;
                     gBearCount++;
                     DrawBearDivLine(gPrevTopBar, gPrevTopPrice, gPrevTopHist,
                                     gTopBar, gValTop, gValTopHist);
                  }
               }
            }
         }

         // --- Bullish Divergence ---
         if(isLow && downTrend)
         {
            // Shift positions
            gPrevBtmBar = gBtmBar;
            gPrevBtmPrice = gValBtm;
            gPrevBtmHist = gValBtmHist;

            gBtmBar = i;
            gValBtm = low[i];
            gValBtmHist = HistBuffer[i];

            // Check divergence
            if(gPrevBtmBar > 0 && gPrevBtmHist < 0 && gValBtmHist < 0)
            {
               int barDist = gBtmBar - gPrevBtmBar;
               if(barDist < 30 && (gBtmBar + 30) > i)
               {
                  if(gValBtm < gPrevBtmPrice && gValBtmHist > gPrevBtmHist)
                  {
                     gBullDiv = true;
                     gBullCount++;
                     DrawBullDivLine(gPrevBtmBar, gPrevBtmPrice, gPrevBtmHist,
                                     gBtmBar, gValBtm, gValBtmHist);
                  }
               }
            }
         }
      }
   }

   return rates_total;
}

//+------------------------------------------------------------------+
void DrawBearDivLine(int bar1, double price1, double hist1,
                     int bar2, double price2, double hist2)
{
   // Delete old objects with same key
   string key = "bear_" + IntegerToString(bar2);
   ObjectDelete(ChartID(), gPrefix + "line_hist_" + key);
   ObjectDelete(ChartID(), gPrefix + "line_chart_" + key);
   ObjectDelete(ChartID(), gPrefix + "label_" + key);

   // Divergence line on indicator
   ObjectCreate(ChartID(), gPrefix + "line_hist_" + key, OBJ_TREND, 0,
      (datetime)bar1, hist1, (datetime)bar2, hist2);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_COLOR, BearDivColor);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_WIDTH, 2);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_STYLE, STYLE_SOLID);

   // Divergence line on chart
   ObjectCreate(ChartID(), gPrefix + "line_chart_" + key, OBJ_TREND, 0,
      (datetime)bar1, price1, (datetime)bar2, price2);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_COLOR, BearDivColor);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_WIDTH, 2);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_STYLE, STYLE_SOLID);

   if(ShowLabels)
   {
      ObjectCreate(ChartID(), gPrefix + "label_" + key, OBJ_TEXT, 0,
         (datetime)bar2, hist2);
      ObjectSetString(ChartID(), gPrefix + "label_" + key, OBJPROP_TEXT, "-RD");
      ObjectSetInteger(ChartID(), gPrefix + "label_" + key, OBJPROP_COLOR, BearDivColor);
      ObjectSetInteger(ChartID(), gPrefix + "label_" + key, OBJPROP_FONTSIZE, 8);
   }
}

//+------------------------------------------------------------------+
void DrawBullDivLine(int bar1, double price1, double hist1,
                     int bar2, double price2, double hist2)
{
   string key = "bull_" + IntegerToString(bar2);
   ObjectDelete(ChartID(), gPrefix + "line_hist_" + key);
   ObjectDelete(ChartID(), gPrefix + "line_chart_" + key);
   ObjectDelete(ChartID(), gPrefix + "label_" + key);

   ObjectCreate(ChartID(), gPrefix + "line_hist_" + key, OBJ_TREND, 0,
      (datetime)bar1, hist1, (datetime)bar2, hist2);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_COLOR, BullDivColor);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_WIDTH, 2);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(ChartID(), gPrefix + "line_hist_" + key, OBJPROP_STYLE, STYLE_SOLID);

   ObjectCreate(ChartID(), gPrefix + "line_chart_" + key, OBJ_TREND, 0,
      (datetime)bar1, price1, (datetime)bar2, price2);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_COLOR, BullDivColor);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_WIDTH, 2);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(ChartID(), gPrefix + "line_chart_" + key, OBJPROP_STYLE, STYLE_SOLID);

   if(ShowLabels)
   {
      ObjectCreate(ChartID(), gPrefix + "label_" + key, OBJ_TEXT, 0,
         (datetime)bar2, hist2);
      ObjectSetString(ChartID(), gPrefix + "label_" + key, OBJPROP_TEXT, "+RD");
      ObjectSetInteger(ChartID(), gPrefix + "label_" + key, OBJPROP_COLOR, BullDivColor);
      ObjectSetInteger(ChartID(), gPrefix + "label_" + key, OBJPROP_FONTSIZE, 8);
   }
}
