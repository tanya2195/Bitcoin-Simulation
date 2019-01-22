defmodule Bitcoin1.Proj42 do
    use GenServer

    def bcastTx(pid, {txHash, tx, boolBcast}) do
      GenServer.call(pid, {:bcastTx, txHash, tx, boolBcast})
    end
  
    def handle_call({:bcastTx, _txHash, tx, boolBcast}, _from, state) do
      {nodeMap, txMap, difficulty, blockSize, lastBcastBlock, blocks} = state
      #IO.inspect({String.slice(tx.txId, 0..8)}, label: "Tx bcast")
      if boolBcast == true do
        Enum.each(Map.values(nodeMap), fn({nodePid, _}) -> Kernel.send(nodePid, {:addTxToPool, tx}) end)
        #Enum.each(Map.values(nodeMap), fn({nodePid, _}) -> Bitcoin1.Node.addTxToPool(nodePid, tx) end)
      end
      {:reply, :ok, {nodeMap, txMap, difficulty, blockSize, lastBcastBlock, blocks}}
    end
  
    def bcastBlock(pid, block) do
      GenServer.cast(pid, {:bcastBlock, block})
    end
  
    def addTxToMap(pid, txHash, tx) do
      GenServer.cast(pid, {:addTxToMap, txHash, tx})
    end
  
    def handle_cast({:addTxToMap, txHash, tx}, state) do
      {nodeMap, txMap, difficulty, blockSize, lastBcastBlock, blocks} = state
      #IO.inspect({String.slice(tx.txId, 0..8)}, label: "Tx in map")
      newTxMap = Map.put_new(txMap, txHash, tx)
      {:noreply, {nodeMap, newTxMap, difficulty, blockSize, lastBcastBlock, blocks}}
    end
  
    def handle_cast({:bcastBlock, block}, state) do
      {nodeMap, txMap, difficulty, blockSize, _lastBcastBlock, blocks} = state
      #IO.inspect({String.slice(block.bHash, 0..8)}, label: "Block bcast")
      Enum.each(Map.values(nodeMap), fn({nodePid, _}) -> Bitcoin1.Node.addBlockToChain(nodePid, block) end)
      Process.send_after(self(), :sendBtcUpdate, 500)
      Process.send_after(self(), :sendTxUpdate, 500)
      Process.send_after(self(), :sendBHashUpdate, 500)
      #IO.inspect({String.slice(block.bHash, 0..8), "height", block.height}, label: "Block bcast")
      {:noreply, {nodeMap, txMap, difficulty, blockSize, block, [block|blocks]}}
    end
  
    def handle_info(:sendBtcUpdate, state) do
      {_nodeMap, txMap, _difficulty, _blockSize, _lastBcastBlock, blocks} = state
      blocksMap = Map.new Enum.map(blocks, fn(block) ->
        totalBtc = Enum.reduce(block.txHashes, 0, fn(txHash, acc) ->
          txOPs = Map.fetch!(txMap, txHash).txOPs
          totalOP = Enum.reduce(txOPs, 0, fn(txOP, sumOP) ->
            {_, amt1} = txOP
            sumOP + amt1
          end)
          acc + totalOP
        end)
        {"B"<>to_string(block.height), totalBtc-50}
      end)
      Bitcoin1Web.BitcoinController.update_btc(blocksMap)
      {:noreply, state}
    end

    def handle_info(:sendBHashUpdate, state) do
      {_nodeMap, txMap, _difficulty, _blockSize, _lastBcastBlock, blocks} = state
      blocksMap = Map.new Enum.map(blocks, fn(block) ->
        {"B"<>to_string(block.height), block.nonce}
      end)
      Bitcoin1Web.BitcoinController.update_hash(blocksMap)
      {:noreply, state}
    end

    def handle_info(:sendTxUpdate, state) do
      {_nodeMap, txMap, _difficulty, _blockSize, _lastBcastBlock, blocks} = state
      blocksMap = Map.new Enum.map(blocks, fn(block) ->
        totalTx = length(block.txHashes)
        {"B"<>to_string(block.height), totalTx}
      end)
      Bitcoin1Web.BitcoinController.update_tx(blocksMap)
      {:noreply, state}
    end

    def getTxFromMap(pid, txHash) do
      GenServer.call(pid, {:getTxFromMap, txHash})
    end
  
    def handle_call({:getTxFromMap, txHash}, _from, state) do
      {_nodeMap, txMap, _difficulty, _blockSize, _lastBcastBlock, blocks} = state
      tx = Map.fetch!(txMap, txHash)
      {:reply, tx, state}
    end
  
    def removeTxFromMap(pid, txHash) do
      GenServer.cast(pid, {:removeTxFromMap, txHash})  
    end
  
    def handle_cast({:removeTxFromMap, txHash}, state) do
      {nodeMap, txMap, difficulty, blockSize, lastBcastBlock, blocks} = state
      newTxMap = Map.delete(txMap, txHash)
      {:noreply, {nodeMap, newTxMap, difficulty, blockSize, lastBcastBlock, blocks}}
    end
  
    def getDifficulty(pid) do
      GenServer.call(pid, {:getDifficulty})
    end
  
    def handle_call({:getDifficulty}, _from, state) do
      {_nodeMap, _txMap, difficulty, _blockSize, _lastBcastBlock, blocks} = state
      {:reply, difficulty, state}
    end
  
    def getBlockSize(pid) do
      GenServer.call(pid, {:getBlockSize})
    end
  
    def handle_call({:getBlockSize}, _from, state) do
      {_nodeMap, _txMap, _difficulty, blockSize, _lastBcastBlock, blocks} = state
      {:reply, blockSize, state}
    end
  
    def getNodeMap(pid) do
      GenServer.call(pid, {:getNodeMap})
    end
  
    def handle_call({:getNodeMap}, _from, state) do
      {nodeMap, _txMap, _difficulty, _blockSize, _lastBcastBlock, blocks} = state
      {:reply, nodeMap, state}
    end
  
    def getNodePWid(pid, addr) do
      GenServer.call(pid, {:getNodePWid, addr})
    end
  
    def handle_call({:getNodePWid, addr}, _from, state) do
      {nodeMap, _txMap, _difficulty, _blockSize, _lastBcastBlock, blocks} = state
      {pid, wid} = Map.fetch!(nodeMap, addr)
      {:reply, {pid, wid}, state}
    end
  
    def getTxMap(pid) do
      GenServer.call(pid, {:getTxMap})
    end
  
    def handle_call({:getTxMap}, _from, state) do
      {_nodeMap, txMap, _difficulty, _blockSize, _lastBcastBlock, blocks} = state
      {:reply, txMap, state}
    end
  
    def getLastBcastBlock(pid) do
      GenServer.call(pid, {:getLastBcastBlock})
    end
  
    def handle_call({:getLastBcastBlock}, _from, state) do
      {_nodeMap, _txMap, _difficulty, _blockSize, lastBcastBlock, blocks} = state
      {:reply, lastBcastBlock, state}
    end
  
    def init(params) do
        IO.inspect params
      numNodes = Enum.at(params, 0, "100") |> String.to_integer
      numMiners = Enum.at(params, 1, "80") |> String.to_integer
      if numNodes < 10 do
        Process.exit(self(), "Let number of participants be 10 or more")
      end
      # nodeMap is a map with key=pubAddr and val=nodePid
      nodeMap = Map.new Enum.map(1..numNodes, fn(_i) ->
        {:ok, nodePid} = Bitcoin1.Node.start_link({self()})
        addr = Bitcoin1.Node.getAddress(nodePid)
        walletPid = Bitcoin1.Node.getWallet(nodePid)
        {addr, {nodePid, walletPid}}
      end)
      rndMinerList = Enum.take_random(Map.values(nodeMap), numMiners)
      Enum.each(rndMinerList, fn({pid, _}) -> Bitcoin1.Node.setMiner(pid) end)
      #IO.inspect rndMinerList
      txMap = %{}
      difficulty = 5
      blockSize = 4
      lastBcastBlock = %{}
      blocks = []
      state = {nodeMap, txMap, difficulty, blockSize, lastBcastBlock, blocks}
      {:ok, state}
    end


    def start_link(args) do
      {:ok, _mainPID} = GenServer.start_link(__MODULE__, args, [])
    end
  
    
  
    
  
    
  
  end