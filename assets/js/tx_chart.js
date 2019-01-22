import Chart from "chart.js"

var TxChart = {
    buildChart(socket) {
        var ctx = document.getElementById("txChart");
        var height = document.getElementById("txData").dataset.blockheight;
        var tx = document.getElementById("txData").dataset.blocktx;
        // console.log("initHeight", JSON.parse(height))
        // console.log("initTx", JSON.parse(tx))
        var myChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: JSON.parse(height),
                datasets: [{
                    label: 'Block height vs Tx',
                    data: JSON.parse(tx),
                    backgroundColor: ['rgba(0,0,0,0.5)'],
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
        
        let channel = socket.channel("chart1:tx", {})
        
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

export default TxChart