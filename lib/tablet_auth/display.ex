defmodule TabletAuth.Display do
  @moduledoc """
  Schema for tablet displays that can be registered with PIN codes.
  
  This module provides a flexible display schema that applications can
  use or extend for tablet registration functionality.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "displays" do
    field :title, :string
    field :registration_pin, :string
    field :pin_expires_at, :utc_datetime
    field :secret_key, :string
    field :friendly_name, :string
    field :is_tablet, :boolean, default: false
    field :tablet_parent_display, :binary_id
    field :owner_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(display, attrs) do
    display
    |> cast(attrs, [:title, :friendly_name, :secret_key, :registration_pin, :pin_expires_at, :tablet_parent_display, :is_tablet, :owner_id])
    |> validate_required([:title])
  end

  @doc """
  Generates a new PIN for display registration that expires in the specified time.
  Returns {:ok, updated_display} or {:error, changeset}.
  
  ## Options
  - `:repo` - Ecto repository module (required)
  - `:pin_length` - Length of PIN (default: 6)
  - `:expiry_hours` - Hours until PIN expires (default: 6)
  """
  def generate_registration_pin(display, repo, opts \\ []) do
    changeset = generate_registration_pin_changeset(display, opts)
    repo.update(changeset)
  end

  @doc """
  Generates a new PIN for display registration that expires in the specified time.
  
  ## Options
  - `:pin_length` - Length of PIN (default: 6)
  - `:expiry_hours` - Hours until PIN expires (default: 6)
  
  This function returns a changeset that applications should update using their repo.
  """
  def generate_registration_pin_changeset(display, opts \\ []) do
    pin_length = Keyword.get(opts, :pin_length, 6)
    expiry_hours = Keyword.get(opts, :expiry_hours, 6)
    
    # Generate random PIN with specified length
    pin = generate_pin(pin_length)
    secret_key = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
    expires_at = DateTime.utc_now() |> DateTime.add(expiry_hours, :hour)
    
    display
    |> cast(%{
      registration_pin: pin,
      pin_expires_at: expires_at,
      secret_key: secret_key
    }, [:registration_pin, :pin_expires_at, :secret_key])
  end

  defp generate_pin(length) do
    # Use crypto-secure random generation to avoid bias
    # Generate enough random bytes and use modulo to get desired range
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(trunc(:math.pow(10, length)))
    |> Integer.to_string()
    |> String.pad_leading(length, "0")
  end

  @doc """
  Validates a registration PIN and returns the display if valid.
  
  This function should be called by your application's context module
  with the appropriate repository.
  """
  def validate_registration_pin(pin, repo) do
    import Ecto.Query
    
    query = from d in __MODULE__,
      where: d.registration_pin == ^pin and d.pin_expires_at > ^DateTime.utc_now(),
      select: d
    
    repo.one(query)
  end

  @doc """
  Clears the registration PIN and sets up tablet configuration.
  
  ## Options
  - `:friendly_name` - Name for the tablet
  - `:parent_display_id` - ID of parent display to associate with
  """
  def complete_registration(display, opts \\ []) do
    friendly_name = Keyword.get(opts, :friendly_name)
    parent_display_id = Keyword.get(opts, :parent_display_id)
    
    display
    |> cast(%{
      registration_pin: nil,
      pin_expires_at: nil,
      friendly_name: friendly_name,
      is_tablet: true,
      tablet_parent_display: parent_display_id
    }, [:registration_pin, :pin_expires_at, :friendly_name, :is_tablet, :tablet_parent_display])
  end

  @doc """
  Finds a tablet by its secret key.
  """
  def find_tablet_by_secret(secret_key, repo) do
    import Ecto.Query
    
    query = from d in __MODULE__,
      where: d.secret_key == ^secret_key and d.is_tablet == true,
      select: d
    
    repo.one(query)
  end

  @doc """
  Finds the best parent display for a tablet (most posts).
  
  This is a helper function that applications can override
  based on their specific logic for selecting parent displays.
  """
  def find_best_parent_display(owner_id, repo, post_schema \\ nil) do
    case post_schema do
      nil -> nil
      post_module ->
        import Ecto.Query
        
        query = from d in __MODULE__,
          left_join: p in ^post_module, on: p.display_id == d.id,
          where: d.owner_id == ^owner_id and d.is_tablet == false,
          group_by: d.id,
          order_by: [desc: count(p.id), asc: d.inserted_at],
          select: d,
          limit: 1
        
        repo.one(query)
    end
  end
end