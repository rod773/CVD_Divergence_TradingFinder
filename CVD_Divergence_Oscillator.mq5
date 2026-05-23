//+------------------------------------------------------------------+
//|                              CVD_Divergence_Oscillator.mq5 |
//|              Cumulative Volume Delta Divergence Oscillator |
//|                Converted from TradingView "CVD Divergence [TradingFinder]" |
//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

input int      FractalPeriod    = 2;     // Divergence Fractal Periods
input int      CVDPeriod        = 21;    // CVD Period
input bool     UseEMA           = false; // Use EMA (false = Periodic/Sum)
input bool     ShowLabels       = true;  // Show Divergence Labels
input int      EMAPeriod        = 50;    // Trend EMA Period

double         HistBuffer[];
double         HistColorBuffer[];
double         EMABuffer[];

string   gPrefix;
double   gValTop, gValBtm;
double   gValTopHist, gValBtmHist;
int      gTopBar, gBtmBar;
int      gPrevTopBar, gPrevBtmBar;
double   gPrevTopHist, gPrevBtmHist;
double   gPrevTopPrice, gPrevBtmPrice;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, HistBuffer,      INDICATOR_DATA);
   SetIndexBuffer(1, HistColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, EMABuffer,       INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrMediumSeaGreen);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrIndianRed);

   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, clrDarkGray);

   gPrefix = "CVD_" + IntegerToString(ChartID()) + "_";
   gValTop = EMPTY_VALUE; gValBtm = EMPTY_VALUE;
   gValTopHist = EMPTY_VALUE; gValBtmHist = EMPTY_VALUE;
   gTopBar = -1; gBtmBar = -1;
   gPrevTopBar = -1; gPrevBtmBar = -1;
   gPrevTopHist = EMPTY_VALUE; gPrevBtmHist = EMPTY_VALUE;
   gPrevTopPrice = EMPTY_VALUE; gPrevBtmPrice = EMPTY_VALUE;

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
   if(rates_total < CVDPeriod + FractalPeriod + 5) return 0;

   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
      double range = high[i] - low[i];
      double buying, selling;
      if(range > 0)
      {
         buying  = (double)volume[i] * ((close[i] - low[i]) / range);
         selling = (double)volume[i] * ((high[i] - close[i]) / range);
      }
      else
      {
         buying  = (double)volume[i] * 0.5;
         selling = (double)volume[i] * 0.5;
      }
      double delta = buying - selling;

      if(!UseEMA)
      {
         double sum = 0;
         int count = 0;
         for(int k = 0; k < CVDPeriod && i - k >= 0; k++)
         {
            double r = high[i-k] - low[i-k];
            double b, s;
            if(r > 0)
            {
               b = (double)volume[i-k] * ((close[i-k] - low[i-k]) / r);
               s = (double)volume[i-k] * ((high[i-k] - close[i-k]) / r);
            }
            else { b = (double)volume[i-k]*0.5; s = (double)volume[i-k]*0.5; }
            sum += (b - s);
            count++;
         }
         HistBuffer[i] = count > 0 ? sum : 0;
      }
      else
      {
         if(i == 0)
            HistBuffer[i] = delta;
         else
            HistBuffer[i] = (delta * 2.0 / (CVDPeriod + 1)) + (HistBuffer[i-1] * (1.0 - 2.0 / (CVDPeriod + 1)));
      }

      HistColorBuffer[i] = (HistBuffer[i] >= 0) ? 0 : 1;

      if(i == 0)
         EMABuffer[i] = close[i];
      else
         EMABuffer[i] = (close[i] * 2.0 / (EMAPeriod + 1)) + (EMABuffer[i-1] * (1.0 - 2.0 / (EMAPeriod + 1)));

      if(i >= FractalPeriod && i + FractalPeriod < rates_total)
      {
         int pivotBar = i - FractalPeriod;

         bool isHigh = true;
         for(int k = 1; k <= FractalPeriod; k++)
         {
            if(high[pivotBar] <= high[pivotBar-k] || high[pivotBar] <= high[pivotBar+k])
            { isHigh = false; break; }
         }
         bool isLow = true;
         for(int k = 1; k <= FractalPeriod; k++)
         {
            if(low[pivotBar] >= low[pivotBar-k] || low[pivotBar] >= low[pivotBar+k])
            { isLow = false; break; }
         }

         bool upTrend   = close[i] > EMABuffer[i];
         bool downTrend = close[i] < EMABuffer[i];

         if(isHigh && upTrend)
         {
            gPrevTopBar    = gTopBar;
            gPrevTopPrice  = gValTop;
            gPrevTopHist   = gValTopHist;

            gTopBar    = pivotBar;
            gValTop    = high[pivotBar];
            gValTopHist = HistBuffer[pivotBar];

            if(gPrevTopBar > 0 && gPrevTopHist > 0 && gValTopHist > 0)
            {
               int barDist = gTopBar - gPrevTopBar;
               if(barDist < 30 && gValTop > gPrevTopPrice && gValTopHist < gPrevTopHist)
               {
                  DrawDivLine("bear", gPrevTopBar, gPrevTopPrice, gPrevTopHist,
                              gTopBar, gValTop, gValTopHist, clrTomato);
               }
            }
         }

         if(isLow && downTrend)
         {
            gPrevBtmBar    = gBtmBar;
            gPrevBtmPrice  = gValBtm;
            gPrevBtmHist   = gValBtmHist;

            gBtmBar    = pivotBar;
            gValBtm    = low[pivotBar];
            gValBtmHist = HistBuffer[pivotBar];

            if(gPrevBtmBar > 0 && gPrevBtmHist < 0 && gValBtmHist < 0)
            {
               int barDist = gBtmBar - gPrevBtmBar;
               if(barDist < 30 && gValBtm < gPrevBtmPrice && gValBtmHist > gPrevBtmHist)
               {
                  DrawDivLine("bull", gPrevBtmBar, gPrevBtmPrice, gPrevBtmHist,
                              gBtmBar, gValBtm, gValBtmHist, clrMediumSeaGreen);
               }
            }
         }
      }
   }
   return rates_total;
}

