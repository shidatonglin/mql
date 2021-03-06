// ------------------------------------------------------------------------------------------------
// Copyright ?2011, www.lifesdream.org
// http://www.lifesdream.org
// ------------------------------------------------------------------------------------------------
#include <stdlib.mqh>
#include <stderror.mqh> 
#property copyright "Copyright ?2011, www.lifesdream.org"
#property link "http://www.lifesdream.org"
//#include <log.mq4>

// V1.1 FIx bugs when close order. Buys>1--->Buys>0.
//      Add logic to caculate how many candles over EMA21 and EMA50.
//      Add logic to caculate how many the red or green candle has continue. 
//      Set MA parameter as input parameter, so user can input.
//      Remove parameter nolonger use.

// V1.2 Add check_third_candle_for_open and check_price_over_MA
//      This two paramater will be used in caculate signal.

// V1.3 Add stopelose in case of ea not running or network issues
//      Check the validation of sl

// V1.4 Add CCI signal   
//      CC1-14 buy:price close over cci 100, close buy price cross 100
//             sell: price close below -100, close sell price cross -100

// V1.5 Gold Renko size 120 21MA cross 
/*
        My manual renko strategy: If the prices 2 bricks are above the MA buy trades . 
        If the prices 2 brick are below the MA sell trades . 
        If the prices 1 bricks are above or below the MA exit open trade. 
        I use GOLD. EMA 21 and 12 pip renko bricks. 2 bricks after breakeven. 
        http://www.forexfactory.com/showthread.php?p=8234586#post8234586
*/ 

// V1.6 Each renko bar create a order
        
/*        
  My version has a few other features that could be useful in your next update.
  1.Gap detection between the EMA's to further filter out sideways action.
  2.Check spreads are less then X before placing the trade.. (I got smashed by a news release as I left EA running.. so added this)
  3.Count minutes between the last two closed bars. (I use this for an extra entry to try catch volatile conditions.
   ie If 2x last bars are same color and formed in less then 2 minutes place trade.)      
           
   int Gap = MathAbs(NormalizeDouble(EMA1-EMA2,Digits)/Point);
   int Spread = MathAbs(NormalizeDouble(Bid-Ask,Digits)/Point);
    
   int bar1 = (ulong)datetime(Time[1]);
   int bar2 = (ulong)datetime(Time[2]);
   int Mins = MathAbs((bar1-bar2)/60);
   
   string bar1,bar2,bar3;
if(iClose(NULL,0,1)<iOpen(NULL,0,1)){bar1="red";}else{bar1="green";}
if(iClose(NULL,0,2)<iOpen(NULL,0,2)){bar2="red";}else{bar2="green";}
if(iClose(NULL,0,3)<iOpen(NULL,0,3)){bar3="red";}else{bar3="green";}

if((bar3=="green")&&(bar2=="green")&&(bar1=="red")){
//more magic here
}

My question is, what is the definition of a fast building Renko brick ? 1 second / pip, 30 seconds / pip ?
 I don't know what time is considered to be fast.
Depending on your brick size, I mainly look at 5pip bricks as I'm working with spread around 1pip.. 
I found bricks < 5 minutes usually have momentum.


*/

// V1.7 Fix buys about useGoldEMA 


/* More feature in futher

1. BreakEven and trainling stop
2. Let user to indicate only buy or only sell
3.    
 
// V1.8 Add option for exit order


// V1.9 Add restriction for entry order
// If the EMA angle follow in -4 ~ 4, the price should break the last high or last low to open a order


// V2.0 Should automatically choose exit method according to the ma angle.
   Fix bugs about sl when using gold
   Can not set useMaExit and check price over ma together in some seinario.
   Fix bugs about iHighest and iLowest

// V2.1 Add sma channel entry and exit method

*/

// ------------------------------------------------------------------------------------------------
// VARIABLES EXTERNAS
// ------------------------------------------------------------------------------------------------
#define buy 1
#define sell 2
extern int magic = 14709;
// Configuration
extern string CommonSettings = "---------------------------------------------";
extern int user_slippage = 2; 
extern int user_tp = 30;
extern int user_sl = 30;
extern int use_tp_sl = 0;// Can only be 0 or 1
extern double profit_lock = 0.60;
extern string MoneyManagementSettings = "---------------------------------------------";
// Money Management
extern int money_management = 0;
extern double min_lots = 0.01;
extern int risk=5;
extern int progression = 0; // 0=none | 1:ascending | 2:martingale
// Indicator
extern string IndicatorSettings = "---------------------------------------------";
//extern int ma_mode=1; // Optimization
//extern double ma_period=35; // Optimization
extern int shift = 1;

extern bool check_third_candle_for_open=true;
extern bool check_price_over_MA = true;
extern int mafast_period=21;
extern int maslow_period=50;
extern int max_candle_check_for_open = 3;
input ENUM_MA_METHOD MA_Method=MODE_EMA;
input ENUM_APPLIED_PRICE APPLIED_PRICE=PRICE_CLOSE;

extern bool useCCI = false;
extern int cci_period = 14;
extern int cci_applied_price = PRICE_TYPICAL;
extern int cci_shift = 1;
extern int cci_level = 100;

extern bool useGoldEMA = false;
extern int goldEAM_period = 50;
extern bool useBreakEven = true;
extern int breakEvenPips = 150;
extern double TrailingStop = 0;

extern bool useMaExit = false;
extern bool useReverseCandleExit = true;
extern int numberOfCandleToExit = 2;

extern bool useMAAngleRestriction = true;
extern int MAAnglePeriod = 50;
extern int MaThreshold = 4;
extern bool debugMode = true;
extern int minProfit = 3;

extern bool useMAChannel = false;

extern bool useDynamicExit = false;

extern int StopLoss = 60;
extern bool useMaSL = false;
extern bool useLastLowHighAsSL = false;
extern int candleNumberSL = 0;

extern bool tradeUnderRestriction = false;

enum maTypes
{
   ma_sma,  // Simple moving average
   ma_ema,  // Exponential moving average
   ma_smma, // Smoothed moving average
   ma_lwma, // Linear weighted moving average
   ma_lsma  // Linear regression value (lsma)
};

enum MA_ANGLE_SIG
{
   angle_none = 0,
   angle_buy = 1,
   angle_sell = 2,
   angle_exit = -1
};
//The input modifier is indicated before the data type. 
//A variable with the input modifier can't be changed inside mql4-programs, 
//such variables can be accessed for reading only. Values of input variables can be changed only by a user from the program properties window.
// The difference of input parameter and extern parameter:
// Input can not change in code, can only change by user input
// extern can change in code,
// ------------------------------------------------------------------------------------------------
// VARIABLES GLOBALES
// ------------------------------------------------------------------------------------------------
string key = "Renko EA V1.3";
// Definimos 1 variable para guardar los tickets
int order_tickets;
// Definimos 1 variable para guardar los lotes
double order_lots;
// Definimos 1 variable para guardar las valores de apertura de las ordenes
double order_price;
// Definimos 1 variable para guardar los beneficios
double order_profit;
// Definimos 1 variable para guardar los tiempos
int order_time;
// One bar can only open one order
datetime bar_time=0;
// indicadores
double signal=0;
// Cantidad de ordenes;
int orders = 0;
int buys = 0;
int sells = 0;
int direction= 0;
double max_profit=0, close_profit=0;
double last_order_profit=0, last_order_lots=0;
// Colores
color c=Black;
// Cuenta
double balance, equity;
int slippage=0;
// OrderReliable
int retry_attempts = 10; 
double sleep_time = 4.0;
double sleep_maximum	= 25.0;  // in seconds
string OrderReliable_Fname = "OrderReliable fname unset";
static int _OR_err = 0;
string OrderReliableVersion = "V1_1_1"; 
string commentStr = "";
int con_direction = 0;
int count = 0;
string text1="";
string text2="";
double maAngle = 0;
double maAngle_pre = 0;
double maAngle_cur = 0;
double renkoSize = 0;
bool maAngleChange = false;
// double 	StopLoss = 60;
static int crossIndex = 0;

int init(){
   //double maAngle = iCustom(Symbol(),0,"Angle of average + alerts 1_1",50,ma_ema,0,8,6,false,false,false,false,false,false,3,1);
   //Print("MA---->",maAngle);
   //log_open( key );
   double StopLevel = MathMax ( MarketInfo ( Symbol(), MODE_FREEZELEVEL ), MarketInfo ( Symbol(), MODE_STOPLEVEL ) );
   if(StopLoss>0){
      StopLoss = MathMax ( StopLoss, StopLevel );
   }
   
   log( "init(): log file opened successfully..." );
   if(renkoSize==0){
     renkoSize = MathMin(MathAbs(Open[1]-Close[1]),MathAbs(Open[2]-Close[2]));
   }
   return 0;
}

int deinit()
{
  log( "deinit(): closing log file..." );
  //log_close();
  return(0);
}


