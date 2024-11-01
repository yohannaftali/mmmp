//+------------------------------------------------------------------+
//|                                               Martingale Grid M1 |
//|                                    Copyright 2024, Yohan Naftali |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yohan Naftali"
#property link      "https://github.com/yohannaftali"
#property version   "241.029"
#property strict

#include <Strings\String.mqh>
#include <Trade\Trade.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Trade Classes                                                    |
//+------------------------------------------------------------------+
CTrade            trade;    // trade operations execution
CPositionInfo     position; // working with open position properties

//+------------------------------------------------------------------+
//| Global Enum                                                      |
//+------------------------------------------------------------------+
enum ENUM_ORDER_DIRECTION
{
  DIRECTION_BUY_ONLY = 1,  // Buy Only
  DIRECTION_SELL_ONLY = 2, // Sell Only
  DIRECTION_BUY_SELL = 3   // Buy And Sell
};

enum ENUM_MARTINGALE_SEQUENCES
{
  SEQ_ARITHMETIC = 1,      // Arithmetic Sequences
  SEQ_GEOMETRIC = 2,       // Geometric Sequences
  SEQ_GEOMETRIC_ROUND = 3  // Geometric Sequences with Rounded Factor
};

//+------------------------------------------------------------------+
//| Input                                                            |
//+------------------------------------------------------------------+
input group "Strategy";
input ENUM_ORDER_DIRECTION ORDER_DIRECTION = DIRECTION_BUY_SELL;            // Order Direction
input ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M1;                                // Timeframe Period

input group "Condition to Start First Buy Order";
input bool USE_RSI_FOR_FIRST_BUY = false;                                   // Use RSI Condition for First Order Buy
input double RSI_RANGE_FROM_BUY = 20;                                       // RSI Range From, e.g. 20
input double RSI_RANGE_TO_BUY = 80;                                         // RSI Range To, e.g. 80
input ENUM_TIMEFRAMES RSI_RANGE_PERIOD_BUY = PERIOD_M15;                    // Timeframe
input int RSI_RANGE_LENGTH_BUY = 7;                                         // Length

input group "Condition to Start First Sell Order";
input bool USE_RSI_FOR_FIRST_SELL = false;                                  // Use RSI Condition for First Order Sell
input double RSI_RANGE_FROM_SELL = 20;                                      // RSI Range From, e.g. 20
input double RSI_RANGE_TO_SELL = 80;                                        // RSI Range To, e.g. 80
input ENUM_TIMEFRAMES RSI_RANGE_PERIOD_SELL = PERIOD_M15;                   // Timeframe
input int RSI_RANGE_LENGTH_SELL = 7;                                        // Length

input group "Volume";
input double BASE_VOLUME = 0;                                               // Fixed Base Volume (a1), set 0 to use dynamic base volume
input double BASE_VOLUME_LOT_STEP = 0.01;                                   // Dynamic Base Volume Lot Step (ls) (increase lot every increasing balance step)
input double BASE_VOLUME_BALANCE_STEP = 40000;                              // Dynamic Base Volume Balance Step (bs) (p = ls/bs) (a1 = rounddown(p/min_volume)*min_volume)
input ENUM_MARTINGALE_SEQUENCES MARTINGALE_SEQUENCES = SEQ_GEOMETRIC_ROUND; // Volume Scale Sequence
input double MULTIPLIER_ARITHMETIC = 0;                                     // Arithmetic Volume Scale Multiplier (d = distance), an = a1 + d*(n-1)
input double MULTIPLIER_GEOMETRIC = 1.055;                                  // Geometric Volume Scale Multiplier (r = ratio), an = a1*r^(n-1)

input group "Deviation Grid Step Price";
input double BASE_STEP = 0;                                                 // Price Deviation in Percentage to Open Next Grid (a1) (%), 0 to disable
input double MULTIPLIER_STEP = 0;                                           // Grid Step Scale Multiplier (d = distance), an = a1 + d*(n-1), 0 for fixed distance

input group "TP By Point";
input int TP_BY_POINT_BUY = 58;                                             // Buy Take Profit by Point (Point), 0 to disable
input int TP_BY_POINT_SELL = 47;                                            // Sell Take Profit by Point (Point), 0 to disable
input double MODIFY_STEP_TP_POINT = 5;                                      // Step Modify Take Profit by Point

input group "TP By Price Percentage";
input double TP_BY_PRICE_PERCENTAGE_BUY = 0;                                // Buy Take Profit by Price Percentage (%), 0 to disable
input double TP_BY_PRICE_PERCENTAGE_SELL = 0;                               // Sell Take Profit by Price Percentage (%), 0 to disable
input double MODIFY_STEP_TP_PERCENT = 0.1;                                  // Step Modify Take Profit by Price Percentage (%)

input group "TP By Price Balance";
input double TP_BY_BALANCE_PERCENTAGE = 0;                                  // Take Profit by Balance Percentage (%), 0 to disable

input group "Condition to Stop New Order Buy";
input double MAX_VOLUME_BUY = 0;                                            // Maximum Volume for Buy Order, 0 to disable
input int MAX_GRID_BUY = 0;                                                 // Maximum Grid Buy Position, 0 to disable

input group "Condition to Stop New Order Sell";
input double MAX_VOLUME_SELL = 0;                                           // Maximum Volume for Sell Order, 0 to disable
input int MAX_GRID_SELL = 0;                                                // Maximum Grid Sell Position, 0 to disable

input group "Condition to Boost Position Buy when RSI reached";
input int TIMER_OPEN_BUY = 0;                                               // Open new buy position in timeframe every n seconds, 0 to disable
input int MIN_GRID_BOOST_BUY = 20;                                          // No of minimum grid to activate boost, 0 to disable
input int MAX_GRID_BOOST_BUY = 0;                                           // No of maximum grid adding boost, 0 to disable
input double RSI_OVERSOLD = 10;                                             // RSI Oversold Threshold
input ENUM_TIMEFRAMES RSI_PERIOD_BUY = PERIOD_M15;                          // RSI Oversold Period
input int RSI_LENGTH_BUY = 7;                                               // RSI Oversold Length

input group "Condition to Boost Position Sell when RSI reached";
input int TIMER_OPEN_SELL = 0;                                              // Open new sell position in timeframe every n seconds, 0 to disable
input int MIN_GRID_BOOST_SELL = 20;                                         // No of minimum grid to activate boost, 0 to disable
input int MAX_GRID_BOOST_SELL = 20;                                         // No of maximum grid adding boost, 0 to disable
input double RSI_OVERBOUGHT = 90;                                           // RSI Overbought Threshold
input ENUM_TIMEFRAMES RSI_PERIOD_SELL = PERIOD_M15;                         // RSI Overbought Period
input int RSI_LENGTH_SELL = 7;                                              // RSI Overbought Length

input group "EA";
input int MAGIC_NUMBER = 1;                                                 // EA Magic Number
input string COMMENT = "GM_M1";                                             // EA Comment

input group "Trade";
input int SLIPPAGE = 100;                                                   // Slippage (Point)

input group "Telegram";
input bool SEND_TELEGRAM = false;                                           // Send Telegram (allow web request to https://api.telegram.org)
input const string API_KEY = "";                                            // API Key
input string CHANNEL_ID = "";                                               // Channel ID
input double CAPITAL_ALL = 600000;                                          // Capital All pair
input double CAPITAL_EA = 200000;                                           // Capital Current EA
input int OFFSET_TIMEZONE_LOCAL = 7;                                        // Timezone Local for Report

