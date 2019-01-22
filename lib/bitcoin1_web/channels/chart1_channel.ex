defmodule Bitcoin1Web.Chart1Channel do
  use Bitcoin1Web, :channel

  def join("chart1:btc", _payload, socket) do
      {:ok, socket}
  end

  def join("chart1:tx", _payload, socket) do
    {:ok, socket}
  end

  def join("chart1:hash", _payload, socket) do
    {:ok, socket}
  end
  
  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (chart1:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  # defp authorized?(_payload) do
  #   true
  # end
end
