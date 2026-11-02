//+------------------------------------------------------------------+
//|  QuickTradePanel_Pro.mq5                                         |
//|  Horizontal Trading Panel — v4.0 Pro                             |
//+------------------------------------------------------------------+
//  CHANGES in v4.0
//  ─────────────────────────────────────────────────────────────────
//  UI REDESIGN (horizontal bar, 3 rows + hotkey drawer)
//    Row 1  TRADE   : status | LOT | RISK % | SL pips | TP | BUY SELL
//    Row 2  MANAGE  : CLOSE ALL / CLOSE + / B.E / CLOSE 50% |
//                     RR 1:2 / MTP / AUTO $SL / AUTO B.E / AVG LINE | KEYS
//    Row 3  STATS   : daily progress bar, Day/Open/Total P&L, win rate, streak
//    Drawer HOTKEYS : opens under the stats row (button "KEYS")
//
//  NEW: Risk % lot calculator
//    • "RISK %" toggle + risk-percent box. Lot = (balance × risk%) / (SL pips × pip value).
//    • Needs "SL" pips box > 0. Calculated lot is shown live next to the box.
//    • Lot box is greyed out while Risk mode is ON.
//
//  NEW: SL pips box (works with or without Risk mode, and with RR mode)
//    • If > 0, every new trade gets this SL. Takes priority over AUTO $SL.
//
//  NEW: Hotkeys for EVERY action — assigned by you, inside the panel
//    • Click "KEYS", click a key box, press the combo you want
//      (Ctrl / Shift / Alt + key supported). Esc cancels. "x" clears one.
//    • Saved in terminal Global Variables, so they survive restarts.
//    • No defaults: everything starts unassigned.
//    • Hotkeys are ignored while you are typing in a panel input box.
//
//  FIXES / IMPROVEMENTS
//    • RR mode remembers each trade's ORIGINAL risk distance, so moving SL
//      (manual B.E / Auto-BE) no longer breaks the 1:1 / 1:2 targets.
//    • RR mode sets the broker TP (1:2) automatically when you add an SL later.
//    • RR / MTP / Auto-BE never loosen an SL that is already better.
//    • MTP no longer sends an invalid TP when T2 = 0.
//    • AUTO $SL applies to open trades only when switching ON.
//    • Lot rounding uses an epsilon (0.07 no longer floors to 0.06).
//    • Chart TP/RR lines update in place (no more delete/recreate flicker).
//    • Fill mode and deviation set; failed orders print the broker reason.
//+------------------------------------------------------------------+
#property strict
#property copyright "QuickTradePanel v4.0 Pro"
#property version   "4.00"
#property description "Redesigned panel: Risk % lot calc, RR 1:1/1:2 split, user-assigned hotkeys."

#include <Trade/Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//|  INPUTS                                                          |
//+------------------------------------------------------------------+
input group "═══ PANEL SETTINGS ═══"
input double DefaultLotSize    = 0.01;   // Starting lot size
input double DefaultRiskPct    = 1.0;    // Starting Risk % per trade (Risk mode)
input bool   RiskOnEquity      = false;  // Risk % based on Equity (false = Balance)
input double PartialClosePct   = 50.0;   // % to close on the "CLOSE 50%" button
input double TP1ClosePct       = 50.0;   // % to close when TP1 is hit (MTP mode)
input int    MaxSpreadPoints   = 80;     // Spread above this = Red LED
input double AutoBETriggerPips = 15.0;   // Pips in profit to trigger Auto-BE
input double AutoBEBufferPips  = 4.0;    // Auto-BE SL offset in pips (covers spread)
input double AutoSLDollar      = 5.0;    // Starting $ risk for AUTO $SL
input double DailyPnLTarget    = 50.0;   // Daily profit target for progress bar ($). 0 = hide.
input int    MagicNumber       = 0;      // 0 = manage ALL trades on symbol
input bool   ScanShootingStars = true;   // Mark shooting stars on M1/M3/M5

//+------------------------------------------------------------------+
//|  COLOURS                                                         |
//+------------------------------------------------------------------+
#define CLR_BG           C'10,11,18'
#define CLR_BORDER       C'38,40,62'
#define CLR_BORDER_LT    C'55,58,90'
#define CLR_DIVIDER      C'30,32,50'
#define CLR_WHITE        C'236,240,255'
#define CLR_SOFT         C'160,168,200'
#define CLR_LABEL        C'90,96,130'
#define CLR_GREEN        C'0,215,110'
#define CLR_GREEN_DIM    C'0,140,70'
#define CLR_YELLOW       C'255,195,0'
#define CLR_RED          C'255,65,65'
#define CLR_BLUE         C'80,160,255'
#define CLR_CYAN         C'0,210,200'
#define CLR_ORANGE       C'255,145,0'
#define CLR_BUY_BG       C'0,165,82'
#define CLR_BUY_EDGE     C'0,200,100'
#define CLR_SELL_BG      C'210,38,65'
#define CLR_SELL_EDGE    C'255,60,90'
#define CLR_BTN_BG       C'22,23,36'
#define CLR_BTN_EDGE     C'44,46,72'
#define CLR_TOGGLE_ON    C'0,105,55'
#define CLR_TOGGLE_MTP   C'100,60,0'
#define CLR_TOGGLE_SL    C'110,50,0'
#define CLR_TOGGLE_RR    C'80,40,110'
#define CLR_TOGGLE_RISK  C'0,80,95'
#define CLR_RR_ON        C'160,80,220'
#define CLR_EDIT_BG      C'14,15,24'
#define CLR_BAR_BG       C'18,19,30'
#define CLR_BAR_GREEN    C'0,180,90'
#define CLR_BAR_YELLOW   C'200,155,0'
#define CLR_BAR_RED      C'190,40,55'
#define CLR_STAT_DIM     C'70,78,115'

#define PANEL_W   1000
#define LINE_PFX  "QTP_LN_"

//+------------------------------------------------------------------+
//|  HOTKEY ACTIONS                                                  |
//+------------------------------------------------------------------+
enum ENUM_HK
{
   HK_BUY = 0, HK_SELL, HK_CLOSE_ALL, HK_CLOSE_PROFIT, HK_BREAKEVEN, HK_PARTIAL,
   HK_LOT_UP, HK_LOT_DOWN, HK_RISK, HK_RR, HK_MTP, HK_AUTO_SL, HK_AUTO_BE, HK_AVG_LINE,
   HK_N
};

string g_hkNames[HK_N] =
{
   "Buy", "Sell", "Close All", "Close Profit", "Break-Even", "Close 50%",
   "Lot +", "Lot -", "Risk % Mode", "RR 1:2 Mode", "Multi-TP", "Auto $SL", "Auto B.E", "Avg Line"
};

int    g_hk[HK_N];          // encoded: keyCode + 1000*mods (1=Ctrl 2=Shift 4=Alt), 0 = unset
string g_btn[HK_N];         // panel button name for each action
int    g_hkCapture = -1;    // action index waiting for a key press, -1 = none
bool   g_hkOpen    = false; // hotkey drawer visible
bool   g_editing   = false; // an input box is being edited

//+------------------------------------------------------------------+
//|  GLOBALS                                                         |
//+------------------------------------------------------------------+
string   PFX            = "QTP_";
double   g_lotSize      = 0.01;
double   g_riskPct      = 1.0;
double   g_slPips       = 0.0;
double   g_tpPips       = 0.0;
double   g_tpMoney      = 0.0;
double   g_autoSLAmt    = 5.0;
bool     g_autoBE       = false;
bool     g_showNetPrice = true;
bool     g_multiTP      = false;
bool     g_autoSLDollar = false;
bool     g_rrMode       = false;
bool     g_riskMode     = false;
datetime g_lastTime[3]  = {0, 0, 0};
string   g_keep         = "";

//+------------------------------------------------------------------+
//|  RR TRACKER (remembers original risk distance per ticket)        |
//+------------------------------------------------------------------+
#define MAX_TRK 200
ulong  g_rrT[MAX_TRK];
double g_rrD[MAX_TRK];
bool   g_rrDone[MAX_TRK];
int    g_rrN = 0;

int RRFind(ulong t)
{
   for(int i = 0; i < g_rrN; i++)
      if(g_rrT[i] == t) return i;
   return -1;
}

void RRPurge()
{
   for(int i = g_rrN - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(g_rrT[i])) continue;
      for(int k = i; k < g_rrN - 1; k++)
      {
         g_rrT[k] = g_rrT[k+1]; g_rrD[k] = g_rrD[k+1]; g_rrDone[k] = g_rrDone[k+1];
      }
      g_rrN--;
   }
}

