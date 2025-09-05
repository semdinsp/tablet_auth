defmodule TabletAuth.User do
  @moduledoc """
  Schema for tablet users. 
  
  Note: This is a generic schema - applications should adapt
  the fields to their specific needs.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tablet_users" do
    field :name, :string
    field :pin, :string, virtual: true
    field :pin_hash, :string
    field :active, :boolean, default: true
    field :last_activity, :utc_datetime
    field :failed_attempts, :integer, default: 0
    field :locked_until, :utc_datetime
    field :device_id, :string
    field :device_name, :string
    field :registered_at, :utc_datetime
    
    # SECURITY: Don't expose internal app relationships
    # Applications can add their own foreign keys
    field :external_user_id, :string
    
    timestamps()
  end

  def changeset(user, attrs, opts \\ []) do
    pin_length = Keyword.get(opts, :pin_length, 4)
    
    user
    |> cast(attrs, [:name, :pin, :active, :external_user_id, :device_id, :device_name])
    |> validate_required([:name, :pin])
    |> validate_length(:pin, is: pin_length)
    |> validate_format(:pin, ~r/^\d+$/, message: "PIN must be numeric")
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:device_id, min: 1, max: 255)
    |> validate_length(:device_name, max: 100)
    |> unique_constraint(:device_id)
    |> put_registered_timestamp()
    |> hash_pin()
  end

  defp put_registered_timestamp(changeset) do
    case get_field(changeset, :registered_at) do
      nil -> put_change(changeset, :registered_at, DateTime.utc_now())
      _ -> changeset
    end
  end

  defp hash_pin(%Ecto.Changeset{valid?: true, changes: %{pin: pin}} = changeset) do
    # SECURITY: Use strong hashing with random salt
    hashed = Bcrypt.hash_pwd_salt(pin, rounds: 12)
    changeset
    |> put_change(:pin_hash, hashed)
    |> delete_change(:pin)  # Remove plaintext PIN
  end

  defp hash_pin(changeset), do: changeset

  @doc """
  Verifies a PIN against the stored hash.
  """
  def verify_pin(user, pin) do
    Bcrypt.verify_pass(pin, user.pin_hash)
  end
end