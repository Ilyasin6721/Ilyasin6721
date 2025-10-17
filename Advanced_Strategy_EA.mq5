//+------------------------------------------------------------------+
//|                                       Advanced_Strategy_EA.mq5 |
//|                                   Expert Advisor پیشرفته فارکس |
//|                           شامل RSI، MACD و استراتژی‌های متنوع     |
//+------------------------------------------------------------------+
#property copyright "Advanced Forex EA"
#property version   "2.00"
#property strict

//--- شناسه‌های ورودی
input group "=== انتخاب استراتژی ==="
enum STRATEGY_TYPE
{
   STRATEGY_MA_CROSS,     // تقاطع میانگین متحرک
   STRATEGY_RSI_REVERSAL, // بازگشت RSI
   STRATEGY_MACD_SIGNAL,  // سیگنال MACD
   STRATEGY_BREAKOUT,     // شکست سطوح
   STRATEGY_COMBINED      // ترکیبی
};
input STRATEGY_TYPE SelectedStrategy = STRATEGY_COMBINED; // استراتژی انتخابی

input group "=== تنظیمات میانگین متحرک ==="
input int      MA_Fast = 12;                    // میانگین سریع
input int      MA_Slow = 26;                    // میانگین کند
input ENUM_MA_METHOD MA_Method = MODE_EMA;      // روش محاسبه

input group "=== تنظیمات RSI ==="
input int      RSI_Period = 14;                // دوره RSI
input double   RSI_Oversold = 30;              // سطح فروش بیش از حد
input double   RSI_Overbought = 70;            // سطح خرید بیش از حد

input group "=== تنظیمات MACD ==="
input int      MACD_Fast = 12;                 // EMA سریع MACD
input int      MACD_Slow = 26;                 // EMA کند MACD
input int      MACD_Signal = 9;                // خط سیگنال

input group "=== تنظیمات شکست ==="
input int      Breakout_Period = 20;           // دوره محاسبه سطوح
input double   Breakout_Buffer = 5;            // بافر شکست (پیپ)

input group "=== مدیریت ریسک پیشرفته ==="
input double   BaseLotSize = 0.1;              // لات پایه
input bool     UseMoneyManagement = true;       // مدیریت پول
input double   RiskPercentage = 2.0;           // درصد ریسک
input double   MaxRiskPerDay = 5.0;            // حداکثر ریسک روزانه
input int      MaxPositions = 3;               // حداکثر پوزیشن همزمان
input bool     UseMarginCheck = true;          // بررسی مارژین

input group "=== تنظیمات خروج ==="
input int      StopLossPips = 50;              // حد ضرر (پیپ)
input int      TakeProfitPips = 100;           // حد سود (پیپ)
input bool     UseTrailingStop = true;         // توقف دنباله‌دار
input int      TrailingStopPips = 30;          // فاصله توقف دنباله‌دار
input bool     UseBreakEven = true;            // سر به سر
input int      BreakEvenPips = 20;             // فاصله سر به سر

input group "=== فیلترهای معاملاتی ==="
input bool     UseTimeFilter = true;           // فیلتر زمانی
input int      StartHour = 8;                  // ساعت شروع
input int      EndHour = 18;                   // ساعت پایان
input bool     UseSpreadFilter = true;         // فیلتر اسپرد
input double   MaxSpread = 3.0;                // حداکثر اسپرد (پیپ)
input bool     UseVolatilityFilter = false;    // فیلتر نوسانات
input double   MinATR = 10;                    // حداقل ATR (پیپ)

input group "=== تنظیمات عمومی ==="
input int      MagicNumber = 54321;            // شماره جادویی
input string   CommentPrefix = "AdvancedEA";   // پیشوند کامنت

//--- متغیرهای سراسری
int ma_fast_handle, ma_slow_handle, rsi_handle, macd_handle, atr_handle;
double ma_fast[], ma_slow[], rsi[], macd_main[], macd_signal[], atr[];
datetime lastBarTime;
double dailyLoss = 0;
datetime lastResetDate;