//+------------------------------------------------------------------+
void DrawDivLine(string type, int b1, double p1, double h1,
                 int b2, double p2, double h2, color clr)
{
   string key = type + "_" + IntegerToString(b2);
   ObjectDelete(ChartID(), gPrefix + "h_" + key);
   ObjectDelete(ChartID(), gPrefix + "c_" + key);
   ObjectDelete(ChartID(), gPrefix + "l_" + key);

   ObjectCreate(ChartID(), gPrefix + "h_" + key, OBJ_TREND, 0,
      (datetime)b1, h1, (datetime)b2, h2);
   ObjectSetInteger(ChartID(), gPrefix + "h_" + key, OBJPROP_COLOR, clr);
   ObjectSetInteger(ChartID(), gPrefix + "h_" + key, OBJPROP_WIDTH, 2);
   ObjectSetInteger(ChartID(), gPrefix + "h_" + key, OBJPROP_RAY_RIGHT, false);

   ObjectCreate(ChartID(), gPrefix + "c_" + key, OBJ_TREND, 0,
      (datetime)b1, p1, (datetime)b2, p2);
   ObjectSetInteger(ChartID(), gPrefix + "c_" + key, OBJPROP_COLOR, clr);
   ObjectSetInteger(ChartID(), gPrefix + "c_" + key, OBJPROP_WIDTH, 2);
   ObjectSetInteger(ChartID(), gPrefix + "c_" + key, OBJPROP_RAY_RIGHT, false);

   if(ShowLabels)
   {
      string txt = (type == "bull") ? "+RD" : "-RD";
      ObjectCreate(ChartID(), gPrefix + "l_" + key, OBJ_TEXT, 0, (datetime)b2, h2);
      ObjectSetString(ChartID(), gPrefix + "l_" + key, OBJPROP_TEXT, txt);
      ObjectSetInteger(ChartID(), gPrefix + "l_" + key, OBJPROP_COLOR, clr);
      ObjectSetInteger(ChartID(), gPrefix + "l_" + key, OBJPROP_FONTSIZE, 8);
   }
}