// ── MTP TP1 tracker ──────────────────────────────────────────────
ulong g_tp1Done[MAX_TRK];
int   g_tp1DoneCount = 0;

bool IsTP1Done(ulong t)
{
   for(int i = 0; i < g_tp1DoneCount; i++)
      if(g_tp1Done[i] == t) return true;
   return false;
}
void MarkTP1Done(ulong t)
{
   if(IsTP1Done(t) || g_tp1DoneCount >= MAX_TRK) return;
   g_tp1Done[g_tp1DoneCount++] = t;
}
void PurgeTP1Done()
{
   for(int i = g_tp1DoneCount - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(g_tp1Done[i])) continue;
      for(int k = i; k < g_tp1DoneCount - 1; k++) g_tp1Done[k] = g_tp1Done[k+1];
      g_tp1DoneCount--;
   }
}

//+------------------------------------------------------------------+
//|  HOTKEY STORAGE + NAMING                                         |
//+------------------------------------------------------------------+
string HKVar(int i) { return "QTP_HK_" + IntegerToString(i); }

void SaveHK(int i)
{
   if(g_hk[i] > 0) GlobalVariableSet(HKVar(i), (double)g_hk[i]);
   else if(GlobalVariableCheck(HKVar(i))) GlobalVariableDel(HKVar(i));
}

void LoadHotkeys()
{
   for(int i = 0; i < HK_N; i++)
      g_hk[i] = GlobalVariableCheck(HKVar(i)) ? (int)GlobalVariableGet(HKVar(i)) : 0;
}

string BaseKeyName(int k)
{
   if((k >= 48 && k <= 57) || (k >= 65 && k <= 90)) return CharToString((uchar)k);
   if(k >= 112 && k <= 123) return "F" + IntegerToString(k - 111);
   if(k >= 96  && k <= 105) return "Num" + IntegerToString(k - 96);
   switch(k)
   {
      case 8:   return "Bksp";   case 9:   return "Tab";    case 13:  return "Enter";
      case 32:  return "Space";  case 33:  return "PgUp";   case 34:  return "PgDn";
      case 35:  return "End";    case 36:  return "Home";   case 37:  return "Left";
      case 38:  return "Up";     case 39:  return "Right";  case 40:  return "Down";
      case 45:  return "Ins";    case 46:  return "Del";
      case 106: return "Num*";   case 107: return "Num+";   case 109: return "Num-";
      case 110: return "Num.";   case 111: return "Num/";
      case 186: return ";";      case 187: return "=";      case 188: return ",";
      case 189: return "-";      case 190: return ".";      case 191: return "/";
      case 192: return "`";      case 219: return "[";      case 220: return "\\";
      case 221: return "]";      case 222: return "'";
   }
   return "Key" + IntegerToString(k);
}

string KeyName(int enc)
{
   if(enc <= 0) return "";
   int mods = enc / 1000, k = enc % 1000;
   string s = "";
   if((mods & 1) != 0) s += "Ctrl+";
   if((mods & 2) != 0) s += "Shift+";
   if((mods & 4) != 0) s += "Alt+";
   return s + BaseKeyName(k);
}

string HKText(int a) { return (g_hk[a] > 0) ? KeyName(g_hk[a]) : ""; }

int CurrentMods()
{
   int m = 0;
   if((TerminalInfoInteger(TERMINAL_KEYSTATE_CONTROL) & 0x8000) != 0) m |= 1;
   if((TerminalInfoInteger(TERMINAL_KEYSTATE_SHIFT)   & 0x8000) != 0) m |= 2;
   if((TerminalInfoInteger(TERMINAL_KEYSTATE_MENU)    & 0x8000) != 0) m |= 4;
   return m;
}

//+------------------------------------------------------------------+
//|  TOOLTIP HELPERS                                                 |
//+------------------------------------------------------------------+
string TT(string shortcut, string action, string example)
{
   string s = "";
   if(shortcut != "") s += "⌨  " + shortcut + "\n";
   s += "▶  " + action;
   if(example  != "") s += "\n✎  e.g. " + example;
   return s;
}
string TTK(int a, string action, string example) { return TT(HKText(a), action, example); }

//+------------------------------------------------------------------+
//|  CHART OBJECT HELPERS                                            |
//+------------------------------------------------------------------+
void MakeLabel(string name, int x, int y, string txt, color clr,
               int fs = 9, string fnt = "Arial Bold")
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, name, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetString (0, name, OBJPROP_FONT,       fnt);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void MakeRect(string name, int x, int y, int w, int h,
              color bg, color border = CLR_BORDER, bool back = false)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       border);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      true);
   ObjectSetInteger(0, name, OBJPROP_BACK,        back);
}

void MakeRoundBtn(string name, int x, int y, int w, int h,
                  string txt, color bg, color edgeClr, color tc,
                  int fs = 9, string tip = "")
{
   MakeRect(PFX+"_E_"+name, x-1, y-1, w+2, h+2, edgeClr, edgeClr);
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetString (0, name, OBJPROP_TEXT,         txt);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR,        tc);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,     fs);
   ObjectSetString (0, name, OBJPROP_FONT,         "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_STATE,        false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,       true);
   if(tip != "") ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
}

// Toggle button: highlighted + "●" prefix when ON
void MakeToggle(string name, int x, int y, int w, int h, string txt, bool on,
                color onBg, color onClr, string tip, int fs = 8)
{
   MakeRoundBtn(name, x, y, w, h, (on ? "● " : "") + txt,
                on ? onBg : CLR_BTN_BG,
                on ? onClr : CLR_BTN_EDGE,
                on ? onClr : CLR_SOFT, fs, tip);
}

void MakeEditOnce(string name, int x, int y, int w, int h,
                  string defaultTxt, int fs = 10, string tip = "")
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
      ObjectSetString(0, name, OBJPROP_TEXT, defaultTxt);
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      CLR_EDIT_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR,        CLR_WHITE);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, CLR_BORDER_LT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,     fs);
   ObjectSetString (0, name, OBJPROP_FONT,         "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_ALIGN,        ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,       true);
   ObjectSetInteger(0, name, OBJPROP_READONLY,     false);
   if(tip != "") ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
}

// Greys out an input box (read-only) when it is not used by the current mode
void SetEditEnabled(string name, bool enabled)
{
   ObjectSetInteger(0, name, OBJPROP_READONLY, !enabled);
   ObjectSetInteger(0, name, OBJPROP_COLOR,    enabled ? CLR_WHITE : CLR_LABEL);
}

//+------------------------------------------------------------------+
//|  UTILITIES                                                       |
//+------------------------------------------------------------------+
double GetPipSize()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return (dg == 3 || dg == 5) ? pt * 10.0 : pt;
}

double ClampLot(double lot)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   int vd = (int)MathMax(0, MathRound(-MathLog10(step)));
   double l = NormalizeDouble(MathFloor(lot / step + 1e-9) * step, vd);
   return MathMax(mn, MathMin(mx, l));
}

// Selects position at index i; true only if it belongs to this symbol/magic
bool SelMine(int i, ulong &t)
{
   t = PositionGetTicket(i);
   if(t == 0 || !PositionSelectByTicket(t)) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(MagicNumber != 0 && PositionGetInteger(POSITION_MAGIC) != MagicNumber) return false;
   return true;
}

void ReadInputs()
{
   double v;
   if(ObjectFind(0, PFX+"EditLot") >= 0)
   { v = StringToDouble(ObjectGetString(0, PFX+"EditLot", OBJPROP_TEXT)); if(v > 0) g_lotSize = v; }
   if(ObjectFind(0, PFX+"EditRisk") >= 0)
   { v = StringToDouble(ObjectGetString(0, PFX+"EditRisk", OBJPROP_TEXT)); if(v > 0) g_riskPct = v; }
   if(ObjectFind(0, PFX+"EditSLDollar") >= 0)
   { v = StringToDouble(ObjectGetString(0, PFX+"EditSLDollar", OBJPROP_TEXT)); if(v > 0) g_autoSLAmt = v; }
   if(ObjectFind(0, PFX+"EditSLPips") >= 0)
      g_slPips  = MathMax(0.0, StringToDouble(ObjectGetString(0, PFX+"EditSLPips", OBJPROP_TEXT)));
   if(ObjectFind(0, PFX+"EditTPPips") >= 0)
      g_tpPips  = MathMax(0.0, StringToDouble(ObjectGetString(0, PFX+"EditTPPips", OBJPROP_TEXT)));
   if(ObjectFind(0, PFX+"EditTPMoney") >= 0)
      g_tpMoney = MathMax(0.0, StringToDouble(ObjectGetString(0, PFX+"EditTPMoney", OBJPROP_TEXT)));
}

