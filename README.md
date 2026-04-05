<div align="center">

![VisualRiskCalc Banner](https://placehold.co/800x200/2C3E50/FFFFFF?text=VisualRiskCalculator&font=montserrat)

![MetaTrader 5](https://img.shields.io/badge/MetaTrader-5-green?logo=metatrader&logoColor=white)
![MQL5](https://img.shields.io/badge/Language-MQL5-blue)
![License](https://img.shields.io/badge/License-MIT-yellow?logo=opensourceinitiative)

</div>

> ⚠️ **Setup & Requirement Notice**
>
> VisualRiskCalculator is an **Expert Advisor (EA)** for **MetaTrader 5**.
>
> **Algo Trading Required:** For the drag-and-drop features and trade execution to work, you must enable the **"Algo Trading"** button in your MT5 toolbar.
>
> **Account Compatibility:** This tool works with both **Netting** and **Hedging** accounts. It automatically detects your account currency (e.g., trading EURUSD on a JPY account) and handles all conversion math instantly.

This utility is built on a simple philosophy: **Stop calculating. Start trading.** It eliminates the need for external calculators or mental math by integrating risk management directly into the visual chart experience.

---

## How to Install

This follows the standard installation process for any MetaTrader Expert Advisor.

1.  **Download** the `VisualRiskCalc.mq5` file from this repository.
2.  Open **MetaTrader 5**.
3.  Go to **File** -> **Open Data Folder**.
4.  Navigate to the `MQL5` folder, then open the `Experts` folder.
5.  **Copy and Paste** the `VisualRiskCalc.mq5` file into this folder.
6.  Go back to MetaTrader 5, right-click on the **Navigator** panel (usually on the left), and click **Refresh**. The EA will appear under the "Expert Advisors" list.

---

## Showcase: The Tool in Action

VisualRiskCalc provides a fluid, Visual interface for trade management. Here is how it improves your workflow.

| Feature Showcase                                           | Description                                                                                                                                                                                                                                   |
| :--------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ![Drag Showcase](.github/assets/price_line_dragging.gif)   | **Seamless Drag-and-Drop**: A red "handle" arrow sits on the current price line. simply click and drag it to your desired Stop Loss level. The tool automatically detects if you are going Short or Long based on where you drag.             |
| ![RealTime Showcase](.github/assets/panel_update.gif)      | **Real-Time Calculation**: As you move your mouse, the panel updates instantly. It calculates the exact **Lot Size** needed to risk your specific percentage, converts currency rates, and projects the Pip distance.                         |
| ![Execution Showcase](.github/assets/take_profit_line.gif) | **Smart Execution**: The tool draws a dynamic **Take Profit** line (default 1:2) that moves with you. When you are ready, the "WAITING" button turns into a **BUY** or **SELL** button. One click executes the trade and cleans up the chart. |

---

## Configuration & Usage

### 1. The Workflow

Forget opening calculator apps. The process is entirely visual.

1.  **Grab the Handle:** Look for the red line on the current price axis and drag it, **OR** type your exact target price into the "Stop Loss" box and press Enter.
2.  **Drag to SL:** Pull it to where your Stop Loss should be. The tool activates immediately.
3.  **Adjust:** You can tweak the **Risk %** or **R:R Ratio** in the panel while the lines are active; the lines and math will update instantly.
4.  **Execute:** Click the large colored button at the bottom to place the order.

### 2. Input Parameters

You can configure the defaults when you first load the EA onto the chart.

| Parameter        | Default        | Description                                                                                                               |
| :--------------- | :------------- | :------------------------------------------------------------------------------------------------------------------------ |
| `DefRiskPercent` | `1.0`          | The default percentage of your Account Balance you are willing to lose on a trade.                                        |
| `DefRewardRatio` | `2.0`          | The default Risk-to-Reward ratio. `2.0` sets the Take Profit at 2x the distance of the Stop Loss.                         |
| `PanelYOffset`   | `60`           | How far down (in pixels) the panel sits from the top of the chart. Useful if you have other indicators in the top corner. |
| `ThemeColor`     | `MidnightBlue` | The background color of the control panel.                                                                                |

### 3. The Panel Interface

The on-chart GUI gives you full control without navigating menus.

- **Risk % Field:** Change this to `0.5`, `2.0`, etc., to resize your position instantly.
- **Reward Field:** Change this to `3.0` to extend your Take Profit line further out.
- **Stop Loss Field:** Manually type a specific price (e.g., `1.15600`) and press Enter for ultimate precision. The visual lines will instantly snap to this exact level.
- **Type-Safety:** Enter numbers however you like. The calculator automatically converts commas (`,`) to dots (`.`).
- **Exact Currency Loss:** The panel displays your exact calculated monetary risk natively in your account's currency (e.g., `Loss: 10.50 EUR`), automatically factoring in broker lot-step rounding.
- **Reset Button:** Cancels the current analysis, removes the lines, and resets the tool to the "Passive" state.

---

## Features

- **Zero Dependencies:** Uses standard MQL5 libraries (`Trade.mqh`) included with every MT5 installation.
- **Dynamic Stop Loss:** Dragging the SL line automatically adjusts the TP line to maintain your R:R ratio.
- **Smart Direction:** Automatically detects **Long (Buy)** vs **Short (Sell)** based on whether the Stop Loss is below or above the current price.
- **Cross-Asset Math:** Uses MT5's native `TickSize` and `TickValue` mechanics. This guarantees 100% accurate risk calculations across **Forex, Crypto, Metals, and Indices**, perfectly converted to your account currency without blowing your account.
- **Lot Normalization:** Automatically rounds lot sizes to the broker's `Step` value (e.g., 0.01 or 0.1) and adheres to Min/Max volume limits.
