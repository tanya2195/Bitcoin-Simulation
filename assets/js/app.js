// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"
import BtcChart from "./btc_chart"
import socket from "./socket"
var btcChartElement = document.getElementById("btcChart")
btcChartElement && BtcChart.buildChart(socket)

import HashChart from "./hash_chart"
var hashChartElement = document.getElementById("hashChart")
hashChartElement && HashChart.buildChart(socket)

import TxChart from "./tx_chart"
var txChartElement = document.getElementById("txChart")
txChartElement && TxChart.buildChart(socket)

import TxPara from "./tx_para"
var txParaElement = document.getElementById("para")
txParaElement && TxPara.buildChart(socket)



// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"
