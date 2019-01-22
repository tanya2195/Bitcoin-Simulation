defmodule Bitcoin1.Wallet do
    use GenServer

    def getUtxo(pid) do   # Enquired by mainPID
        GenServer.call(pid, {:getUtxo})
    end
  
    def handle_call({:getUtxo}, _from, state) do
        {pubAddr, utxo, mainPID} = state
        {:reply, utxo, state}
    end

    def updateUtxo(pid, newUtxo) do
        GenServer.call(pid, {:updateUtxo, newUtxo})
    end

    def handle_call({:updateUtxo, newUtxo}, _from, state) do
        {pubAddr, utxo, mainPID} = state
        #IO.inspect({length(newUtxo -- utxo), self()}, label: "updateUtxo in")
        #IO.inspect({self()}, label: "updateUtxo out")
        {:reply, :ok, {pubAddr, newUtxo, mainPID}}
    end

    def getTxIpChange(pid, amt) do
        GenServer.call(pid, {:getTxIpChange, amt})
    end

    def updateUtxoFromBlock(pid, block) do
        GenServer.call(pid, {:updateUtxoFromBlock, block})
    end

    def handle_call({:updateUtxoFromBlock, block}, _from, state) do
        #IO.inspect({"hash", String.slice(block.bHash, 0..8), "ht", block.height, self()}, label: "updateUtxoFromBlock")
        {pubAddr, utxo, mainPID} = state
        if block.height == 0 do
            tx = Bitcoin1.Proj42.getTxFromMap(mainPID, Enum.at(block.txHashes, 0))
            txOP = Enum.at(tx.txOPs, 0)
            {cbAddr, _} = txOP
            if cbAddr == pubAddr and length(tx.txOPs) == 1 do
                #IO.inspect({self()}, label: "updateUtxoFromBlock out 1")
                txGb = Bitcoin1.Proj42.getTxFromMap(mainPID, Enum.at(block.txHashes, 0))
                #{:reply, :ok, {pubAddr, [Enum.at(block.txHashes, 0)|utxo], mainPID}}
                {:reply, :ok, {pubAddr, [txGb|utxo], mainPID}}
            else
                #IO.inspect({self()}, label: "updateUtxoFromBlock out 2")
                {:reply, :ok, state}
            end
        else
            #[cb|txExceptCb] = block.txHashes
            addUtxo = Enum.reduce(block.txHashes, [], fn(txHash, acc) ->
                tx = Bitcoin1.Proj42.getTxFromMap(mainPID, txHash)
                {firstAddr, firstAmt} = Enum.at(tx.txOPs, 0)
                iReceived =
                    if firstAddr == pubAddr do
                        true
                    else
                        false
                    end
                newAcc =
                    if iReceived == true do
                        #IO.inspect({"I Got", self()}, label: ">")
                        #[txHash|acc]
                        [tx|acc]
                    else
                        acc
                    end
                newAcc
            end)
            addedUtxo =
                if addUtxo != nil and length(addUtxo) > 0 do
                    addUtxo ++ utxo
                else
                    utxo
                end
            #IO.inspect({self()}, label: "updateUtxoFromBlock out 3")
            {:reply, :ok, {pubAddr, addedUtxo, mainPID}}
        end
    end

    def handle_call({:getTxIpChange, amt}, _from, state) do
        #IO.inspect({amt, self()}, label: "getTxIpChange in")
        {pubAddr, utxo, mainPID} = state
        #txIPsTemp = Enum.reduce_while(utxo, [], fn(txHash, accRes) ->
        txIPsTemp = Enum.reduce_while(utxo, [], fn(utx, accRes) ->
            amtSoFar = Enum.reduce(accRes, 0, fn(accTuple, sumAcc1) ->
                {_, _, amt1} = accTuple
                sumAcc1 + amt1
            end)
            if amtSoFar >= amt do
                {:halt, accRes}
            else
                #utx = Bitcoin1.Proj42.getTxFromMap(mainPID, txHash)
                vOut = Enum.find_index(utx.txOPs, fn(txOP) ->
                    {pubAddr1, _} = txOP
                    pubAddr1 == pubAddr
                end)
                {_, outAmt} = Enum.fetch!(utx.txOPs, vOut)
                #{:cont, [{txHash, vOut, outAmt}|accRes]}
                {:cont, [{utx, vOut, outAmt}|accRes]}
            end
        end)
        txIPsSum = Enum.reduce(txIPsTemp, 0, fn(txIP, sumAcc2) ->
            {_, _, amt2} = txIP
            sumAcc2 + amt2
        end)
        if txIPsSum < amt do
            {:reply, {[], -1, -1, false}, state}
        else
            change = txIPsSum - amt
            txIPs = Enum.map(txIPsTemp, fn(tuple) ->
                #{txId, vOut, _} = tuple
                #{txId, vOut}
                {tx, vOut, _} = tuple
                {tx, vOut}
            end)
            if change > 0 do
                #IO.inspect({self()}, label: "getTxIpChange out 1")
                {:reply, {txIPs, txIPsSum, change, true}, state}
            else
                #IO.inspect({self()}, label: "getTxIpChange out 2")
                {:reply, {txIPs, txIPsSum, change, false}, state}
            end
        end
    end

    def getBalance(pid) do
        GenServer.call(pid, {:getBalance})
    end
    
    def handle_call({:getBalance}, _call, state) do
        # IO.inspect({self()}, label: "getBalance")
        {pubAddr, utxo, mainPID} = state
        if utxo == nil or length(utxo) == 0 do
            {:reply, 0, state}
        else
            balance = Enum.reduce(utxo, 0, fn(tx, sum) ->
                #tx = Bitcoin1.Proj42.getTxFromMap(mainPID, txHash)
                {myAddr, myAmt} = Enum.find(tx.txOPs, fn(txOP) ->
                    {addr, _} = txOP
                    addr == pubAddr
                end)
                sum + myAmt
            end)
            {:reply, balance, state}
        end
    end

    def init(args) do
        {pubAddr, mainPID} = args
        utxo = []
        state = {pubAddr, utxo, mainPID}
        {:ok, state}
    end

    def start_link(args) do
        GenServer.start_link(__MODULE__, args, [])
    end

end