# QuickTradePanel Pro v4.0 — MT5 Expert Advisor

A horizontal one-click trading panel for MetaTrader 5. Place trades, size lots by account risk, manage open positions, and assign your own hotkeys to every action.

> **Risk warning:** Trading leveraged products carries a high risk of loss. This tool is provided as-is, with no warranty. Test on a **demo account** before using it live.

---

## Screenshots

<p align="center"><em>Each screenshot sits in its own bordered frame with spacing between them.</em></p>

<br>

<table align="center" width="100%">
  <tr>
    <th align="center">Panel — trade &amp; manage rows</th>
  </tr>
  <tr>
    <td align="center">
      <br>
      <img src="https://github.com/user-attachments/assets/8b861667-79c3-4d05-9aa8-cdd0f994dbd1" alt="QuickTradePanel trade and manage rows" width="95%">
      <br><br>
    </td>
  </tr>
</table>

<br><br>

<table align="center" width="100%">
  <tr>
    <th align="center">Panel — stats row &amp; options</th>
  </tr>
  <tr>
    <td align="center">
      <br>
      <img src="https://github.com/user-attachments/assets/39cef7dc-f1fd-42ed-a56f-f4a9d9395a67" alt="QuickTradePanel stats row and options" width="95%">
      <br><br>
    </td>
  </tr>
</table>

<br><br>

<table align="center" width="100%">
  <tr>
    <th align="center">Panel on a live chart</th>
  </tr>
  <tr>
    <td align="center">
      <br>
      <img src="https://github.com/user-attachments/assets/fe86b29e-1346-4d92-a380-ba3f10264975" alt="QuickTradePanel running on an MT5 chart" width="95%">
      <br><br>
    </td>
  </tr>
</table>

<br>

---

## Features

- **One-click BUY / SELL** with lot, SL and TP fields
- **Risk % lot calculator** — lot is sized from account risk and your SL distance
- **SL pips box** — stop-loss applied to every new trade
- **RR 1:2 mode** — at 1:1 closes 50% and moves SL to break-even; remaining 50% runs to 1:2
- **Multi-TP (MTP)** — T1 partial close + break-even, T2 final target
- **AUTO $SL** — fixed-dollar stop-loss on every trade
- **AUTO B.E** — automatic break-even after X pips in profit
- **Manage buttons** — Close All, Close Profitable, Break-Even, Close 50%
- **Average entry price line** and TP / RR target lines with expected $ on the chart
- **Daily stats** — progress bar to your daily goal, Day / Open / Total P&L, win rate, last 5 results
- **Custom hotkeys** for every action, set inside the panel and saved across restarts

---

## Installation

1. In MT5, open **File → Open Data Folder**.
2. Go to `MQL5 → Experts`.
3. Copy `QuickTradePanel_Pro_v4.mq5` into that folder.
4. Open **MetaEditor** (press `F4` in MT5), open the file, and press **Compile** (`F7`). It should finish with 0 errors.
5. Back in MT5, press **Ctrl+N** to open the Navigator and right-click **Expert Advisors → Refresh**.
6. Make sure **Algo Trading** is turned on (toolbar button is green).
7. Drag **QuickTradePanel_Pro_v4** onto a chart.
8. In the dialog, open the **Common** tab and tick **Allow Algo Trading**, then click **OK**.

The panel appears at the top-left of the chart. It manages positions on the **chart's symbol** only.

> The panel is an Expert Advisor, so it needs Algo Trading enabled even though you click the trades yourself.

---

## Panel Layout

**Row 1 — Trade**

| Control | What it does |
|---|---|
| ● LED | Spread indicator (green / yellow / red vs. `MaxSpreadPoints`) |
| LOT ▼ box ▲ | Fixed lot size (greyed out while RISK % is on) |
| RISK % + box | Toggle risk-based sizing; box is the % per trade; label shows the lot that will be used |
| SL | Stop-loss in pips for every new trade (0 = none) |
| TP / $ (or T1 / T2) | Take-profit in pips / in dollars (T1 and T2 pips in MTP mode) |
| ▲ BUY / ▼ SELL | Open a market order |

**Row 2 — Manage**

| Button | What it does |
|---|---|
| CLOSE ALL | Close every position on this symbol |
| CLOSE + | Close only profitable positions |
| B.E | Move SL to entry on all positions |
| CLOSE 50% | Partial close (percent set by `PartialClosePct`) |
| RR 1:2 | Toggle the 1:1 / 1:2 auto-split |
| MTP | Toggle multi-level take-profit |
| AUTO $SL (+ box) | Toggle fixed-dollar SL; box is the dollar risk |
| AUTO B.E | Toggle automatic break-even |
| AVG LINE | Show the average entry price line |
| ⌨ KEYS | Open / close the hotkey settings |

