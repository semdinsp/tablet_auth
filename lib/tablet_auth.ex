defmodule TabletAuth do
  @moduledoc """
  A secure authentication system designed for tablet applications.
  
  Provides PIN-based authentication with configurable security features.
  Includes device registration for mobile tablets connecting via API.
  Does not expose internal implementation details.
  """

  alias TabletAuth.{User, Context, DeviceRegistration}

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
end