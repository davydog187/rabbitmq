defmodule Rabbitmq.Producer do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: :producer)
  end

  def init(:ok) do
    IO.puts("producer init")
    {:ok, :init, {:continue, :start_producer}}
  end

  @exchange "headers_exchange"
  def handle_continue(:start_producer, :init) do
    {:ok, connection} = AMQP.Connection.open(username: "user", password: "bitnami")
    {:ok, channel} = AMQP.Channel.open(connection)

    :ok = AMQP.Exchange.declare(channel, @exchange, :headers, durable: true)

    {:ok, timer} = :timer.send_interval(:timer.seconds(1), :publish)

    {:noreply, %{timer: timer, channel: channel, connection: connection, messages: messages()}}
  end

  def handle_info(:publish, %{messages: [message | messages]} = state) do
    Logger.info("Publishing #{inspect(message)} headers=#{inspect(headers(message))}")

    AMQP.Basic.publish(state.channel, @exchange, "", Jason.encode!(message),
      headers: headers(message)
    )

    {:noreply, %{state | messages: messages}}
  end

  def handle_info(:publish, %{messages: []} = state) do
    :timer.cancel(state.timer)

    {:noreply, %{state | timer: nil}}
  end

  def terminate(_reason, state) do
    AMQP.Connection.close(state.connection)
  end

  def messages do
    (generate_messages(:over_under, :baseball) ++
       generate_messages(:spread, :football) ++
       generate_messages(:micro, :baseball) ++
       generate_messages(:micro, :football))
    |> Enum.shuffle()
  end

  defp generate_messages(market_type, sport) do
    [
      :pending,
      :update,
      :update,
      :update,
      :update,
      :done
    ]
    |> Enum.with_index()
    |> Enum.map(fn {status, index} ->
      %{type: market_type, sport: sport, status: status, message_number: index + 1}
    end)
  end

  defp headers(payload) do
    payload
    |> Map.take([:sport, :status, :type])
    |> Enum.to_list()
  end
end