// ------------------------------------------------------------------------------------------------
// START
// ------------------------------------------------------------------------------------------------
int start()
{  
  double point = MarketInfo(Symbol(), MODE_POINT);
  double dd=0;
  int ticket, i, n;
  double price;
  bool cerrada, encontrada;
  balance=AccountBalance();
  equity=AccountEquity();
  
  if (MarketInfo(Symbol(),MODE_DIGITS)==4)
  {
    slippage = user_slippage;
  }
  else if (MarketInfo(Symbol(),MODE_DIGITS)==5)
  {
    slippage = 10*user_slippage;
  }
  
  if(IsTradeAllowed() == false) 
  {
    Comment("Copyright ?2011, www.lifesdream.org\nTrade not allowed.");
    return 0;  
  }
  
  user_sl = user_tp;
  
  //if (use_tp_sl==0)

    //Comment(StringConcatenate("\nCopyright ?2011, www.lifesdream.org\nHeiken Ashi MA EA v1.3 is running.\nNext order lots: ",CalcularVolumen()));
  //else if (use_tp_sl==1)  
    //Comment(StringConcatenate("\nCopyright ?2011, www.lifesdream.org\nHeiken Ashi MA EA v1.3 is running.\nNext order lots: ",CalcularVolumen(),"\nTake profit ($): ",CalcularVolumen()*10*user_tp,"\nStop loss ($): ",CalcularVolumen()*10*user_sl));
  
  // Actualizamos el estado actual
  InicializarVariables();
  ActualizarOrdenes();
  
  encontrada=FALSE;
  if (OrdersHistoryTotal()>0)
  {
    i=1;
    
    while (i<=10 && encontrada==FALSE)
    { 
      n = OrdersHistoryTotal()-i;
      if(OrderSelect(n,SELECT_BY_POS,MODE_HISTORY)==TRUE)
      {
        if (OrderMagicNumber()==magic)
        {
          encontrada=TRUE;
          last_order_profit=OrderProfit();
          last_order_lots=OrderLots();
        }
      }
      i++;
    }
  }
  
  point = MarketInfo(Symbol(), MODE_POINT);
  Robot();
  
  return(0);
}


// ------------------------------------------------------------------------------------------------
// INICIALIZAR VARIABLES
// ------------------------------------------------------------------------------------------------
void InicializarVariables()
{
  // Reseteamos contadores de ordenes de compa y venta
  orders=0;
  buys=0;
  sells=0;
  direction=0;
  
  order_tickets = 0;
  order_lots = 0;
  order_price = 0;
  order_time = 0;
  order_profit = 0;
  
  last_order_profit = 0;
  last_order_lots = 0;
  
}

// ------------------------------------------------------------------------------------------------
// ACTUALIZAR ORDENES
// ------------------------------------------------------------------------------------------------
void ActualizarOrdenes()
{
  int ordenes=0;
  
  // Lo que hacemos es introducir los tickets, los lotes, y los valores de apertura en las matrices. 
  // Adem醩 guardaremos el n鷐ero de ordenes en una variables.
  
  // Ordenes de compra
  for(int i=0; i<OrdersTotal(); i++)
  {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
    {
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic)
      {
        order_tickets = OrderTicket();
        order_lots = OrderLots();
        order_price = OrderOpenPrice();
        order_time = OrderOpenTime();
        order_profit = OrderProfit();
        ordenes++;
        if (OrderType()==OP_BUY) {direction=1;buys++;}
        if (OrderType()==OP_SELL) {direction=2;sells++;}
      }
    }
  }
  
  // Actualizamos variables globales
  orders = ordenes;
}

// ------------------------------------------------------------------------------------------------
// ESCRIBE
// ------------------------------------------------------------------------------------------------
void Escribe(string nombre, string s, int x, int y, string font, int size, color c)
{
  if (ObjectFind(nombre)!=-1)
  {
    ObjectSetText(nombre,s,size,font,c);
  }
  else
  {
    ObjectCreate(nombre,OBJ_LABEL,0,0,0);
    ObjectSetText(nombre,s,size,font,c);
    ObjectSet(nombre,OBJPROP_XDISTANCE, x);
    ObjectSet(nombre,OBJPROP_YDISTANCE, y);
  }
}

// ------------------------------------------------------------------------------------------------
// CALCULAR VOLUMEN
// ------------------------------------------------------------------------------------------------
double CalcularVolumen()
{ 
  double aux; 
  int n;
  
  if (money_management==0)
  {
    aux=min_lots;
  }
  else
  {    
    if (progression==0) 
    { 
      aux = risk*AccountFreeMargin();
      aux= aux/100000;
      n = MathFloor(aux/min_lots);
      
      aux = n*min_lots;                   
    }  
  
    if (progression==1)
    {
      if (last_order_profit<0)
      {
        aux = last_order_lots+min_lots;
      }
      else 
      {
        aux = last_order_lots-min_lots;
      }  
    }        
    
    if (progression==2)
    {
      if (last_order_profit<0)
      {
        aux = last_order_lots*2;
      }
      else 
      {
         aux = risk*AccountFreeMargin();
         aux= aux/100000;
         n = MathFloor(aux/min_lots);
         
         aux = n*min_lots;         
      }  
    }     
    
    if (aux<min_lots)
        aux=min_lots;
     
    if (aux>MarketInfo(Symbol(),MODE_MAXLOT))
      aux=MarketInfo(Symbol(),MODE_MAXLOT);
      
    if (aux<MarketInfo(Symbol(),MODE_MINLOT))
      aux=MarketInfo(Symbol(),MODE_MINLOT);
  }
  
  return(aux);
}

// ------------------------------------------------------------------------------------------------
// CALCULA VALOR PIP
// ------------------------------------------------------------------------------------------------
double CalculaValorPip(double lotes)
{ 
   if(lotes==0){
      return 0;
   }
   double aux_mm_valor=0;
   
   double aux_mm_tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   double aux_mm_tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
   int aux_mm_digits = MarketInfo(Symbol(),MODE_DIGITS);   
   double aux_mm_veces_lots = 1/lotes;
      
   if (aux_mm_digits==5)
   {
     aux_mm_valor=aux_mm_tick_value*10;
   }
   else if (aux_mm_digits==4)
   {
     aux_mm_valor = aux_mm_tick_value;
   }
   
   if (aux_mm_digits==3)
   {
     aux_mm_valor=aux_mm_tick_value*10;
   }
   else if (aux_mm_digits==2)
   {
     aux_mm_valor = aux_mm_tick_value;
   }
   
   aux_mm_valor = aux_mm_valor/aux_mm_veces_lots;
   
   return(aux_mm_valor);
}

// ------------------------------------------------------------------------------------------------
// CALCULA TAKE PROFIT
// ------------------------------------------------------------------------------------------------
int CalculaTakeProfit()
{ 
   //if(Symbol()=="GOLD" || Symbol()=="XAUUSD") return 3;
  int aux_take_profit;      
  
  aux_take_profit=MathRound(CalculaValorPip(order_lots)*user_tp);  
  if(aux_take_profit<minProfit){
    aux_take_profit = minProfit;
  }
  return(aux_take_profit);
}

// ------------------------------------------------------------------------------------------------
// CALCULA STOP LOSS
// ------------------------------------------------------------------------------------------------
int CalculaStopLoss()
{ 
  int aux_stop_loss;      
  
  aux_stop_loss=-1*MathRound(CalculaValorPip(order_lots)*user_sl);
    
  return(aux_stop_loss);
}


double getStopLossPrice(){
   if(StopLoss==0)return 0;
   if(useLastLowHighAsSL){
         
   }
   if(useMaSL){
      
   }
   return 0;
}

void CalculaConsistentTrend(){
    con_direction = 0;
    count = 0;
   if(Close[1]>Open[1]){
      con_direction = 1;
   } else {
      con_direction = -1;
   }
   
   for(int i=2;i<20;i++){
      if(con_direction==1){
         if(Close[i]>Open[i]){
            count++;
         }else {
            break;
         }
      } else {
         if(Close[i]<Open[i]){
            count++;
         }else {
            break;
         }
      }
   }
   //Print("count==",count);
   //Print("con_direction==",con_direction);
   //Write("label_direction",IntegerToString(con_direction),300,240,"Times New Roman",18,Green);
   //Write("value_direction",IntegerToString(count),320,260,"Times New Roman",18,Green);
}

bool CheckPriceCrossMA(){
   
   bool isLong = false;
   bool isShort = false;
   int longNum=0,shortNum=0;
   double MAFast,MASlow,Max_MA,Min_MA;
   if(Close[1]>Open[1]){
      isLong = true;
   } else {
      isShort = true;
   }
   for(int i=2;i<20;i++){
      MAFast = iMA(NULL,0,mafast_period,shift,MA_Method,APPLIED_PRICE,shift);
      MASlow = iMA(NULL,0,maslow_period,shift,MA_Method,APPLIED_PRICE,shift);
      Max_MA = MathMax(MAFast,MASlow);
      Min_MA = MathMin(MAFast,MASlow);
      if(isLong){
         if(Open[i]>Max_MA){
            longNum++;
         } else {
            break;
         }   
      }else if(isShort){
         if(Close[i]<Min_MA){
            shortNum++;
         } else {
            break;
         }
      }
   }
}

int GetCCISignal(){
   int mode = 0;
   double ccl_value = iCCI(NULL,0,cci_period,cci_applied_price,cci_shift);
   double pre_ccl_value = iCCI(NULL,0,cci_period,cci_applied_price,cci_shift+1);
   
   if(pre_ccl_value<100 && ccl_value >= 100){
      mode =  buy;
   }
   if(pre_ccl_value>-100 && ccl_value <= -100){
      mode = sell;
   }
   if(mode > 0)log("CCI Signal open new order---->"+mode);
   return mode;
}


int GetGoldEMASignal(){
   double ema_value = iMA(NULL,0,goldEAM_period,0,MA_Method,APPLIED_PRICE,shift);
   double ema_value1 = iMA(NULL,0,goldEAM_period,0,MA_Method,APPLIED_PRICE,shift+1);
   ema_value = (ema_value + ema_value1)/2;

   //double below_val = MathMin(Low[2],Low[3]);
   //double high_val = MathMax(High[2],High[3]);
   int ret = 0;
   // BUY
   if(Close[1]>Open[1] && Close[2]>Open[2] && Close[3] > Open[3]){
      if(High[2]>ema_value && Low[3]<ema_value){
         ret = 1;
      }
   }
   // SELL
   if(Close[1]<Open[1] && Close[2]<Open[2] && Close[3] < Open[3]){
      if(Low[2]<ema_value && High[3]>ema_value)
      ret = 2;
   }
   if(ret>0)log("Use Gold MA Signal to open new order----->"+ret);
   return ret;
}