//+------------------------------------------------------------------+
//| تابع اولیه‌سازی                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- ایجاد هندل‌های اندیکاتور
   ma_fast_handle = iMA(_Symbol, _Period, MA_Fast, 0, MA_Method, PRICE_CLOSE);
   ma_slow_handle = iMA(_Symbol, _Period, MA_Slow, 0, MA_Method, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   macd_handle = iMACD(_Symbol, _Period, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, 14);
   
   //--- بررسی هندل‌ها
   if(ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE ||
      rsi_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
   {
      Print("خطا در ایجاد اندیکاتورها");
      return(INIT_FAILED);
   }
   
   //--- تنظیم آرایه‌ها
   ArraySetAsSeries(ma_fast, true);
   ArraySetAsSeries(ma_slow, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macd_main, true);
   ArraySetAsSeries(macd_signal, true);
   ArraySetAsSeries(atr, true);
   
   //--- تنظیم اولیه
   lastResetDate = TimeCurrent();
   
   Print("Expert Advisor پیشرفته راه‌اندازی شد");
   Print("استراتژی انتخابی: ", EnumToString(SelectedStrategy));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع اصلی تیک                                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- بررسی کندل جدید
   if(!IsNewBar()) return;
   
   //--- ریست کردن ضرر روزانه
   ResetDailyLoss();
   
   //--- بررسی فیلترها
   if(!PassFilters()) return;
   
   //--- به‌روزرسانی اندیکاتورها
   if(!UpdateIndicators()) return;
   
   //--- مدیریت پوزیشن‌های باز
   ManageOpenPositions();
   
   //--- بررسی سیگنال‌ها بر اساس استراتژی انتخابی
   CheckTradingSignals();
}

//+------------------------------------------------------------------+
//| بررسی کندل جدید                                                   |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ریست ضرر روزانه                                                   |
//+------------------------------------------------------------------+
void ResetDailyLoss()
{
   MqlDateTime dt_current, dt_last;
   TimeToStruct(TimeCurrent(), dt_current);
   TimeToStruct(lastResetDate, dt_last);
   
   if(dt_current.day != dt_last.day)
   {
      dailyLoss = 0;
      lastResetDate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| بررسی فیلترها                                                     |
//+------------------------------------------------------------------+
bool PassFilters()
{
   //--- فیلتر زمانی
   if(UseTimeFilter)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour < StartHour || dt.hour >= EndHour)
         return false;
   }
   
   //--- فیلتر اسپرد
   if(UseSpreadFilter)
   {
      double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point / 10;
      if(spread > MaxSpread)
         return false;
   }
   
   //--- فیلتر نوسانات
   if(UseVolatilityFilter && CopyBuffer(atr_handle, 0, 1, 1, atr) == 1)
   {
      double currentATR = atr[0] / _Point / 10;
      if(currentATR < MinATR)
         return false;
   }
   
   //--- فیلتر ضرر روزانه
   if(dailyLoss >= MaxRiskPerDay)
   {
      Print("حداکثر ضرر روزانه رسیده: ", dailyLoss, "%");
      return false;
   }
   
   //--- فیلتر تعداد پوزیشن
   if(CountMyPositions() >= MaxPositions)
      return false;
   
   //--- فیلتر مارژین
   if(UseMarginCheck)
   {
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double requiredMargin = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL) * BaseLotSize;
      if(freeMargin < requiredMargin * 2) // حداقل 2 برابر مارژین مورد نیاز
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| به‌روزرسانی اندیکاتورها                                           |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   if(CopyBuffer(ma_fast_handle, 0, 0, 3, ma_fast) < 3) return false;
   if(CopyBuffer(ma_slow_handle, 0, 0, 3, ma_slow) < 3) return false;
   if(CopyBuffer(rsi_handle, 0, 0, 3, rsi) < 3) return false;
   if(CopyBuffer(macd_handle, MAIN_LINE, 0, 3, macd_main) < 3) return false;
   if(CopyBuffer(macd_handle, SIGNAL_LINE, 0, 3, macd_signal) < 3) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| بررسی سیگنال‌های معاملاتی                                          |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
   int signal = 0; // 0: هیچ، 1: خرید، -1: فروش
   
   switch(SelectedStrategy)
   {
      case STRATEGY_MA_CROSS:
         signal = GetMACrossSignal();
         break;
      case STRATEGY_RSI_REVERSAL:
         signal = GetRSISignal();
         break;
      case STRATEGY_MACD_SIGNAL:
         signal = GetMACDSignal();
         break;
      case STRATEGY_BREAKOUT:
         signal = GetBreakoutSignal();
         break;
      case STRATEGY_COMBINED:
         signal = GetCombinedSignal();
         break;
   }
   
   if(signal == 1)
      OpenPosition(ORDER_TYPE_BUY);
   else if(signal == -1)
      OpenPosition(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| سیگنال تقاطع میانگین متحرک                                        |
//+------------------------------------------------------------------+
int GetMACrossSignal()
{
   if(ma_fast[1] > ma_slow[1] && ma_fast[2] <= ma_slow[2])
      return 1; // خرید
   else if(ma_fast[1] < ma_slow[1] && ma_fast[2] >= ma_slow[2])
      return -1; // فروش
   
   return 0;
}

//+------------------------------------------------------------------+
//| سیگنال RSI                                                       |
//+------------------------------------------------------------------+
int GetRSISignal()
{
   if(rsi[1] < RSI_Oversold && rsi[2] >= RSI_Oversold)
      return 1; // خرید
   else if(rsi[1] > RSI_Overbought && rsi[2] <= RSI_Overbought)
      return -1; // فروش
   
   return 0;
}

//+------------------------------------------------------------------+
//| سیگنال MACD                                                      |
//+------------------------------------------------------------------+
int GetMACDSignal()
{
   if(macd_main[1] > macd_signal[1] && macd_main[2] <= macd_signal[2] && macd_main[1] < 0)
      return 1; // خرید
   else if(macd_main[1] < macd_signal[1] && macd_main[2] >= macd_signal[2] && macd_main[1] > 0)
      return -1; // فروش
   
   return 0;
}

//+------------------------------------------------------------------+
//| سیگنال شکست                                                      |
//+------------------------------------------------------------------+
int GetBreakoutSignal()
{
   double high = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, Breakout_Period, 1));
   double low = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, Breakout_Period, 1));
   double currentPrice = iClose(_Symbol, _Period, 0);
   
   if(currentPrice > high + Breakout_Buffer * _Point * 10)
      return 1; // خرید
   else if(currentPrice < low - Breakout_Buffer * _Point * 10)
      return -1; // فروش
   
   return 0;
}

