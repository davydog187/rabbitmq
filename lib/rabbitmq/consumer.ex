defmodule Rabbitmq.Consumer do
  use GenServer
  use AMQP

  require Logger

  def start_link(opts) do
    IO.inspect(opts, label: "opts")
    headers = Keyword.fetch!(opts, :headers)
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, %{name: name, headers: headers}, name: name)
  end

  def child_spec(data) do
    %{
      id: Keyword.fetch!(data, :name),
      start: {__MODULE__, :start_link, [data]}
    }
  end

  def init(data) do
    {:ok, data, {:continue, :start_consumer}}
  end

  def handle_continue(:start_consumer, %{headers: headers, name: name}) do
    {:ok, connection} = AMQP.Connection.open(username: "user", password: "bitnami")
    {:ok, channel} = AMQP.Channel.open(connection)
    name = to_string(name)

    {:ok, _} = AMQP.Queue.declare(channel, name)

    :ok =
      AMQP.Queue.bind(channel, name, "headers_exchange", arguments: [{"x-match", "all"} | headers])

    AMQP.Basic.consume(channel, name, nil, no_ack: true)

    {:noreply, %{name: name, channel: channel, connection: connection}}
  end                                                                   

  def handle_info({:basic_deliver, payload, _meta}, state) do
    IO.inspect(Jason.decode!(payload), label: "#{state.name} received payload")

    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, _payload}, state) do
    {:noreply, state}
  end
end