// If the target ma angle below -4 ~ 4, must wait price to close above the 
// last 15 highest to buy, and below last 15 lowest to sell
bool CheckMAAngleEntry(){
   crossIndex++;
   double val_low;
   maAngleChange = false;
//--- calculating the lowest value on the 10 consequtive bars in the range
//--- from the 10th to the 19th index inclusive on the current chart
   int val_index=iLowest(NULL,0,MODE_LOW,15,1);
   if(val_index!=-1) val_low=Low[val_index];
   else PrintFormat("Error in iLowest. Error code=%d",GetLastError());
   
   double val_high;
//--- calculating the lowest value on the 10 consequtive bars in the range
//--- from the 10th to the 19th index inclusive on the current chart
   val_index=iHighest(NULL,0,MODE_HIGH,15,1);
   if(val_index!=-1) val_high=High[val_index];
   else PrintFormat("Error in iLowest. Error code=%d",GetLastError());
   maAngle_cur = iCustom(Symbol(),0,"Angle of average + alerts 1_1",MAAnglePeriod,ma_ema,0,8,6,false,false,false,false,false,false,3,0);
   maAngle = iCustom(Symbol(),0,"Angle of average + alerts 1_1",MAAnglePeriod,ma_ema,0,8,6,false,false,false,false,false,false,3,1);
   maAngle_pre = iCustom(Symbol(),0,"Angle of average + alerts 1_1",MAAnglePeriod,ma_ema,0,8,6,false,false,false,false,false,false,3,2);

   if(maAngle_cur > MaThreshold && maAngle >= MaThreshold && maAngle_pre < MaThreshold){// Cross up the threshold 
      maAngleChange = true;
      crossIndex = 0;
   }
   if(maAngle_cur < -1*MaThreshold && maAngle <=-1* MaThreshold && maAngle_pre > -1*MaThreshold){
      maAngleChange = true;
      crossIndex = 0;
   }

   // Comment("maAngle=="+maAngle
   // +"\nval_high==="+val_high
   // +"\nval_low ==="+val_low
   // +"\nClose[1]==="+Close[1]);
   text1="maAngle=="+maAngle
   +"\nval_high==="+val_high
   +"\nval_low ==="+val_low
   +"\nClose[1]==="+Close[1];
 //  Print(maAngle);
   if(maAngle > -1*MaThreshold && maAngle < MaThreshold){
      /*if(Close[1]>Open[1]){
         
      } else if(Close[1]<Open[1]){
         
      }*/
      // Remove == for this condition
      useMAChannel = true;
      return true;
      /*
      if(Close[1] >= val_high || Close[1] <= val_low){
         return true;
      } else return false;*/

   } else {
      useMAChannel = false;
      return true;
   }
     
   
}
/*
1.
Need to open order when the first bar cross over ma channel
2.
If the ma angle > threshold, we also can open order according to ma channel cross.
3. 
Add ma angle > 0 for buy order and ma angle < 0 for sell order
4.
Should we wait for the total bar up or down the ma channel to open new order
*/

// Check for open
int MA_Channel_Open(){
  int mode = 0;
  double iHighc = iMA(NULL,0,5,0,MODE_SMA,PRICE_HIGH,1);
  double vHigh = iMA(NULL,0,5,0,MODE_SMA,PRICE_HIGH,2);
  double iHigh_pre = iMA(NULL,0,5,0,MODE_SMA,PRICE_HIGH,3);
  
  double iLowc = iMA(NULL,0,5,0,MODE_SMA,PRICE_LOW,1);
  double vLow = iMA(NULL,0,5,0,MODE_SMA,PRICE_LOW,2);
  double iLow_pre = iMA(NULL,0,5,0,MODE_SMA,PRICE_LOW,3);
  if(maAngleChange || crossIndex==1){
      if(count>=4){
        return 0;
      }
      if(Close[1] > Open[1] && Close[2] > Open[2]){// Check for buy
    // if(Low[1] > vHigh && Low[2] < vHigh){
    //   mode = buy;
    // }
        // if(Open[2] > vHigh && Low[1]>iHighc){
        if(Open[2] > vHigh && Low[1]>iHighc){
          mode = buy;
        }
      } else if(Close[1] < Open[1] && Close[2] < Open[2]){// Check for sell
        // if(Close[2] < vLow && High[1] < iLowc){
        if(Close[2] < vLow && High[1] < iLowc){
          mode = sell;
        }
      }
      if(mode>0)log("Ma Angle Change and MA Channel Open Order Signal---->"+mode);
  } else {
      if(!tradeUnderRestriction){
        return 0;
      }
      if(Close[1] > Open[1] && Close[2] > Open[2] && Close[3] > Open[3]){// Check for buy
    // if(Low[1] > vHigh && Low[2] < vHigh){
    //   mode = buy;
    // }
        if(Open[2] > vHigh && Low[3] < iHigh_pre && Low[1]>iHighc){
          mode = buy;
        }
      } else if(Close[1] < Open[1] && Close[2] < Open[2] && Close[3] < Open[3]){// Check for sell
        if(Close[2] < vLow && Open[3] > iLow_pre && High[1] < iLowc){
          mode = sell;
        }
      }
      if(mode>0)log("MA Channel Open Order Signal---->"+mode);
      // Add check for ma channel open order
      if(mode > 0){
          log("mode value before check MACD---->"+orderType);
        if(checkMACD(mode)){
           log("Check MACD pass!!!");
          return mode; 
        } else {
           log("Check MACD fail!!!");
           return 0;
        }
      }
  }
  
  
  return mode;
}


// ------------------------------------------------------------------------------------------------
// CALCULA SIGNAL
// ------------------------------------------------------------------------------------------------

int CalculaSignal(int aux_ma_mode, int aux_ma_fast_period, int aux_ma_slow_period, int aux_shift)
{
  int orderType = 0;
  if(Time[0] <= bar_time){
     return 0;
  } else {
     bar_time = Time[0];
  }   
  double MA21 = iMA(NULL,0,aux_ma_fast_period,aux_shift,aux_ma_mode,APPLIED_PRICE,aux_shift);
  double MA50 = iMA(NULL,0,aux_ma_slow_period,aux_shift,aux_ma_mode,APPLIED_PRICE,aux_shift);
  //Comment(StringConcatenate("\nMA21====",MA21,"\nMA50===",MA50,"\nCLOSE[1]===",Close[1]));
  // commentStr = "\nMA21===="+ DoubleToStr(MA21,Digits)
  //                          + "\nMA50==="+DoubleToStr(MA50,Digits)
  //                          + "\nCLOSE[1]==="+DoubleToStr(Close[1])
  //                          + "\nCurrentDirection=="+IntegerToString(con_direction)
  //                          + "\nConsist NUmber=="+IntegerToString(count)
  //                          + "\nStopLevel == "+ MarketInfo(Symbol(),MODE_STOPLEVEL)
  //                          + "\nMax_profit == "+max_profit
  //                          + "\nClose_profit == "+close_profit
  //                          + "\nOrdwe_profit == "+order_profit
  //                          + "\nPoint == "+Point;  
   bool tradeAllowed = false;
   if(useMAAngleRestriction){
       tradeAllowed = CheckMAAngleEntry();
       //Comment("tradAllowd==="+tradeAllowed);
   }

   if(useMAChannel || maAngleChange || crossIndex==1){
      //log("Use Ma Channel To Determine whether to open new order!!!");
     return MA_Channel_Open();
   }
   
   if(!tradeAllowed){
      return 0;
   }
   
   if(useCCI && !useGoldEMA){
      return GetCCISignal();
   }
   if(!useCCI && useGoldEMA){
      return GetGoldEMASignal();
   }
  
  //if (Close[3]<Open[3]&&Close[2]>Open[2]&&Close[1]>Open[1]&&Close[1]>MA21&&Close[1]>MA50) return(buy);
  //if (Close[3]>Open[3]&&Close[2]<Open[2]&&Close[1]<Open[1]&&Close[1]<MA21&&Close[1]<MA50) return(sell);
  double MA21_4 = iMA(NULL,0,aux_ma_fast_period,aux_shift,aux_ma_mode,APPLIED_PRICE,4);
  double MA50_4 = iMA(NULL,0,aux_ma_slow_period,aux_shift,aux_ma_mode,APPLIED_PRICE,4);
  
  if (Close[2]>Open[2]&&Close[1]>Open[1]){
     if(check_third_candle_for_open && check_price_over_MA){
        if(Close[3]<Open[3]&&Close[1]>MA21&&Close[1]>MA50){
        	orderType = buy;
          // return buy;
        } else {
          if(max_candle_check_for_open==4 && Close[3]>Open[3]){
             
             if(Close[4]<Open[4]&&Close[1]>MA21&&Close[1]>MA50 && Close[4] < MA21_4 && Close[4] < MA50_4 ){
               orderType = buy;
             } else orderType = 0;
          } else
        	orderType = 0;
          // return 0;
        }
     } else if(!check_third_candle_for_open && check_price_over_MA){
         if(Close[1]>MA21&&Close[1]>MA50){
          // return buy;
         	orderType = buy;
        } else {
          // return 0;
        	orderType = 0;
        }
     } else if(check_third_candle_for_open && !check_price_over_MA){
         if(Close[3]<Open[3]){
          // return buy;
         	orderType = buy;
        } else {
            if(max_candle_check_for_open==4 && Close[3]>Open[3]){
                if(Close[4]<Open[4]&&Close[1]>MA21&&Close[1]>MA50 && Close[4] < MA21_4 && Close[4] < MA50_4 ){
                  orderType = buy;
                } else orderType = 0;
             } else
             // return 0;
           	orderType = 0;
        }
     } else {
         // return buy;
     	orderType = buy;
     }
     // return(buy);
     //orderType = buy;
  } else
  if (Close[2]<Open[2]&&Close[1]<Open[1]){
      if(check_third_candle_for_open && check_price_over_MA){
        if(Close[3]>Open[3]&&Close[1]<MA21&&Close[1]<MA50){
          // return sell;
          orderType = sell;
        } else {
          // return 0;
          if(max_candle_check_for_open==4 && Close[3]<Open[3]){
             
             if(Close[4]>Open[4]&&Close[1]<MA21&&Close[1]<MA50 && Close[4] > MA21_4 && Close[4] > MA50_4 ){
               orderType = sell;
             } else orderType = 0;
          } else
        	 orderType = 0;
        }
     } else if(!check_third_candle_for_open && check_price_over_MA){
         if(Close[1]<MA21&&Close[1]<MA50){
          // return sell;
         	orderType = sell;
        } else {
          // return 0;
        	orderType = 0;
        }
     } else if(check_third_candle_for_open && !check_price_over_MA){
         if(Close[3]>Open[3]){
          // return sell;
         	orderType = sell;
        } else {
          // return 0;
        	  if(max_candle_check_for_open==4 && Close[3]<Open[3]){
             
             if(Close[4]>Open[4]&&Close[1]<MA21&&Close[1]<MA50 && Close[4] > MA21_4 && Close[4] > MA50_4 ){
               orderType = sell;
             } else orderType = 0;
          } else
        	 orderType = 0;
        }
     } else {
         // return sell;
     	orderType = sell;
     }
     // return(sell);
     //orderType = sell;
  }
  if(orderType > 0){
      log("OrderType value before check MACD---->"+orderType);
   	if(checkMACD(orderType)){
   	   log("Check MACD pass!!!");
   		return orderType; 
   	} else {
   	   log("Check MACD fail!!!");
   	   return 0;
   	}
	}
   
}

