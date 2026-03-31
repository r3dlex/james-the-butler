defmodule James.Hooks do
  @moduledoc """
  Manages hook configuration and querying.
  """

  import Ecto.Query
  alias James.Hooks.Hook
  alias James.Repo

  def list_hooks(user_id) do
    from(h in Hook, where: h.user_id == ^user_id, order_by: [asc: h.event])
    |> Repo.all()
  end

  def list_hooks_for_event(user_id, event) do
    from(h in Hook,
      where: h.user_id == ^user_id and h.event == ^event and h.enabled == true,
      order_by: [asc: h.scope]
    )
    |> Repo.all()
  end

  def get_hook(id), do: Repo.get(Hook, id)

  def create_hook(attrs) do
    %Hook{}
    |> Hook.changeset(attrs)
    |> Repo.insert()
  end

  def update_hook(%Hook{} = hook, attrs) do
    hook |> Hook.changeset(attrs) |> Repo.update()
  end

  def delete_hook(%Hook{} = hook) do
    Repo.delete(hook)
  end

  def enable_hook(%Hook{} = hook) do
    hook |> Hook.changeset(%{enabled: true}) |> Repo.update()
  end

  def disable_hook(%Hook{} = hook) do
    hook |> Hook.changeset(%{enabled: false}) |> Repo.update()
  end
end
