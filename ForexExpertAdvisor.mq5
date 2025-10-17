//+------------------------------------------------------------------+
//|                                          ForexExpertAdvisor.mq5 |
//|                                    کد نویسی شده برای معاملات فارکس |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Forex Expert Advisor"
#property link      ""
#property version   "1.00"
#property strict

//--- شناسه‌های ورودی
input group "=== تنظیمات استراتژی ==="
input int      FastMA_Period = 12;           // دوره میانگین متحرک سریع
input int      SlowMA_Period = 26;           // دوره میانگین متحرک کند
input ENUM_MA_METHOD MA_Method = MODE_EMA;   // روش محاسبه میانگین متحرک
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE; // قیمت اعمالی

input group "=== مدیریت ریسک ==="
input double   LotSize = 0.1;                // اندازه لات
input bool     UseAutoLot = true;            // استفاده از لات خودکار
input double   RiskPercent = 2.0;            // درصد ریسک از سرمایه
input int      StopLoss = 50;                // حد ضرر (پیپ)
input int      TakeProfit = 100;             // حد سود (پیپ)
input int      TrailingStop = 30;            // توقف دنباله‌دار (پیپ)

input group "=== تنظیمات زمانی ==="
input int      StartHour = 8;                // ساعت شروع معاملات
input int      EndHour = 18;                 // ساعت پایان معاملات
input bool     TradeOnFriday = false;        // معامله در روز جمعه

input group "=== تنظیمات عمومی ==="
input int      MagicNumber = 12345;          // شماره جادویی
input string   TradeComment = "ForexEA";     // کامنت معاملات
input int      Slippage = 3;                 // لغزش قیمت

//--- متغیرهای سراسری
int fastMA_handle, slowMA_handle;
double fastMA[], slowMA[];
datetime lastBarTime;
bool tradingAllowed = true;

//+------------------------------------------------------------------+
//| تابع اولیه‌سازی                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- ایجاد هندل‌های اندیکاتور
   fastMA_handle = iMA(_Symbol, _Period, FastMA_Period, 0, MA_Method, MA_Price);
   slowMA_handle = iMA(_Symbol, _Period, SlowMA_Period, 0, MA_Method, MA_Price);
   
   if(fastMA_handle == INVALID_HANDLE || slowMA_handle == INVALID_HANDLE)
   {
      Print("خطا در ایجاد اندیکاتورها");
      return(INIT_FAILED);
   }
   
   //--- تنظیم آرایه‌ها
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   
   Print("Expert Advisor راه‌اندازی شد - نماد: ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع پاک‌سازی                                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- آزادسازی هندل‌ها
   IndicatorRelease(fastMA_handle);
   IndicatorRelease(slowMA_handle);
   
   Print("Expert Advisor متوقف شد");
}

//+------------------------------------------------------------------+
//| تابع اصلی تیک                                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- بررسی کندل جدید
   if(!IsNewBar()) return;
   
   //--- بررسی مجوز معاملات
   if(!IsTradingAllowed()) return;
   
   //--- به‌روزرسانی اندیکاتورها
   if(!UpdateIndicators()) return;
   
   //--- مدیریت پوزیشن‌های باز
   ManageOpenPositions();
   
   //--- بررسی سیگنال‌های معاملاتی
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
//| بررسی مجوز معاملات                                                |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   //--- بررسی ساعات معاملاتی
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour < StartHour || dt.hour >= EndHour)
      return false;
   
   //--- بررسی روز جمعه
   if(!TradeOnFriday && dt.day_of_week == 5)
      return false;
   
   //--- بررسی وضعیت بازار
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| به‌روزرسانی اندیکاتورها                                           |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   //--- کپی کردن مقادیر اندیکاتور
   if(CopyBuffer(fastMA_handle, 0, 0, 3, fastMA) < 3) return false;
   if(CopyBuffer(slowMA_handle, 0, 0, 3, slowMA) < 3) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| بررسی سیگنال‌های معاملاتی                                          |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
   //--- بررسی وجود پوزیشن باز
   if(PositionsTotal() > 0) return;
   
   //--- سیگنال خرید: تقاطع صعودی
   if(fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2])
   {
      OpenPosition(ORDER_TYPE_BUY);
   }
   //--- سیگنال فروش: تقاطع نزولی
   else if(fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2])
   {
      OpenPosition(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| باز کردن پوزیشن                                                   |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double price, sl, tp;
   double lotSize = CalculateLotSize();
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = StopLoss > 0 ? price - StopLoss * _Point * 10 : 0;
      tp = TakeProfit > 0 ? price + TakeProfit * _Point * 10 : 0;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = StopLoss > 0 ? price + StopLoss * _Point * 10 : 0;
      tp = TakeProfit > 0 ? price - TakeProfit * _Point * 10 : 0;
   }
   
   //--- ایجاد درخواست معامله
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   
   //--- ارسال درخواست
   if(OrderSend(request, result))
   {
      string direction = (orderType == ORDER_TYPE_BUY) ? "خرید" : "فروش";
      Print("پوزیشن ", direction, " باز شد - قیمت: ", price, " حجم: ", lotSize);
   }
   else
   {
      Print("خطا در باز کردن پوزیشن: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| محاسبه اندازه لات                                                 |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!UseAutoLot)
      return LotSize;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double stopLossPoints = StopLoss * 10; // تبدیل پیپ به پوینت
   
   if(stopLossPoints == 0 || tickValue == 0)
      return LotSize;
   
   double calculatedLot = riskAmount / (stopLossPoints * tickValue);
   
   //--- اعمال حداقل و حداکثر لات
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLot = MathMax(calculatedLot, minLot);
   calculatedLot = MathMin(calculatedLot, maxLot);
   calculatedLot = NormalizeDouble(calculatedLot / lotStep, 0) * lotStep;
   
   return calculatedLot;
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
      
      //--- اعمال توقف دنباله‌دار
      if(TrailingStop > 0)
         ApplyTrailingStop(ticket, posType);
   }
}

//+------------------------------------------------------------------+
//| اعمال توقف دنباله‌دار                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, ENUM_POSITION_TYPE posType)
{
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double newSL = 0;
   
   if(posType == POSITION_TYPE_BUY)
   {
      newSL = currentPrice - TrailingStop * _Point * 10;
      if(newSL > currentSL && newSL > openPrice)
      {
         ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
   }
   else
   {
      newSL = currentPrice + TrailingStop * _Point * 10;
      if((currentSL == 0 || newSL < currentSL) && newSL < openPrice)
      {
         ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
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
   
   if(OrderSend(request, result))
   {
      Print("پوزیشن تغییر یافت - SL جدید: ", sl);
   }
}

//+------------------------------------------------------------------+
//| نمایش اطلاعات روی چارت                                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 32) // فاصله
      {
         tradingAllowed = !tradingAllowed;
         string status = tradingAllowed ? "فعال" : "غیرفعال";
         Print("وضعیت معاملات: ", status);
      }
   }
}