double PipsToPrice(int dir, double entry, double pips)
{
   return NormalizeDouble(entry + dir * pips * GetPipSize(), _Digits);
}

double PipValuePerLot()
{
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return 0.0;
   return tv * (GetPipSize() / ts);
}

double PipsToDollars(double pipCount, double lots)
{
   double pv = PipValuePerLot();
   if(pv <= 0 || lots <= 0) return 0.0;
   return pv * lots * pipCount;
}

double CalcTPSingle(int dir, double entry, double lot)
{
   if(g_tpPips > 0.0) return PipsToPrice(dir, entry, g_tpPips);
   if(g_tpMoney > 0.0)
   {
      double pv = PipValuePerLot();
      if(pv <= 0 || lot <= 0) return 0.0;
      return PipsToPrice(dir, entry, g_tpMoney / (pv * lot));
   }
   return 0.0;
}

double CalcDollarSLPrice(int dir, double entry, double lots, double dollars)
{
   double pv = PipValuePerLot();
   if(pv <= 0 || lots <= 0 || dollars <= 0) return 0.0;
   return PipsToPrice(-dir, entry, dollars / (pv * lots));
}

// ── Risk % lot calculator ────────────────────────────────────────
double RiskMoney()
{
   double base = RiskOnEquity ? AccountInfoDouble(ACCOUNT_EQUITY)
                              : AccountInfoDouble(ACCOUNT_BALANCE);
   return base * g_riskPct / 100.0;
}

double CalcRiskLot(double slPips)
{
   double pv = PipValuePerLot();
   if(pv <= 0 || slPips <= 0.0) return 0.0;
   return ClampLot(RiskMoney() / (slPips * pv));
}

double GetOpenPnL(int &count, int &buys, int &sells)
{
   count = buys = sells = 0;
   double total = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      total += PositionGetDouble(POSITION_PROFIT);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buys++; else sells++;
      count++;
   }
   return total;
}

//+------------------------------------------------------------------+
//|  RR 1:1 / 1:2 AUTO SPLIT                                         |
//+------------------------------------------------------------------+
double CalcRRTP2(int dir, double entry, double sl)
{
   if(sl == 0.0) return 0.0;
   double d = MathAbs(entry - sl);
   if(d < SymbolInfoDouble(_Symbol, SYMBOL_POINT)) return 0.0;
   return NormalizeDouble(entry + dir * d * 2.0, _Digits);
}

void ProcessRRMode()
{
   if(!g_rrMode) return;
   RRPurge();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t;
      if(!SelMine(i, t)) continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      int    dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;

      int idx = RRFind(t);
      if(idx < 0)
      {
         // First time we see this trade with an SL: lock in its risk distance
         if(sl == 0.0 || g_rrN >= MAX_TRK) continue;
         double d = MathAbs(entry - sl);
         if(d < SymbolInfoDouble(_Symbol, SYMBOL_POINT)) continue;
         idx = g_rrN++;
         g_rrT[idx] = t; g_rrD[idx] = d; g_rrDone[idx] = false;

         if(curTP == 0.0)
         {
            double tp2 = CalcRRTP2(dir, entry, sl);
            if(tp2 > 0.0 && trade.PositionModify(t, sl, tp2))
               PrintFormat("QTP RR | #%I64u | broker TP set to 1:2 = %s", t, DoubleToString(tp2, _Digits));
         }
      }
      if(g_rrDone[idx]) continue;

      double dist     = g_rrD[idx];
      double tp1Price = NormalizeDouble(entry + dir * dist, _Digits);
      double curP     = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool tp1Hit = (dir == 1) ? (curP >= tp1Price) : (curP <= tp1Price);
      if(!tp1Hit) continue;

      double vol  = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double ml   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half = MathFloor((vol * 0.5) / step + 1e-9) * step;
      if(half < ml) half = ml;

      if((vol - half) >= ml)
      {
         if(trade.PositionClosePartial(t, half))
         {
            PrintFormat("QTP RR | #%I64u | TP1 (1:1) hit | closed %.2f | remaining %.2f", t, half, vol - half);
            if(PositionSelectByTicket(t))
            {
               double nowSL = PositionGetDouble(POSITION_SL);
               bool better  = (nowSL == 0.0) || (dir == 1 ? entry > nowSL : entry < nowSL);
               if(better) trade.PositionModify(t, entry, PositionGetDouble(POSITION_TP));
            }
            g_rrDone[idx] = true;
         }
      }
      else
      {
         if(trade.PositionClose(t))
            PrintFormat("QTP RR | #%I64u | TP1 hit | lot too small to split — full close.", t);
         g_rrDone[idx] = true;
      }
   }
}

//+------------------------------------------------------------------+
//|  CHART LINES (TP / RR) — updated in place, swept when stale      |
//+------------------------------------------------------------------+
void SetLine(string name, double price, color clr, ENUM_LINE_STYLE st, string txt)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble (0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, st);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetString (0, name, OBJPROP_TEXT,  txt);
   g_keep += "|" + name + "|";
}

void SweepLines()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string n = ObjectName(0, i);
      if(StringFind(n, LINE_PFX) == 0 && StringFind(g_keep, "|" + n + "|") < 0)
         ObjectDelete(0, n);
   }
}

void DeleteLines() { g_keep = ""; SweepLines(); }

void BuildRRLines()
{
   double pip = GetPipSize();
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double ml   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      int idx = RRFind(t);
      if(idx < 0) continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      int    dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      string tid   = IntegerToString((long)t);

      double dist   = g_rrD[idx];
      double slPips = dist / pip;
      double half   = MathMax(ml, MathFloor((vol * 0.5) / step + 1e-9) * step);
      double rem    = g_rrDone[idx] ? vol : ((vol - half) >= ml ? vol - half : vol);

      if(!g_rrDone[idx])
         SetLine(LINE_PFX+"RR1_"+tid, NormalizeDouble(entry + dir * dist, _Digits), CLR_YELLOW, STYLE_DASH,
                 "RR TP1 (1:1)  +" + DoubleToString(slPips, 1) + " pips  →  ~$" +
                 DoubleToString(PipsToDollars(slPips, half), 2) + "  (close 50% + BE)  #" + tid);

      SetLine(LINE_PFX+"RR2_"+tid, NormalizeDouble(entry + dir * dist * 2.0, _Digits), CLR_GREEN, STYLE_DASHDOT,
              "RR TP2 (1:2)  +" + DoubleToString(slPips * 2.0, 1) + " pips  →  ~$" +
              DoubleToString(PipsToDollars(slPips * 2.0, rem), 2) + "  (full target)  #" + tid);
   }
}

void BuildMTPLines()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double ml   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      int    dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      string tid   = IntegerToString((long)t);

      double closeLots = MathMax(ml, MathFloor((vol * TP1ClosePct / 100.0) / step + 1e-9) * step);

      if(!IsTP1Done(t) && g_tpPips > 0.0)
         SetLine(LINE_PFX+"TP1_"+tid, PipsToPrice(dir, entry, g_tpPips), CLR_YELLOW, STYLE_DASH,
                 "TP1 +" + DoubleToString(g_tpPips, 0) + " pips  →  ~$" +
                 DoubleToString(PipsToDollars(g_tpPips, closeLots), 2) +
                 "  (close " + DoubleToString(TP1ClosePct, 0) + "% + BE)  #" + tid);

      if(g_tpMoney > 0.0)
      {
         double rem = MathMax(0, vol - closeLots);
         if(IsTP1Done(t) || rem < ml) rem = vol;
         SetLine(LINE_PFX+"TP2_"+tid, PipsToPrice(dir, entry, g_tpMoney), CLR_GREEN, STYLE_DASHDOT,
                 "TP2 +" + DoubleToString(g_tpMoney, 0) + " pips  →  ~$" +
                 DoubleToString(PipsToDollars(g_tpMoney, rem), 2) + "  (full target)  #" + tid);
      }
   }
}