bool checkMACD(int type){
	bool allowed = true;
	string i_name = "MACD Alert2";
	double i_signal = iCustom(Symbol(),0,i_name,12,26,9,false,1,1);
	double i_value = iCustom(Symbol(),0,i_name,12,26,9,false,0,1);

	if(type == buy){
		if(i_value > 0 && i_value<i_signal){
			allowed = false;
		}
	} else if(type == sell){
		if(i_value < 0 && i_value>i_signal){
			allowed = false;
		}
	}
	return allowed;
}

void CloseGoldOrder(int orderType){
   
   double ema_value = iMA(NULL,0,goldEAM_period,0,MA_Method,APPLIED_PRICE,1);
   if(orderType==1){
      if(Close[1] < ema_value || Open[1] < ema_value){
         //close buy
         OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
         Print("Close Order Due To Gold Method!--->"+order_tickets);
         log("Close Order Due To Gold Method!--->"+order_tickets);
         max_profit=0;
         close_profit=0; 
      }
   } else if(orderType==2){
      if(Close[1] > ema_value || Open[1] > ema_value){
         //close sell
         OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
         Print("Close Order Due To Gold Method!--->"+order_tickets);
         log("Close Order Due To Gold Method!--->"+order_tickets);
         max_profit=0;
         close_profit=0;
      }
   } 
}

void CloseCCIOrder(int orderType){
   double ccl_value = iCCI(NULL,0,cci_period,cci_applied_price,cci_shift);
   double pre_ccl_value = iCCI(NULL,0,cci_period,cci_applied_price,cci_shift+1);
   
   
   // Close Buy Order
   if(orderType==1){
      if(pre_ccl_value>100 && ccl_value < 100){
         OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
         Print("Close Order Due To CCI Method!--->"+order_tickets);
         log("Close Order Due To CCI Method!--->"+order_tickets);
         max_profit=0;
         close_profit=0; 
      }
   }// Close Sell Order 
   else if(orderType==2){
      if(pre_ccl_value<-100 && ccl_value > -100){
         if(Close[1]>Open[1]){
            OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
            Print("Close Order Due To CCI Method!--->"+order_tickets);
            log("Close Order Due To CCI Method!--->"+order_tickets);
            max_profit=0;
            close_profit=0;
         }
      }
   }
}

void CloseByReverseCandle(int number,int orderType){
   if(number <1){
      number = 1;
   }
   bool exit = true;
   for(int i=1;i<=number;i++){
      if(orderType==1){//close buy order
         if(Open[i]<Close[i]){
            exit = false;
            break;
         }
      }else if(orderType==2){//close sell order
         if(Open[i]>Close[i]){// If the last number of bar, exit a reverse bar, then close 
            exit = false;
            break;
         }
      }
   }
   if(exit){
      //return;
   
      if(orderType==1){
         OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
         Print("Close Order By ReverseCandle!--->"+order_tickets);
         log("Close Order By ReverseCandle!--->"+order_tickets);
         max_profit=0;
         close_profit=0;
      }else if(orderType==2){
         OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
         Print("Close Order By ReverseCandle!--->"+order_tickets);
         log("Close Order By ReverseCandle!--->"+order_tickets);
         max_profit=0;
         close_profit=0;
      }
   }
   
}


void MA_Channel_Close(int orderType){
  int mode = 0;
  double vHigh = iMA(NULL,0,5,0,MODE_SMA,PRICE_HIGH,1);
  double vLow = iMA(NULL,0,5,0,MODE_SMA,PRICE_LOW,1);
  if(orderType == 1){// Close buy order
    if(Close[1] < vHigh){
      OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
      Print("Close Order By MA Channel!--->"+order_tickets);
      log("Close Order By MA Channel!--->"+order_tickets);
      max_profit=0;
      close_profit=0;  
    }
  } else if(orderType == 2){// Close sell order
    if(Close[1] > vLow){
      OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
      Print("Close Order By MA Channel!--->"+order_tickets);
      log("Close Order By MA Channel!--->"+order_tickets);
      max_profit=0;
      close_profit=0;
    }
  }
}


void CloseBuy(){
   if(Close[1]<Open[1]){
      OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
      Print("Close Order By First ReverseCandle!--->"+order_tickets);
      log("Close Order By First ReverseCandle!--->"+order_tickets);
      max_profit=0;
      close_profit=0;  
   }
}

void CloseSell(){
   if(Close[1]>Open[1]){
      OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
      Print("Close Order By First ReverseCandle!--->"+order_tickets);
      log("Close Order By First ReverseCandle!--->"+order_tickets);
      max_profit=0;
      close_profit=0;
   }
}

void CloseMaExit(int orderType){
   double ema_value = iMA(NULL,0,mafast_period,0,MA_Method,APPLIED_PRICE,1);
   if(orderType==1){
      if(Close[1] < ema_value){
         //close buy
         OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
         Print("Close Order By Ma Cross!--->"+order_tickets);
         log("Close Order By Ma Cross!--->"+order_tickets);
         max_profit=0;
         close_profit=0; 
      }
   } else if(orderType==2){
      if(Close[1] > ema_value){
         //close sell
         OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
         Print("Close Order By Ma Cross!--->"+order_tickets);
         log("Close Order By Ma Cross!--->"+order_tickets);
         max_profit=0;
         close_profit=0;
      }
   }
}

void DoBreakEven(int BP, int BE) {
   bool bres;
   for (int i = 0; i < OrdersTotal(); i++) {
      if ( !OrderSelect (i, SELECT_BY_POS) )  continue;
      if ( OrderSymbol() != Symbol() || OrderMagicNumber() != magic )  continue;
      if ( OrderType() == OP_BUY ) {
         if (Bid<OrderOpenPrice()+BP*Point) continue;
         if ( OrderOpenPrice()+BE*Point-OrderStopLoss()>Point/10) {
               //Print(BP,"  ",BE," bestop");
               bres=OrderModify (OrderTicket(), OrderOpenPrice(), OrderOpenPrice()+BE*Point, OrderTakeProfit(), 0, Black);
           if (!bres) Print("Error Modifying BE BUY order : ",ErrorDescription(GetLastError()));
           else log("Order Modified due to breakeven!!!--->"+OrderTicket());
         }
      }

      if ( OrderType() == OP_SELL ) {
         if (Ask>OrderOpenPrice()-BP*Point) continue;
         if ( OrderStopLoss()-(OrderOpenPrice()-BE*Point)>Point/10) {
               //Print(BP,"  ",BE," bestop");
               bres=OrderModify (OrderTicket(), OrderOpenPrice(), OrderOpenPrice()-BE*Point, OrderTakeProfit(), 0, Gold);
           if (!bres) Print("Error Modifying BE SELL order : ",ErrorDescription(GetLastError()));
           else log("Order Modified due to breakeven!!!--->"+OrderTicket());
         }
      }
   }
   return;
}

void DoTrailingStop(){

  for(int i=0; i<OrdersTotal(); i++)
  {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
    {
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic)
      {
        if (OrderType()==OP_BUY) {

            if(Bid-OrderOpenPrice()>Point*TrailingStop)

              if (OrderStopLoss()<(Bid-Point*TrailingStop)) 
              {            
                 OrderModify(OrderTicket(),OrderOpenPrice(),Bid-Point*TrailingStop,0,0,Yellow);
                 return(0);
              }
            }
          
          //direction=1;buys++;
        }
        if (OrderType()==OP_SELL) {
            if (OrderOpenPrice()-Ask>=(TrailingStop*Point)) {      
               if (OrderStopLoss()>(Ask+Point*TrailingStop))
               {      
                  OrderModify(OrderTicket(),OrderOpenPrice(),Ask+Point*TrailingStop,0,0,Purple);
                  return(0);             
                }
            } 
        }
      }
    }
}

