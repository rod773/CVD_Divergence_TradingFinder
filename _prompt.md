# Development Prompt — CVD Divergence & ZigZag Fib Golden Zone

## Context

These are MQL4/MQL5 ports of TradingView Pine Script indicators. The primary indicator is the CVD Divergence TradingFinder; an oscillator variant and a ZigZag Fibonacci Golden Zone indicator are also included.

## Naming Conventions

- MQL4 files: `*_TradingFinder.mq4`, `*_Oscillator.mq4`
- MQL5 files: `*_TradingFinder.mq5`, `*_Oscillator.mq5`
- Pine Script: `*.pine`
- Avoid built-in identifiers: use `EMATrend` (not `EMA`), `CVD_EMA` (not `MODE_EMA`), `_Digits` (not `Digits`)
- Indicator object prefix: `CVD_` for all chart objects

## File Locations

All files in `D:\Descargas\indicator\`

## Architecture Guidelines

### CVD Divergence (`CVD_Divergence_TradingFinder.*`)

**Buffers (MQL5)**:
- `HistBuffer` — `DRAW_COLOR_HISTOGRAM` data
- `ColorBuffer` — `INDICATOR_COLOR_INDEX` (0=green, 1=red)
- `BuyBuffer` — `DRAW_ARROW` buy signals in panel
- `SellBuffer` — `DRAW_ARROW` sell signals in panel

**Key Logic**:
1. CVD = Buying - Selling (volume-weighted delta per bar)
2. Cumulative mode: Periodic (sum over CVDPeriod) or EMA (alpha = 2/(CVDPeriod+1))
3. Trend EMA: period 50 on close
4. Fractal swing detection: compare high/low within ±FractalPeriod bars
5. Divergence: consecutive swing points with price/CVD mismatch
6. Bearish divergence: higher price + lower CVD → SELL
7. Bullish divergence: lower price + higher CVD → BUY

**Object Drawing** (guarded by `prev_calculated == 0 || newBar`):
- `OBJ_TREND` lines on chart (subwindow 0) and panel (`ChartWindowFind`)
- `OBJ_ARROW` BUY (code 233) / SELL (code 234) on chart
- `OBJ_TEXT` BUY/SELL labels and `+RD`/`-RD` labels on chart + panel

### ZigZag Fibonacci Golden Zone (`ZigZag_Fib_Golden_Zone.*`)

- Object-only indicator: `#property indicator_plots 0`
- Williams fractal ZigZag using lookback period
- `OBJ_HLINE` for Fibonacci levels (50%, 61.8%, 78.6%)
- `OBJ_TEXT` "Golden Zone" label at 23.6% level
- Pullback signals at 23.6-38.2% (buy) and 61.8-78.6% (sell)
- All objects deleted on deinit using `gPrefix` naming convention
- Static arrays for oscillation state (`osArr`, `buyArr`, `sellArr`)

### MQL4 vs MQL5 Differences

| Feature | MQL4 | MQL5 |
|---------|------|------|
| Buffer binding | `SetIndexBuffer(id, arr)` | `SetIndexBuffer(id, arr, flag)` |
| Plot config | `SetIndexStyle`, `SetIndexLabel` | `PlotIndexSetInteger` |
| Arrow codes | `OBJPROP_ARROWCODE` via `ObjectSetInteger` | `PLOT_ARROW` via `PlotIndexSetInteger` |
| Scoping | C-style (function-level) | C++ (block-level) |
| ATR | `iATR(symbol, tf, period, shift)` | Custom `CalcATR()` function |
| Subwindow | Hardcoded `1` | `ChartWindowFind()` |
| Digits | `Digits` | `_Digits` |

## Common Gotchas

- MQL4 does NOT allow redeclaring the same variable name in nested for-loops (C scoping) — use unique names or declare at function top
- Always set `#property indicator_plots` — MQL5 errors with "no indicator plot defined" if missing (use `0` for object-only indicators)
- MQL4 `#property indicator_buffers` must match the index count; MQL5 also needs `#property indicator_plots`
- Avoid flickering: wrap `ObjectCreate` / `ObjectsDeleteAll` inside `if (prev_calculated == 0 || newBar)`

## Verification

- MQL4: compile with MetaEditor — must show 0 errors, 0 warnings
- MQL5: compile with MetaTrader 5 MetaEditor
- Test on a chart: verify divergence lines, BUY/SELL arrows, and panel display without flicker on tick updates
