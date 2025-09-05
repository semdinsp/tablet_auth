defmodule TabletAuth do
  @moduledoc """
  A secure authentication system designed for tablet applications.
  
  Provides PIN-based authentication with configurable security features.
  Includes device registration for mobile tablets connecting via API.
  Supports both tablet user authentication and display-based tablet registration.
  Does not expose internal implementation details.
  """

  alias TabletAuth.{Context, DeviceRegistration, Registration, Display}

  @doc """
  Creates a new tablet user with PIN authentication.
  
  ## Options
  - `:pin_length` - Length of PIN (default: 4)
  - `:max_attempts` - Max failed attempts before lockout (default: 3)
  - `:lockout_duration` - Lockout duration in minutes (default: 15)
  """
  def create_tablet_user(attrs, opts \\ []) do
    Context.create_tablet_user(attrs, opts)
  end

  @doc """
  Registers a new device for an existing user.
  
  Typically called via HTTPS API when a mobile device wants to
  connect to a user account.
  
  ## Parameters
  - `device_attrs` - Device information (device_id, name, etc.)
  - `user_lookup` - How to find the user (email, user_id, etc.)
  - `opts` - Configuration options
  
  Returns {:ok, registration_data} or {:error, reason}
  """
  def register_device(device_attrs, user_lookup, opts \\ []) do
    DeviceRegistration.register_device(device_attrs, user_lookup, opts)
  end

  @doc """
  Authenticates a tablet user with PIN.
  Returns {:ok, user} or {:error, reason}
  """
  def authenticate_pin(pin, opts \\ []) do
    Context.authenticate_pin(pin, opts)
  end

  @doc """
  Authenticates a device with PIN and device ID.
  Typically used for mobile device login.
  """
  def authenticate_device(pin, device_id, opts \\ []) do
    Context.authenticate_device(pin, device_id, opts)
  end

  @doc """
  Updates tablet user session activity.
  """
  def update_last_activity(user_id) do
    Context.update_last_activity(user_id)
  end

  @doc """
  Checks if a user session is still valid.
  """
  def session_valid?(user_id, opts \\ []) do
    Context.session_valid?(user_id, opts)
  end

  @doc """
  Revokes device access (for remote logout/security).
  """
  def revoke_device(device_id, opts \\ []) do
    DeviceRegistration.revoke_device(device_id, opts)
  end

  # Display-based tablet registration functions

  @doc """
  Generates a registration PIN for a display that can be used to register tablets.
  
  ## Parameters
  - `display` - The display struct
  - `opts` - Configuration options
  
  ## Options
  - `:repo` - Ecto repository module (required)
  - `:display_schema` - Display schema module (default: TabletAuth.Display)
  - `:pin_length` - PIN length (default: 6)
  - `:expiry_hours` - Hours until PIN expires (default: 6)
  
  Returns `{:ok, updated_display}` or `{:error, changeset}`
  
  ## Examples
  
      display = %MyApp.Display{id: "abc123"}
      TabletAuth.generate_display_pin(display, repo: MyApp.Repo)
      # => {:ok, %MyApp.Display{registration_pin: "123456", pin_expires_at: ~U[2024-01-01 12:00:00Z]}}}
  """
  def generate_display_pin(display, opts) do
    Registration.generate_pin_for_display(display, opts)
  end

  @doc """
  Registers a tablet using a PIN code.
  
  This function validates the PIN, completes the tablet registration,
  and optionally associates it with the display owner.
  
  ## Parameters
  - `pin` - The registration PIN
  - `attrs` - Registration attributes (friendly_name, etc.)
  - `opts` - Configuration options
  
  ## Options
  - `:repo` - Ecto repository module (required)
  - `:display_schema` - Display schema module (default: TabletAuth.Display)
  - `:user_display_schema` - User-Display association schema (optional)
  - `:post_schema` - Post schema for finding best parent display (optional)
  - `:pubsub_module` - PubSub module for broadcasting updates (optional)
  - `:broadcast_topic` - Topic pattern for broadcasts (optional)
  
  Returns `{:ok, %{tablet: tablet, association: association}}` or `{:error, reason}`
  
  ## Examples
  
      TabletAuth.register_tablet_with_pin("123456", %{friendly_name: "Kitchen Tablet"}, 
        repo: MyApp.Repo, 
        user_display_schema: MyApp.UsersDisplays,
        post_schema: MyApp.Post)
      # => {:ok, %{tablet: %Display{...}, association: %UsersDisplays{...}}}
  """
  def register_tablet_with_pin(pin, attrs, opts) do
    Registration.register_tablet_with_pin(pin, attrs, opts)
  end

  @doc """
  Retrieves tablet information by secret key.
  
  ## Parameters
  - `secret_key` - The tablet's secret key
  - `opts` - Configuration options
  
  ## Options
  - `:repo` - Ecto repository module (required)
  - `:display_schema` - Display schema module (default: TabletAuth.Display)
  
  Returns the tablet display or `nil` if not found
  
  ## Examples
  
      TabletAuth.get_tablet_by_secret("abc123...", repo: MyApp.Repo)
      # => %Display{is_tablet: true, ...}
  """
  def get_tablet_by_secret(secret_key, opts) do
    Registration.get_tablet_by_secret(secret_key, opts)
  end

  @doc """
  Validates a registration PIN and returns the associated display if valid.
  
  ## Parameters
  - `pin` - The registration PIN to validate
  - `opts` - Configuration options
  
  ## Options
  - `:repo` - Ecto repository module (required)
  - `:display_schema` - Display schema module (default: TabletAuth.Display)
  
  Returns the display struct or `nil` if PIN is invalid/expired
  
  ## Examples
  
      TabletAuth.validate_pin("123456", repo: MyApp.Repo)
      # => %Display{registration_pin: "123456", ...}
      
      TabletAuth.validate_pin("invalid", repo: MyApp.Repo)
      # => nil
  """
  def validate_pin(pin, opts) do
    repo = Keyword.fetch!(opts, :repo)
    display_schema = Keyword.get(opts, :display_schema, Display)
    
    # Use schema delegation similar to Registration module
    validate_pin_with_schema(pin, repo, display_schema)
  end
  
  # Schema delegation helper for validate_pin
  defp validate_pin_with_schema(pin, repo, Display) do
    # Use tablet_auth's own Display module
    Display.validate_registration_pin(pin, repo)
  end
  
  defp validate_pin_with_schema(pin, _repo, display_schema) do
    # Delegate to the application's display schema
    # Assume it has a validate_registration_pin/1 function
    display_schema.validate_registration_pin(pin)
  end
end