void displayInfo()
{
   int i;
   string obj_name="label_object";
   long current_chart_id=ChartID();
   for(i=0;i<9;i++){
      obj_name = "label_object"+string(i);
      
      if(ObjectFind(obj_name)<0){
      //--- creating label object (it does not have time/price coordinates)
         if(!ObjectCreate(current_chart_id,obj_name,OBJ_LABEL,0,0,0))
        {
         Print("Error: can't create label! code #",GetLastError());
         return(0);
        }
      }
      //--- set color to Red
      ObjectSetInteger(current_chart_id,obj_name,OBJPROP_COLOR,clrRed);
   }
   

   
   

//--- move object down and change its text
   //for(i=0; i<200; i++)
     //{
      
      
      //--- set distance property
      obj_name = "label_object" + string(0);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1000);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,24);
      //--- set text property
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,"Max_Profit:");
      
      obj_name = "label_object" + string(1);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1000);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,44);
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,"Close_Profit:");
      
      obj_name = "label_object" + string(2);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1000);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,64);
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,"Order_Profit:");
      
      obj_name = "label_object" + string(3);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1080);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,24);
      //--- set text property
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,DoubleToStr(max_profit,2));
      
      obj_name = "label_object" + string(4);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1080);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,44);
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,DoubleToStr(close_profit,2));
      
      obj_name = "label_object" + string(5);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1080);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,64);
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,DoubleToStr(order_profit,2));
      
      obj_name = "label_object" + string(6);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1000);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,84);
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,"User_Profit:");
      
      obj_name = "label_object" + string(7);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1080);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,84);
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,DoubleToStr(CalculaTakeProfit(),2));
      
      // Display tradeAllowed by ema angle 
      obj_name = "label_object" + string(8);
      ObjectSet(obj_name,OBJPROP_XDISTANCE,1000);
      ObjectSet(obj_name,OBJPROP_YDISTANCE,104);
      ObjectSetString(current_chart_id,obj_name,OBJPROP_TEXT,CheckMAAngleEntry());
      
      
      
      
      
      //--- forced chart redraw
      ChartRedraw(current_chart_id);
      Sleep(10);
     //}
         //"\nMA21===="+ DoubleToStr(MA21,Digits)
                          // + "\nMA50==="+DoubleToStr(MA50,Digits)
                          // + "\nCLOSE[1]==="+DoubleToStr(Close[1])
                  commentStr = "\nCurrentDirection=="+IntegerToString(con_direction)
                           + "\nConsist NUmber=="+IntegerToString(count)
                           + "\nStopLevel == "+ MarketInfo(Symbol(),MODE_STOPLEVEL)
                           + "\nMax_profit == "+max_profit
                           + "\nClose_profit == "+close_profit
                           + "\nOrdwe_profit == "+order_profit
                           + "\nPoint == "+Point
                           + "\nTickValue ==="+MarketInfo(Symbol(), MODE_TICKVALUE)
                           + "\nTickSize==="+MarketInfo(Symbol(), MODE_TICKSIZE)
                           + "\nRenkoSize ==="+renkoSize
                           + "\nUseMaExit ==="+useMaExit
                           + "\nuse_tp_sl ==="+use_tp_sl
                           + "\nuseReverseCandleExit-->"+useReverseCandleExit
                           + "\nCheckMACD(1)-->"+checkMACD(1)
                           + "\nCheckMACD(2)-->"+checkMACD(2);
                           
      Comment(commentStr + "\n" + text1);
   return(0);
  }