//+------------------------------------------------------------------+
//| سیگنال ترکیبی                                                     |
//+------------------------------------------------------------------+
int GetCombinedSignal()
{
   int maSignal = GetMACrossSignal();
   int rsiSignal = GetRSISignal();
   int macdSignal = GetMACDSignal();
   
   // حداقل 2 سیگنال موافق
   int buySignals = (maSignal == 1 ? 1 : 0) + (rsiSignal == 1 ? 1 : 0) + (macdSignal == 1 ? 1 : 0);
   int sellSignals = (maSignal == -1 ? 1 : 0) + (rsiSignal == -1 ? 1 : 0) + (macdSignal == -1 ? 1 : 0);
   
   if(buySignals >= 2)
      return 1;
   else if(sellSignals >= 2)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| باز کردن پوزیشن                                                   |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double price, sl, tp;
   double lotSize = CalculateOptimalLotSize();
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = StopLossPips > 0 ? price - StopLossPips * _Point * 10 : 0;
      tp = TakeProfitPips > 0 ? price + TakeProfitPips * _Point * 10 : 0;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = StopLossPips > 0 ? price + StopLossPips * _Point * 10 : 0;
      tp = TakeProfitPips > 0 ? price - TakeProfitPips * _Point * 10 : 0;
   }
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.magic = MagicNumber;
   request.comment = CommentPrefix + "_" + EnumToString(SelectedStrategy);
   
   if(OrderSend(request, result))
   {
      Print("پوزیشن باز شد: ", (orderType == ORDER_TYPE_BUY ? "خرید" : "فروش"), 
            " حجم: ", lotSize, " قیمت: ", price);
   }
}

