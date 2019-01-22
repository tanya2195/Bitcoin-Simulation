defmodule Bitcoin1Web.BitcoinController do
    use Bitcoin1Web, :controller

    def index(conn, _params) do
        render(conn, "index.html")
    end

    def showBtc(conn, _params) do
        map = %{}
        # nodeMap = %{s: "94", p: "93"}
        # #nodeMap = GenServer.call(Bitcoin1.Btcmain, :getNodeMap)
        keys = Poison.encode!(Map.keys(map))
        IO.inspect keys
        vals = Poison.encode!(Map.values(map))
        IO.inspect vals
        # render(conn, "btc_chart_pg.html", nodeAddr: nodeAddr, nodeVals: dummyVals)
        render(conn, "btc_chart_pg.html", blockheight: keys, blockbtc: vals)
      end

      def showHash(conn, _params) do
        map = %{}
        keys = Poison.encode!(Map.keys(map))
        vals = Poison.encode!(Map.values(map))
        # render(conn, "btc_chart_pg.html", nodeAddr: nodeAddr, nodeVals: dummyVals)
        render(conn, "hash_chart_pg.html", blockheight: keys, blockhash: vals)
      end

      
      def showTx(conn, _params) do
        map = %{}
        keys = Poison.encode!(Map.keys(map))
        vals = Poison.encode!(Map.values(map))
        # render(conn, "btc_chart_pg.html", nodeAddr: nodeAddr, nodeVals: dummyVals)
        render(conn, "tx_chart_pg.html", blockheight: keys, blocktx: vals)
      end

      def showTxList(conn, _params) do
        map = %{}
        keys = Poison.encode!(Map.keys(map))
        vals = Poison.encode!(Map.values(map))
        # render(conn, "btc_chart_pg.html", nodeAddr: nodeAddr, nodeVals: dummyVals)
        render(conn, "tx_list_pg.html", key: keys, tx: vals)
      end

    def add_tx(payload) do
        IO.inspect("********new tx bc************")
        Bitcoin1Web.Endpoint.broadcast("chart1:tx", "new_tx", %{body: payload })
    end

    def update_btc(payload) do
        # payload = %{
        #     "height" => blockDetails.height,
        #     "coins" => blockDetails.totalBtc
        # }
        IO.inspect("********new btc************")
        Bitcoin1Web.Endpoint.broadcast("chart1:btc", "new_block", %{body: payload })
    end

    def update_hash(payload) do
        IO.inspect("********new hash************")
        Bitcoin1Web.Endpoint.broadcast("chart1:hash", "new_block", %{body: payload })
    end

    def update_tx(payload) do
        IO.inspect("********new tx count************")
        Bitcoin1Web.Endpoint.broadcast("chart1:tx", "new_block", %{body: payload })
    end

  end
  