defmodule JamesWeb.ErrorView do
  def render(template, _assigns) do
    # Return iodata that Phoenix.HTML.Safe can encode
    Jason.encode!(%{
      errors: %{
        detail: Phoenix.Controller.status_message_from_template(template)
      }
    })
  end

  def template_not_found(template, _assigns) do
    Jason.encode!(%{
      errors: %{
        detail: "Template not found: #{template}"
      }
    })
  end
end
