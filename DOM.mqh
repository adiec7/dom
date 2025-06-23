//+------------------------------------------------------------------+
//|                                                 DomAnalyzer.mqh |
//|                      Copyright 2025, KSQUANTITATIVE              |
//|                                      https://www.ksquants.com    |
//|                                                                  |
//|    A self-contained class for advanced Depth of Market (DOM)     |
//|    and Order Flow analysis.                                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, KSQUANTITATIVE"
#property link      "https://www.ksquants.com"
#property version   "1.10"

#include <Trade/SymbolInfo.mqh> // Include necessary standard library

//+------------------------------------------------------------------+
//| Structure to hold all data related to DOM and Order Flow analysis|
//+------------------------------------------------------------------+
struct SOrderFlowData
{
    // DOM-based data
    double bidAskImbalance;   // Bid volume / Ask volume ratio
    double orderBookPressure; // Net order book pressure ((Bids-Asks)/(Bids+Asks))
    double bidDepth;          // Total bid volume in DOM
    double askDepth;          // Total ask volume in DOM
    int    strongBidLevels;   // Number of significant bid levels
    int    strongAskLevels;   // Number of significant ask levels
    double absorptionScore;   // Score indicating how well price absorbs selling/buying (0-100)
    bool   isDOMAvailable;    // Flag indicating if DOM data is available for the symbol
    double domConfidence;     // Confidence in DOM data (0-100), based on depth and volume

    // --- Method to reset all values to default ---
    void   Reset()
    {
        bidAskImbalance = 1.0;
        orderBookPressure = 0.0;
        bidDepth = 0.0;
        askDepth = 0.0;
        strongBidLevels = 0;
        strongAskLevels = 0;
        absorptionScore = 50.0;
        isDOMAvailable = false;
        domConfidence = 0.0;
    }
};


//+------------------------------------------------------------------+
//| CDomAnalyzer Class                                               |
//| Encapsulates all DOM analysis logic.                             |
//+------------------------------------------------------------------+
class CDomAnalyzer
{
private:
    // --- Member Variables ---
    string           m_symbol;
    CSymbolInfo      m_symbol_info;
    bool             m_is_initialized;
    bool             m_log_to_experts; // Flag to control logging

    // --- State variables for cached/timed calculations ---
    double           m_absorption_prev_bid_depth;
    double           m_absorption_prev_ask_depth;
    double           m_absorption_prev_price;
    double           m_cached_avg_book_volume;
    datetime         m_avg_book_volume_last_update;

    // --- Private Helper Methods ---
    void             CalculateAbsorptionScore();
    double           GetAverageBookVolume();
    double           GetMinimumBookVolume();
    bool             IsCryptoSymbol();

public:
    // --- Public Member Data ---
    SOrderFlowData   Result; // Holds the latest analysis results

    // --- Constructor & Destructor ---
                     CDomAnalyzer(void);
                    ~CDomAnalyzer(void);

    // --- Main Methods ---
    bool             Init(const string symbol, bool enable_logging = true);
    void             Deinit(void);
    bool             Analyze(void); // Main analysis function
    bool             IsAvailable(void);
};

//+------------------------------------------------------------------+
//| Class Constructor                                                |
//+------------------------------------------------------------------+
CDomAnalyzer::CDomAnalyzer(void) : m_is_initialized(false),
                                     m_log_to_experts(true),
                                     m_absorption_prev_bid_depth(0),
                                     m_absorption_prev_ask_depth(0),
                                     m_absorption_prev_price(0),
                                     m_cached_avg_book_volume(0),
                                     m_avg_book_volume_last_update(0)
{
    Result.Reset();
}

//+------------------------------------------------------------------+
//| Class Destructor                                                 |
//+------------------------------------------------------------------+
CDomAnalyzer::~CDomAnalyzer(void)
{
    Deinit();
}