void BuildSingleLines()
{
   if(g_tpPips <= 0.0 && g_tpMoney <= 0.0) return;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      int    dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      string tid   = IntegerToString((long)t);

      double tpPrice = CalcTPSingle(dir, entry, vol);
      if(tpPrice <= 0.0) continue;
      double pips = MathAbs(tpPrice - entry) / GetPipSize();

      SetLine(LINE_PFX+"STP_"+tid, tpPrice, C'0,180,255', STYLE_DASH,
              "TP +" + DoubleToString(pips, 1) + " pips  →  ~$" + DoubleToString(PipsToDollars(pips, vol), 2) +
              "  (" + DoubleToString(vol, 2) + " lots)  #" + tid);
   }
}

void DrawLines()
{
   g_keep = "";
   if(g_rrMode)        BuildRRLines();
   else if(g_multiTP)  BuildMTPLines();
   else                BuildSingleLines();
   SweepLines();
}

//+------------------------------------------------------------------+
//|  DAILY STATS ENGINE                                              |
//+------------------------------------------------------------------+
datetime TodayMidnight()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = dt.min = dt.sec = 0;
   return StructToTime(dt);
}

void GetDailyStats(double &realizedPnL, int &wins, int &losses)
{
   realizedPnL = 0.0;
   wins = losses = 0;
   if(!HistorySelect(TodayMidnight(), TimeCurrent() + 1)) return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(MagicNumber != 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      long en = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(en != DEAL_ENTRY_OUT && en != DEAL_ENTRY_INOUT) continue;
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(MathAbs(profit) < 0.001) continue;
      realizedPnL += profit;
      if(profit > 0) wins++; else losses++;
   }
}

string BuildStreakDots(int maxN)
{
   if(!HistorySelect(TodayMidnight(), TimeCurrent() + 1)) return "";
   int total = HistoryDealsTotal();
   string dots = "";
   int count = 0;
   for(int i = total - 1; i >= 0 && count < maxN; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(MagicNumber != 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      long en = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(en != DEAL_ENTRY_OUT && en != DEAL_ENTRY_INOUT) continue;
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(MathAbs(profit) < 0.001) continue;
      dots += (profit > 0) ? "▲" : "▼";
      count++;
   }
   return (dots == "") ? "—" : dots;
}

void DrawStatsRow(double realizedPnL, double openPnL, int wins, int losses)
{
   const int X = 10, SY = 90, SH = 18, W = PANEL_W;

   MakeRect(PFX+"SR_BG_G", X-1, SY-1, W+2, SH+2, CLR_BORDER, CLR_BORDER);
   MakeRect(PFX+"SR_BG",   X,   SY,   W,   SH,   CLR_BAR_BG, CLR_BAR_BG);

   int cx = X + 10;
   double totalDay = realizedPnL + openPnL;

   if(DailyPnLTarget > 0.0)
   {
      const int BAR_W = 180, BAR_H = 8;
      int BAR_Y = SY + (SH - BAR_H) / 2;
      MakeRect(PFX+"SR_BarBG", cx, BAR_Y, BAR_W, BAR_H, CLR_BG, CLR_BORDER);

      int fillW; color barClr;
      if(totalDay >= DailyPnLTarget)     { fillW = BAR_W; barClr = CLR_BAR_GREEN; }
      else if(totalDay >= 0.0)           { fillW = (int)MathRound(totalDay / DailyPnLTarget * BAR_W); barClr = CLR_BAR_YELLOW; }
      else { fillW = (int)MathRound(MathMin(1.0, MathAbs(totalDay) / DailyPnLTarget) * BAR_W); barClr = CLR_BAR_RED; }

      if(fillW > 0) MakeRect(PFX+"SR_BarFill", cx, BAR_Y, fillW, BAR_H, barClr, barClr);
      else          MakeRect(PFX+"SR_BarFill", cx, BAR_Y, 1, BAR_H, CLR_BAR_BG, CLR_BAR_BG);

      MakeLabel(PFX+"SR_Target", cx + BAR_W + 4, SY + 4, "$" + DoubleToString(DailyPnLTarget, 0) + " goal", CLR_STAT_DIM, 7, "Arial");
      cx += BAR_W + 56;
   }

   MakeLabel(PFX+"SR_Real", cx, SY + 4, "Day: " + (realizedPnL >= 0 ? "+" : "") + DoubleToString(realizedPnL, 2),
             realizedPnL > 0 ? CLR_GREEN : realizedPnL < 0 ? CLR_RED : CLR_SOFT, 8);
   cx += 100;
   MakeRect(PFX+"SR_D1", cx, SY+3, 1, SH-6, CLR_DIVIDER, CLR_DIVIDER); cx += 8;

   MakeLabel(PFX+"SR_Open", cx, SY + 4, "Open: " + (openPnL >= 0 ? "+" : "") + DoubleToString(openPnL, 2),
             openPnL > 0 ? CLR_CYAN : openPnL < 0 ? CLR_ORANGE : CLR_SOFT, 8);
   cx += 100;
   MakeRect(PFX+"SR_D2", cx, SY+3, 1, SH-6, CLR_DIVIDER, CLR_DIVIDER); cx += 8;

   MakeLabel(PFX+"SR_Tot", cx, SY + 4, "Total: " + (totalDay >= 0 ? "+" : "") + DoubleToString(totalDay, 2),
             totalDay > 0 ? CLR_GREEN : totalDay < 0 ? CLR_RED : CLR_SOFT, 8);
   cx += 110;
   MakeRect(PFX+"SR_D3", cx, SY+3, 1, SH-6, CLR_DIVIDER, CLR_DIVIDER); cx += 8;

   int n = wins + losses;
   double winPct = (n > 0) ? wins * 100.0 / n : 0.0;
   string wrTxt; color wrClr;
   if(n == 0) { wrTxt = "W:0  L:0  —"; wrClr = CLR_STAT_DIM; }
   else
   {
      wrTxt = "W:" + IntegerToString(wins) + "  L:" + IntegerToString(losses) + "   " + DoubleToString(winPct, 0) + "%";
      wrClr = (winPct >= 60.0) ? CLR_GREEN : (winPct >= 40.0) ? CLR_YELLOW : CLR_RED;
   }
   MakeLabel(PFX+"SR_WR", cx, SY + 4, wrTxt, wrClr, 8);
   ObjectSetString(0, PFX+"SR_WR", OBJPROP_TOOLTIP,
      "Win rate since midnight today\nW = profitable closed trades\nL = losing closed trades\nOnly counts closed deals on " + _Symbol);
   cx += 120;
   MakeRect(PFX+"SR_D4", cx, SY+3, 1, SH-6, CLR_DIVIDER, CLR_DIVIDER); cx += 8;

   MakeLabel(PFX+"SR_Streak", cx, SY + 4, BuildStreakDots(5), CLR_SOFT, 9);
   ObjectSetString(0, PFX+"SR_Streak", OBJPROP_TOOLTIP, "Last 5 trade results  (▲=win  ▼=loss)");
}

//+------------------------------------------------------------------+
//|  TRADE ACTIONS                                                   |
//+------------------------------------------------------------------+
void OpenTrade(int dir)
{
   ReadInputs();
   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = ClampLot(g_lotSize);
   double sl = 0.0, tp = 0.0;

   // ── Stop loss ────────────────────────────────────────────────
   if(g_slPips > 0.0) sl = PipsToPrice(-dir, price, g_slPips);

   // ── Lot size (Risk % mode) ───────────────────────────────────
   if(g_riskMode)
   {
      if(g_slPips <= 0.0)
      {
         Print("QTP RISK | Trade skipped — enter SL pips (> 0) to size the lot from Risk %.");
         return;
      }
      lot = CalcRiskLot(g_slPips);
      if(lot <= 0.0) { Print("QTP RISK | Cannot calculate lot — check tick value data."); return; }
      double realRisk = PipsToDollars(g_slPips, lot);
      if(realRisk > RiskMoney() * 1.2)
         PrintFormat("QTP RISK | Warning: minimum lot %.2f risks ~$%.2f (target $%.2f).", lot, realRisk, RiskMoney());
   }
   else if(sl == 0.0 && g_autoSLDollar)
   {
      sl = CalcDollarSLPrice(dir, price, lot, g_autoSLAmt);
      if(sl <= 0.0) Print("QTP ADSL | Cannot calculate SL — check tick value data.");
   }

   // ── Take profit ──────────────────────────────────────────────
   if(g_rrMode)        tp = (sl > 0.0) ? CalcRRTP2(dir, price, sl) : 0.0;   // set later once SL exists
   else if(g_multiTP)  tp = (g_tpMoney > 0.0) ? PipsToPrice(dir, price, g_tpMoney) : 0.0;
   else                tp = CalcTPSingle(dir, price, lot);

   bool ok = (dir == 1) ? trade.Buy (lot, _Symbol, price, sl, tp, "QTP_Buy")
                        : trade.Sell(lot, _Symbol, price, sl, tp, "QTP_Sell");
   if(!ok)
      PrintFormat("QTP | %s failed: %s (%d)", dir == 1 ? "BUY" : "SELL",
                  trade.ResultRetcodeDescription(), (int)trade.ResultRetcode());
}

void ApplyDollarSLToAll()
{
   if(PipValuePerLot() <= 0) { Print("QTP ADSL | Cannot compute pip value."); return; }
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopLevel * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;

      double vol   = PositionGetDouble(POSITION_VOLUME);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curTP = PositionGetDouble(POSITION_TP);
      int    dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;

      double sl = CalcDollarSLPrice(dir, entry, vol, g_autoSLAmt);
      if(sl <= 0.0) { PrintFormat("QTP ADSL | Skipping #%I64u — bad pip value.", t); continue; }

      double curPrice = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(MathAbs(curPrice - sl) < minDist)
      {
         PrintFormat("QTP ADSL | #%I64u | SL %s too close (min dist %s) — skipped.", t,
                     DoubleToString(sl, _Digits), DoubleToString(minDist, _Digits));
         continue;
      }

      double newTP = curTP;
      if(g_rrMode)
      {
         double rr = CalcRRTP2(dir, entry, sl);
         if(rr > 0.0) newTP = rr;
      }
      if(trade.PositionModify(t, sl, newTP))
         PrintFormat("QTP ADSL | #%I64u | SL set to %s (risk ~$%.2f on %.2f lots)", t,
                     DoubleToString(sl, _Digits), g_autoSLAmt, vol);
      else
         PrintFormat("QTP ADSL | #%I64u | PositionModify failed: %s", t, trade.ResultRetcodeDescription());
   }
}

void DoCloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   { ulong t; if(SelMine(i, t)) trade.PositionClose(t); }
}

void DoCloseProfit()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   { ulong t; if(SelMine(i, t) && PositionGetDouble(POSITION_PROFIT) > 0) trade.PositionClose(t); }
}

void DoBreakEven()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      long   pType = PositionGetInteger(POSITION_TYPE);
      bool move = (pType == POSITION_TYPE_BUY  && (curSL == 0 || entry > curSL))
               || (pType == POSITION_TYPE_SELL && (curSL == 0 || entry < curSL));
      if(move) trade.PositionModify(t, entry, curTP);
   }
}

void DoPartialClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double ml   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double part = MathFloor((vol * PartialClosePct / 100.0) / step + 1e-9) * step;
      if(part >= ml && (vol - part) >= ml) trade.PositionClosePartial(t, part);
      else trade.PositionClose(t);
   }
}

//+------------------------------------------------------------------+
//|  MULTI-LEVEL TP                                                  |
//+------------------------------------------------------------------+
void ProcessMultiTP()
{
   if(g_rrMode) return;
   if(!g_multiTP || g_tpPips <= 0.0) return;
   PurgeTP1Done();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      if(IsTP1Done(t)) continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      int    dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double curP  = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double tp1   = PipsToPrice(dir, entry, g_tpPips);
      bool hit = (dir == 1) ? (curP >= tp1) : (curP <= tp1);
      if(!hit) continue;

      double vol  = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double ml   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double part = MathFloor((vol * TP1ClosePct / 100.0) / step + 1e-9) * step;
      if(part < ml) part = ml;

      if((vol - part) >= ml) trade.PositionClosePartial(t, part);
      else                   trade.PositionClose(t);

      if(PositionSelectByTicket(t))
      {
         double nowSL = PositionGetDouble(POSITION_SL);
         bool better  = (nowSL == 0.0) || (dir == 1 ? entry > nowSL : entry < nowSL);
         if(better) trade.PositionModify(t, entry, PositionGetDouble(POSITION_TP));
      }
      MarkTP1Done(t);
      PrintFormat("QTP MTP | #%I64u | TP1 %s hit | closed %.2f lots | SL => entry", t, DoubleToString(tp1, _Digits), part);
   }
}

//+------------------------------------------------------------------+
//|  ADVANCED FEATURES                                               |
//+------------------------------------------------------------------+
void ProcessAutoBE()
{
   if(!g_autoBE) return;
   double pip = GetPipSize();
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      long   pType = PositionGetInteger(POSITION_TYPE);
      double curP  = (pType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double profPips = (pType == POSITION_TYPE_BUY) ? (curP - entry) / pip : (entry - curP) / pip;
      if(profPips < AutoBETriggerPips) continue;

      double bePrice = (pType == POSITION_TYPE_BUY) ? NormalizeDouble(entry + AutoBEBufferPips * pip, _Digits)
                                                    : NormalizeDouble(entry - AutoBEBufferPips * pip, _Digits);
      bool mv = (pType == POSITION_TYPE_BUY  && (curSL == 0 || bePrice > curSL))
             || (pType == POSITION_TYPE_SELL && (curSL == 0 || bePrice < curSL));
      if(mv) trade.PositionModify(t, bePrice, curTP);
   }
}

void ProcessNetPriceLine()
{
   if(!g_showNetPrice) { ObjectDelete(0, PFX+"NetBuy"); ObjectDelete(0, PFX+"NetSell"); return; }

   double tb = 0, ts = 0, sb = 0, ss = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t;
      if(!SelMine(i, t)) continue;
      double v = PositionGetDouble(POSITION_VOLUME), p = PositionGetDouble(POSITION_PRICE_OPEN);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) { tb += v; sb += p * v; }
      else                                                       { ts += v; ss += p * v; }
   }

   string nb = PFX+"NetBuy", ns = PFX+"NetSell";
   if(tb > 0)
   {
      double a = sb / tb;
      if(ObjectFind(0, nb) < 0) { ObjectCreate(0, nb, OBJ_HLINE, 0, 0, a); ObjectSetInteger(0, nb, OBJPROP_SELECTABLE, false); }
      ObjectSetDouble (0, nb, OBJPROP_PRICE, a);
      ObjectSetInteger(0, nb, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, nb, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetString (0, nb, OBJPROP_TEXT,  "Net BUY BE");
   }
   else ObjectDelete(0, nb);

   if(ts > 0)
   {
      double a = ss / ts;
      if(ObjectFind(0, ns) < 0) { ObjectCreate(0, ns, OBJ_HLINE, 0, 0, a); ObjectSetInteger(0, ns, OBJPROP_SELECTABLE, false); }
      ObjectSetDouble (0, ns, OBJPROP_PRICE, a);
      ObjectSetInteger(0, ns, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, ns, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetString (0, ns, OBJPROP_TEXT,  "Net SELL BE");
   }
   else ObjectDelete(0, ns);
}

void ScanShootingStarsNow()
{
   if(!ScanShootingStars) return;
   ENUM_TIMEFRAMES tfs[3] = {PERIOD_M1, PERIOD_M3, PERIOD_M5};
   for(int i = 0; i < 3; i++)
   {
      datetime time[1];
      if(CopyTime(_Symbol, tfs[i], 1, 1, time) <= 0) continue;
      if(time[0] <= g_lastTime[i]) continue;
      g_lastTime[i] = time[0];
      double o[1], h[1], l[1], c[1];
      if(CopyOpen(_Symbol, tfs[i], 1, 1, o) <= 0 || CopyHigh(_Symbol, tfs[i], 1, 1, h) <= 0 ||
         CopyLow (_Symbol, tfs[i], 1, 1, l) <= 0 || CopyClose(_Symbol, tfs[i], 1, 1, c) <= 0) continue;
      double body = MathAbs(o[0] - c[0]);
      double up   = h[0] - MathMax(o[0], c[0]);
      double dn   = MathMin(o[0], c[0]) - l[0];
      double pip  = GetPipSize();
      if(up > body * 2.0 && dn < body && up > 2.0 * pip)
      {
         string nm = PFX+"SS_"+EnumToString(tfs[i])+"_"+TimeToString(time[0]);
         if(ObjectFind(0, nm) < 0)
         {
            ObjectCreate(0, nm, OBJ_ARROW_DOWN, 0, time[0], h[0] + 3 * pip);
            ObjectSetInteger(0, nm, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
            ObjectSetString (0, nm, OBJPROP_TEXT, "Shooting Star " + EnumToString(tfs[i]));
         }
      }
   }
}

//+------------------------------------------------------------------+
//|  ACTION DISPATCH (buttons + hotkeys share this)                  |
//+------------------------------------------------------------------+
void ToggleRR()
{
   g_rrMode = !g_rrMode;
   if(g_rrMode) g_multiTP = false;   // RR and MTP share TP1 logic
}

void ToggleMTP()
{
   if(g_rrMode) { Print("QTP | Multi-TP is disabled while RR 1:2 mode is ON."); return; }
   g_multiTP = !g_multiTP;
}

void ToggleAutoSL()
{
   g_autoSLDollar = !g_autoSLDollar;
   if(g_autoSLDollar) { ReadInputs(); ApplyDollarSLToAll(); }
}

void StepLot(int dir)
{
   ReadInputs();
   double step = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), 0.01);
   g_lotSize = ClampLot(g_lotSize + dir * step);
   ObjectSetString(0, PFX+"EditLot", OBJPROP_TEXT, DoubleToString(g_lotSize, 2));
}