//+------------------------------------------------------------------+
//| Global Constant                                                  |
//+------------------------------------------------------------------+
const string TELEGRAM_API_URL = "https://api.telegram.org";
const string SYSTEM_TAG = "GM_" + IntegerToString(MAGIC_NUMBER);
const string ADD_BUY_BUTTON = SYSTEM_TAG + "_ADD_BUY_BUTTON";
const string ADD_SELL_BUTTON = SYSTEM_TAG + "_ADD_SELL_BUTTON";
const string CLOSE_BUY_BUTTON = SYSTEM_TAG + "_CLOSE_BUY_BUTTON";
const string CLOSE_SELL_BUTTON = SYSTEM_TAG + "_CLOSE_SELL_BUTTON";
const string CLOSE_ALL_BUTTON = SYSTEM_TAG + "_CLOSE_ALL_BUTTON";
const string PAUSE_BUY_BUTTON = SYSTEM_TAG + "_PAUSE_BUY_BUTTON";
const string RESUME_BUY_BUTTON = SYSTEM_TAG + "_RESUME_BUY_BUTTON";
const string PAUSE_SELL_BUTTON = SYSTEM_TAG + "_PAUSE_SELL_BUTTON";
const string RESUME_SELL_BUTTON = SYSTEM_TAG + "_RESUME_SELL_BUTTON";
const string PAUSE_ALL_BUTTON = SYSTEM_TAG + "_PAUSE_ALL_BUTTON";
const string RESUME_ALL_BUTTON = SYSTEM_TAG + "_RESUME_ALL_BUTTON";
const string MODIFY_POINT_UP_BUY_BUTTON = SYSTEM_TAG + "_MODIFY_POINT_UP_BUY_BUTTON";
const string MODIFY_POINT_UP_SELL_BUTTON = SYSTEM_TAG + "_MODIFY_POINT_UP_SELL_BUTTON";
const string MODIFY_POINT_DOWN_BUY_BUTTON = SYSTEM_TAG + "_MODIFY_POINT_DOWN_BUY_BUTTON";
const string MODIFY_POINT_DOWN_SELL_BUTTON = SYSTEM_TAG + "_MODIFY_POINT_DOWN_SELL_BUTTON";
const string MODIFY_PERCENTAGE_UP_BUY_BUTTON = SYSTEM_TAG + "_MODIFY_PERCENTAGE_UP_BUY_BUTTON";
const string MODIFY_PERCENTAGE_UP_SELL_BUTTON = SYSTEM_TAG + "_MODIFY_PERCENTAGE_UP_SELL_BUTTON";
const string MODIFY_PERCENTAGE_DOWN_BUY_BUTTON = SYSTEM_TAG + "_MODIFY_PERCENTAGE_DOWN_BUY_BUTTON";
const string MODIFY_PERCENTAGE_DOWN_SELL_BUTTON = SYSTEM_TAG + "_MODIFY_PERCENTAGE_DOWN_SELL_BUTTON";
const string SEND_TELEGRAM_BUTTON = SYSTEM_TAG + "_SEND_TELEGRAM_BUTTON";

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int digitPrice;
int digitVolume;
double symbolPoint;
double baseVolume;
double maxVolume;
double minVolume;
double tpByBalancePercentage = 0;
double tpByPointBuy = 0;
double tpByPointSell = 0;
double tpByPricePercentageBuy = 0;
double tpByPricePercentageSell = 0;
double marginPriceByPointBuy;
double marginPriceByPointSell;
int offsetTimezone = 0;
bool pauseBuy;
bool pauseSell;
int lastGridBuy;
double lastVolumeBuy;
int lastGridSell;
double lastVolumeSell;
int rsiHandleBuy;
int timerBuy;
int timerSell;
int rsiHandleSell;
int rsiHandleFirstBuy;
int rsiHandleFirstSell;
double nextPriceBuy = 0;
double nextPriceSell = 0;
double currentDrawdown = 0;
double maxTodayDrawdown = 0;
double maxDrawdown = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  datetime current = TimeCurrent();
  datetime server = TimeTradeServer();
  datetime gmt = TimeGMT();
  datetime local = TimeLocal();
  offsetTimezone = ((int) current - (int) gmt)/(60*60);
  MqlDateTime localCurrent = toLocalMqlDateTime(current);

  pauseBuy = false;
  pauseSell = false;

  double balance = ACCOUNT_BALANCE;
  double equity = ACCOUNT_EQUITY;
  double margin = ACCOUNT_MARGIN;
  double freeMargin = ACCOUNT_MARGIN_FREE;

  symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  digitPrice = (int) SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  tpByBalancePercentage = TP_BY_BALANCE_PERCENTAGE;
  tpByPointBuy = TP_BY_POINT_BUY;
  tpByPointSell = TP_BY_POINT_SELL;
  tpByPricePercentageBuy = TP_BY_PRICE_PERCENTAGE_BUY;
  tpByPricePercentageSell = TP_BY_PRICE_PERCENTAGE_SELL;

  marginPriceByPointBuy = tpByPointBuy * symbolPoint;
  marginPriceByPointSell = tpByPointSell * symbolPoint;

  double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  minVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
  maxVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
  digitVolume = getDigit(step);

  calculateBaseVolume();

  lastGridBuy = countOrder(POSITION_TYPE_BUY);
  lastGridSell = countOrder(POSITION_TYPE_SELL);

  trade.SetDeviationInPoints(SLIPPAGE);
  trade.SetExpertMagicNumber(MAGIC_NUMBER);

  // Handle RSI
  rsiHandleBuy = iRSI(_Symbol, RSI_PERIOD_BUY, RSI_LENGTH_BUY, PRICE_CLOSE);
  if(rsiHandleBuy == INVALID_HANDLE) {
    Print("Invalid RSI, error: ",_LastError);
    return(INIT_FAILED);
  }

  rsiHandleSell = iRSI(_Symbol, RSI_PERIOD_SELL, RSI_LENGTH_SELL, PRICE_CLOSE);
  if(rsiHandleSell == INVALID_HANDLE) {
    Print("Invalid RSI, error: ",_LastError);
    return(INIT_FAILED);
  }

  if(USE_RSI_FOR_FIRST_BUY) {
    rsiHandleFirstBuy = iRSI(_Symbol, RSI_RANGE_PERIOD_BUY, RSI_RANGE_LENGTH_BUY, PRICE_CLOSE);
  }

  if(USE_RSI_FOR_FIRST_SELL) {
    rsiHandleFirstSell = iRSI(_Symbol, RSI_RANGE_PERIOD_SELL, RSI_RANGE_LENGTH_SELL, PRICE_CLOSE);
  }

  // Set Timer
  EventSetTimer(1);
  timerBuy = 0;
  timerSell = 0;

  // Chart
  ObjectsDeleteAll(ChartID(), SYSTEM_TAG);

  showAddBuyButton();
  showAddSellButton();
  showCloseBuyButton();
  showCloseSellButton();
  showCloseAllButton();
  showPauseBuyButton();
  showPauseSellButton();
  showPauseAllButton();
  showSendTelegramButton();

  if(TP_BY_POINT_BUY > 0) {
    showModifyTpPointUpBuyButton();
    showModifyTpPointDownBuyButton();
  }

  if(TP_BY_POINT_SELL > 0) {
    showModifyTpPointUpSellButton();
    showModifyTpPointDownSellButton();
  }

  if(TP_BY_PRICE_PERCENTAGE_BUY > 0) {
    showModifyTpPricePercentageUpBuyButton();
    showModifyTpPricePercentageDownBuyButton();
  }

  if(TP_BY_PRICE_PERCENTAGE_SELL > 0) {
    showModifyTpPricePercentageUpSellButton();
    showModifyTpPricePercentageDownSellButton();
  }

  // Print information
  Print("# Time Info");
  Print("- GMT Time: " + TimeToString(gmt));
  Print("- Current Time: " + TimeToString(current));
  Print("- Trade Server Time: " + TimeToString(server));
  Print("- Offset From GMT: " + IntegerToString(offsetTimezone));
  Print("- PC Local Time: " + TimeToString(local));
  Print("- Local Report Time: " + TimeToString(StructToTime(localCurrent)));

  Print("# Account Info");
  Print("- Balance: " + DoubleToString(balance, 2));
  Print("- Equity: " + DoubleToString(equity, 2));
  Print("- Margin: " + DoubleToString(margin, 2));
  Print("- Free Margin: " + DoubleToString(freeMargin, 2));

  Print("# Risk Management Info");
  Print("- Direction: " + EnumToString(ORDER_DIRECTION));
  Print("- Base Order Size (a): " + DoubleToString(baseVolume, 2) + " lot");
  Print("- Martingle Sequences: " +  EnumToString(MARTINGALE_SEQUENCES));
  Print("- Arithmetic Multiplier(r): " + DoubleToString(MULTIPLIER_ARITHMETIC, 4) + "*(n-1)");
  Print("- Geometric Multiplier (r): " + DoubleToString(MULTIPLIER_GEOMETRIC, 4) + "^(n-1)");
  Print("- Symbol Step: " + DoubleToString(step, _Digits));
  Print("- Minimum Volume:" + DoubleToString(minVolume, 2) + " lot");
  Print("- Maximum Volume:" + DoubleToString(maxVolume, 2) + " lot");
  Print("- Margin Price Buy:" + DoubleToString(marginPriceByPointBuy, _Digits) + " (" + IntegerToString(TP_BY_POINT_BUY) + ")");
  Print("- Margin Price Sell:" + DoubleToString(marginPriceByPointBuy, _Digits) + " (" + IntegerToString(TP_BY_POINT_SELL) + ")");

  Print("# Symbol Info");
  Print("- Symbol: " + _Symbol);
  Print("- SymbolPoint: " + DoubleToString(symbolPoint, _Digits));
  Print("- Digit Price: " + IntegerToString(digitPrice, _Digits));
  Print("- Digit Volume: " + IntegerToString(digitVolume, _Digits));

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  EventKillTimer();
  deleteObject();
  Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  handleTakeProfitEvent();
  handleTPByBalancePercentage();

  if(!isNewBar()) return;
  timerBuy = 0;
  timerSell = 0;
  double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  askPrice = NormalizeDouble(askPrice, _Digits);
  double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  bidPrice = NormalizeDouble(bidPrice, _Digits);
  setupTrade(askPrice, bidPrice);
  showRealtimeInfo();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
  if(TIMER_OPEN_BUY == 0 && TIMER_OPEN_SELL == 0) return;
  timerBuy++;
  timerSell++;
  boostBuyPosition();
  boostSellPosition();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void boostBuyPosition()
{
  if(ORDER_DIRECTION == DIRECTION_SELL_ONLY) return;
  if(TIMER_OPEN_BUY == 0) return;
  if(timerBuy < TIMER_OPEN_BUY) return;
  timerBuy = 0;
  double rsiBuy = getRsiValue(rsiHandleBuy);
  if(rsiBuy > RSI_OVERSOLD) return;
  Print("* RSI oversold detected");

  int grid = countOrder(POSITION_TYPE_BUY);
  if(MIN_GRID_BOOST_BUY > 0 && grid < MIN_GRID_BOOST_BUY) return;
  if(MAX_GRID_BOOST_BUY > 0 && grid > MAX_GRID_BOOST_BUY) return;
  Print("* Boost Activate [Buy] - Grid #" + IntegerToString(grid+1));
  double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  askPrice = NormalizeDouble(askPrice, _Digits);
  setupBuy(askPrice, grid, true);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void boostSellPosition()
{
  if(ORDER_DIRECTION == DIRECTION_BUY_ONLY) return;
  if(TIMER_OPEN_SELL == 0) return;
  if(timerSell < TIMER_OPEN_SELL) return;
  timerSell = 0;
  double rsiSell = getRsiValue(rsiHandleSell);
  if(rsiSell < RSI_OVERBOUGHT) return;
  Print("* RSI overbought detected");

  int grid = countOrder(POSITION_TYPE_SELL);
  if(MIN_GRID_BOOST_SELL > 0 && grid < MIN_GRID_BOOST_SELL) return;
  if(MAX_GRID_BOOST_SELL > 0 && grid > MAX_GRID_BOOST_SELL) return;
  Print("* Boost Activate [Sell] - Grid #" + IntegerToString(grid+1));
  double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  bidPrice = NormalizeDouble(bidPrice, _Digits);
  setupSell(bidPrice, grid, true);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setupTrade(double askPrice, double bidPrice)
{
  setupBuy(askPrice);
  setupSell(bidPrice);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool setupBuy(double price, int grid = NULL, bool boostOrder = false)
{
  if(pauseBuy) return false;
  if(ORDER_DIRECTION == DIRECTION_SELL_ONLY) return false;
  grid = grid == NULL ? countOrder(POSITION_TYPE_BUY) : grid;
  if(MAX_GRID_BUY > 0 && grid > MAX_GRID_BUY) return false;
  double volume = calculateVolume(grid);
  if(MAX_VOLUME_BUY > 0 && volume > MAX_VOLUME_BUY) return false;
  if(grid == 0) {
    if(USE_RSI_FOR_FIRST_BUY) {
      double rsiFirstBuy = getRsiValue(rsiHandleFirstBuy);
      if(rsiFirstBuy < RSI_RANGE_FROM_BUY || rsiFirstBuy > RSI_RANGE_TO_BUY) return false;
    }
    return sendOrder(POSITION_TYPE_BUY, volume, price, grid + 1,  false, boostOrder);
  }
  double lowest = lowestBuyPrice();
  double distance = calculateDistancePrice(grid, lowest);
  double nextPrice = lowest - distance;
  if(!(price <= nextPrice)) return false;
  return sendOrder(POSITION_TYPE_BUY, volume, price, grid + 1, false, boostOrder);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool addBuy()
{
  if(ORDER_DIRECTION == DIRECTION_SELL_ONLY) return false;
  int grid = countOrder(POSITION_TYPE_BUY);
  double volume = calculateVolume(grid);
  double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  return sendOrder(POSITION_TYPE_BUY, volume, price, grid + 1, true);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool setupSell(double price, int grid = NULL, bool boostOrder = false)
{
  if(pauseSell) return false;
  if(ORDER_DIRECTION == DIRECTION_BUY_ONLY) return false;
  grid = grid == NULL ? countOrder(POSITION_TYPE_SELL) : grid;
  if(MAX_GRID_SELL > 0 && grid > MAX_GRID_SELL) return false;
  double volume = calculateVolume(grid);
  if(MAX_VOLUME_SELL > 0 && volume > MAX_VOLUME_SELL) return false;
  if(grid == 0) {
    if(USE_RSI_FOR_FIRST_SELL) {
      double rsiFirstSell = getRsiValue(rsiHandleFirstSell);
      if(rsiFirstSell < RSI_RANGE_FROM_SELL || rsiFirstSell > RSI_RANGE_TO_SELL) return false;
    }
    return sendOrder(POSITION_TYPE_SELL, volume, price, grid + 1, false, boostOrder);
  }
  double highest = highestSellPrice();
  double distance = calculateDistancePrice(grid, highest);
  double nextPrice = highest + distance;
  if(!(price >= nextPrice)) return false;
  return sendOrder(POSITION_TYPE_SELL, volume, price, grid + 1, false, boostOrder);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool addSell()
{
  if(ORDER_DIRECTION == DIRECTION_BUY_ONLY) return false;
  int grid = countOrder(POSITION_TYPE_SELL);
  double volume = calculateVolume(grid);
  double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  return sendOrder(POSITION_TYPE_SELL, volume, price, grid + 1, true);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calculateBaseVolume()
{
  double lastBaseVolume = baseVolume;
  baseVolume = BASE_VOLUME;
  if(baseVolume <= 0) {
    double dynamicRatio = BASE_VOLUME_LOT_STEP/BASE_VOLUME_BALANCE_STEP; // 0.01/40,000 = 0.00000025
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);                 // 1,000,000 (10,000 usd)
    double share = CAPITAL_ALL > 0 ? CAPITAL_EA / CAPITAL_ALL : 1;       // 1
    share = share > 1 ? share : share;                                   // 1
    double eaBalance = balance * share;                                  // 1,000,000
    double factor = eaBalance * dynamicRatio;                            // 1,000,000 x 0.00000025 = 0.25 lot
    baseVolume = MathFloor(factor/minVolume)*minVolume;                  // MathFloor(0.25/0.01)*0.01 = 0.25 lot
  }
  baseVolume = baseVolume < minVolume ? minVolume : baseVolume;
  baseVolume = baseVolume > maxVolume ? maxVolume : baseVolume;
  baseVolume = NormalizeDouble(baseVolume, digitVolume);
  if(baseVolume != lastBaseVolume) {
    Print("Base volume changed from " + DoubleToString(lastBaseVolume, digitVolume) + " to " + DoubleToString(baseVolume, digitVolume));
  }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateVolume(int grid)
{
  if(baseVolume <= 0) return 0;
  if(grid == 0) {
    calculateBaseVolume();
    return baseVolume;
  }
  double factor = calculateFactor(grid);
  double volume = MARTINGALE_SEQUENCES == SEQ_ARITHMETIC ? (baseVolume + factor) : (baseVolume * factor);
  volume = volume < minVolume ? minVolume : volume;
  volume = volume > maxVolume ? maxVolume : volume;
  volume = NormalizeDouble(volume, digitVolume);
  return volume;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateDistancePrice(int grid, double price)
{
  if(BASE_STEP == 0) return 0;
  double factor = grid * MULTIPLIER_STEP;
  double minimumDistancePercentage = BASE_STEP + factor;
  return price * minimumDistancePercentage / 100;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateFactor(int grid)
{
  if(MARTINGALE_SEQUENCES == SEQ_ARITHMETIC) return MULTIPLIER_ARITHMETIC * grid;
  if(MARTINGALE_SEQUENCES == SEQ_GEOMETRIC) return MathPow(MULTIPLIER_GEOMETRIC, grid);
  if(MARTINGALE_SEQUENCES == SEQ_GEOMETRIC_ROUND) return round(MathPow(MULTIPLIER_GEOMETRIC, grid));
  return 0;
}

//+------------------------------------------------------------------+
//| Return Lowest Position Buy Price (First Grid Buy Price)          |
//+------------------------------------------------------------------+
double lowestBuyPrice()
{
  ENUM_POSITION_TYPE positionType = POSITION_TYPE_BUY;
  double value = DBL_MAX;
  for(int i = (PositionsTotal() - 1); i >= 0; i--) {
    if(!selectPosition(i, positionType)) continue;
    if(position.PriceOpen() > value) continue;
    value = position.PriceOpen();
  }
  return value;
}

//+------------------------------------------------------------------+
//| Return Highest Position Sell Price (First Grid Sell Price)       |
//+------------------------------------------------------------------+
double highestSellPrice()
{
  ENUM_POSITION_TYPE positionType = POSITION_TYPE_SELL;
  double value = DBL_MIN;
  for(int i = (PositionsTotal() - 1); i >= 0; i--) {
    if(!selectPosition(i, positionType)) continue;
    if(position.PriceOpen() < value) continue;
    value = position.PriceOpen();
  }
  return value;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool selectPosition(int i, ENUM_POSITION_TYPE positionType)
{
  if(!position.SelectByIndex(i)) return false;
  if(position.Symbol() != _Symbol) return false;
  if(position.Magic() != MAGIC_NUMBER) return false;
  if(position.PositionType() != positionType) return false;
  return true;
}

//+------------------------------------------------------------------+
//| Send Order                                                       |
//+------------------------------------------------------------------+
bool sendOrder(ENUM_POSITION_TYPE positionType, double volume, double price, int grid, bool manualOrder = false, bool boostOrder = false)
{
  string comment = positionType == POSITION_TYPE_BUY
                   ? COMMENT + "-B-#" + IntegerToString(grid)
                   : COMMENT + "-S-#" + IntegerToString(grid);
  comment = manualOrder ? comment + "-M" : comment;
  comment = boostOrder ? comment + "-++" : comment;
  int ticket = false;
  switch(positionType) {
  case POSITION_TYPE_BUY:
    ticket = trade.Buy(volume, _Symbol, price, 0, 0, comment);
    break;
  case POSITION_TYPE_SELL:
    ticket = trade.Sell(volume, _Symbol, price, 0, 0, comment);
    break;
  }
  if(!ticket) {
    Print("Error: Failed to send order");
    return false;
  }
  if(positionType == POSITION_TYPE_BUY && tpByPointBuy == 0 && tpByPricePercentageBuy == 0) return true;
  if(positionType == POSITION_TYPE_SELL && tpByPointSell == 0 && tpByPricePercentageSell == 0) return true;
  modifyPosition(positionType);
  return true;
}

//+------------------------------------------------------------------+
//| Modify Take Profit of Position by Order Type                     |
//+------------------------------------------------------------------+
void modifyPosition(ENUM_POSITION_TYPE positionType)
{
  double avg = averagePositionPrice(positionType);
  if(avg == 0) return;
  double tp = positionType == POSITION_TYPE_BUY
              ? calculateTakeProfitBuy(avg)
              : calculateTakeProfitSell(avg);
  tp = NormalizeDouble(tp, _Digits);

  trade.SetAsyncMode(true);
  for(int i = (PositionsTotal() - 1); i >= 0; i--) {
    if(!selectPosition(i, positionType)) continue;
    if(position.TakeProfit() == tp) continue;
    ulong ticket = position.Ticket();
    double openPrice = position.PriceOpen();
    double sl = position.StopLoss();
    bool res = trade.PositionModify(ticket, sl, tp);
    if(!res) {
      Print("Error modify order ticket no #" + IntegerToString(ticket));
    }
  }
  trade.SetAsyncMode(false);
  return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateTakeProfitBuy(double avg)
{
  if(tpByPointBuy > 0) {
    return avg + marginPriceByPointBuy;
  }
  return avg + (avg * tpByPricePercentageBuy / 100);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateTakeProfitSell(double avg)
{
  if(tpByPointSell > 0) {
    return avg - marginPriceByPointSell;
  }
  return avg - (avg * tpByPricePercentageSell / 100);
}

//+------------------------------------------------------------------+
//| Return Average Price on Position by Order Type                   |
//+------------------------------------------------------------------+
double averagePositionPrice(ENUM_POSITION_TYPE positionType)
{
  double sumVolume = 0;
  double sumSize = 0;
  for(int i = (PositionsTotal() - 1); i >= 0; i--) {
    if(!selectPosition(i, positionType)) continue;
    double volume = position.Volume();
    double openPrice = position.PriceOpen();
    double size = openPrice * volume;
    sumVolume += volume;
    sumSize += size;
  }
  double averagePrice = sumVolume > 0 ? sumSize / sumVolume : 0;
  averagePrice = NormalizeDouble(averagePrice, _Digits);
  return averagePrice;
}

//+------------------------------------------------------------------+
//| Handle TP by Balance Percentage                                  |
//+------------------------------------------------------------------+
void handleTPByBalancePercentage()
{
  if(tpByBalancePercentage == 0) return;
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  double target = balance * tpByBalancePercentage/100;
  if(ORDER_DIRECTION == DIRECTION_BUY_ONLY || ORDER_DIRECTION == DIRECTION_BUY_SELL) {
    double profit = sumProfit(POSITION_TYPE_BUY);
    if(profit >= target)
      closeAllPosition(POSITION_TYPE_BUY);
  }

  if(ORDER_DIRECTION == DIRECTION_SELL_ONLY || ORDER_DIRECTION == DIRECTION_BUY_SELL) {
    double profit = sumProfit(POSITION_TYPE_SELL);
    if(profit >= target)
      closeAllPosition(POSITION_TYPE_SELL);
  }
  return;
}

//+------------------------------------------------------------------+
//| Close All Position                                               |
//+------------------------------------------------------------------+
void closeAllPosition(ENUM_POSITION_TYPE positionType)
{
  double price = positionType == POSITION_TYPE_BUY
                 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

  trade.SetAsyncMode(true);
  for(int i = (PositionsTotal() - 1); i >= 0; i--) {
    if(!selectPosition(i, positionType)) continue;
    ulong ticket = position.Ticket();
    double volume =position.Volume();
    bool res = trade.PositionClose(ticket);
    if(!res) {
      Print("Error close order ticket no #" + IntegerToString(ticket));
    }
  }
  trade.SetAsyncMode(false);
  return;
}

//+------------------------------------------------------------------+
//| Sum Total Profit of Current Open Trade by Order Type             |
//+------------------------------------------------------------------+
double sumProfit(ENUM_POSITION_TYPE positionType)
{
  double sumProfit = 0;
  for(int i = (PositionsTotal() - 1); i >= 0; i--) {
    if(!selectPosition(i, positionType)) continue;
    sumProfit += position.Profit() + position.Swap() + position.Commission();
  }
  return sumProfit;
}

//+------------------------------------------------------------------+
//| Return whether a Take Profit Event is Detected for Buy Position  |
//+------------------------------------------------------------------+
bool isTakeProfitEventBuy()
{
  int currentGridBuy = countOrder(POSITION_TYPE_BUY);
  if(lastGridBuy > 0 && currentGridBuy == 0) {
    lastGridBuy = currentGridBuy;
    return true;
  }
  lastGridBuy = currentGridBuy;
  return false;
}

//+------------------------------------------------------------------+
//| Return whether a Take Profit Event is Detected for Sell Position |
//+------------------------------------------------------------------+
bool isTakeProfitEventSell()
{
  int currentGridSell = countOrder(POSITION_TYPE_SELL);
  if(lastGridSell > 0 && currentGridSell == 0) {
    lastGridSell = currentGridSell;
    return true;
  }
  lastGridSell = currentGridSell;
  return false;
}

//+------------------------------------------------------------------+
//| Return no of Order (Grid) by Position Type                       |
//+------------------------------------------------------------------+
int countOrder(ENUM_POSITION_TYPE positionType)
{
  int count = 0;
  for(int i = (PositionsTotal() - 1); i >= 0; i--) {
    if(!selectPosition(i, positionType)) continue;
    count++;
  }
  return count;
}

//+------------------------------------------------------------------+
//| Get Digit of given number                                        |
//+------------------------------------------------------------------+
int getDigit(double number)
{
  int d = 0;
  double p = 1;
  while(MathRound(number * p) / p != number) {
    p = MathPow(10, ++d);
  }
  return d;
}

//+------------------------------------------------------------------+
//| Return whether current tick is a new bar                         |
//+------------------------------------------------------------------+
bool isNewBar()
{
  static datetime lastBar;
  return lastBar != (lastBar = iTime(_Symbol, TIMEFRAME, 0));
}

//+------------------------------------------------------------------+
//| Get RSI Value                                                    |
//+------------------------------------------------------------------+
double getRsiValue(int handle)
{
  double bufferRsi[];
  ArrayResize(bufferRsi, 1);
  CopyBuffer(handle, 0, 0, 1, bufferRsi);
  ArraySetAsSeries(bufferRsi, true);
  return bufferRsi[0];
}


//+------------------------------------------------------------------+
//| Chart Event Button Listener                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  if(id != CHARTEVENT_OBJECT_CLICK) return;

  if(sparam == ADD_BUY_BUTTON) {
    actionAddBuy();
    return;
  } else if(sparam == ADD_SELL_BUTTON) {
    actionAddSell();
    return;
  } else if(sparam == CLOSE_BUY_BUTTON) {
    actionCloseBuy();
    return;
  } else if(sparam == CLOSE_SELL_BUTTON) {
    actionCloseSell();
    return;
  } else if(sparam == CLOSE_ALL_BUTTON) {
    actionCloseAll();
    return;
  } else if(sparam == PAUSE_BUY_BUTTON) {
    actionPauseBuy();
    return;
  } else if(sparam == PAUSE_SELL_BUTTON) {
    actionPauseSell();
    return;
  } else if(sparam == PAUSE_ALL_BUTTON) {
    actionPauseAll();
    return;
  } else if(sparam == RESUME_BUY_BUTTON) {
    actionResumeBuy();
    return;
  } else if(sparam == RESUME_SELL_BUTTON) {
    actionResumeSell();
    return;
  } else if(sparam == RESUME_ALL_BUTTON) {
    actionResumeAll();
    return;
  } else if(sparam == MODIFY_POINT_UP_BUY_BUTTON) {
    actionModifyTpPointBuy(MODIFY_STEP_TP_POINT);
    return;
  } else if(sparam == MODIFY_POINT_UP_SELL_BUTTON) {
    actionModifyTpPointSell(MODIFY_STEP_TP_POINT);
    return;
  } else if(sparam == MODIFY_POINT_DOWN_BUY_BUTTON) {
    actionModifyTpPointBuy(-MODIFY_STEP_TP_POINT);
    return;
  } else if(sparam == MODIFY_POINT_DOWN_SELL_BUTTON) {
    actionModifyTpPointSell(-MODIFY_STEP_TP_POINT);
    return;
  } else if(sparam == MODIFY_PERCENTAGE_UP_BUY_BUTTON) {
    actionModifyTpPricePercentageBuy(MODIFY_STEP_TP_PERCENT);
    return;
  } else if(sparam == MODIFY_PERCENTAGE_UP_SELL_BUTTON) {
    actionModifyTpPricePercentageSell(MODIFY_STEP_TP_PERCENT);
    return;
  } else if(sparam == MODIFY_PERCENTAGE_DOWN_BUY_BUTTON) {
    actionModifyTpPricePercentageBuy(-MODIFY_STEP_TP_PERCENT);
    return;
  } else if(sparam == MODIFY_PERCENTAGE_DOWN_SELL_BUTTON) {
    actionModifyTpPricePercentageSell(-MODIFY_STEP_TP_PERCENT);
    return;
  } else if(sparam == SEND_TELEGRAM_BUTTON) {
    actionSendTelegram();
    return;
  }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionAddBuy()
{
  addBuy();
  ObjectSetInteger(0, ADD_BUY_BUTTON, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionAddSell()
{
  addSell();
  ObjectSetInteger(0, ADD_SELL_BUTTON, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionCloseBuy()
{
  int confirmation = MessageBox("Are you sure to close BUY position? and pause BUY", "Close BUY", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseBuy = true;
  closeAllPosition(POSITION_TYPE_BUY);
  showResumeBuyButton();
  showPauseAllButton();
  if(pauseSell) {
    showResumeAllButton();
  } else {
    showPauseAllButton();
  }
  MessageBox("BUY position Cleared, trade for BUY paused", "Close Position Done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionCloseSell()
{
  int confirmation = MessageBox("Are you sure to close SELL position? and pause SELL", "Close SELL", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseSell = true;
  closeAllPosition(POSITION_TYPE_SELL);
  showResumeSellButton();
  if(pauseBuy) {
    showResumeAllButton();
  } else {
    showPauseAllButton();
  }
  MessageBox("SELL position Cleared, trade for SELL paused", "Close Position Done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionCloseAll()
{
  int confirmation = MessageBox("Are you sure to close ALL position? and pause ALL", "Close ALL", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseBuy = true;
  pauseSell = true;
  closeAllPosition(POSITION_TYPE_BUY);
  closeAllPosition(POSITION_TYPE_SELL);
  showResumeBuyButton();
  showResumeSellButton();
  showResumeAllButton();
  MessageBox("ALL position Cleared, ALL trade paused", "Close Position Done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionPauseBuy()
{
  int confirmation = MessageBox("Are you sure to pause BUY new order?", "Pause BUY", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseBuy = true;
  showResumeBuyButton();
  if(pauseSell) {
    showResumeAllButton();
  } else {
    showPauseAllButton();
  }
  MessageBox("trade for new BUY paused", "Pause new order done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionPauseSell()
{
  int confirmation = MessageBox("Are you sure to pause SELL new order?", "Pause SELL", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseSell = true;
  showResumeSellButton();
  if(pauseBuy) {
    showResumeAllButton();
  } else {
    showPauseAllButton();
  }
  MessageBox("Trade for new SELL paused", "Pause new order done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionPauseAll()
{
  int confirmation = MessageBox("Are you sure to pause ALL new order?", "Pause ALL", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseBuy = true;
  pauseSell = true;
  showResumeBuyButton();
  showResumeSellButton();
  showResumeAllButton();
  MessageBox("ALL trade paused", "Pause new order done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionResumeBuy()
{
  int confirmation = MessageBox("Are you sure to resume trade for BUY?", "Resume BUY", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseBuy = false;
  showPauseBuyButton();
  showPauseAllButton();
  MessageBox("trade for new BUY resumed", "Resume trade done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionResumeSell()
{
  int confirmation = MessageBox("Are you sure to resume trade for SELL?", "Resume SELL", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseSell = false;
  showPauseSellButton();
  showPauseAllButton();
  MessageBox("trade for new SELL resumed", "Resume trade done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionResumeAll()
{
  int confirmation = MessageBox("Are you sure to resume ALL trade?", "Resume ALL", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  pauseBuy = false;
  pauseSell = false;
  showPauseBuyButton();
  showPauseSellButton();
  showPauseAllButton();
  MessageBox("ALL trade resumed", "Resume trade done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionModifyTpPointBuy(double change)
{
  string modifyTitle = "TP +" + DoubleToString(change, 2);
  int confirmation = MessageBox("Are you sure to modify take profit BUY by point?", modifyTitle, MB_OKCANCEL);
  if(confirmation != IDOK) return;
  modifyTpByPointBuy(change);
  MessageBox("BUY position modified", "Modify done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionModifyTpPointSell(double change)
{
  string modifyTitle = "TP +" + DoubleToString(change, 2);
  int confirmation = MessageBox("Are you sure to modify take profit SELL by point?", modifyTitle, MB_OKCANCEL);
  if(confirmation != IDOK) return;
  modifyTpByPointSell(change);
  MessageBox("SELL position modified", "Modify done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionModifyTpPricePercentageBuy(double change)
{
  string modifyTitle = "TP +" + DoubleToString(change, 2) + "%";
  int confirmation = MessageBox("Are you sure to modify take profit BUY by price percentage?", modifyTitle, MB_OKCANCEL);
  if(confirmation != IDOK) return;
  modifyTpByPricePercentageBuy(change);
  MessageBox("BUY position modified", "Modify done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionModifyTpPricePercentageSell(double change)
{
  string modifyTitle = "TP +" + DoubleToString(change, 2) + "%";
  int confirmation = MessageBox("Are you sure to modify take profit SELL by price percentage?", modifyTitle, MB_OKCANCEL);
  if(confirmation != IDOK) return;
  modifyTpByPricePercentageSell(change);
  MessageBox("SELL position modified", "Modify done", MB_OK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actionSendTelegram()
{
  int confirmation = MessageBox("Are you sure resend last take profit message?", "Send Telegram", MB_OKCANCEL);
  if(confirmation != IDOK) return;
  lastTakeProfit();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showAddBuyButton()
{
  createButton(ADD_BUY_BUTTON, clrMediumSeaGreen, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 20, 120, "Add Buy");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showAddSellButton()
{
  createButton(ADD_SELL_BUTTON, clrMediumVioletRed, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 270, 120, "Add Sell");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showCloseBuyButton()
{
  createButton(CLOSE_BUY_BUTTON, clrRed, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 20, 160, "Close Buy");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showCloseSellButton()
{
  createButton(CLOSE_SELL_BUTTON, clrCrimson, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 270, 160, "Close Sell");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showCloseAllButton()
{
  createButton(CLOSE_ALL_BUTTON, clrMaroon, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 200, "Close All");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showPauseBuyButton()
{
  createButton(PAUSE_BUY_BUTTON, clrOrangeRed, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 20, 240, "Pause Buy");
  ObjectDelete(0, RESUME_BUY_BUTTON);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showResumeBuyButton()
{
  createButton(RESUME_BUY_BUTTON, clrGreen, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 20, 240, "Resume Buy");
  ObjectDelete(0, PAUSE_BUY_BUTTON);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showPauseSellButton()
{
  createButton(PAUSE_SELL_BUTTON, clrCrimson, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 270, 240, "Pause Sell");
  ObjectDelete(0, RESUME_SELL_BUTTON);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showResumeSellButton()
{
  createButton(RESUME_SELL_BUTTON, clrTeal, clrNONE, clrWhite, 250, 40, CORNER_LEFT_UPPER, 270, 240, "Resume Sell");
  ObjectDelete(0, PAUSE_SELL_BUTTON);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showPauseAllButton()
{
  createButton(PAUSE_ALL_BUTTON, clrFireBrick, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 280, "Pause All");
  ObjectDelete(0, RESUME_ALL_BUTTON);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showResumeAllButton()
{
  createButton(RESUME_ALL_BUTTON, clrDarkGreen, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 280, "Resume All");
  ObjectDelete(0, PAUSE_ALL_BUTTON);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPointUpBuyButton()
{
  createButton(MODIFY_POINT_UP_BUY_BUTTON, clrDarkOliveGreen, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 360, "Modify TP Point Buy Up +" + DoubleToString(MODIFY_STEP_TP_POINT, 2) );
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPricePercentageUpBuyButton()
{
  createButton(MODIFY_PERCENTAGE_UP_BUY_BUTTON, clrDarkOliveGreen, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 360, "Modify TP Percent Buy Up +" + DoubleToString(MODIFY_STEP_TP_PERCENT, 2) );
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPointUpSellButton()
{
  createButton(MODIFY_POINT_UP_SELL_BUTTON, clrSeaGreen, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 400, "Modify TP Point Sell Up +" + DoubleToString(MODIFY_STEP_TP_POINT, 2) );
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPricePercentageUpSellButton()
{
  createButton(MODIFY_PERCENTAGE_UP_SELL_BUTTON, clrSeaGreen, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 400, "Modify TP Percent Sell Up +" + DoubleToString(MODIFY_STEP_TP_PERCENT, 2) );
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPointDownBuyButton()
{
  createButton(MODIFY_POINT_DOWN_BUY_BUTTON, clrMidnightBlue, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 440, "Modify TP Point Buy Down -" + DoubleToString(MODIFY_STEP_TP_POINT, 2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPricePercentageDownBuyButton()
{
  createButton(MODIFY_PERCENTAGE_DOWN_BUY_BUTTON, clrMidnightBlue, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 440, "Modify TP Percent Buy Down -" + DoubleToString(MODIFY_STEP_TP_PERCENT, 2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPointDownSellButton()
{
  createButton(MODIFY_POINT_DOWN_SELL_BUTTON, clrDarkSlateGray, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 480, "Modify TP Point Sell Down -" + DoubleToString(MODIFY_STEP_TP_POINT, 2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showModifyTpPricePercentageDownSellButton()
{
  createButton(MODIFY_PERCENTAGE_DOWN_SELL_BUTTON, clrDarkSlateGray, clrNONE, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 480, "Modify TP Percent Sell Down -" + DoubleToString(MODIFY_STEP_TP_PERCENT, 2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showSendTelegramButton()
{
  createButton(SEND_TELEGRAM_BUTTON, clrNavy, clrNONE, clrWhite, 500, 40, CORNER_LEFT_LOWER, 20, 80, "Send Telegram");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void modifyTpByPointBuy(double change)
{
  tpByPointBuy = tpByPointBuy + change;
  if(tpByPointBuy < 0) {
    tpByPointBuy = 0;
  }
  marginPriceByPointBuy = tpByPointBuy * symbolPoint;

  if(tpByPointBuy == 0) return;

  modifyPosition(POSITION_TYPE_BUY);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void modifyTpByPointSell(double change)
{
  tpByPointSell = tpByPointSell + change;
  if(tpByPointSell < 0) {
    tpByPointSell = 0;
  }
  marginPriceByPointSell = tpByPointSell * symbolPoint;

  if(tpByPointSell == 0) return;

  modifyPosition(POSITION_TYPE_SELL);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void modifyTpByPricePercentageBuy(double change)
{
  tpByPricePercentageBuy = tpByPricePercentageBuy + change;
  if(tpByPricePercentageBuy < 0) {
    tpByPricePercentageBuy = 0;
  }
  if(tpByPricePercentageBuy == 0) return;

  modifyPosition(POSITION_TYPE_BUY);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void modifyTpByPricePercentageSell(double change)
{
  tpByPricePercentageSell = tpByPricePercentageSell + change;
  if(tpByPricePercentageSell < 0) {
    tpByPricePercentageSell = 0;
  }
  if(tpByPricePercentageSell == 0) return;

  modifyPosition(POSITION_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| Delete object all or by name                                     |
//+------------------------------------------------------------------+
void deleteObject(string objectName = "")
{
  for(int i = (ObjectsTotal(0, -1, -1) - 1); i >= 0; i--) {
    if(!(StringFind(ObjectName(0, i, -1, -1), MQLInfoString(MQL_PROGRAM_NAME)) != -1)) continue;
    if(objectName == "") {
      ObjectDelete(0, ObjectName(0, i, -1, -1));
      continue;
    }
    if(!StringFind(ObjectName(0, i, -1, -1), objectName)) continue;
    ObjectDelete(0, ObjectName(0, i, -1, -1));
  }
}

//+------------------------------------------------------------------+
//| Create Button Wrapper                                            |
//+------------------------------------------------------------------+
void createButton(string buttonName, color bgClr, color borderClr, color textClr, int width, int height, int corner, int x, int y, string label)
{
  ObjectCreate(0, buttonName, OBJ_BUTTON, 0, 0, 0);
  ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, bgClr);
  ObjectSetInteger(0, buttonName, OBJPROP_BORDER_COLOR, borderClr);
  ObjectSetInteger(0, buttonName, OBJPROP_COLOR, textClr);
  ObjectSetInteger(0, buttonName, OBJPROP_YSIZE, height);
  ObjectSetInteger(0, buttonName, OBJPROP_XSIZE, width);
  ObjectSetInteger(0, buttonName, OBJPROP_CORNER, corner);
  ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, x);
  ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, y);
  ObjectSetString(0, buttonName, OBJPROP_TEXT, label);
  ObjectSetInteger(0, buttonName, OBJPROP_STATE, false);
  ObjectSetInteger(0, buttonName, OBJPROP_FONTSIZE, 8);
  ObjectSetInteger(0, buttonName, OBJPROP_ZORDER, 100);
  ObjectSetInteger(0, buttonName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Handle Take Profit Message                                       |
//+------------------------------------------------------------------+
void handleTakeProfitEvent()
{
  bool tpBuy = isTakeProfitEventBuy();
  bool tpSell = isTakeProfitEventSell();
  if(!(tpBuy || tpSell)) return;

  // TP Detected
  lastTakeProfit();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void showRealtimeInfo()
{
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  double balancePerCapital = 100 * balance / CAPITAL_ALL;
  double accountProfit = AccountInfoDouble(ACCOUNT_PROFIT);
  double profitPerCapital = accountProfit * 100 / CAPITAL_ALL;
  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  double floating = equity - balance;
  maxDrawdown = floating < maxDrawdown ? floating : maxDrawdown;
  Comment("Floating: " + DoubleToString(floating, 2) + " Max Drawdown: " + DoubleToString(maxDrawdown, 2));
}

//+------------------------------------------------------------------+
//| Calculate Last Take Profit                                       |
//+------------------------------------------------------------------+
void lastTakeProfit()
{
  double groupTakeProfit = 0;
  datetime groupOpenTime = __DATE__;
  datetime groupCloseTime = __DATE__;
  int tpToday = 0;
  int tpMonth = 0;
  int tpYear = 0;
  int tpAll = 0;
  int tpTodayAllPair = 0;
  int tpMonthAllPair = 0;
  int tpYearAllPair = 0;
  int tpAllPair = 0;
  double profitToday = 0;
  double profitMonth = 0;
  double profitYear = 0;
  double profitAll = 0;

  double profitTodayAllPair = 0;
  double profitMonthAllPair = 0;
  double profitYearAllPair = 0;
  double profitAllPair = 0;
  bool groupType = false;
  double groupSumLots = 0;
  double groupProfit = 0;
  int countGrid = 0;
  double maxLot = DBL_MIN;
  double minPrice = DBL_MAX;
  double maxPrice = DBL_MIN;
  double groupSumSizePrice = 0;
  double maxSlippage = 0;

  datetime now = TimeCurrent();
  Print("now");
  Print(TimeToString(now));
  MqlDateTime localNow = toLocalMqlDateTime(now);
  int year = localNow.year;
  int month = localNow.mon;
  int day = localNow.day;

  HistorySelect(0, now);
  bool isLatest = true;
  int total = HistoryDealsTotal();
  for(int i = (total - 1); i >= 0; i--) {
    CDealInfo dealOut;
    if(!dealOut.SelectByIndex(i)) continue;
    if(dealOut.Entry() != DEAL_ENTRY_OUT) continue;

    // Get Current Deal Type
    ENUM_DEAL_TYPE dealType = dealOut.DealType();
    if(!(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)) continue;
    bool currentType = !(dealType == DEAL_TYPE_BUY); // Deal out is opposite to Deal in

    // Get Current Close Time
    datetime currentCloseTime = dealOut.Time();
    if(currentCloseTime == 0) continue;

    // Get Current Profit
    double currentProfit = dealOut.Profit() + dealOut.Swap() + dealOut.Commission();

    // Count Profit by Close Time
    MqlDateTime localClose = toLocalMqlDateTime(currentCloseTime);
    if(localClose.year == year) {
      tpYearAllPair ++;
      profitYearAllPair += currentProfit;
      if(localClose.mon == month) {
        tpMonthAllPair++;
        profitMonthAllPair += currentProfit;
        if(localClose.day == day) {
          tpTodayAllPair++;
          profitTodayAllPair += currentProfit;
        }
      }
    }
    tpAllPair++;
    profitAllPair += currentProfit;

    if(dealOut.Symbol() != _Symbol) continue;
    if(dealOut.Magic() != MAGIC_NUMBER) continue;

    if(localClose.year == year) {
      tpYear ++;
      profitYear += currentProfit;
      if(localClose.mon == month) {
        tpMonth++;
        profitMonth += currentProfit;
        if(localClose.day == day) {
          tpToday++;
          profitToday += currentProfit;
        }
      }
    }
    tpAll++;
    profitAll += currentProfit;

    // Skip if not same type with group
    if(!isLatest && currentType != groupType) continue;

    // Skip if delta time is above 60 seconds, possible different take profit group
    if(!isLatest) {
      int delta = fabs((int) currentCloseTime - (int) groupCloseTime);
      if(delta > 60) continue;
    }

    // Get Current Take Profit
    ulong ticket = dealOut.Ticket();
    double currentTakeProfit = HistoryDealGetDouble(ticket, DEAL_TP);

    // Skip if not same take profit with group
    if(!isLatest && currentTakeProfit != groupTakeProfit) continue;

    // Summing group grid
    countGrid ++;
    groupProfit += currentProfit;
    groupType = isLatest ? currentType : groupType;
    groupTakeProfit = isLatest ? currentTakeProfit : groupTakeProfit;
    groupCloseTime = isLatest ? currentCloseTime
                     : currentCloseTime > groupCloseTime ? currentCloseTime
                     : groupCloseTime;

    // Get Current Close Price And Slippage
    double currentClosePrice = dealOut.Price();
    double currentSlippage = fabs(currentClosePrice - currentTakeProfit);
    maxSlippage = currentSlippage > maxSlippage ? currentSlippage : maxSlippage;

    // Get volume
    double currentOrderLots = dealOut.Volume();
    groupSumLots += currentOrderLots;
    maxLot = currentOrderLots > maxLot ? currentOrderLots : maxLot;

    // Get Current Open Time and Current Open Price
    long positionId = dealOut.PositionId();
    datetime currentOpenTime = __DATE__;
    double currentOpenPrice = DBL_MIN;
    if(HistorySelectByPosition(positionId)) {
      int totalByPosition = HistoryDealsTotal();
      for(int j = 0; j < totalByPosition; j++) {
        CDealInfo dealIn;
        if(!dealIn.SelectByIndex(j)) continue;
        if(dealIn.Entry() != DEAL_ENTRY_IN) continue;
        currentOpenTime  = dealIn.Time();
        currentOpenPrice = dealIn.Price();
        break;
      }
    }
    HistorySelect(0, now); // Don't forget bring back history select

    // Set Group Open Time
    groupOpenTime = isLatest ? currentOpenTime
                    : currentOpenTime < groupOpenTime ? currentOpenTime
                    : groupOpenTime;

    // Set Min and Max Price
    minPrice = currentOpenPrice < minPrice ? currentOpenPrice : minPrice;
    maxPrice = currentOpenPrice > maxPrice ? currentOpenPrice : maxPrice;

    // Calculate Sum Size x Price
    groupSumSizePrice += (currentOpenPrice * currentOrderLots);

    // Set isLatest to false before continue iteration
    isLatest = false;
  }

  double groupAveragePrice = groupSumLots > 0 ? groupSumSizePrice/groupSumLots : 0;
  int groupDuration = (int) groupCloseTime - (int) groupOpenTime;
  string symbol = _Symbol;

  prepareTelegramMessage(
    symbol, groupType,
    groupSumLots, countGrid,
    groupOpenTime, groupCloseTime,
    minPrice, maxPrice,
    groupAveragePrice, groupTakeProfit,
    groupProfit, groupDuration,
    maxSlippage,
    tpToday, tpMonth, tpYear, tpAll,
    profitToday, profitMonth, profitYear, profitAll,
    tpTodayAllPair, tpMonthAllPair, tpYearAllPair, tpAllPair,
    profitTodayAllPair, profitMonthAllPair, profitYearAllPair, profitAllPair
  );
}

//+------------------------------------------------------------------+
//| Prepare Message for Telegram                                     |
//+------------------------------------------------------------------+
void prepareTelegramMessage(
  string symbol, bool groupType,
  double sumVolume, int countGrid,
  datetime timeOpen, datetime timeClose,
  double minPrice, double maxPrice,
  double groupAveragePrice,  double groupTakeProfit,
  double sumProfit, int duration,
  double maxSlippage,
  int tpToday, int tpMonth, int tpYear, int tpAll,
  double profitToday, double profitMonth, double profitYear, double profitAll,
  int tpTodayAllPair, int tpMonthAllPair, int tpYearAllPair, int tpAllPair,
  double profitTodayAllPair, double profitMonthAllPair, double profitYearAllPair, double profitAllPair
)
{
  string strDirection = groupType ? "Buy" : "Sell";
  string strBot = COMMENT;

  // Symbol / Capital
  string baseSymbol = StringSubstr(symbol, 0, 3);
  int lengthSymbol = StringLen(symbol);

  // Detect cents
  bool isCent = lengthSymbol == 7 && (StringSubstr(symbol, 6, 1) == "c" || StringSubstr(symbol, 6, 1) == "m");
  string baseCurrency = StringSubstr(symbol, 3, 3) == "USD" ? "$" : StringSubstr(symbol, 3, 3);

  baseCurrency = isCent ? "¢" : baseCurrency;
  string strCapitalEa = baseCurrency + NumberToString(CAPITAL_EA, 0);
  string strCapital = baseCurrency + NumberToString(CAPITAL_ALL, 0);

  // Lot
  string strVolume = DoubleToString(sumVolume, 2) + " Lot | " + IntegerToString(countGrid) + " Grids";

  // Price
  string min = NumberToString(minPrice, _Digits);
  string max = NumberToString(maxPrice, _Digits);
  string startPrice = groupType ? max : min ;
  string endPrice = groupType ? min : max;

  double height = fabs(maxPrice - minPrice);
  string strHeightPrice = NumberToString(height / symbolPoint, 0);

  // Time Start End
  string strTimeStart = TimeToString(toLocalDateTime(timeOpen), TIME_MINUTES) + " @" + startPrice;
  string strTimeEnd = TimeToString(toLocalDateTime(timeClose), TIME_MINUTES) + " @" + endPrice;


  double tpPoint = fabs(groupTakeProfit - groupAveragePrice) / symbolPoint;
  string strAverage = NumberToString(groupAveragePrice,2);

  string strTp = NumberToString(groupTakeProfit,2) + " (" + NumberToString(tpPoint, 0) + " Points)";
  string strSlippage = NumberToString(maxSlippage/symbolPoint, 0) + " Points";

  // Profit
  double percentProfit = sumProfit * 100 / CAPITAL_EA;
  string strProfit = baseCurrency + DoubleToString(sumProfit, 2) + " | " + DoubleToString(percentProfit, 3) + "% \xF4B0 \xF4B0 \xF4B0";

  // Take Profit History
  string strDuration = templateDuration(duration) + " (" + strHeightPrice + " Points)";

  double percentToday = profitToday * 100 / CAPITAL_EA;
  string strToday = templateTp(tpToday, profitToday, percentToday, baseCurrency);

  double percentMonth = profitMonth * 100 / CAPITAL_EA;
  string strMonth = templateTp(tpMonth, profitMonth, percentMonth, baseCurrency);

  double percentYear = profitYear * 100 / CAPITAL_EA;
  string strYear = templateTp(tpYear, profitYear, percentYear, baseCurrency);

  double percentAll = profitAll * 100 / CAPITAL_EA;
  string strAll = templateTp(tpAll, profitAll, percentAll, baseCurrency);

  // Take Profit History All Pair
  double percentTodayAllPair = profitTodayAllPair * 100 / CAPITAL_ALL;
  string strTodayAllPair = templateTp(tpTodayAllPair, profitTodayAllPair, percentTodayAllPair, baseCurrency);

  double percentMonthAllPair = profitMonthAllPair * 100 / CAPITAL_ALL;
  string strMonthAllPair = templateTp(tpMonthAllPair, profitMonthAllPair, percentMonthAllPair, baseCurrency);

  double percentYearAllPair = profitYearAllPair * 100 / CAPITAL_ALL;
  string strYearAllPair = templateTp(tpYearAllPair, profitYearAllPair, percentYearAllPair, baseCurrency);

  // Financial Info
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  double balancePerCapital = 100 * balance / CAPITAL_ALL;
  double accountProfit = AccountInfoDouble(ACCOUNT_PROFIT);
  double profitPerCapital = accountProfit * 100 / CAPITAL_ALL;
  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  double equityPerCapital = 100 * equity / CAPITAL_ALL;
  double unPNL = equity - CAPITAL_ALL;
  double unPNLPerCapital = 100 * unPNL / CAPITAL_ALL;
  string strBalance = templateFinance(balance, balancePerCapital, baseCurrency);
  string strFloating = templateFinance(accountProfit, profitPerCapital, baseCurrency);
  string strEquity = templateFinance(equity, equityPerCapital, baseCurrency);
  string strUnPNL = templateFinance(unPNL,unPNLPerCapital, baseCurrency);
  datetime gmtTime = TimeGMT();
  datetime serverTime = TimeCurrent();
  string strGMTTime = "GMT Time: " + TimeToString(gmtTime) + "\n";
  string strServerTime = "Server Time: " + TimeToString(serverTime) + "\n";
  datetime localTime = toLocalDateTime(serverTime);
  string strLocalTime = "Local Time: " + TimeToString(localTime);
  string t = "<b>Take Profit Completed!</b>\n\n" +
             strLn("\xF47D Bot: ", strBot) +
             strLn("\xF3C5 Pair: ", symbol) +
             "\n<b>=========== TP Info ===========</b>\n" +
             strLn("\xF52D Direction: ", strDirection) +
             strLn("\xF3AF Volume: ", strVolume) +
             "<b>-----------------------------------------------</b>\n" +
             strLn("\xF559 S: ", strTimeStart) +
             strLn("\xF3C1 E: ", strTimeEnd) +
             strLn("\xF4DF D: ", strDuration) +
             strLn("\xF3BE Avg Price: ", strAverage) +
             strLn("\xF514 TP Price: ", strTp) +
             //strLn("\xF3C3 Max Slippage: ", strSlippage) +
             "<b>-----------------------------------------------</b>\n" +
             strLn("\xF680 Profit: ", strProfit) +
             "<b>-----------------------------------------------</b>\n" +
             "<b>=== Profit History Pair: "+ _Symbol +" ===</b>\n" +
             strLn("\xF6C4 Capital: ", strCapitalEa) +
             strLn("\x2600 Today: ", strToday) +
             strLn("\xF319 Month: ", strMonth) +
             strLn("\x26C4 Year: ", strYear) +
             strLn("\xF320 All: ", strAll) +
             "<b> </b>\n" +
             "<b>=== Financial Info (All-Pair) ===</b>\n" +
             strLn("\xF6C4 Capital: ", strCapital) +
             strLn("\x2600 Today: ", strTodayAllPair) +
             strLn("\xF319 Month: ", strMonthAllPair) +
             strLn("\xF4B5 Balance: ", strBalance) +
             strLn("\xF648 Floating: ", strFloating) +
             strLn("\xF4C0 Equity: ", strEquity) +
             strLn("\xF4B3 Un-P&L: ", strUnPNL) +
             "<b>============================</b>\n";
  //strServerTime;
  Print(t);

  if(!SEND_TELEGRAM) return;
  sendTelegramMessage(t, "HTML");
}

//+------------------------------------------------------------------+
//| Send message to telegram                                         |
//+------------------------------------------------------------------+
void sendTelegramMessage(string text, const string parseMode = NULL,  const string replyMarkup = NULL, const bool silently = false)
{
  string url = StringFormat("%s/bot%s/sendMessage", TELEGRAM_API_URL, API_KEY);
  string params = StringFormat("chat_id=%s&text=%s", CHANNEL_ID, UrlEncode(text));

  if(parseMode != NULL) {
    params += "&parse_mode=" + parseMode;
  }
  if(silently) {
    params += "&disable_notification=true";
  }
  if(replyMarkup != NULL) {
    params += "&reply_markup=" + replyMarkup;
  }
  PostRequest(url, params, 5000);
  return;
}

//+------------------------------------------------------------------+
//| Web Request Post                                                 |
//+------------------------------------------------------------------+
void PostRequest(const string url, const string params, const int timeout = 5000)
{
  char data[];
  int dataSize = StringLen(params);
  StringToCharArray(params, data, 0, dataSize);

  uchar result[];
  string resultHeaders;
  int res = WebRequest("POST", url, NULL, NULL, timeout, data, dataSize, result, resultHeaders);
  Print("Web request result: ", res, ", error: #", (res == -1 ? GetLastError() : 0));
  return;
}


//+------------------------------------------------------------------+
//| Encode Url                                                       |
//+------------------------------------------------------------------+
string UrlEncode(const string text)
{
  string result = NULL;
  int length = StringLen(text);
  for(int i = 0; i < length; i++) {
    ushort ch = StringGetCharacter(text, i);

    if((ch >= 48 && ch <= 57) || // 0-9
        (ch >= 65 && ch <= 90) || // A-Z
        (ch >= 97 && ch <= 122) || // a-z
        (ch == '!') || (ch == '\'') || (ch == '(') ||
        (ch == ')') || (ch == '*') || (ch == '-') ||
        (ch == '.') || (ch == '_') || (ch == '~')
      ) {
      result += ShortToString(ch);
    } else {
      if(ch == ' ')
        result += ShortToString('+');
      else {
        uchar array[];
        int total=ShortToUtf8(ch, array);
        for(int k=0; k < total; k++)
          result += StringFormat("%%%02X", array[k]);
      }
    }
  }
  return result;
}

//+------------------------------------------------------------------+
//| Short to UTF8                                                    |
//+------------------------------------------------------------------+
int ShortToUtf8(const ushort _ch,uchar &out[])
{
  //---
  if(_ch<0x80) {
    ArrayResize(out,1);
    out[0]=(uchar)_ch;
    return(1);
  }
  //---
  if(_ch<0x800) {
    ArrayResize(out,2);
    out[0] = (uchar)((_ch >> 6)|0xC0);
    out[1] = (uchar)((_ch & 0x3F)|0x80);
    return(2);
  }
  //---
  if(_ch<0xFFFF) {
    if(_ch>=0xD800 && _ch<=0xDFFF) { //Ill-formed
      ArrayResize(out,1);
      out[0]=' ';
      return(1);
    } else if(_ch>=0xE000 && _ch<=0xF8FF) { //Emoji
      int ch=0x10000|_ch;
      ArrayResize(out,4);
      out[0] = (uchar)(0xF0 | (ch >> 18));
      out[1] = (uchar)(0x80 | ((ch >> 12) & 0x3F));
      out[2] = (uchar)(0x80 | ((ch >> 6) & 0x3F));
      out[3] = (uchar)(0x80 | ((ch & 0x3F)));
      return(4);
    } else {
      ArrayResize(out,3);
      out[0] = (uchar)((_ch>>12)|0xE0);
      out[1] = (uchar)(((_ch>>6)&0x3F)|0x80);
      out[2] = (uchar)((_ch&0x3F)|0x80);
      return(3);
    }
  }
  ArrayResize(out,3);
  out[0] = 0xEF;
  out[1] = 0xBF;
  out[2] = 0xBD;
  return(3);
}

//+------------------------------------------------------------------+
//| String template with new line                                    |
//+------------------------------------------------------------------+
string strLn(string a, string b = "")
{
  return a + b + "\n";
}

//+------------------------------------------------------------------+
//| String template take profit                                      |
//+------------------------------------------------------------------+
string templateTp(int a, double b, double c, string baseCurrency = "$")
{
  return IntegerToString(a) + " | " + baseCurrency + NumberToString(b, 0) + " | " + DoubleToString(c, 2) + "%";
}

//+------------------------------------------------------------------+
//| String template financial info                                   |
//+------------------------------------------------------------------+
string templateFinance(double a, double b, string baseCurrency = "$")
{
  return baseCurrency + NumberToString(a, 0, ",") + " (" + DoubleToString(b, 2) + "%)";
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string templateDuration(int duration)
{
  double day = MathFloor((double)duration / 86400);
  double hour = duration - (day * 86400);
  hour = MathFloor(hour / 3600);
  double minute = duration - (day * 86400) - (hour * 3600);
  minute = MathFloor(minute/60);
  string strDay =  day > 0 ? DoubleToString(day, 0) + (day > 1 ? " Days " : " Day ") : "";
  string strHour = hour > 0 ?  DoubleToString(hour, 0) + (hour > 1 ? " Hours ": " Hour ") : "";
  string strMinute = DoubleToString(minute, 0) + " Min";
  return strDay + strHour + strMinute;
}

//+------------------------------------------------------------------+
//| Convert datetime to Local datetime                               |
//+------------------------------------------------------------------+
datetime toLocalDateTime(datetime dt)
{
  MqlDateTime mdt = toLocalMqlDateTime(dt);
  return StructToTime(mdt);
}

//+------------------------------------------------------------------+
//| Convert datetime to Local as MqlDateTime                         |
//+------------------------------------------------------------------+
MqlDateTime toLocalMqlDateTime(datetime dt)
{
  MqlDateTime mdt;
  TimeToStruct(dt, mdt);
  int m = mdt.mon;
  int y = mdt.year;
  int dom = daysOfMonth(y, m);

  int offset = OFFSET_TIMEZONE_LOCAL - offsetTimezone;

  int newHour = mdt.hour + offset;

  // same day, same month, same year
  if(newHour >= 0 && newHour < 24) {
    mdt.hour = newHour;
    return mdt;
  }

  // yesterday, hour is less than 0
  if(newHour < 0) {
    mdt.hour = newHour + 24;
    int newDay = mdt.day - 1;
    // > same month, day is greater than 0, set new day
    if(newDay > 0) {
      mdt.day = newDay;
      return mdt;
    }
    // > last month, new day is zero
    int newMon = mdt.mon - 1;
    // > - same year, set new month, set date to dom of last month
    if(newMon > 0) {
      int newDom = daysOfMonth(y, newMon);
      mdt.day = newDom;
      mdt.mon = newMon;
      return mdt;
    }
    // > - last year, new month is zero, set to 31 Dec
    mdt.day = 31;
    mdt.mon = 12;
    mdt.year = mdt.year - 1;
    return mdt;
  }

  // tomorrow, new hour is overlap
  newHour -= 24;
  mdt.hour = newHour;
  int newDay = mdt.day + 1;
  if(newDay <= dom) {
    mdt.day = newDay;
    return mdt;
  }
  // > next month, day 1
  mdt.day = 1;
  int newMon = mdt.mon + 1;
  if(newMon <= 12) {
    // > - same year, set new month
    mdt.mon = newMon;
    return mdt;
  }
  // > - next year, set month to 1
  mdt.mon = 1;
  mdt.year = mdt.year + 1;
  return mdt;
}

//+------------------------------------------------------------------+
//| Return number days in month                                      |
//+------------------------------------------------------------------+
int daysOfMonth(int y, int m)
{
  switch (m) {
  case 1:
  case 3:
  case 5:
  case 7:
  case 8:
  case 10:
  case 12:
    return 31;
  case 4:
  case 6:
  case 9:
  case 11:
    return 30;
  case 2:
    // Leap year check for February
    if(y % 4 == 0 && (y % 100 != 0 || y % 400 == 0))
      return 29;
    else
      return 28;
  default:
    return 0; // Should never reach here
  }
}

//+------------------------------------------------------------------+
//| Number to String                                                 |
//+------------------------------------------------------------------+
template<typename T>
string NumberToString(T number, int digits = 0, string sep = ",")
{
  CString numberString;
  string prepend = number < 0 ? "-" : "";
  number = number < 0 ? -number : number;
  int decimalIndex = -1;
  if(typename(number) == "double" || typename(number) == "float") {
    numberString.Assign(DoubleToString((double) number, digits));
    decimalIndex = numberString.Find(0, ".");
  } else
    numberString.Assign(string(number));
  int len = (int)numberString.Len();
  decimalIndex = decimalIndex > 0 ? decimalIndex : len;
  int res = len - (len - decimalIndex);
  for(int i = res - 3; i > 0; i -= 3)
    numberString.Insert(i,sep);
  return prepend + numberString.Str();
}

//+------------------------------------------------------------------+