//+------------------------------------------------------------------+
//| Initializes the analyzer for a specific symbol.                  |
//| Call this in your EA's OnInit().                                 |
//+------------------------------------------------------------------+
bool CDomAnalyzer::Init(const string symbol, bool enable_logging)
{
    m_symbol = symbol;
    m_log_to_experts = enable_logging;

    if(!m_symbol_info.Name(m_symbol))
    {
        if(m_log_to_experts) PrintFormat("CDomAnalyzer Error: Failed to initialize CSymbolInfo for %s.", m_symbol);
        return(false);
    }

    if (!IsAvailable())
    {
        if(m_log_to_experts) PrintFormat("CDomAnalyzer Info: DOM not available for %s.", m_symbol);
        m_is_initialized = false;
        return(false);
    }

    if (!MarketBookAdd(m_symbol))
    {
        if(m_log_to_experts) PrintFormat("CDomAnalyzer Error: Failed to subscribe to DOM for %s. Error: %d", m_symbol, GetLastError());
        m_is_initialized = false;
        return(false);
    }

    if(m_log_to_experts) PrintFormat("CDomAnalyzer: Successfully initialized and subscribed to DOM for %s.", m_symbol);
    m_is_initialized = true;
    return(true);
}

//+------------------------------------------------------------------+
//| Releases resources. Call this in your EA's OnDeinit().           |
//+------------------------------------------------------------------+
void CDomAnalyzer::Deinit(void)
{
    if(m_is_initialized)
    {
        MarketBookRelease(m_symbol);
        if(m_log_to_experts) PrintFormat("CDomAnalyzer: Released DOM subscription for %s.", m_symbol);
        m_is_initialized = false;
    }
}

//+------------------------------------------------------------------+
//| Checks if DOM is available for the configured symbol.            |
//+------------------------------------------------------------------+
bool CDomAnalyzer::IsAvailable(void)
{
    MqlBookInfo book[];
    return(MarketBookGet(m_symbol, book));
}

//+------------------------------------------------------------------+
//| Performs a full analysis and updates the public 'Result' struct. |
//+------------------------------------------------------------------+
bool CDomAnalyzer::Analyze(void)
{
    if(!m_is_initialized) return false;

    // Refresh symbol rates to ensure prices are current
    m_symbol_info.RefreshRates();

    MqlBookInfo book_array[];
    if(!MarketBookGet(m_symbol, book_array))
    {
        Result.isDOMAvailable = false;
        Result.domConfidence = 0;
        return(false);
    }
    
    Result.isDOMAvailable = true;

    if(ArraySize(book_array) < 4)
    {
        Result.domConfidence = 10;
        if(m_log_to_experts) PrintFormat("CDomAnalyzer Warning: Insufficient DOM depth on %s: %d levels.", m_symbol, ArraySize(book_array));
        return(false);
    }

    // Reset metrics before calculation
    Result.Reset();
    Result.isDOMAvailable = true; // Set back to true after reset

    double totalBidVolume = 0;
    double totalAskVolume = 0;
    double avgBookVolume = GetAverageBookVolume();

    for(int i = 0; i < ArraySize(book_array); i++)
    {
        if(book_array[i].type == BOOK_TYPE_BUY || book_array[i].type == BOOK_TYPE_BUY_MARKET)
        {
            totalBidVolume += (double)book_array[i].volume;
            if(book_array[i].volume > avgBookVolume * 2.0) Result.strongBidLevels++;
        }
        else if(book_array[i].type == BOOK_TYPE_SELL || book_array[i].type == BOOK_TYPE_SELL_MARKET)
        {
            totalAskVolume += (double)book_array[i].volume;
            if(book_array[i].volume > avgBookVolume * 2.0) Result.strongAskLevels++;
        }
    }

    Result.bidDepth = totalBidVolume;
    Result.askDepth = totalAskVolume;

    // Calculate Bid/Ask Imbalance Ratio
    Result.bidAskImbalance = (totalAskVolume > 0) ? totalBidVolume / totalAskVolume : (totalBidVolume > 0 ? 100.0 : 1.0);

    // Calculate Normalized Order Book Pressure
    double totalBookVolume = totalBidVolume + totalAskVolume;
    Result.orderBookPressure = (totalBookVolume > 0) ? (totalBidVolume - totalAskVolume) / totalBookVolume : 0.0;

    // Calculate DOM Confidence
    Result.domConfidence = MathMin(100.0, (double)ArraySize(book_array) * 5.0);
    if(totalBookVolume < GetMinimumBookVolume()) Result.domConfidence *= 0.5;

    // Calculate advanced absorption score
    CalculateAbsorptionScore();
    
    return true;
}