void RunAction(int a)
{
   switch(a)
   {
      case HK_BUY:          OpenTrade(1);                      break;
      case HK_SELL:         OpenTrade(-1);                     break;
      case HK_CLOSE_ALL:    DoCloseAll();                      break;
      case HK_CLOSE_PROFIT: DoCloseProfit();                   break;
      case HK_BREAKEVEN:    DoBreakEven();                     break;
      case HK_PARTIAL:      DoPartialClose();                  break;
      case HK_LOT_UP:       StepLot(1);                        break;
      case HK_LOT_DOWN:     StepLot(-1);                       break;
      case HK_RISK:         g_riskMode = !g_riskMode;          break;
      case HK_RR:           ToggleRR();                        break;
      case HK_MTP:          ToggleMTP();                       break;
      case HK_AUTO_SL:      ToggleAutoSL();                    break;
      case HK_AUTO_BE:      g_autoBE = !g_autoBE;              break;
      case HK_AVG_LINE:     g_showNetPrice = !g_showNetPrice;  break;
   }
}

void RefreshAll()
{
   DrawPanel();
   ProcessNetPriceLine();
   DrawLines();
}

//+------------------------------------------------------------------+
//|  HOTKEY DRAWER                                                   |
//+------------------------------------------------------------------+
void DeleteHotkeyDrawer()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string n = ObjectName(0, i);
      if(StringFind(n, "HK_") >= 0) ObjectDelete(0, n);
   }
}

void DrawHotkeyDrawer()
{
   if(!g_hkOpen) { DeleteHotkeyDrawer(); return; }

   const int X = 10, Y0 = 112, W = PANEL_W, H = 34 + 4 * 30 + 8;
   MakeRect(PFX+"HK_BG_G", X-1, Y0-1, W+2, H+2, CLR_BORDER, CLR_BORDER);
   MakeRect(PFX+"HK_BG",   X,   Y0,   W,   H,   CLR_BG,    CLR_BG);

   string hdr = (g_hkCapture >= 0)
      ? "⌨  PRESS the key combo for \"" + g_hkNames[g_hkCapture] + "\"  (Ctrl / Shift / Alt allowed — Esc cancels)"
      : "⌨  HOTKEYS — click a key box, then press the combo you want.  x = clear.  Saved automatically.";
   MakeLabel(PFX+"HK_Hdr", X + 12, Y0 + 10, hdr, (g_hkCapture >= 0) ? CLR_YELLOW : CLR_SOFT, 8);

   MakeRoundBtn(PFX+"BtnHKReset", X + W - 190, Y0 + 6, 84, 22, "CLEAR ALL", CLR_BTN_BG, CLR_RED, CLR_RED, 8,
                TT("", "Remove every assigned hotkey", ""));
   MakeRoundBtn(PFX+"BtnHKClose", X + W - 98, Y0 + 6, 84, 22, "CLOSE", CLR_BTN_BG, CLR_BTN_EDGE, CLR_SOFT, 8,
                TT("", "Hide this drawer", ""));

   const int colW = (W - 20) / 4;
   for(int i = 0; i < HK_N; i++)
   {
      int col = i % 4, row = i / 4;
      int x = X + 10 + col * colW;
      int y = Y0 + 36 + row * 30;
      string id = IntegerToString(i);

      MakeLabel(PFX+"HK_L"+id, x, y + 5, g_hkNames[i], CLR_SOFT, 8);

      bool cap = (g_hkCapture == i);
      string kt = cap ? "press key…" : (g_hk[i] > 0 ? KeyName(g_hk[i]) : "— not set —");
      color  ke = cap ? CLR_YELLOW : (g_hk[i] > 0 ? CLR_GREEN_DIM : CLR_BTN_EDGE);
      color  kc = cap ? CLR_YELLOW : (g_hk[i] > 0 ? CLR_GREEN : CLR_LABEL);
      MakeRoundBtn(PFX+"HK_B"+id, x + 84, y, 106, 22, kt, CLR_BTN_BG, ke, kc, 8,
                   TT("", "Click, then press the key combo for: " + g_hkNames[i], "Ctrl+Shift+B  /  F9  /  Alt+1"));
      MakeRoundBtn(PFX+"HK_X"+id, x + 194, y, 22, 22, "x", CLR_BTN_BG, CLR_BTN_EDGE, CLR_RED, 8,
                   TT("", "Clear hotkey for " + g_hkNames[i], ""));
   }
}

// Called while a key box is waiting for input
void HandleCapture(int key)
{
   if(key == 27) { g_hkCapture = -1; RefreshAll(); return; }                      // Esc = cancel
   if(key == 16 || key == 17 || key == 18 || key == 91 || key == 92) return;       // lone modifier
   int enc = key + 1000 * CurrentMods();

   for(int i = 0; i < HK_N; i++)                                                   // remove duplicates
      if(g_hk[i] == enc && i != g_hkCapture) { g_hk[i] = 0; SaveHK(i); }

   g_hk[g_hkCapture] = enc;
   SaveHK(g_hkCapture);
   g_hkCapture = -1;
   RefreshAll();
}

