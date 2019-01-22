defmodule Bitcoin1.Btcmain do
    use GenServer

    def start_link(args) do
        {:ok, _thisPID} = GenServer.start_link(__MODULE__, args, [])
    end


    def init(args) do
        {:ok, mainPID} = Bitcoin1.Proj42.start_link(args)
        Process.send_after(self(), :beginNetwork, 100)
        {:ok, {mainPID}}
    end

    def handle_call(:getNodeMap, _from, state) do
      {mainPID, nodeMap} = state
      {:reply, nodeMap, state}
    end

    def handle_info(:beginNetwork, state) do
        {mainPID} = state
        nodeMap = Bitcoin1.Proj42.getNodeMap(mainPID)
        Enum.each(Map.values(nodeMap), fn({nodePid, _}) -> Bitcoin1.Node.createGenBlock(nodePid) end)
        #IO.inspect nodeMap
        dummyTx(nodeMap)
        {:noreply, {mainPID, nodeMap}}
    end

    def checkFirstTxBal(nodeMapValues) do
        index =  Enum.find_index(nodeMapValues, fn({_pid, wid}) ->
          Bitcoin1.Wallet.getBalance(wid) > 0
        end)
        if index == nil do
          checkFirstTxBal(nodeMapValues)
        else
          Enum.at(nodeMapValues, index)
        end
      end

      def dummyTx(nodeMap) do
        {_pidM, _widM} = checkFirstTxBal(Map.values(nodeMap))
        numRndNodes = Integer.floor_div(length(Map.keys(nodeMap)), 2)
        tempNodeVals = Enum.take_random(Map.values(nodeMap), numRndNodes)
        send4nRndTx(nil, nodeMap, tempNodeVals, 4)
      end

      def send4nRndTx(_pidM, nodeMap, tempNodeVals, count4n) do
        {pidM, _} = Enum.find(Enum.shuffle(Map.values(nodeMap)), nil, fn({_pid, wid}) -> Bitcoin1.Wallet.getBalance(wid) >= 50 end)
        rndNodeVals = Enum.reject(Enum.shuffle(tempNodeVals), fn({pid, _}) -> pid == pidM end)
        rndNodePids = Enum.map(rndNodeVals, fn({pid, _}) -> pid end)
        rndNodeWids = Enum.map(rndNodeVals, fn({_, wid}) -> wid end)
        rndNodePubKeys = Enum.map(rndNodePids, fn(pid) -> Bitcoin1.Node.getPubKey(pid) end)
        rndNodeAddrs = Enum.map(rndNodePubKeys, fn(pub) -> getAddrFromPubKey(pub) end)
        balB4_0 = Bitcoin1.Wallet.getBalance(Enum.at(rndNodeWids, 0))
        Bitcoin1.Node.createTx(pidM, Enum.at(rndNodeAddrs, 0), 20)
        Bitcoin1.Node.createTx(pidM, Enum.at(rndNodeAddrs, 1), 5)
        balB4_2 = Bitcoin1.Wallet.getBalance(Enum.at(rndNodeWids, 2))
        waitForTx(Enum.at(rndNodeWids, 0), balB4_0 + 20)
        Bitcoin1.Node.createTx(Enum.at(rndNodePids, 0), Enum.at(rndNodeAddrs, 2), 10)
        balB4_3 = Bitcoin1.Wallet.getBalance(Enum.at(rndNodeWids, 3))
        waitForTx(Enum.at(rndNodeWids, 2), balB4_2 + 10)
        Bitcoin1.Node.createTx(Enum.at(rndNodePids, 2), Enum.at(rndNodeAddrs, 3), 8)
        waitForTx(Enum.at(rndNodeWids, 3), balB4_3 + 8)
        Process.sleep(500)
        if count4n == 1 do
          nil
        else
          send4nRndTx(nil, nodeMap, tempNodeVals, count4n - 1)
        end
      end
    
      def waitForTx(walletPid, balReq) do
        if balReq > Bitcoin1.Wallet.getBalance(walletPid) do
          waitForTx(walletPid, balReq)
        else
          nil
        end
      end


      def getAddrFromPubKey(pubKey) do
        Base.encode16(:crypto.hash(:ripemd160, Base.encode16(:crypto.hash(:sha256, pubKey))))
      end

end