//+------------------------------------------------------------------+
//| Private: Calculates the absorption score.                        |
//+------------------------------------------------------------------+
void CDomAnalyzer::CalculateAbsorptionScore()
{
    double currentPrice = m_symbol_info.Bid();
    if(currentPrice <= 0) return;

    if(m_absorption_prev_price == 0) // Initialize on first run
    {
        m_absorption_prev_price = currentPrice;
        m_absorption_prev_bid_depth = Result.bidDepth;
        m_absorption_prev_ask_depth = Result.askDepth;
        Result.absorptionScore = 50.0;
        return;
    }

    double priceChange = currentPrice - m_absorption_prev_price;
    double bidDepthChange = Result.bidDepth - m_absorption_prev_bid_depth;
    double askDepthChange = Result.askDepth - m_absorption_prev_ask_depth;

    Result.absorptionScore = 50.0; // Default to neutral

    if(priceChange > 0 && askDepthChange < 0 && Result.askDepth > 0) // Price went up, asks were absorbed
    {
        Result.absorptionScore = 70.0 + MathMin(30.0, MathAbs(askDepthChange) / Result.askDepth * 100.0);
    }
    else if(priceChange < 0 && bidDepthChange < 0 && Result.bidDepth > 0) // Price went down, bids were absorbed
    {
        Result.absorptionScore = 30.0 - MathMin(30.0, MathAbs(bidDepthChange) / Result.bidDepth * 100.0);
    }

    m_absorption_prev_price = currentPrice;
    m_absorption_prev_bid_depth = Result.bidDepth;
    m_absorption_prev_ask_depth = Result.askDepth;
}

//+------------------------------------------------------------------+
//| Private: Gets average volume per level, cached for 60s.          |
//+------------------------------------------------------------------+
double CDomAnalyzer::GetAverageBookVolume()
{
    if(TimeCurrent() - m_avg_book_volume_last_update > 60)
    {
        MqlBookInfo book[];
        if(MarketBookGet(m_symbol, book) && ArraySize(book) > 0)
        {
            double totalVolume = 0;
            for(int i = 0; i < ArraySize(book); i++) totalVolume += (double)book[i].volume;
            m_cached_avg_book_volume = totalVolume / ArraySize(book);
        }
        m_avg_book_volume_last_update = TimeCurrent();
    }
    return m_cached_avg_book_volume > 0 ? m_cached_avg_book_volume : 1.0;
}

//+------------------------------------------------------------------+
//| Private: Gets a minimum volume threshold based on asset type.    |
//+------------------------------------------------------------------+
double CDomAnalyzer::GetMinimumBookVolume()
{
    if(IsCryptoSymbol()) return 10;
    if(StringFind(m_symbol, "US30") != -1 || StringFind(m_symbol, "NAS100") != -1) return 100;
    return 1000; // Forex Default
}

//+------------------------------------------------------------------+
//| Private: Checks if the symbol is a cryptocurrency.               |
//+------------------------------------------------------------------+
bool CDomAnalyzer::IsCryptoSymbol()
{
    string upper_symbol = m_symbol;
    StringToUpper(upper_symbol);
    return(StringFind(upper_symbol, "BTC") != -1 || StringFind(upper_symbol, "ETH") != -1 || StringFind(upper_symbol, "XRP") != -1);
}
//+------------------------------------------------------------------+