//+------------------------------------------------------------------+
//|  DRAW PANEL                                                      |
//+------------------------------------------------------------------+
void DrawPanel()
{
   int bc = 0, buy = 0, sell = 0;
   double pnl = GetOpenPnL(bc, buy, sell);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool hasPos = (bc > 0);
   color pClr = (pnl >= 0) ? CLR_GREEN : CLR_RED;

   const int X = 10, W = PANEL_W, BH = 24;
   const int Y1 = 10, H1 = 38, BY1 = Y1 + 7;
   const int Y2 = 52, H2 = 34, BY2 = Y2 + 5;

   MakeRect(PFX+"BG1_G", X-1, Y1-1, W+2, H1+2, CLR_BORDER, CLR_BORDER);
   MakeRect(PFX+"BG1",   X,   Y1,   W,   H1,   CLR_BG,     CLR_BG);
   MakeRect(PFX+"BG2_G", X-1, Y2-1, W+2, H2+2, CLR_BORDER, CLR_BORDER);
   MakeRect(PFX+"BG2",   X,   Y2,   W,   H2,   CLR_BG,     CLR_BG);

   // ══════════════ ROW 1 — TRADE ═══════════════════════════════
   int cx = X + 10;

   color led = (spread > MaxSpreadPoints) ? CLR_RED : (spread > MaxSpreadPoints * 0.5) ? CLR_YELLOW : CLR_GREEN;
   MakeLabel(PFX+"LED", cx, Y1 + 10, "●", led, 11, "Arial");
   ObjectSetString(0, PFX+"LED", OBJPROP_TOOLTIP,
      TT("", "Spread indicator", IntegerToString((int)spread) + " pts  (limit=" + IntegerToString(MaxSpreadPoints) + ")"));
   cx += 18;

   string ps = _Symbol + "  " + DoubleToString(bid, _Digits);
   if(hasPos) ps += "   " + ((pnl >= 0) ? "+" : "") + DoubleToString(pnl, 2) + "  [" + IntegerToString(buy) + "▲ " + IntegerToString(sell) + "▼]";
   MakeLabel(PFX+"Sym", cx, BY1 + 5, ps, hasPos ? pClr : CLR_BLUE, 9);
   cx += 235;
   MakeRect(PFX+"D1", cx, Y1 + 5, 1, H1 - 10, CLR_DIVIDER, CLR_DIVIDER); cx += 10;

   // ── LOT ──
   MakeLabel(PFX+"CapLot", cx, BY1 + 7, "LOT", CLR_LABEL, 7); cx += 26;
   MakeRoundBtn(PFX+"BtnLotDec", cx, BY1, 22, BH, "▼", CLR_BTN_BG, CLR_BTN_EDGE, CLR_SOFT, 8,
                TTK(HK_LOT_DOWN, "Decrease lot by one step", "0.02 → 0.01")); cx += 25;
   MakeEditOnce(PFX+"EditLot", cx, BY1, 52, BH, DoubleToString(DefaultLotSize, 2), 10,
                TT("", "Fixed lot size (ignored while RISK % is ON)", "0.01 micro | 0.10 mini | 1.00 standard"));
   SetEditEnabled(PFX+"EditLot", !g_riskMode); cx += 55;
   MakeRoundBtn(PFX+"BtnLotInc", cx, BY1, 22, BH, "▲", CLR_BTN_BG, CLR_BTN_EDGE, CLR_SOFT, 8,
                TTK(HK_LOT_UP, "Increase lot by one step", "0.01 → 0.02")); cx += 32;
   MakeRect(PFX+"D2", cx, Y1 + 5, 1, H1 - 10, CLR_DIVIDER, CLR_DIVIDER); cx += 10;

   // ── RISK % ──
   MakeToggle(PFX+"BtnRisk", cx, BY1, 66, BH, "RISK %", g_riskMode, CLR_TOGGLE_RISK, CLR_CYAN,
              TTK(HK_RISK, g_riskMode ? "Risk % ON — lot = risk$ ÷ (SL pips × pip value). Click to switch to fixed lot."
                                      : "Risk % OFF — click to size every trade from account risk",
                  "1% of $1000 = $10 risk; SL 20 pips → lot sized so a stop-out costs ~$10")); cx += 70;
   MakeEditOnce(PFX+"EditRisk", cx, BY1, 40, BH, DoubleToString(DefaultRiskPct, 2), 10,
                TT("", "Risk per trade in % of " + (RiskOnEquity ? "equity" : "balance"), "1.0 = 1%"));
   SetEditEnabled(PFX+"EditRisk", true); cx += 44;

   double calcLot = (g_slPips > 0.0) ? CalcRiskLot(g_slPips) : 0.0;
   string rl; color rc;
   if(g_riskMode) { rl = (calcLot > 0.0) ? "→ " + DoubleToString(calcLot, 2) + " lot" : "set SL pips"; rc = (calcLot > 0.0) ? CLR_CYAN : CLR_ORANGE; }
   else           { rl = "≈$" + DoubleToString(RiskMoney(), 2); rc = CLR_STAT_DIM; }
   MakeLabel(PFX+"RiskCalc", cx, BY1 + 6, rl, rc, 8);
   ObjectSetString(0, PFX+"RiskCalc", OBJPROP_TOOLTIP,
      g_riskMode ? "Lot that will be used on the next trade" : "Dollar amount of one risk unit at the current Risk %");
   cx += 66;
   MakeRect(PFX+"D3", cx, Y1 + 5, 1, H1 - 10, CLR_DIVIDER, CLR_DIVIDER); cx += 10;

   // ── SL pips ──
   MakeLabel(PFX+"CapSL", cx, BY1 + 7, "SL", CLR_RED, 7); cx += 16;
   MakeEditOnce(PFX+"EditSLPips", cx, BY1, 46, BH, "0", 10,
                TT("", "Stop-loss in pips on every new trade (0 = none). Needed for RISK % and RR 1:2.",
                   "20 = SL 20 pips from entry"));
   ObjectSetInteger(0, PFX+"EditSLPips", OBJPROP_BORDER_COLOR, CLR_RED);
   SetEditEnabled(PFX+"EditSLPips", true); cx += 50;
   MakeRect(PFX+"D4", cx, Y1 + 5, 1, H1 - 10, CLR_DIVIDER, CLR_DIVIDER); cx += 10;

   // ── TP ──
   bool tpOn = !g_rrMode;
   if(g_multiTP && !g_rrMode)
   {
      MakeLabel(PFX+"TPLbl", cx, BY1 + 7, "T1", CLR_YELLOW, 7); cx += 18;
      MakeEditOnce(PFX+"EditTPPips", cx, BY1, 42, BH, "0", 10,
                   TT("", "TP1 — first target in pips", "15: at +15 pips close " + DoubleToString(TP1ClosePct, 0) + "% and move SL to entry"));
      ObjectSetInteger(0, PFX+"EditTPPips", OBJPROP_BORDER_COLOR, CLR_YELLOW); cx += 46;
      MakeLabel(PFX+"DolLbl", cx, BY1 + 7, "T2", CLR_GREEN, 7); cx += 18;
      MakeEditOnce(PFX+"EditTPMoney", cx, BY1, 42, BH, "0", 10,
                   TT("", "TP2 — final target in pips (broker TP)", "30: remaining position closes at +30 pips"));
      ObjectSetInteger(0, PFX+"EditTPMoney", OBJPROP_BORDER_COLOR, CLR_GREEN); cx += 47;
   }
   else
   {
      MakeLabel(PFX+"TPLbl", cx, BY1 + 7, "TP", CLR_LABEL, 7); cx += 16;
      MakeEditOnce(PFX+"EditTPPips", cx, BY1, 42, BH, "0", 10,
                   TT("", g_rrMode ? "Not used — RR 1:2 sets targets from your SL" : "Take-profit in pips (0 = off)", "20 pips from entry"));
      ObjectSetInteger(0, PFX+"EditTPPips", OBJPROP_BORDER_COLOR, CLR_BORDER_LT); cx += 46;
      MakeLabel(PFX+"DolLbl", cx, BY1 + 7, "$", CLR_LABEL, 7); cx += 12;
      MakeEditOnce(PFX+"EditTPMoney", cx, BY1, 42, BH, "0", 10,
                   TT("", g_rrMode ? "Not used — RR 1:2 sets targets from your SL" : "Take-profit in $ (0 = off)", "5.00 = close at +$5.00"));
      ObjectSetInteger(0, PFX+"EditTPMoney", OBJPROP_BORDER_COLOR, CLR_BORDER_LT); cx += 47;
   }
   SetEditEnabled(PFX+"EditTPPips",  tpOn);
   SetEditEnabled(PFX+"EditTPMoney", tpOn);
   MakeRect(PFX+"D5", cx, Y1 + 5, 1, H1 - 10, CLR_DIVIDER, CLR_DIVIDER); cx += 10;

   // ── BUY / SELL ──
   string hint = g_riskMode ? "Lot from RISK % ÷ SL pips" : g_rrMode ? "Broker TP = 1:2 | TP1 split watched in code | Needs SL"
               : g_multiTP ? "Broker TP = T2 | T1 watched in code" : "Lot=" + DoubleToString(g_lotSize, 2) + "  TP=" + DoubleToString(g_tpPips, 0) + " pips";
   MakeRoundBtn(PFX+"BtnBuy",  cx, BY1, 62, BH, "▲ BUY",  CLR_BUY_BG,  CLR_BUY_EDGE,  CLR_WHITE, 9, TTK(HK_BUY,  "Open BUY at ASK",  hint)); cx += 66;
   MakeRoundBtn(PFX+"BtnSell", cx, BY1, 62, BH, "▼ SELL", CLR_SELL_BG, CLR_SELL_EDGE, CLR_WHITE, 9, TTK(HK_SELL, "Open SELL at BID", hint));

   // ══════════════ ROW 2 — MANAGE ══════════════════════════════
   cx = X + 10;
   MakeRoundBtn(PFX+"BtnClose", cx, BY2, 84, BH, "CLOSE ALL", CLR_BTN_BG, CLR_RED, CLR_RED, 8,
                TTK(HK_CLOSE_ALL, "Close ALL positions at market", "3 trades → all closed")); cx += 90;
   MakeRoundBtn(PFX+"BtnWin", cx, BY2, 78, BH, "CLOSE +", CLR_BTN_BG, CLR_GREEN_DIM, CLR_GREEN, 8,
                TTK(HK_CLOSE_PROFIT, "Close profitable positions only", "2 winners + 1 loser → 2 closed")); cx += 84;
   MakeRoundBtn(PFX+"BtnBE", cx, BY2, 50, BH, "B.E", CLR_BTN_BG, CLR_SOFT, CLR_WHITE, 8,
                TTK(HK_BREAKEVEN, "Move SL to entry on all positions", "Entry 1.3000, SL 1.2950 → SL 1.3000")); cx += 56;
   MakeRoundBtn(PFX+"BtnHalf", cx, BY2, 84, BH, "CLOSE " + DoubleToString(PartialClosePct, 0) + "%", CLR_BTN_BG, CLR_SOFT, CLR_SOFT, 8,
                TTK(HK_PARTIAL, "Close " + DoubleToString(PartialClosePct, 0) + "% of each position", "0.10 lot → 0.05 closed, 0.05 remains")); cx += 94;
   MakeRect(PFX+"D6", cx, Y2 + 5, 1, H2 - 10, CLR_DIVIDER, CLR_DIVIDER); cx += 10;

   MakeToggle(PFX+"BtnRR", cx, BY2, 68, BH, "RR 1:2", g_rrMode, CLR_TOGGLE_RR, CLR_RR_ON,
              TTK(HK_RR, g_rrMode ? "RR 1:2 ON — TP1 = 1:1 (close 50% + BE), TP2 = 1:2 (broker TP). Click to disable."
                                  : "RR 1:2 OFF — click to auto-split every trade at 1:1 and 1:2",
                  "Needs an SL on each trade (SL pips box, AUTO $SL, or set manually)")); cx += 74;
   MakeToggle(PFX+"BtnMTP", cx, BY2, 56, BH, "MTP", g_multiTP && !g_rrMode, CLR_TOGGLE_MTP, CLR_ORANGE,
              TTK(HK_MTP, (g_multiTP && !g_rrMode) ? "Multi-TP ON — click to disable" : "Multi-TP OFF — click to enable",
                  "T1 closes part + BE | T2 = final target (disabled while RR is ON)")); cx += 62;
   MakeToggle(PFX+"BtnAutoSL", cx, BY2, 82, BH, "AUTO $SL", g_autoSLDollar, CLR_TOGGLE_SL, CLR_ORANGE,
              TTK(HK_AUTO_SL, g_autoSLDollar ? "Auto $SL ON — new trades get a fixed-dollar SL. Click to disable."
                                             : "Auto $SL OFF — click to apply the $ SL to open trades and every new trade",
                  "Pip distance is calculated so one stop-out costs the $ amount")); cx += 86;
   MakeEditOnce(PFX+"EditSLDollar", cx, BY2, 46, BH, DoubleToString(AutoSLDollar, 2), 9,
                TT("", "Dollar risk used by AUTO $SL", "5.00 = stop-out costs ~$5"));
   SetEditEnabled(PFX+"EditSLDollar", true); cx += 52;
   MakeToggle(PFX+"BtnAutoBE", cx, BY2, 78, BH, "AUTO B.E", g_autoBE, CLR_TOGGLE_ON, CLR_GREEN,
              TTK(HK_AUTO_BE, "Auto break-even every tick", "At +" + DoubleToString(AutoBETriggerPips, 0) + " pips SL moves to entry +" +
                  DoubleToString(AutoBEBufferPips, 0) + " pips")); cx += 84;
   MakeToggle(PFX+"BtnNetViz", cx, BY2, 78, BH, "AVG LINE", g_showNetPrice, CLR_TOGGLE_ON, CLR_CYAN,
              TTK(HK_AVG_LINE, "Average entry price line on chart", "Buys at 1.3000 & 1.3010 → dashed line at 1.3005")); cx += 84;
   MakeRect(PFX+"D7", cx, Y2 + 5, 1, H2 - 10, CLR_DIVIDER, CLR_DIVIDER); cx += 10;

   MakeToggle(PFX+"BtnKeys", cx, BY2, 84, BH, "⌨ KEYS", g_hkOpen, C'60,60,20', CLR_YELLOW,
              TT("", "Open / close the hotkey settings", "Assign a key to every button"));

   // ══════════════ ROW 3 — STATS ═══════════════════════════════
   double realizedPnL = 0.0;
   int wins = 0, losses = 0;
   GetDailyStats(realizedPnL, wins, losses);
   DrawStatsRow(realizedPnL, pnl, wins, losses);

   // ══════════════ HOTKEY DRAWER ═══════════════════════════════
   DrawHotkeyDrawer();

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//|  LIFECYCLE                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_rrMode) ProcessRRMode();
   else if(g_multiTP) ProcessMultiTP();
   if(g_autoBE) ProcessAutoBE();
}

