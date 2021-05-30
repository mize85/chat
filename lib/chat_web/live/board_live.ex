defmodule ChatWeb.BoardLive do
  use ChatWeb, :live_view


  @lists [1, 2]

  @impl true
  def mount(_params, _session, socket) do
    tasks = [
      %{id: 1, name: "test1", list_id: 1},
      %{id: 2, name: "test2", list_id: 1},
      %{id: 3, name: "test3", list_id: 1},
      %{id: 4, name: "test4", list_id: 1},
      %{id: 5, name: "test5", list_id: 2},
      %{id: 6, name: "test6", list_id: 2},
      %{id: 7, name: "test7", list_id: 2},
    ]

    {
      :ok,
      socket
      |> assign(tasks: tasks, lists: @lists)
    }
  end

  @impl true
  def handle_event("sort", %{"list" => [_ | _] = list}, socket) do
    list
    |> Enum.each(
         fn %{"id" => id, "list_id" => list_id, "sort_order" => sort_order} ->
           #Tasks.get_task(id)
           #|> Tasks.update_task(%{list_id: list_id, sort_order: sort_order})
         end
       )

    {:noreply, socket}
  end
end
