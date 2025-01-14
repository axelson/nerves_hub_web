defmodule NervesHub.Accounts.Invite do
  use Ecto.Schema

  import Ecto.Changeset

  alias NervesHub.Accounts.Org
  alias __MODULE__

  @type t :: %__MODULE__{}

  schema "invites" do
    belongs_to(:org, Org, where: [deleted_at: nil])

    field(:email, :string)
    field(:token, Ecto.UUID)
    field(:accepted, :boolean)

    timestamps()
  end

  def changeset(%Invite{} = invite, params) do
    invite
    |> cast(params, [:email, :token, :org_id, :accepted])
    |> validate_required([:email, :token, :org_id])
  end
end
