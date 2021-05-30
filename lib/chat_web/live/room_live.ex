defmodule ChatWeb.RoomLive do
  use ChatWeb, :live_view
  require Logger

  @default_locale "en"
  @default_timezone "UTC"
  @default_timezone_offset 0

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    username = MnemonicSlugs.generate_slug(1)
    avatar = "https://i.pravatar.cc/40?img=#{Enum.random(1..70)}"
    topic = "room:" <> room_id
    if connected?(socket) do
      ChatWeb.Endpoint.subscribe(topic)
      ChatWeb.Presence.track(self(), topic, username, %{avatar: avatar, username: username, typing: false})

      ChatWeb.Endpoint.broadcast(
        topic,
        "new_message",
        %{
          id: Ecto.UUID.generate(),
          body: "#{username} joined the channel.",
          type: :system,
          created_at: DateTime.utc_now()
        }
      )
      Process.send_after(self(), :tick, 1_000)
    end
    {
      :ok,
      socket
      |> assign_locale()
      |> assign_timezone()
      |> assign_timezone_offset()
      |> assign(
           room_id: room_id,
           current_user: %{username: username, avatar: avatar},
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

  defp assign_locale(socket) do
    locale = get_connect_params(socket)["locale"] || @default_locale
    assign(socket, locale: locale)
  end

  defp assign_timezone(socket) do
    timezone = get_connect_params(socket)["timezone"] || @default_timezone
    assign(socket, timezone: timezone)
  end

  defp assign_timezone_offset(socket) do
    timezone_offset = get_connect_params(socket)["timezone_offset"] || @default_timezone_offset
    assign(socket, timezone_offset: timezone_offset)
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
            current_user: current_user
          }
        } = socket
      ) do

    ChatWeb.Endpoint.broadcast(
      topic,
      "new_message",
      %{
        id: Ecto.UUID.generate(),
        body: message,
        user: current_user,
        type: :user,
        created_at: DateTime.utc_now()
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
            current_user: %{username: username}
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
        :tick,
        socket
      ) do

    Process.send_after(self(), :tick, 5_000)

    {:noreply, push_event(socket, "chat_notify", %{message: "hi"})}
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
            current_user: %{username: username}
          }
        } = socket
      ) do

    ChatWeb.Endpoint.broadcast(
      topic,
      "new_message",
      %{
        id: Ecto.UUID.generate(),
        body: "#{username} left the channel.",
        type: :system,
        created_at: DateTime.utc_now()
      }
    )

    :ok
  end


  def render_message(%{type: :system, created_at: created_at} = message, current_user, locale_opts) do
    ~E"""
    <p id="<%= message.id %>"><%= Chat.Cldr.format_time(message.created_at, locale_opts) %> <i><%= message.body %></i></p>
    """
  end

  def render_message(%{type: :user} = message, current_user, locale_opts) do
    render_user_message(message, current_user, locale_opts)
  end

  def render_user_message(%{type: :user, user: %{username: username, avatar: avatar}} = message, %{username: name} = current_user, locale_opts)
      when username == name do

    ~E"""
    <div id="<%= message.id %>" title="<%= message.user.username %>" class="d-flex justify-content-end mb-4">
    <div class="msg_container_send">
    <%= message.body %>
    <span class="msg_time_send"><%= Chat.Cldr.format_time(message.created_at, locale_opts) %></span>
    </div>
    <div class="img_cont_msg">
    <img alt="user" src="<%= avatar %>" class="rounded-circle user_img_msg">
    </div>
    </div>
    """
  end

  def render_user_message(%{type: :user, user: %{avatar: avatar}} = message, current_user, locale_opts) do
    ~E"""
    <div id="<%= message.id %>" title="<%= message.user.username %>" class="d-flex justify-content-start mb-4">
    <div class="img_cont_msg">
    <img  alt="<%= message.user.username %>" src="<%= avatar %>" class="rounded-circle user_img_msg">
    </div>
    <div class="msg_container">
    <%= message.body %>
    <span class="msg_time"><%= Chat.Cldr.format_time(message.created_at, locale_opts) %></span>
    </div>
    </div>
    """


  end

end
