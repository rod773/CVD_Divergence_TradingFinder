# CVD Divergence TradingFinder — MQL4 / MQL5 Ports

Port of the TradingView indicator **"Cumulative Volume Delta Divergence [TradingFinder] Periodic EMA"** to MetaTrader 4 (MQL4) and MetaTrader 5 (MQL5), plus a ZigZag Fibonacci Golden Zone indicator.

## Files

| File | Description |
|------|-------------|
| `CVD_Divergence_TradingFinder.pine` | Original Pine Script source (TradingView) |
| `CVD_Divergence_TradingFinder.mq4` | MQL4 port — compiled, no errors |
| `CVD_Divergence_TradingFinder.mq5` | MQL5 port — uses `DRAW_COLOR_HISTOGRAM` + `DRAW_ARROW` plots |
| `CVD_Divergence_Oscillator.mq4` | MQL4 oscillator variant (2-plot histogram) |
| `CVD_Divergence_Oscillator.mq5` | MQL5 oscillator variant (2-plot histogram) |
| `ZigZag_Fib_Golden_Zone.mq4` | MQL4 ZigZag with Fibonacci retracements + Golden Zone label |
| `ZigZag_Fib_Golden_Zone.mq5` | MQL5 ZigZag with Fibonacci retracements + Golden Zone label |
| `default.tpl` | Chart template — place in your template folder to load a preconfigured chart layout |

## Chart Template

`default.tpl` provides a preconfigured chart layout (timeframe, indicators, settings). Copy it to:

- **MT4**: `%AppData%\MetaQuotes\Terminal\<instance>\Profiles\Templates\`
- **MT5**: `%AppData%\MetaQuotes\Terminal\<instance>\Profiles\Templates\`
- **Manual install**: from MetaTrader, drag the `.tpl` file into the chart window

Apply via: right‑click chart → Template → Load Template → `default.tpl`

## CVD Divergence Indicator Features

- **CVD Calculation** — Cumulative Volume Delta from tick volume
- **Cumulative Modes** — Periodic (sum over N bars) or EMA-smoothed
- **Fractal Swing Detection** — Finds pivot highs/lows using fractal periods
- **Divergence Detection** — Bearish (price higher, CVD lower) and Bullish (price lower, CVD higher)
- **Visual Elements** (both on chart and indicator panel):
  - Divergence trend lines (red/green)
  - `+RD` / `-RD` labels
  - BUY / SELL arrow signals (233/234 wingdings)
  - BUY / SELL text labels
- **No Flickering** — Object creation only on new bar or first run

## ZigZag Fibonacci Golden Zone Features

- **Williams Fractal ZigZag** — Swing high/low detection
- **Fibonacci Retracement Levels** — 50%, 61.8%, 78.6% horizontal lines
- **Golden Zone Label** — Text label at the 23.6% level
- **Pullback Signals** — Buy/Sell text signals at 23.6–38.2% and 61.8–78.6% zones
- **Configurable** — ZigZag length, colors, prices, signals toggle

## Key MQL4/5 Porting Decisions

- `EMA` renamed to `EMATrend` to avoid built-in conflict
- `MODE_EMA` renamed to `CVD_EMA` (MQL5 defines `MODE_EMA` in `ENUM_MA_TYPE`)
- `Digits` → `_Digits` (MQL5 built-in collision)
- Enum defined before `input` directives
- `DRAW_COLOR_HISTOGRAM` for CVD bars (green/red)
- `DRAW_ARROW` extra plots for panel arrows (MQL5)
- `ChartWindowFind()` for subwindow object placement
- `OBJ_TREND`, `OBJ_ARROW`, `OBJ_TEXT` chart objects for divergence lines and signals
- All object creation guarded by `newBar` check to prevent flickering

## Compilation

- **MQL4**: compiles with 0 errors, 0 warnings (MetaEditor for MT4)
- **MQL5**: requires MetaTrader 5 MetaEditor

## License

Mozilla Public License 2.0 (as per original Pine Script).