void OnTimer()
{
   DrawPanel();
   ProcessNetPriceLine();
   ScanShootingStarsNow();
   DrawLines();
}

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_lotSize   = DefaultLotSize;
   g_riskPct   = DefaultRiskPct;
   g_autoSLAmt = AutoSLDollar;

   g_btn[HK_BUY]          = PFX+"BtnBuy";
   g_btn[HK_SELL]         = PFX+"BtnSell";
   g_btn[HK_CLOSE_ALL]    = PFX+"BtnClose";
   g_btn[HK_CLOSE_PROFIT] = PFX+"BtnWin";
   g_btn[HK_BREAKEVEN]    = PFX+"BtnBE";
   g_btn[HK_PARTIAL]      = PFX+"BtnHalf";
   g_btn[HK_LOT_UP]       = PFX+"BtnLotInc";
   g_btn[HK_LOT_DOWN]     = PFX+"BtnLotDec";
   g_btn[HK_RISK]         = PFX+"BtnRisk";
   g_btn[HK_RR]           = PFX+"BtnRR";
   g_btn[HK_MTP]          = PFX+"BtnMTP";
   g_btn[HK_AUTO_SL]      = PFX+"BtnAutoSL";
   g_btn[HK_AUTO_BE]      = PFX+"BtnAutoBE";
   g_btn[HK_AVG_LINE]     = PFX+"BtnNetViz";

   LoadHotkeys();
   ObjectsDeleteAll(0, PFX);
   EventSetMillisecondTimer(500);
   DrawPanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
   ObjectsDeleteAll(0, LINE_PFX);
}

//+------------------------------------------------------------------+
//|  EVENTS                                                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // ── Clicks ───────────────────────────────────────────────────
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      g_editing = (StringFind(sparam, PFX+"Edit") == 0);

      string hkB = PFX+"HK_B", hkX = PFX+"HK_X";

      // Hotkey drawer controls
      if(StringFind(sparam, hkB) == 0)
      {
         g_hkCapture = (int)StringToInteger(StringSubstr(sparam, StringLen(hkB)));
         if(g_hkCapture < 0 || g_hkCapture >= HK_N) g_hkCapture = -1;
         DrawPanel();
         return;
      }
      g_hkCapture = -1;   // clicking anywhere else cancels a pending capture

      if(StringFind(sparam, hkX) == 0)
      {
         int a = (int)StringToInteger(StringSubstr(sparam, StringLen(hkX)));
         if(a >= 0 && a < HK_N) { g_hk[a] = 0; SaveHK(a); }
         RefreshAll();
         return;
      }
      if(sparam == PFX+"BtnHKReset")
      {
         for(int i = 0; i < HK_N; i++) { g_hk[i] = 0; SaveHK(i); }
         RefreshAll();
         return;
      }
      if(sparam == PFX+"BtnHKClose") { g_hkOpen = false; RefreshAll(); return; }
      if(sparam == PFX+"BtnKeys")    { g_hkOpen = !g_hkOpen; RefreshAll(); return; }

      // Trading / mode buttons
      for(int a = 0; a < HK_N; a++)
         if(sparam == g_btn[a])
         {
            RunAction(a);
            RefreshAll();
            return;
         }
      return;
   }

   // ── Input box finished editing ───────────────────────────────
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      g_editing = false;
      if(StringFind(sparam, PFX+"Edit") == 0) { ReadInputs(); RefreshAll(); }
      return;
   }

   // ── Keyboard ─────────────────────────────────────────────────
   if(id == CHARTEVENT_KEYDOWN)
   {
      int key = (int)lparam;

      if(g_hkCapture >= 0) { HandleCapture(key); return; }
      if(g_editing) return;                                      // typing in an input box
      if(key == 16 || key == 17 || key == 18 || key == 91 || key == 92) return;

      int enc = key + 1000 * CurrentMods();
      for(int a = 0; a < HK_N; a++)
         if(g_hk[a] > 0 && g_hk[a] == enc)
         {
            RunAction(a);
            RefreshAll();
            return;
         }
   }
}
//+------------------------------------------------------------------+
