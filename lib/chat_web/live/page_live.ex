defmodule ChatWeb.PageLive do
  use ChatWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("random_room", _params, socket) do
    slug = "/chat/" <> MnemonicSlugs.generate_slug(4)
    {:noreply, push_redirect(socket, to: slug)}
  end
end
