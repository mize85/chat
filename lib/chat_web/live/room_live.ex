defmodule ChatWeb.RoomLive do
  use ChatWeb, :live_view
  require Logger

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    username = MnemonicSlugs.generate_slug(1)
    topic = "room:" <> room_id
    if connected?(socket) do
      ChatWeb.Endpoint.subscribe(topic)
      ChatWeb.Presence.track(self(), topic, username, %{username: username, typing: false})

      ChatWeb.Endpoint.broadcast(
        topic,
        "new_message",
        %{
          id: Ecto.UUID.generate(),
          body: "#{username} joined the channel.",
          type: :system
        }
      )

    end
    {
      :ok,
      socket
      |> assign(
           room_id: room_id,
           username: username,
           users: [],
           topic: topic,
           message: "",
           messages: []
         ),
      temporary_assigns: [
        messages: []
      ]
    }
  end

  @impl true
  def handle_event(
        "submit_message",
        %{
          "chat" => %{
            "message" => message
          }
        },
        %{
          assigns: %{
            topic: topic,
            username: username
          }
        } = socket
      ) do
    Logger.debug(message: message)

    ChatWeb.Endpoint.broadcast(
      topic,
      "new_message",
      %{
        id: Ecto.UUID.generate(),
        body: message,
        username: username,
        type: :user
      }
    )

    {
      :noreply,
      socket
      |> assign(message: "")
    }
  end

  @impl true
  def handle_event(
        "typing",
        %{
          "chat" => %{
            "message" => message
          }
        },
        %{
          assigns: %{
            topic: topic,
            username: username
          } = assigns
        } = socket
      ) do

    ChatWeb.Presence.update(self(), topic, username, fn m -> %{m | typing: true}  end)
    case Map.get(assigns, :typing_ref) do
      nil -> :ignore
      typing_ref -> Process.cancel_timer(typing_ref, async: true, info: false)
    end

    typing_ref = Process.send_after(self(), %{event: "stop_typing", username: username}, 1_000)

    {
      :noreply,
      socket
      |> assign(message: message, typing_ref: typing_ref)
    }
  end

  @impl true
  def handle_info(
        %{event: "new_message", payload: message},
        %{
          assigns: %{
            messages: messages
          }
        } = socket
      ) do
    Logger.debug(message)
    {
      :noreply,
      socket
      |> assign(messages: [message])
    }
  end

  @impl true
  def handle_info(
        %{event: "stop_typing", username: username},
        %{
          assigns: %{
            topic: topic
          }
        } = socket
      ) do

    metas =
      ChatWeb.Presence.get_by_key(topic, username)
      |> Map.get(:metas)
      |> List.first()
      |> Map.merge(%{typing: false})

    ChatWeb.Presence.update(self(), topic, username, metas)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{
          event: "presence_diff"
        } = payload,
        %{
          assigns: %{
            topic: topic
          }
        } = socket
      ) do

    Logger.debug(payload)

    users =
      ChatWeb.Presence.list(topic)
      |> Enum.map(
           fn {_user_id, data} ->
             Map.get(data, :metas)
             |> List.first()
           end
         )

    {
      :noreply,
      socket
      |> assign(users: users)
    }
  end

  def terminate(
        reason,
        %{
          assigns: %{
            topic: topic,
            username: username
          }
        } = socket
      ) do

    ChatWeb.Endpoint.broadcast(
      topic,
      "new_message",
      %{
        id: Ecto.UUID.generate(),
        body: "#{username} left the channel.",
        type: :system
      }
    )

    :ok
  end

end