// ------------------------------------------------------------------------------------------------
// ROBOT
// ------------------------------------------------------------------------------------------------
void Robot()
{
  int ticket=-1, i;
  bool cerrada=FALSE;  
  //int mafast_period=21,maslow_period=50;
  if(useMaExit && !check_price_over_MA){
    Alert("Setting conflict, check_price_over_MA=false and useMaExit=true can not choose together!!");
  }
  CalculaConsistentTrend();
  //Comment(commentStr);
  displayInfo();
  if (orders==0 && direction==0)
  {     
    //signal = CalculaSignal(ma_mode,ma_period,shift);
    
    signal = CalculaSignal(MA_Method,mafast_period,maslow_period,shift);
    //Write("CurrentSignalLabel","CurrentSignal:",200,60,"Times New Roman",20,Red);
    //Write("CurrentSignal",IntegerToString(signal),240,60,"Times New Roman",20,Red);
    //commentStr = commentStr + "\nCurrent Signal==="+IntegerToString(signal);
    //Comment(StringConcatenate("\nCurrent Signal===",signal));
    // ----------
    // COMPRA
    // ----------
    double sl = 0;
    StopLoss = MathMax(StopLoss,3*renkoSize/Point);
    if (signal==1){
       //sl = NormalizeDouble(Open[2],Digits);
       
       // sl = Bid - NormalizeDouble(3 * MathAbs(Open[1]-Close[1]), Digits);
       // if((MarketInfo(Symbol(),MODE_ASK)-sl)/Point<MarketInfo(Symbol(),MODE_STOPLEVEL)){
       //   sl = MarketInfo(Symbol(),MODE_ASK)- MarketInfo(Symbol(),MODE_STOPLEVEL)*Point - 10*Point;
       // }
    	
       sl =  Bid - StopLoss * Point;
       //sl=0;
       ticket = OrderSendReliable(Symbol(),OP_BUY,CalcularVolumen(),MarketInfo(Symbol(),MODE_ASK),slippage,NormalizeDouble(sl,Digits),0,key,magic,0,Blue); 
    }
    // En este punto hemos ejecutado correctamente la orden de compra
    // Los arrays se actualizar醤 en la siguiente ejecuci髇 de start() con ActualizarOrdenes()
     
    // ----------
    // VENTA
    // ----------
    if (signal==2){
       //sl = NormalizeDouble(Open[2],Digits);
       // sl = Bid + NormalizeDouble(3 * MathAbs(Open[1]-Close[1]), Digits);
       // if((sl - MarketInfo(Symbol(),MODE_BID))/Point<MarketInfo(Symbol(),MODE_STOPLEVEL)){
       //   //Print("Not trigger");
       //   sl = MarketInfo(Symbol(),MODE_BID)+ MarketInfo(Symbol(),MODE_STOPLEVEL)*Point + 20*Point;
       // }
       //orderprice + spread + StopLoss * Point + AddPriceGap
       // sl = Bid + (Ask - Bid) + StopLoss * Point ;
       sl = Ask + StopLoss * Point ;
       //sl = MarketInfo(Symbol(),MODE_BID)+ MarketInfo(Symbol(),MODE_STOPLEVEL)*Point + 20*Point;
       //sl=0;
       ticket = OrderSendReliable(Symbol(),OP_SELL,CalcularVolumen(),MarketInfo(Symbol(),MODE_BID),slippage,NormalizeDouble(sl,Digits),0,key,magic,0,Red); 
    }        
    // En este punto hemos ejecutado correctamente la orden de venta
    // Los arrays se actualizar醤 en la siguiente ejecuci髇 de start() con ActualizarOrdenes()       
  }
  
  if(buys>0){
  	   //double maAngle = iCustom(Symbol(),0,"Angle of average + alerts 1_1",MAAnglePeriod,ma_ema,0,8,6,false,false,false,false,false,false,3,1);
		if(useDynamicExit){
		   if(maAngle >= -1*MaThreshold && maAngle <= MaThreshold){// The ma angle value is too samll
			 use_tp_sl=1;
			 useMaExit = false;
		   } else {// Normal value
			// Use MaExit strategy: close price cross over the ma line
			 use_tp_sl=0;
			 useMaExit = true;
		   }
	   }
      if(useCCI)CloseCCIOrder(1);
      else if(useReverseCandleExit)CloseByReverseCandle(numberOfCandleToExit,1);
      else if(useMAChannel)MA_Channel_Close(1);
      else if(useGoldEMA)CloseGoldOrder(1);
      else if(useMaExit)CloseMaExit(1);
      else CloseBuy();
      //if ema angal<8 then CloseSell()

  }
  if(sells>0){
  	   //double maAngle = iCustom(Symbol(),0,"Angle of average + alerts 1_1",MAAnglePeriod,ma_ema,0,8,6,false,false,false,false,false,false,3,1);
		if(useDynamicExit){
		   if(maAngle >= -1*MaThreshold && maAngle <= MaThreshold){
			 use_tp_sl=1;
			 useMaExit = false;
		   } else {
			 use_tp_sl=0;
			 useMaExit = true;
		   }
	   }
      if(useCCI)CloseCCIOrder(2);
      else if(useReverseCandleExit)CloseByReverseCandle(numberOfCandleToExit,2);
      else if(useMAChannel)MA_Channel_Close(2);
      else if(useGoldEMA)CloseGoldOrder(2);
      else if(useMaExit)CloseMaExit(2);
      else CloseSell();
      //if ema angal<8 then CloseSell()
  }
  if(buys+sells>0){
    if(useBreakEven){
      DoBreakEven(breakEvenPips,0);
    }
    if(TrailingStop>0){
      DoTrailingStop();
    }
    // Change profit locker according to the order profit
    // profit_lock*order_profit;
    // if(order_profit > 50){
    // 	profit_lock = 0.6
    // } else
    if(order_profit > 40){
    	profit_lock = 0.9;
    } else
    if(order_profit > 30){
    	profit_lock = 0.8;
    } else
    if(order_profit > 20){
    	profit_lock = 0.7;
    } else
    if(order_profit > 10){
    	profit_lock = 0.6;
    }
  }
  
  // **************************************************
  // ORDERS>0 AND DIRECTION=1 AND USE_TP_SL=1
  // **************************************************
  if (orders>0 && direction==1 && use_tp_sl==1)
  {
    // CASO 1.1 >>> Tenemos el beneficio y  activamos el profit lock
    if (order_profit > CalculaTakeProfit() && max_profit==0)
    {
      max_profit = order_profit;
      close_profit = profit_lock*order_profit;      
    } 
    // CASO 1.2 >>> Segun va aumentando el beneficio actualizamos el profit lock
    if (max_profit>0)
    {
      if (order_profit>max_profit)
      {      
        max_profit = order_profit;
        close_profit = profit_lock*order_profit; 
      }
    }   
    // CASO 1.3 >>> Cuando el beneficio caiga por debajo de profit lock cerramos las ordenes
    if (max_profit>0 && close_profit>0 && max_profit>close_profit && order_profit<close_profit) 
    {
      cerrada=OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
      Print("Order Closed Due to close profit meet!","max_profit==:"+max_profit,"order_profit==:"+order_profit,"close_profit==:"
            +close_profit,"order_tickets=="+order_tickets);
      log("Order Closed Due to close profit meet!"+"max_profit==:"+max_profit+"order_profit==:"+order_profit+"close_profit==:"
            +close_profit+"order_tickets=="+order_tickets);
      max_profit=0;
      close_profit=0;  
    }
      
    // CASO 2 >>> Tenemos "size" pips de perdida
    if (order_profit <= CalculaStopLoss())
    {
      // cerrada=OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
      // max_profit=0;
      // close_profit=0;  
    }   
    
  }
    
  // **************************************************
  // ORDERS>0 AND DIRECTION=2 AND USE_TP_SL=1
  // **************************************************
  if (orders>0 && direction==2 && use_tp_sl==1)
  {
    // CASO 1.1 >>> Tenemos el beneficio y  activamos el profit lock
    if (order_profit > CalculaTakeProfit() && max_profit==0)
    {
      max_profit = order_profit;
      close_profit = profit_lock*order_profit;      
    } 
    // CASO 1.2 >>> Segun va aumentando el beneficio actualizamos el profit lock
    if (max_profit>0)
    {
      if (order_profit>max_profit)
      {      
        max_profit = order_profit;
        close_profit = profit_lock*order_profit; 
      }
    }   
    // CASO 1.3 >>> Cuando el beneficio caiga por debajo de profit lock cerramos las ordenes
    if (max_profit>0 && close_profit>0 && max_profit>close_profit && order_profit<close_profit) 
    {
      cerrada=OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
      log("Order Closed Due to close profit meet!"+"max_profit==:"+max_profit+"order_profit==:"+order_profit+"close_profit==:"
            +close_profit+"order_tickets=="+order_tickets);
      max_profit=0;
      close_profit=0;  
    }
      
    // CASO 2 >>> Tenemos "size" pips de perdida
    if (order_profit <= CalculaStopLoss())
    {
      // cerrada=OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
      // max_profit=0;
      // close_profit=0;  
    }   
  }
  
  // **************************************************
  // ORDERS>0 AND DIRECTION=1 AND USE_TP_SL=0
  // **************************************************
  if (orders>0 && direction==1 && use_tp_sl==0)
  {
    //signal = CalculaSignal(ma_mode,ma_period,shift);
    signal = CalculaSignal(MA_Method,mafast_period,maslow_period,shift);
    if (signal==2)
    {
      cerrada=OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
      max_profit=0;
      close_profit=0;    
    }  
  }
    
  // **************************************************
  // ORDERS>0 AND DIRECTION=2 AND USE_TP_SL=0
  // **************************************************
  if (orders>0 && direction==2 && use_tp_sl==0)
  {
    //signal = CalculaSignal(ma_mode,ma_period,shift);
    signal = CalculaSignal(MA_Method,mafast_period,maslow_period,shift);
    if (signal==1)
    {
      cerrada=OrderCloseReliable(order_tickets,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
      max_profit=0;
      close_profit=0;   
    }  
  }    
    
}

void Write(string name, string s, int x, int y, string font="Times New Roman", int size=20, color=Red)
{
  if (ObjectFind(name)!=-1)
  {
    ObjectSetText(name,s,size,font,c);
  }
  else
  {
    ObjectCreate(name,OBJ_LABEL,0,0,0);
    ObjectSetText(name,s,size,font,c);
    ObjectSet(name,OBJPROP_XDISTANCE, x);
    ObjectSet(name,OBJPROP_YDISTANCE, y);
  }
}

string strPeriod( int intPeriod )
{
	switch ( intPeriod )
	{
		case PERIOD_MN1: return("Monthly");
		case PERIOD_W1:  return("Weekly");
		case PERIOD_D1:  return("Daily");
		case PERIOD_H4:  return("H4");
		case PERIOD_H1:  return("H1");
		case PERIOD_M30: return("M30");
		case PERIOD_M15: return("M15");
		case PERIOD_M5:  return("M5");
		case PERIOD_M1:  return("M1");
		case PERIOD_M2:  return("M2");
		case PERIOD_M3:  return("M3");
		case PERIOD_M4:  return("M4");
		case PERIOD_M6:  return("M6");
		case PERIOD_M12:  return("M12");
		case PERIOD_M10:  return("M10");
		default:		 return("Offline");
	}
}

void log(string String)
{
   if(!debugMode){
      return;
   }
   int Handle;

   //if (!Auditing) return;
   string Filename = "logs\\" + key + " (" + Symbol() + ", " + strPeriod( Period() ) + 
							")\\" + TimeToStr( LocalTime(), TIME_DATE ) + ".txt";
							
   Handle = FileOpen(Filename, FILE_READ|FILE_WRITE|FILE_CSV, "/t");
   if (Handle < 1)
   {
      Print("Error opening audit file: Code ", GetLastError());
      return;
   }

   if (!FileSeek(Handle, 0, SEEK_END))
   {
      Print("Error seeking end of audit file: Code ", GetLastError());
      return;
   }

   if (FileWrite(Handle, TimeToStr(CurTime(), TIME_DATE|TIME_SECONDS) + "  " + String) < 1)
   {
      Print("Error writing to audit file: Code ", GetLastError());
      return;
   }

   FileClose(Handle);
}



//=============================================================================
//							 OrderSendReliable()
//
//	This is intended to be a drop-in replacement for OrderSend() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//	Ticket number or -1 under some error conditions.  Check
// final error returned by Metatrader with OrderReliableLastErr().
// This will reset the value from GetLastError(), so in that sense it cannot
// be a total drop-in replacement due to Metatrader flaw. 
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Automatic normalization of Digits
//
//		 * Automatically makes sure that stop levels are more than
//		   the minimum stop distance, as given by the server. If they
//		   are too close, they are adjusted.
//
//		 * Automatically converts stop orders to market orders 
//		   when the stop orders are rejected by the server for 
//		   being to close to market.  NOTE: This intentionally
//       applies only to OP_BUYSTOP and OP_SELLSTOP, 
//       OP_BUYLIMIT and OP_SELLLIMIT are not converted to market
//       orders and so for prices which are too close to current
//       this function is likely to loop a few times and return
//       with the "invalid stops" error message. 
//       Note, the commentary in previous versions erroneously said
//       that limit orders would be converted.  Note also
//       that entering a BUYSTOP or SELLSTOP new order is distinct
//       from setting a stoploss on an outstanding order; use
//       OrderModifyReliable() for that. 
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 2006-05-28 and following
//
//=============================================================================
int OrderSendReliable(string symbol, int cmd, double volume, double price,
					  int slippage, double stoploss, double takeprofit,
					  string comment, int magic, datetime expiration = 0, 
					  color arrow_color = CLR_NONE) 
{

	// ------------------------------------------------
	// Check basic conditions see if trade is possible. 
	// ------------------------------------------------
	OrderReliable_Fname = "OrderSendReliable";
	OrderReliablePrint(" attempted " + OrderReliable_CommandString(cmd) + " " + volume + 
						" lots @" + price + " sl:" + stoploss + " tp:" + takeprofit); 
						
	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(-1);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		_OR_err = ERR_COMMON_ERROR; 
		return(-1);
	}
	
	int cnt = 0;
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
		cnt++;
	}
	
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 

		return(-1);  
	}

	// Normalize all price / stoploss / takeprofit to the proper # of digits.
	int digits = MarketInfo(symbol, MODE_DIGITS);
	if (digits > 0) 
	{
		price = NormalizeDouble(price, digits);
		stoploss = NormalizeDouble(stoploss, digits);
		takeprofit = NormalizeDouble(takeprofit, digits); 
	}
	
	if (stoploss != 0) 
		OrderReliable_EnsureValidStop(symbol, price, stoploss); 

	int err = GetLastError(); // clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	bool limit_to_market = false; 
	
	// limit/stop order. 
	int ticket=-1;

	if ((cmd == OP_BUYSTOP) || (cmd == OP_SELLSTOP) || (cmd == OP_BUYLIMIT) || (cmd == OP_SELLLIMIT)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
				ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, 
									takeprofit, comment, magic, expiration, arrow_color);
				err = GetLastError();
				_OR_err = err; 
			} 
			else 
			{
				cnt++;
			} 
			
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
				
				// retryable errors
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; 
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					RefreshRates();
					continue;	// we can apparently retry immediately according to MT docs.
					
				case ERR_INVALID_STOPS:
					double servers_min_stop = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT); 
					if (cmd == OP_BUYSTOP) 
					{
						// If we are too close to put in a limit/stop order so go to market.
						if (MathAbs(MarketInfo(symbol,MODE_ASK) - price) <= servers_min_stop)	
							limit_to_market = true; 
							
					} 
					else if (cmd == OP_SELLSTOP) 
					{
						// If we are too close to put in a limit/stop order so go to market.
						if (MathAbs(MarketInfo(symbol,MODE_BID) - price) <= servers_min_stop)
							limit_to_market = true; 
					}
					exit_loop = true; 
					break; 
					
				default:
					// an apparently serious error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
				exit_loop = true; 
			 	
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
				}
			}
			 
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + cnt + "/" + retry_attempts + 
									"): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
				RefreshRates(); 
			}
		}
		 
		// We have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUYSTOP or OP_SELLSTOP order placed, details follow.");
			OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
			OrderPrint(); 
			return(ticket); // SUCCESS! 
		} 
		if (!limit_to_market) 
		{
			OrderReliablePrint("failed to execute stop or limit order after " + cnt + " retries");
			OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
								"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
			OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
			return(-1); 
		}
	}  // end	  
  
	if (limit_to_market) 
	{
		OrderReliablePrint("going from limit order to market order because market is too close.");
		if ((cmd == OP_BUYSTOP) || (cmd == OP_BUYLIMIT)) 
		{
			cmd = OP_BUY;
			price = MarketInfo(symbol,MODE_ASK);
		} 
		else if ((cmd == OP_SELLSTOP) || (cmd == OP_SELLLIMIT)) 
		{
			cmd = OP_SELL;
			price = MarketInfo(symbol,MODE_BID);
		}	
	}
	
	// we now have a market order.
	err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	ticket = -1;

	if ((cmd == OP_BUY) || (cmd == OP_SELL)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
				ticket = OrderSend(symbol, cmd, volume, price, slippage, 
									stoploss, takeprofit, comment, magic, 
									expiration, arrow_color);
				err = GetLastError();
				_OR_err = err; 
			} 
			else 
			{
				cnt++;
			} 
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
					
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; // a retryable error
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					RefreshRates();
					continue; // we can apparently retry immediately according to MT docs.
					
				default:
					// an apparently serious, unretryable error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
			 	exit_loop = true; 
			 	
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + cnt + "/" + 
									retry_attempts + "): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
				RefreshRates(); 
			}
			
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
				}
			}
		}
		
		// we have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUY or OP_SELL order placed, details follow.");
			OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
			OrderPrint(); 
			return(ticket); // SUCCESS! 
		} 
		OrderReliablePrint("failed to execute OP_BUY/OP_SELL, after " + cnt + " retries");
		OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
							"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
		OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
		return(-1); 
	}
}
	