**Row 3 — Stats:** daily goal bar, Day / Open / Total P&L, win rate and last 5 results.

Hover over any button for a tooltip that includes its assigned hotkey.

---

## How to Use

### Risk % sizing
1. Click **RISK %** so it lights up.
2. Enter the risk percent (e.g. `1`) and your stop distance in the **SL** box (e.g. `20`).
3. The label shows the lot that will be used. Click BUY or SELL.

Risk is calculated from account **balance** by default (switch to equity with the `RiskOnEquity` input). If SL pips is 0, the trade is skipped and a message is printed to the Experts log.

### RR 1:2 mode
1. Put your stop distance in **SL**, or turn on AUTO $SL, or set an SL on the trade manually.
2. Click **RR 1:2**.
3. At 1:1 profit, 50% of the position is closed and the SL moves to break-even. The rest targets 1:2 (set as the broker TP).

RR mode and MTP can't run at the same time. Each trade's original risk distance is remembered, so moving the SL later doesn't change the targets.

### Multi-TP (MTP)
Enter T1 and T2 in pips. At T1 the panel closes `TP1ClosePct`% and moves SL to entry; T2 is the broker take-profit for the rest.

---

## Setting Up Hotkeys

Every action can have its own key. All start **unassigned**.

1. Click **⌨ KEYS** to open the drawer.
2. Click the key box next to an action (it shows "press key…").
3. Press the combination you want — for example `F9`, `Alt+1` or `Ctrl+Shift+B`.
4. Press **Esc** to cancel, **x** to clear one hotkey, or **CLEAR ALL** to reset everything.

Assignable actions: Buy, Sell, Close All, Close Profit, Break-Even, Close 50%, Lot +, Lot −, Risk % Mode, RR 1:2 Mode, Multi-TP, Auto $SL, Auto B.E, Avg Line.

Notes:
- Hotkeys are saved in the terminal's Global Variables and survive restarts.
- If you assign a key already used by another action, it moves to the new one.
- Hotkeys are ignored while you are typing in a panel input box.
- MT5 has built-in shortcuts, so bare keys may clash. Combos with Ctrl / Shift / Alt are safest.

---

## Input Parameters

Set these in the EA's **Inputs** tab when attaching it.

| Input | Default | Meaning |
|---|---|---|
| `DefaultLotSize` | 0.01 | Starting fixed lot |
| `DefaultRiskPct` | 1.0 | Starting Risk % per trade |
| `RiskOnEquity` | false | Base risk on equity instead of balance |
| `PartialClosePct` | 50 | % closed by the CLOSE 50% button |
| `TP1ClosePct` | 50 | % closed at T1 in MTP mode |
| `MaxSpreadPoints` | 80 | Spread above this turns the LED red |
| `AutoBETriggerPips` | 15 | Profit (pips) that triggers Auto B.E |
| `AutoBEBufferPips` | 4 | SL offset beyond entry for Auto B.E |
| `AutoSLDollar` | 5.0 | Starting dollar risk for AUTO $SL |
| `DailyPnLTarget` | 50 | Daily goal for the progress bar (0 = hide) |
| `MagicNumber` | 0 | 0 = manage all trades on the symbol; otherwise only that magic |
| `ScanShootingStars` | true | Mark shooting-star candles on M1 / M3 / M5 |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Panel doesn't appear | Check Algo Trading is on and the EA shows a smiley face in the chart's top-right corner |
| Buttons do nothing / "trade disabled" | Tick **Allow Algo Trading** in the EA's Common tab; check your broker allows trading |
| Order fails | Read the reason in **Toolbox → Experts** (e.g. invalid stops, market closed, not enough money) |
| Lot looks too big/small | Pip size follows the broker's point/digits; verify SL pips and risk on your symbol with a demo trade |
| Hotkey does nothing | Make sure the chart is focused and you're not typing in an input box; avoid keys MT5 already uses |
| Panel resets when changing timeframe | Toggles and input boxes reset on timeframe or symbol change (hotkeys are kept) |

---

## Notes

- Works on **hedging and netting** accounts, but is designed with hedging in mind (partial closes keep the same ticket).
- Panel actions apply to the **current chart's symbol** only.
- Pip size: 3- and 5-digit symbols use point × 10; other symbols (e.g. gold, indices) use the broker's point. Check values on your instrument.

## Disclaimer

For educational and personal use. Not financial advice. You are responsible for all trades placed with this tool.
