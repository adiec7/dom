

# MQL5 Advanced DOM Analyzer

A powerful, self-contained MQL5 include file (`.mqh`) for advanced Depth of Market (DOM) and order flow analysis. This class-based module is designed to be easily integrated into any Expert Advisor or script, providing actionable intelligence from the live order book with no external dependencies.

This script was created to help traders and developers look deeper than just candlestick data, providing insights into the market's microstructure and the real-time balance of supply and demand.

## ✨ Key Features

  * **📈 Real-Time Order Flow Metrics:** Automatically calculates Bid/Ask Imbalance and a normalized Order Book Pressure score to gauge market control.
  * **💡 DOM Confidence Score:** Don't trade on bad data\! The analyzer scores the reliability of the order book (0-100) based on its depth and volume, preventing your EA from acting on thin, unreliable liquidity.
  * **🛡️ Order Absorption Analysis:** A unique feature that analyzes price vs. liquidity changes to detect when the market is absorbing heavy buying or selling pressure—a powerful technique for identifying institutional activity.
  * **🎯 "Strong Level" Detection:** Automatically flags significant liquidity pools in the order book that can act as powerful intra-day support or resistance zones.
  * **🔌 Plug-and-Play Class (`CDomAnalyzer`):** A fully encapsulated class that requires no external dependencies. It’s clean, professional, and reusable across multiple projects.

## 📋 Prerequisites

1.  **MetaTrader 5 Terminal:** The code is written in MQL5 and requires the MT5 platform.
2.  **A Broker with DOM Data:** Your broker must provide Depth of Market data for the instrument you are trading. For the highest quality and most authentic data, a true **ECN/DMA broker** is highly recommended.

## 🚀 How to Use

Integrating the `DomAnalyzer.mqh` into your project is simple and takes just a few minutes.

1.  **Download:** Download the `DomAnalyzer.mqh` file from this repository.
2.  **Place the File:** Place it in the `MQL5/Include/` directory of your MetaTrader 5 data folder.
3.  **Include in your EA:** At the top of your main `.mq5` file, add the following line:
    ```cpp
    #include <DomAnalyzer.mqh>
    ```
4.  **Declare an Instance:** Declare a global instance of the analyzer class.
    ```cpp
    CDomAnalyzer g_dom_analyzer;
    ```
5.  **Initialize and De-initialize:** Use your EA's `OnInit` and `OnDeinit` functions to manage the analyzer's lifecycle.
    ```cpp
    // In OnInit()
    int OnInit()
    {
        // ...
        g_dom_analyzer.Init(_Symbol, true); // true to enable logging
        return(INIT_SUCCEEDED);
    }

    // In OnDeinit()
    void OnDeinit(const int reason)
    {
        // ...
        g_dom_analyzer.Deinit();
    }
    ```
6.  **Analyze and Use Data:** Call the `Analyze()` method within `OnTick()` or `OnTimer()` to get the latest data. The results are stored in the public `Result` struct.
    ```cpp
    void OnTick()
    {
        if(g_dom_analyzer.Analyze())
        {
            // Analysis was successful, access the results
            double pressure = g_dom_analyzer.Result.orderBookPressure;
            double confidence = g_dom_analyzer.Result.domConfidence;
            double absorption = g_dom_analyzer.Result.absorptionScore;

            if(confidence > 50 && pressure > 0.2 && absorption > 60)
            {
                // Example: Place a trade based on strong bullish order flow
                Comment("Strong Bullish DOM Pressure Detected!");
            }
        }
    }
    ```

## 🎓 Understanding the Data: What You Are Actually Analyzing

It is critical to understand what this tool analyzes. The standard Depth of Market (DOM) provided by brokers to retail platforms **only shows visible limit orders** (the "order book").

  * ✅ **What it shows:** Passive buy/sell limit orders waiting at specific price levels.
  * ❌ **What it does NOT show:** Other traders' private **Stop Loss**, **Take Profit**, or pending stop orders (e.g., Buy/Sell Stops).

This private information is intentionally hidden by brokers to prevent market manipulation like "stop hunting." Our script correctly and powerfully analyzes all the data that is *realistically available* to a retail trader.

## 🤝 Contributing

This script is a starting point. The MQL5 community is full of brilliant developers, and I encourage everyone to contribute, provide feedback, and help improve it. Feel free to fork the repository, make your changes, and submit a pull request.

Some ideas for improvement:

  * Adding more advanced statistical metrics.
  * Creating visual indicators based on the class data.
  * Optimizing for even lower latency.

## 📄 License

This project is licensed under the MIT License. See the `LICENSE` file for details.

-----
