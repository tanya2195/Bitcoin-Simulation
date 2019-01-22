import Chart from "chart.js"

var TxPara = {
    buildChart(socket) {
        var txList = document.getElementById("para");
        this.listenForUpdates(socket);
    },
    listenForUpdates(socket) {
        
        let channel = socket.channel("chart1:tx", {})
        
        channel.join()
        .receive("ok", resp => { console.log("Joined successfully", resp) })
        .receive("error", resp => { console.log("Unable to join", resp) })

        channel.on("new_tx", payload => {
            console.log("new tx successfully received", payload)
            document.getElementById("para").innerHTML += "<br/><b>Tx -> </b>" + Object.values(payload.body);
        })
    }
}

export default TxPara