//=============================================================================
//							 OrderSendReliableMKT()
//
//	This is intended to be an alternative for OrderSendReliable() which
// will update market-orders in the retry loop with the current Bid or Ask.
// Hence with market orders there is a greater likelihood that the trade will
// be executed versus OrderSendReliable(), and a greater likelihood it will
// be executed at a price worse than the entry price due to price movement. 
//			  
//	RETURN VALUE: 
//
//	Ticket number or -1 under some error conditions.  Check
// final error returned by Metatrader with OrderReliableLastErr().
// This will reset the value from GetLastError(), so in that sense it cannot
// be a total drop-in replacement due to Metatrader flaw. 
//
//	FEATURES:
//
//     * Most features of OrderSendReliable() but for market orders only. 
//       Command must be OP_BUY or OP_SELL, and specify Bid or Ask at
//       the time of the call.
//
//     * If price moves in an unfavorable direction during the loop,
//       e.g. from requotes, then the slippage variable it uses in 
//       the real attempt to the server will be decremented from the passed
//       value by that amount, down to a minimum of zero.   If the current
//       price is too far from the entry value minus slippage then it
//       will not attempt an order, and it will signal, manually,
//       an ERR_INVALID_PRICE (displayed to log as usual) and will continue
//       to loop the usual number of times. 
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 2006-08-16
//
//=============================================================================
int OrderSendReliableMKT(string symbol, int cmd, double volume, double price,
					  int slippage, double stoploss, double takeprofit,
					  string comment, int magic, datetime expiration = 0, 
					  color arrow_color = CLR_NONE) 
{

	// ------------------------------------------------
	// Check basic conditions see if trade is possible. 
	// ------------------------------------------------
	OrderReliable_Fname = "OrderSendReliableMKT";
	OrderReliablePrint(" attempted " + OrderReliable_CommandString(cmd) + " " + volume + 
						" lots @" + price + " sl:" + stoploss + " tp:" + takeprofit); 

   if ((cmd != OP_BUY) && (cmd != OP_SELL)) {
      OrderReliablePrint("Improper non market-order command passed.  Nothing done.");
      _OR_err = ERR_MALFUNCTIONAL_TRADE; 
      return(-1);
   }

	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(-1);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		_OR_err = ERR_COMMON_ERROR; 
		return(-1);
	}
	
	int cnt = 0;
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
		cnt++;
	}
	
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 

		return(-1);  
	}

	// Normalize all price / stoploss / takeprofit to the proper # of digits.
	int digits = MarketInfo(symbol, MODE_DIGITS);
	if (digits > 0) 
	{
		price = NormalizeDouble(price, digits);
		stoploss = NormalizeDouble(stoploss, digits);
		takeprofit = NormalizeDouble(takeprofit, digits); 
	}
	
	if (stoploss != 0) 
		OrderReliable_EnsureValidStop(symbol, price, stoploss); 

	int err = GetLastError(); // clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	
	// limit/stop order. 
	int ticket=-1;

	// we now have a market order.
	err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	ticket = -1;

	if ((cmd == OP_BUY) || (cmd == OP_SELL)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
            double pnow = price;
            int slippagenow = slippage;
            if (cmd == OP_BUY) {
            	// modification by Paul Hampton-Smith to replace RefreshRates()
               pnow = NormalizeDouble(MarketInfo(symbol,MODE_ASK),MarketInfo(symbol,MODE_DIGITS)); // we are buying at Ask
               if (pnow > price) {
                  slippagenow = slippage - (pnow-price)/MarketInfo(symbol,MODE_POINT); 
               }
            } else if (cmd == OP_SELL) {
            	// modification by Paul Hampton-Smith to replace RefreshRates()
               pnow = NormalizeDouble(MarketInfo(symbol,MODE_BID),MarketInfo(symbol,MODE_DIGITS)); // we are buying at Ask
               if (pnow < price) {
                  // moved in an unfavorable direction
                  slippagenow = slippage - (price-pnow)/MarketInfo(symbol,MODE_POINT);
               }
            }
            if (slippagenow > slippage) slippagenow = slippage; 
            if (slippagenow >= 0) {
            
				   ticket = OrderSend(symbol, cmd, volume, pnow, slippagenow, 
									stoploss, takeprofit, comment, magic, 
									expiration, arrow_color);
			   	err = GetLastError();
			   	_OR_err = err; 
			  } else {
			      // too far away, manually signal ERR_INVALID_PRICE, which
			      // will result in a sleep and a retry. 
			      err = ERR_INVALID_PRICE;
			      _OR_err = err; 
			  }
			} 
			else 
			{
				cnt++;
			} 
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
					
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; // a retryable error
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					// Paul Hampton-Smith removed RefreshRates() here and used MarketInfo() above instead
					continue; // we can apparently retry immediately according to MT docs.
					
				default:
					// an apparently serious, unretryable error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
			 	exit_loop = true; 
			 	
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + cnt + "/" + 
									retry_attempts + "): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
			}
			
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
				}
			}
		}
		
		// we have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUY or OP_SELL order placed, details follow.");
			OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
			OrderPrint(); 
			return(ticket); // SUCCESS! 
		} 
		OrderReliablePrint("failed to execute OP_BUY/OP_SELL, after " + cnt + " retries");
		OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
							"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
		OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
		return(-1); 
	}
}
		
	
//=============================================================================
//							 OrderModifyReliable()
//
//	This is intended to be a drop-in replacement for OrderModify() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//		TRUE if successful, FALSE otherwise
//
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 	2006-05-28
//
//=============================================================================
bool OrderModifyReliable(int ticket, double price, double stoploss, 
						 double takeprofit, datetime expiration, 
						 color arrow_color = CLR_NONE) 
{
	OrderReliable_Fname = "OrderModifyReliable";

	OrderReliablePrint(" attempted modify of #" + ticket + " price:" + price + 
						" sl:" + stoploss + " tp:" + takeprofit); 

	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(false);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		return(false);
	}
	
	int cnt = 0;
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
		cnt++;
	}
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 
		return(false);  
	}


	
	if (false) {
		 // This section is 'nulled out', because
		 // it would have to involve an 'OrderSelect()' to obtain
		 // the symbol string, and that would change the global context of the
		 // existing OrderSelect, and hence would not be a drop-in replacement
		 // for OrderModify().
		 //
		 // See OrderModifyReliableSymbol() where the user passes in the Symbol 
		 // manually.
		 
		 OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
		 string symbol = OrderSymbol();
		 int digits = MarketInfo(symbol,MODE_DIGITS);
		 if (digits > 0) {
			 price = NormalizeDouble(price,digits);
			 stoploss = NormalizeDouble(stoploss,digits);
			 takeprofit = NormalizeDouble(takeprofit,digits); 
		 }
		 if (stoploss != 0) OrderReliable_EnsureValidStop(symbol,price,stoploss); 
	}



	int err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	cnt = 0;
	bool result = false;
	
	while (!exit_loop) 
	{
		if (IsTradeAllowed()) 
		{
			result = OrderModify(ticket, price, stoploss, 
								 takeprofit, expiration, arrow_color);
			err = GetLastError();
			_OR_err = err; 
		} 
		else 
			cnt++;

		if (result == true) 
			exit_loop = true;

		switch (err) 
		{
			case ERR_NO_ERROR:
				exit_loop = true;
				break;
				
			case ERR_NO_RESULT:
				// modification without changing a parameter. 
				// if you get this then you may want to change the code.
				exit_loop = true;
				break;
				
			case ERR_SERVER_BUSY:
			case ERR_NO_CONNECTION:
			case ERR_INVALID_PRICE:
			case ERR_OFF_QUOTES:
			case ERR_BROKER_BUSY:
			case ERR_TRADE_CONTEXT_BUSY: 
			case ERR_TRADE_TIMEOUT:		// for modify this is a retryable error, I hope. 
				cnt++; 	// a retryable error
				break;
				
			case ERR_PRICE_CHANGED:
			case ERR_REQUOTE:
				RefreshRates();
				continue; 	// we can apparently retry immediately according to MT docs.
				
			default:
				// an apparently serious, unretryable error.
				exit_loop = true;
				break; 
				
		}  // end switch 

		if (cnt > retry_attempts) 
			exit_loop = true; 
			
		if (!exit_loop) 
		{
			OrderReliablePrint("retryable error (" + cnt + "/" + retry_attempts + 
								"): "  +  OrderReliableErrTxt(err)); 
			OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
			RefreshRates(); 
		}
		
		if (exit_loop) 
		{
			if ((err != ERR_NO_ERROR) && (err != ERR_NO_RESULT)) 
				OrderReliablePrint("non-retryable error: "  + OrderReliableErrTxt(err)); 

			if (cnt > retry_attempts) 
				OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
		}
	}  
	
	// we have now exited from loop. 
	if ((result == true) || (err == ERR_NO_ERROR)) 
	{
		OrderReliablePrint("apparently successful modification order, updated trade details follow.");
		OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
		OrderPrint(); 
		return(true); // SUCCESS! 
	} 
	
	if (err == ERR_NO_RESULT) 
	{
		OrderReliablePrint("Server reported modify order did not actually change parameters.");
		OrderReliablePrint("redundant modification: "  + ticket + " " + symbol + 
							"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
		OrderReliablePrint("Suggest modifying code logic to avoid."); 
		return(true);
	}
	
	OrderReliablePrint("failed to execute modify after " + cnt + " retries");
	OrderReliablePrint("failed modification: "  + ticket + " " + symbol + 
						"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
	OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
	
	return(false);  
}
 
 
//=============================================================================
//
//						OrderModifyReliableSymbol()
//
//	This has the same calling sequence as OrderModify() except that the 
//	user must provide the symbol.
//
//	This function will then be able to ensure proper normalization and 
//	stop levels.
//
//=============================================================================
bool OrderModifyReliableSymbol(string symbol, int ticket, double price, 
							   double stoploss, double takeprofit, 
							   datetime expiration, color arrow_color = CLR_NONE) 
{
	int digits = MarketInfo(symbol, MODE_DIGITS);
	
	if (digits > 0) 
	{
		price = NormalizeDouble(price, digits);
		stoploss = NormalizeDouble(stoploss, digits);
		takeprofit = NormalizeDouble(takeprofit, digits); 
	}
	
	if (stoploss != 0) 
		OrderReliable_EnsureValidStop(symbol, price, stoploss); 
		
	return(OrderModifyReliable(ticket, price, stoploss, 
								takeprofit, expiration, arrow_color)); 
	
}
 
 
//=============================================================================
//							 OrderCloseReliable()
//
//	This is intended to be a drop-in replacement for OrderClose() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//		TRUE if successful, FALSE otherwise
//
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Derk Wehler, ashwoods155@yahoo.com  	2006-07-19
//
//=============================================================================
bool OrderCloseReliable(int ticket, double lots, double price, 
						int slippage, color arrow_color = CLR_NONE) 
{
	int nOrderType;
	string strSymbol;
	OrderReliable_Fname = "OrderCloseReliable";
	
	OrderReliablePrint(" attempted close of #" + ticket + " price:" + price + 
						" lots:" + lots + " slippage:" + slippage); 

// collect details of order so that we can use GetMarketInfo later if needed
	if (!OrderSelect(ticket,SELECT_BY_TICKET))
	{
		_OR_err = GetLastError();		
		OrderReliablePrint("error: " + ErrorDescription(_OR_err));
		return(false);
	}
	else
	{
		nOrderType = OrderType();
		strSymbol = OrderSymbol();
	}

	if (nOrderType != OP_BUY && nOrderType != OP_SELL)
	{
		_OR_err = ERR_INVALID_TICKET;
		OrderReliablePrint("error: trying to close ticket #" + ticket + ", which is " + OrderReliable_CommandString(nOrderType) + ", not OP_BUY or OP_SELL");
		return(false);
	}

	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(false);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		return(false);
	}

	
	int cnt = 0;
/*	
	Commented out by Paul Hampton-Smith due to a bug in MT4 that sometimes incorrectly returns IsTradeAllowed() = false
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
		cnt++;
	}
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 
		return(false);  
	}
*/

	int err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	cnt = 0;
	bool result = false;
	
	while (!exit_loop) 
	{
		if (IsTradeAllowed()) 
		{
			result = OrderClose(ticket, lots, price, slippage, arrow_color);
			err = GetLastError();
			_OR_err = err; 
		} 
		else 
			cnt++;

		if (result == true) 
			exit_loop = true;

		switch (err) 
		{
			case ERR_NO_ERROR:
				exit_loop = true;
				break;
				
			case ERR_SERVER_BUSY:
			case ERR_NO_CONNECTION:
			case ERR_INVALID_PRICE:
			case ERR_OFF_QUOTES:
			case ERR_BROKER_BUSY:
			case ERR_TRADE_CONTEXT_BUSY: 
			case ERR_TRADE_TIMEOUT:		// for modify this is a retryable error, I hope. 
				cnt++; 	// a retryable error
				break;
				
			case ERR_PRICE_CHANGED:
			case ERR_REQUOTE:
				continue; 	// we can apparently retry immediately according to MT docs.
				
			default:
				// an apparently serious, unretryable error.
				exit_loop = true;
				break; 
				
		}  // end switch 

		if (cnt > retry_attempts) 
			exit_loop = true; 
			
		if (!exit_loop) 
		{
			OrderReliablePrint("retryable error (" + cnt + "/" + retry_attempts + 
								"): "  +  OrderReliableErrTxt(err)); 
			OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
			// Added by Paul Hampton-Smith to ensure that price is updated for each retry
			if (nOrderType == OP_BUY)  price = NormalizeDouble(MarketInfo(strSymbol,MODE_BID),MarketInfo(strSymbol,MODE_DIGITS));
			if (nOrderType == OP_SELL) price = NormalizeDouble(MarketInfo(strSymbol,MODE_ASK),MarketInfo(strSymbol,MODE_DIGITS));
		}
		
		if (exit_loop) 
		{
			if ((err != ERR_NO_ERROR) && (err != ERR_NO_RESULT)) 
				OrderReliablePrint("non-retryable error: "  + OrderReliableErrTxt(err)); 

			if (cnt > retry_attempts) 
				OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
		}
	}  
	
	// we have now exited from loop. 
	if ((result == true) || (err == ERR_NO_ERROR)) 
	{
		OrderReliablePrint("apparently successful close order, updated trade details follow.");
		OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
		OrderPrint(); 
		return(true); // SUCCESS! 
	} 
	
	OrderReliablePrint("failed to execute close after " + cnt + " retries");
	OrderReliablePrint("failed close: Ticket #" + ticket + ", Price: " + 
						price + ", Slippage: " + slippage); 
	OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
	
	return(false);  
}
 
 

