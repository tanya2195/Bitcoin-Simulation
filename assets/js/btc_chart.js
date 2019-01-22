import Chart from "chart.js"

var BtcChart = {
    buildChart(socket) {
        var ctx = document.getElementById("btcChart");
        var height = document.getElementById("btcData").dataset.blockheight;
        var btc = document.getElementById("btcData").dataset.blockbtc;
        console.log("initHeight", JSON.parse(height))
        console.log("initBtc", JSON.parse(btc))
        var myChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: JSON.parse(height),
                datasets: [{
                    label: 'Block height vs BTC transacted',
                    data: JSON.parse(btc),
                    backgroundColor: ['rgba(0,0,0,0.2)'],
                    borderColor: ['rgba(0,0,0,1)']
                }]
            },
            options: {
                scales: {
                    yAxes: [{
                        ticks: {
                            beginAtZero:true
                        }
                    }]
                }
            }
        });
        this.listenForUpdates(socket, myChart);
    },
    listenForUpdates(socket, myChart) {
        
        let channel = socket.channel("chart1:btc", {})
        
        channel.join()
        .receive("ok", resp => { console.log("Joined successfully", resp) })
        .receive("error", resp => { console.log("Unable to join", resp) })

        channel.on("new_block", payload => {
            console.log("new block successfully received", payload)
            //btcChart.data.datasets.forEach(dataset => {
                // console.log("sentHeight", Object.keys(payload.body))
                // console.log("sentBtc", Object.values(payload.body))
            myChart.data.labels = Object.keys(payload.body);
            myChart.data.datasets[0].data = Object.values(payload.body);
           //});
           myChart.update();
        })
    }
}

export default BtcChart