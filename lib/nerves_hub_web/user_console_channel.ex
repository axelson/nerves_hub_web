defmodule NervesHubWeb.UserConsoleChannel do
  use NervesHubWeb, :channel

  alias Phoenix.Socket.Broadcast

  # intercept(["presence_diff"])

  def join("user_console", %{"device_id" => device_id, "product_id" => product_id}, socket) do
    socket.endpoint.subscribe(console_topic(device_id))
    socket.endpoint.subscribe("product:#{product_id}:devices")
    {:ok, assign(socket, :device_id, device_id)}
  end

  def handle_in(event, payload, %{assigns: %{device_id: device_id}} = socket) do
    # Keypresses are coming in here raw
    # Send them to the device
    socket.endpoint.broadcast_from!(self(), console_topic(device_id), event, payload)
    {:noreply, socket}
  end

  # This ties in the messages from Device that need to be handled in the console
  def handle_info(%Broadcast{payload: payload, event: event}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  defp console_topic(device_id) do
    "console:#{device_id}"
  end
end