//=============================================================================
//=============================================================================
//								Utility Functions
//=============================================================================
//=============================================================================



int OrderReliableLastErr() 
{
	return (_OR_err); 
}


string OrderReliableErrTxt(int err) 
{
	return ("" + err + ":" + ErrorDescription(err)); 
}


void OrderReliablePrint(string s) 
{
	// Print to log prepended with stuff;
	if (!(IsTesting() || IsOptimization())) Print(OrderReliable_Fname + " " + OrderReliableVersion + ":" + s);
}


string OrderReliable_CommandString(int cmd) 
{
	if (cmd == OP_BUY) 
		return("OP_BUY");

	if (cmd == OP_SELL) 
		return("OP_SELL");

	if (cmd == OP_BUYSTOP) 
		return("OP_BUYSTOP");

	if (cmd == OP_SELLSTOP) 
		return("OP_SELLSTOP");

	if (cmd == OP_BUYLIMIT) 
		return("OP_BUYLIMIT");

	if (cmd == OP_SELLLIMIT) 
		return("OP_SELLLIMIT");

	return("(CMD==" + cmd + ")"); 
}


//=============================================================================
//
//						 OrderReliable_EnsureValidStop()
//
// 	Adjust stop loss so that it is legal.
//
//	Matt Kennel 
//
//=============================================================================
void OrderReliable_EnsureValidStop(string symbol, double price, double& sl) 
{
	// Return if no S/L
	if (sl == 0) 
		return;
	
	double servers_min_stop = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT); 
	
	if (MathAbs(price - sl) <= servers_min_stop) 
	{
		// we have to adjust the stop.
		if (price > sl)
			sl = price - servers_min_stop;	// we are long
			
		else if (price < sl)
			sl = price + servers_min_stop;	// we are short
			
		else
			OrderReliablePrint("EnsureValidStop: error, passed in price == sl, cannot adjust"); 
			
		sl = NormalizeDouble(sl, MarketInfo(symbol, MODE_DIGITS)); 
	}
}


//=============================================================================
//
//						 OrderReliable_SleepRandomTime()
//
//	This sleeps a random amount of time defined by an exponential 
//	probability distribution. The mean time, in Seconds is given 
//	in 'mean_time'.
//
//	This is the back-off strategy used by Ethernet.  This will 
//	quantize in tenths of seconds, so don't call this with a too 
//	small a number.  This returns immediately if we are backtesting
//	and does not sleep.
//
//	Matt Kennel mbkennelfx@gmail.com.
//
//=============================================================================
void OrderReliable_SleepRandomTime(double mean_time, double max_time) 
{
	if (IsTesting()) 
		return; 	// return immediately if backtesting.

	double tenths = MathCeil(mean_time / 0.1);
	if (tenths <= 0) 
		return; 
	 
	int maxtenths = MathRound(max_time/0.1); 
	double p = 1.0 - 1.0 / tenths; 
	  
	Sleep(100); 	// one tenth of a second PREVIOUS VERSIONS WERE STUPID HERE. 
	
	for(int i=0; i < maxtenths; i++)  
	{
		if (MathRand() > p*32768) 
			break; 
			
		// MathRand() returns in 0..32767
		Sleep(100); 
	}
}  