//+------------------------------------------------------------------+
//| محاسبه اندازه لات بهینه                                           |
//+------------------------------------------------------------------+
double CalculateOptimalLotSize()
{
   if(!UseMoneyManagement)
      return BaseLotSize;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercentage / 100.0;
   double stopLossPoints = StopLossPips * 10;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(stopLossPoints == 0 || tickValue == 0)
      return BaseLotSize;
   
   double calculatedLot = riskAmount / (stopLossPoints * tickValue);
   
   // اعمال محدودیت‌ها
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLot = MathMax(calculatedLot, minLot);
   calculatedLot = MathMin(calculatedLot, maxLot);
   calculatedLot = NormalizeDouble(calculatedLot / lotStep, 0) * lotStep;
   
   return calculatedLot;
}

//+------------------------------------------------------------------+
//| شمارش پوزیشن‌های من                                               |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| مدیریت پوزیشن‌های باز                                             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      
      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      //--- سر به سر
      if(UseBreakEven)
         ApplyBreakEven(ticket, posType, openPrice, currentPrice, currentSL, currentTP);
      
      //--- توقف دنباله‌دار
      if(UseTrailingStop)
         ApplyTrailingStop(ticket, posType, currentPrice, currentSL, currentTP);
   }
}

//+------------------------------------------------------------------+
//| اعمال سر به سر                                                    |
//+------------------------------------------------------------------+
void ApplyBreakEven(ulong ticket, ENUM_POSITION_TYPE posType, double openPrice, 
                   double currentPrice, double currentSL, double currentTP)
{
   double breakEvenPrice = 0;
   bool shouldModify = false;
   
   if(posType == POSITION_TYPE_BUY)
   {
      if(currentPrice >= openPrice + BreakEvenPips * _Point * 10 && 
         (currentSL == 0 || currentSL < openPrice))
      {
         breakEvenPrice = openPrice + 1 * _Point * 10; // 1 پیپ سود
         shouldModify = true;
      }
   }
   else
   {
      if(currentPrice <= openPrice - BreakEvenPips * _Point * 10 && 
         (currentSL == 0 || currentSL > openPrice))
      {
         breakEvenPrice = openPrice - 1 * _Point * 10; // 1 پیپ سود
         shouldModify = true;
      }
   }
   
   if(shouldModify)
   {
      ModifyPosition(ticket, breakEvenPrice, currentTP);
      Print("سر به سر اعمال شد برای تیکت: ", ticket);
   }
}

//+------------------------------------------------------------------+
//| اعمال توقف دنباله‌دار                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, ENUM_POSITION_TYPE posType, 
                      double currentPrice, double currentSL, double currentTP)
{
   double newSL = 0;
   bool shouldModify = false;
   
   if(posType == POSITION_TYPE_BUY)
   {
      newSL = currentPrice - TrailingStopPips * _Point * 10;
      if(newSL > currentSL)
         shouldModify = true;
   }
   else
   {
      newSL = currentPrice + TrailingStopPips * _Point * 10;
      if(currentSL == 0 || newSL < currentSL)
         shouldModify = true;
   }
   
   if(shouldModify)
   {
      ModifyPosition(ticket, newSL, currentTP);
   }
}

//+------------------------------------------------------------------+
//| تغییر پوزیشن                                                      |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = sl;
   request.tp = tp;
   
   OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| پاک‌سازی                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ma_fast_handle);
   IndicatorRelease(ma_slow_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(macd_handle);
   IndicatorRelease(atr_handle);
}