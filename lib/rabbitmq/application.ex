defmodule Rabbitmq.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Rabbitmq.Producer,
      {Rabbitmq.Consumer, headers: [sport: :football], name: :football},
      {Rabbitmq.Consumer, headers: [sport: :baseball], name: :baseball},
      {Rabbitmq.Consumer, headers: [type: :micro], name: :micro_markets}
    ]

    opts = [strategy: :one_for_one, name: Rabbitmq.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
