defmodule Bitcoin1.Node do
    use GenServer

    def createTx(pid, toPubAddr, amt) do
        GenServer.cast(pid, {:createTx, toPubAddr, amt})
    end

    def handle_cast({:createTx, toPubAddr, amt}, state) do
        {privKey, pubKey, walletPid, bChain, txPool, orphanPool, isMiner, mainPID} = state
        {toPid, _} = Bitcoin1.Proj42.getNodePWid(mainPID, toPubAddr)
        timeStamp = System.system_time(:nanosecond)
        {txIPTxs, txIPsSum, change, toAdd} = Bitcoin1.Wallet.getTxIpChange(walletPid, amt)
        if length(txIPTxs) == 0 or txIPsSum < 0 or change < 0 or amt < 0 do
            {:noreply, state}
        else

            txOPs = [{toPubAddr, amt}, {getAddrFromPubKey(pubKey), change}]
            txIPs = Enum.map(txIPTxs, fn(tuple) ->
                {t, vo} = tuple
                {t.txId, vo}
            end)
            txHash = calcTxHash(timeStamp, length(txIPs), txIPs, length(txOPs), txOPs)
            # dgSig is kept as a byte array
            dgSig = :crypto.sign(:ecdsa, :sha256, txHash, [Base.decode16!(privKey), :secp256k1])
            tx = %{txId: txHash, timeStamp: timeStamp, numIPs: length(txIPs), txIPs: txIPs, numOPs: 2, txOPs: txOPs, pubKey: pubKey, dgSig: dgSig}
            
            utxo = Bitcoin1.Wallet.getUtxo(walletPid)
            stxo = Enum.reduce(txIPTxs, [], fn(txIPTx, acc) ->
                {tempTx, _} = txIPTx
                #[tempTxHash|acc]
                [tempTx|acc]
                end)
            newUtxo = 
                if toAdd == true do
                    #[txHash|utxo] -- stxo
                    [tx|utxo] -- stxo
                else
                    utxo -- stxo
                end
            Bitcoin1.Wallet.updateUtxo(walletPid, newUtxo)
            
            Bitcoin1.Proj42.bcastTx(mainPID, {txHash, tx, true})  #   tx is broadcasted to ALL (through mainPID), including yourself
            #IO.inspect({self()}, label: "createTx out")
            IO.inspect({self(), "to", toPid}, label: "createTx #{String.slice(tx.txId, 0..8)}.. -> send BTC #{amt} pubAddr #{toPubAddr}")
            message = "#{getAddrFromPubKey(pubKey)} sent #{amt} BTC to #{toPubAddr}"
            Bitcoin1Web.BitcoinController.add_tx(%{1 => message})
            {:noreply, {privKey, pubKey, walletPid, bChain, txPool, orphanPool, isMiner, mainPID}}
            # We add the recent tx to out utxo here itself, so as to have utxo for next tx
        end
    end

    def getTxhInPool(pid) do
        GenServer.call(pid, {:getTxhInPool})
    end

    def handle_call({:getTxhInPool}, _from, state) do
        {_privKey, _pubKey, _walletPid, _bChain, txPool, _orphanPool, _isMiner, _mainPID} = state
        poolHashes = Enum.reduce(txPool, [], fn(tx, acc) -> [tx.txId|acc] end)
        {:reply, poolHashes, state}
    end

    def addTxToPool(_pid, tx) do
        #GenServer.cast(pid, {:addTxToPool, tx})
        Kernel.send(self(), {:addTxToPool, tx})
    end

    def handle_info({:addTxToPool, tx}, state) do
        {privKey, pubKey, walletPid, bChain, txPool, orphanPool, isMiner, mainPID} = state
        if isMiner == false do
            {:noreply, state}
        else
            #IO.inspect({"hash", String.slice(tx.txId, 0..8), self()}, label: "addTxToPool")
            isOrphan = Enum.find_value(tx.txIPs, false, fn(txIP) ->
                {txId, _} = txIP
                Map.has_key?(Bitcoin1.Proj42.getTxMap(mainPID), txId) == false
            end)
            if isOrphan == true do
                newState = {privKey, pubKey, walletPid, bChain, txPool, [tx|orphanPool], isMiner, mainPID}
                #IO.inspect({self()}, label: "addTxToPool out 1")
                {:noreply, newState}
            else
                if verifyTx(tx, mainPID) == true do
                    Bitcoin1.Proj42.addTxToMap(mainPID, tx.txId, tx)
                    newTxPool = [tx|txPool]
                    newState = {privKey, pubKey, walletPid, bChain, newTxPool, orphanPool, isMiner, mainPID}  #   update new txPool
                    # if length(newTxPool) >= blockSize-1 and length(bChain) > 0 do
                    #     txForBlock = Enum.take(Enum.reverse(newTxPool), blockSize - 1)
                    #     # We refer to the 0th index because we have prepended new blocks (not appended)
                    #     prevBHash = Enum.at(bChain, 0).bHash
                    #     txHashes = Enum.map(txForBlock, fn(tx) -> calcTxHash(tx.timeStamp, tx.numIPs, tx.txIPs, tx.numOPs, tx.txOPs) end)
                    #     GenServer.cast(self(), {:createBlock, 1 + Enum.at(bChain, 0).height, prevBHash, txHashes})
                    # end
                    #IO.inspect({self()}, label: "addTxToPool out 2")
                    {:noreply, newState}
                else
                    #IO.inspect({self()}, label: "addTxToPool out 3")
                    {:noreply, state}
                end
            end
        end
    end

    def handle_info({:createBlocksFromPool, height}, state) do
        {privKey, pubKey, _walletPid, bChain, txPool, _orphanPool, isMiner, mainPID} = state
        #blockSize = Bitcoin1.Proj42.getBlockSize(mainPID)
        #IO.inspect({"length(txPool)", length(txPool), "length(bChain)", length(bChain), self()})
        #if length(txPool) >= blockSize - 1 and length(bChain) > 0 do
        if length(txPool) >= 1 and length(bChain) > 0 do
            #Enum.each(txPool, fn(tx) -> IO.inspect String.slice(tx.txId, 0..8) end)
            Process.sleep(100)
            #IO.inspect({"height", height, self()}, label: "createBlocksFromPool in")
            #txForBlock = Enum.take(Enum.reverse(txPool), blockSize - 1)
            txForBlock = txPool
            # We refer to the 0th index because we have prepended new blocks (not appended)
            prevBHash = Enum.at(bChain, 0).bHash
            #IO.inspect({self()}, label: "B4 txHashes")
            txHashes = Enum.map(txForBlock, fn(tx) -> calcTxHash(tx.timeStamp, tx.numIPs, tx.txIPs, tx.numOPs, tx.txOPs) end)
            #IO.inspect({self()}, label: "After txHashes")
            #GenServer.cast(self(), {:createBlock, 1 + Enum.at(bChain, 0).height, prevBHash, txHashes})
            {:ok, _msg} = createBlock(privKey, pubKey, bChain, isMiner, mainPID, height, prevBHash, txHashes)
            #IO.inspect({self()}, label: "createBlocksFromPool out 1")
            keepCreatingBlocks(height + 1)
        else
            keepCreatingBlocks(height)
        end
        {:noreply, state} 
    end

    def keepCreatingBlocks(newHeight) do
        Process.send_after(self(), {:createBlocksFromPool, newHeight}, 1)
    end

    def verifyTx(tx, mainPID) do
        if :crypto.verify(:ecdsa, :sha256, tx.txId, tx.dgSig, [Base.decode16!(tx.pubKey), :secp256k1]) == false do
            IO.inspect 1
            # Bitcoin1.Proj42.removeTxFromMap(mainPID, tx.txId)
            false
        else
            #IO.inspect 2
            {addr1, amt1} = Enum.at(tx.txOPs, 0)
            isCoinbase =
                if addr1 == getAddrFromPubKey(tx.pubKey) and tx.numOPs == 1 and amt1 == 50 do
                    true
                else
                    false
                end
            if isCoinbase == false and tx.numIPs == 0 do
                false
            else
                if isCoinbase == true do
                    true
                else
                    #IO.inspect({isCoinbase, String.slice(tx.txId, 0..8), self()}, label: "isCoinbase verified")
                    isNotOwnerOfIPs = Enum.find_value(tx.txIPs, false, fn(txIP) ->
                        {ipTxId, ipVOut} = txIP
                        #IO.inspect({self()}, label: "In verify, gonna check map")
                        ipTx = Bitcoin1.Proj42.getTxFromMap(mainPID, ipTxId)
                        {opAddr, _} = Enum.fetch!(ipTx.txOPs, ipVOut)
                        opAddr != getAddrFromPubKey(tx.pubKey)
                    end)
                    if isNotOwnerOfIPs == true do
                        IO.inspect 3
                        # Bitcoin1.Proj42.removeTxFromMap(mainPID, tx.txId)
                        false
                    else
                        #IO.inspect 4
                        totalOP = Enum.reduce(tx.txOPs, 0, fn(txOP, sumOP) ->
                            {_, amt1} = txOP
                            sumOP + amt1
                        end)
                        totalIP = Enum.reduce(tx.txIPs, 0, fn(txIP, sumIP) ->
                            {tH, vOp} = txIP
                            t = Bitcoin1.Proj42.getTxFromMap(mainPID, tH)
                            {_, amt2} = Enum.fetch!(t.txOPs, vOp)
                            sumIP + amt2
                        end)
                        if totalIP < totalOP do
                            # for a valid coinbase tx, sum(ip) = 0
                            {addr1, _} = Enum.at(tx.txOPs, 0)
                            isCoinbase =
                                if addr1 == getAddrFromPubKey(tx.pubKey) do
                                    true
                                else
                                    false
                                end
                            if isCoinbase == true do
                                #IO.inspect 5
                                true
                            else
                                IO.inspect 6
                                false
                                # Bitcoin1.Proj42.removeTxFromMap(mainPID, tx.txId)
                            end
                        else
                            #IO.inspect 7
                            true
                        end
                    end
                end
            end
        end
    end

    def createBlock(privKey, pubKey, _bChain, isMiner, mainPID, height, prevBHash, txHashes) do
    #def handle_cast({:createBlock, height, prevBHash, txHashes}, state) do
        #{privKey, pubKey, walletPid, bChain, txPool, orphanPool, isMiner, mainPID} = state
        if isMiner == true do
            #IO.inspect({"currBchainLength(from 1)", length(bChain), "new Block ht", height, self()}, label: "createBlock")
            difficulty = Bitcoin1.Proj42.getDifficulty(mainPID)
            myPubAddr = getAddrFromPubKey(pubKey)
            # creating coinbase transaction first
            timeStamp = System.system_time(:nanosecond)
            txOPs = [{myPubAddr, 50}]
            cbTxHash = calcTxHash(timeStamp, 0, [], 1, txOPs)
            # dgSig is kept as a byte array
            dgSig = :crypto.sign(:ecdsa, :sha256, cbTxHash, [Base.decode16!(privKey), :secp256k1])
            cbTx = %{txId: cbTxHash, timeStamp: timeStamp, numIPs: 0, txIPs: [], numOPs: 1, txOPs: txOPs, pubKey: pubKey, dgSig: dgSig}
            # Bitcoin1.Proj42.addTxToMap(mainPID, cbTxHash, cbTx)
            allTxHash =
                if height == 0 do
                    Base.encode16(:crypto.hash(:sha256, cbTxHash))
                else
                    Enum.reduce([cbTxHash|txHashes], "", fn(tHash, acc) -> Base.encode16(:crypto.hash(:sha256, acc <> tHash)) end)
                end
            zeroes = Enum.reduce(1..difficulty, "", fn(_i, acc) -> acc <> "0" end)
            mineAndBcastBlock(mainPID, difficulty, height, prevBHash, allTxHash, zeroes, 0, "noZeroesHash", [cbTxHash|txHashes], cbTx)
            #IO.inspect({self()}, label: "createBlock out")
        end
        {:ok, "done"}
    end

    def mineAndBcastBlock(mainPID, difficulty, height, prevBHash, allTxHash, zeroes, nonce, bHash, txHashes, cbTx) do
        if length(Map.keys(Bitcoin1.Proj42.getLastBcastBlock(mainPID))) != 0 and Bitcoin1.Proj42.getLastBcastBlock(mainPID).height == height do
            #IO.inspect({self()}, label: "Interrupted while finding nonce")
            nil
        else
            if String.length(bHash) >= difficulty and String.slice(bHash, 0..difficulty-1) == zeroes do
                block = %{height: height, prevBHash: prevBHash, allTxHash: allTxHash, nonce: nonce, bHash: bHash, txHashes: txHashes}
                Bitcoin1.Proj42.addTxToMap(mainPID, Enum.at(txHashes, 0), cbTx)
                #IO.inspect({self()}, label: "Bcasting my mined block")
                Bitcoin1.Proj42.bcastBlock(mainPID, block)     #   Not adding directly to your block chain, instead, broadcasting it to everyone (including yourself)
                IO.inspect({self()}, label: "#Block #{String.slice(block.bHash, 0..8)}.. at height #{block.height} and containing #{length(block.txHashes)} Txs (including CB) mined with nonce #{block.nonce}")
            else
                newBHash = calcBlockHash(height, prevBHash, allTxHash, nonce+1)
                mineAndBcastBlock(mainPID, difficulty, height, prevBHash, allTxHash, zeroes, nonce+1, newBHash, txHashes, cbTx)
            end
        end
    end

    def addBlockToChain(pid, block) do
        GenServer.cast(pid, {:addBlockToChain, block})
    end

    def handle_cast({:addBlockToChain, block}, state) do
        {privKey, pubKey, walletPid, bChain, txPool, orphanPool, isMiner, mainPID} = state
        if block.height > 0 do
            #IO.inspect({"new block ht", block.height, "new hash", String.slice(block.bHash, 0..8), "last block ht", Enum.at(bChain, 0).height, "new hash", String.slice(Enum.at(bChain, 0).bHash, 0..8), self()}, label: "addBlockToChain")
        end
        if (length(bChain) == 0 and block.prevBHash == "prevBHash") or (length(bChain) > 0 and Enum.at(bChain, 0).bHash == block.prevBHash) do
            if length(bChain) > 0 and Enum.at(bChain, 0).height == block.height do
                #IO.inspect({self()}, label: "addBlockToChain out 1")
                {:noreply, state}
            else
                #IO.inspect({"ht", block.height, "hash", String.slice(block.bHash, 0..8), self()}, label: "addBlockToChain")
                newState =
                    if verifyBlock(block, Bitcoin1.Proj42.getDifficulty(mainPID)) == true and verifyBlockChain([block|bChain]) == true do
                        Bitcoin1.Wallet.updateUtxoFromBlock(walletPid, block)
                        myBal = Bitcoin1.Wallet.getBalance(walletPid)
                        if myBal > 0 do
                            IO.inspect({self()}, label: "Balance after block #{block.height} is BTC #{myBal}")
                        end
                        newTxPool =
                            if block.height > 0 do
                                #[_cb|txExceptCb] = block.txHashes
                                #cbTx = Bitcoin1.Proj42.getTxFromMap(mainPID, cb)
                                #addTxToPool(self(), cbTx)
                                #IO.inspect({self()}, label: "clearing txpool")
                                txPool -- Enum.reduce(block.txHashes, [], fn(tHash, acc) -> [Bitcoin1.Proj42.getTxFromMap(mainPID, tHash)|acc] end)  
                            else
                                txPool
                            end
                        #IO.inspect({Enum.map(newTxPool, fn(tx) -> tx.txId end), self()}, label: "newTxPool")
                        {privKey, pubKey, walletPid, [block|bChain], newTxPool, orphanPool, isMiner, mainPID}
                    else
                        state
                    end
                if block.height == 0 do
                    Kernel.send(self(), :checkOrphans)
                    Kernel.send(self(), {:createBlocksFromPool, 1})
                end    
                #IO.inspect({self()}, label: "addBlockToChain out 2")
                {:noreply, newState}
            end
        else
            #IO.inspect({self()}, label: "addBlockToChain out 3")
            {:noreply, state}
        end
    end



    def verifyBlock(block, difficulty) do
        zeroes = Enum.reduce(1..difficulty, "", fn(_i, acc) -> acc <> "0" end)
        if String.slice(block.bHash, 0..difficulty-1) != zeroes do
            IO.inspect "FALSE 1"
            false
        else
            if block.bHash != calcBlockHash(block.height, block.prevBHash, block.allTxHash, block.nonce) do
                IO.inspect "FALSE 2"
                false
            else
                true
            end
        end
    end

    def verifyBlockChain(bChain) do
        # 0th block is the recent block as we have prepended new blocks
        if Enum.at(bChain, 0).height == 0 do
            true
        else    # So Genesis block is the last block
            if Enum.at(bChain, 0).prevBHash == Enum.at(bChain, 1).bHash do
                [_|bChainTail] = bChain
                verifyBlockChain(bChainTail)
            else
                false
            end
        end
    end

    def createGenBlock(pid) do
        GenServer.cast(pid, {:createGenBlock})
    end

    def handle_cast({:createGenBlock}, state) do
        {privKey, pubKey, _walletPid, bChain, _txPool, _orphanPool, isMiner, mainPID} = state
        createBlock(privKey, pubKey, bChain, isMiner, mainPID, 0, "prevBHash", [])
        {:noreply, state}
    end

    def calcTxHash(timeStamp, numIPs, txIPs, numOPs, txOPs) do
        hashTxIP = Enum.reduce(txIPs, "", fn(txIP, acc) ->
            {txId, vOut} = txIP
            acc <> Base.encode16(:crypto.hash(:sha256, txId <> Integer.to_string(vOut)))
        end)
        hashTxOP = Enum.reduce(txOPs, "", fn(txOP, acc) ->
            {addr, amt} = txOP
            acc <> Base.encode16(:crypto.hash(:sha256, addr <> to_string(amt)))
        end)
        hash1 = Base.encode16(:crypto.hash(:sha256, to_string(timeStamp) <> Integer.to_string(numIPs) <> hashTxIP <> Integer.to_string(numOPs) <> hashTxOP))
        Base.encode16(:crypto.hash(:sha256, hash1))
    end

    def calcBlockHash(height, prevBHash, allTxHash, nonce) do
        Base.encode16(:crypto.hash(:sha256, Integer.to_string(height) <> prevBHash <> allTxHash <> Integer.to_string(nonce)))
    end

    def getAddrFromPubKey(pubKey) do
        Base.encode16(:crypto.hash(:ripemd160, Base.encode16(:crypto.hash(:sha256, pubKey))))
    end

    def setMiner(pid) do
        GenServer.cast(pid, {:setMiner})
    end

    def handle_cast({:setMiner}, state) do
        {privKey, pubKey, walletPid, bChain, txPool, orphanPool, _isMiner, mainPID} = state
        {:noreply, {privKey, pubKey, walletPid, bChain, txPool, orphanPool, true, mainPID}}
    end

    def getAddress(pid) do  # Used by mainPID
        GenServer.call(pid, {:getAddress})
    end

    def handle_call({:getAddress}, _from, state) do
        {_privKey, pubKey, _walletPid, _bChain, _txPool, _orphanPool, _isMiner, _mainPID} = state
        {:reply, getAddrFromPubKey(pubKey), state}
    end

    def getWallet(pid) do
        GenServer.call(pid, {:getWallet})
    end

    def handle_call({:getWallet}, _from, state) do
        {_privKey, _pubKey, walletPid, _bChain, _txPool, _orphanPool, _isMiner, _mainPID} = state
        {:reply, walletPid, state}
    end

    def getPubKey(pid) do
        GenServer.call(pid, {:getPubKey})  
    end

    def handle_call({:getPubKey}, _from, state) do
        {_privKey, pubKey, _walletPid, _bChain, _txPool, _orphanPool, _isMiner, _mainPID} = state
        {:reply, pubKey, state}
    end

    def handle_info(:checkOrphans, state) do
        {privKey, pubKey, walletPid, bChain, txPool, orphanPool, isMiner, mainPID} = state
        newState =
            if orphanPool != nil and length(orphanPool) > 0 do
                IO.inspect({self()}, label: "checkOrphans")
                validTxList = Enum.reduce(orphanPool, [], fn(oTx, acc) ->
                    isStillOrphan = Enum.find_value(oTx.txIPs, false, fn(oTxIP) ->
                        {oTxId, _} = oTxIP
                        Map.has_key?(Bitcoin1.Proj42.getTxMap(mainPID), oTxId) == false
                    end)
                    if isStillOrphan == true do
                        acc
                    else
                        if verifyTx(oTx, mainPID) == true do
                            [oTx|acc]
                        else
                            acc
                        end
                    end
                end)
                stateInside =
                    if validTxList != nil and length(validTxList) > 0 do
                        {privKey, pubKey, walletPid, bChain, validTxList ++ txPool, orphanPool -- validTxList, isMiner, mainPID}
                    else
                        state
                    end
                stateInside
            else
                state
            end
        againCheckOrphans()
        {:noreply, newState}
    end

    def againCheckOrphans() do
        Process.send_after(self(), :checkOrphans, 1)
    end

    def init(args) do
        {mainPID} = args
        {pub_b, priv_b} = :crypto.generate_key(:ecdh, :secp256k1)
        pubKey = Base.encode16(pub_b)
        privKey = Base.encode16(priv_b)
        pubAddr = getAddrFromPubKey(pubKey)
        {:ok, walletPid} = Bitcoin1.Wallet.start_link({pubAddr, mainPID})
        bChain = []
        txPool = []
        orphanPool = []
        isMiner = false
        state = {privKey, pubKey, walletPid, bChain, txPool, orphanPool, isMiner, mainPID}
        {:ok, state}
    end

    def start_link(args) do
        GenServer.start_link(__MODULE__, args, [])
    end

end