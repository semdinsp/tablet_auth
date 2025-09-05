defmodule TabletAuth.DeviceRegistration do
  @moduledoc false
  
  alias TabletAuth.{User, Security}
  import Ecto.Query

  def register_device(device_attrs, user_lookup, opts \\ []) do
    repo = get_repo(opts)
    
    with {:ok, user} <- find_user(user_lookup, repo),
         {:ok, validated_attrs} <- validate_device_attrs(device_attrs, opts),
         {:ok, registration} <- create_device_registration(user, validated_attrs, repo) do
      {:ok, registration}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def revoke_device(device_id, opts \\ []) do
    repo = get_repo(opts)
    
    case find_user_by_device(device_id, repo) do
      nil ->
        {:error, :device_not_found}
      user ->
        revoke_device_access(user, device_id, repo)
    end
  end

  defp find_user(user_lookup, repo) when is_map(user_lookup) do
    # This would typically query the database based on the lookup criteria
    # For example: email, user_id, external_user_id, etc.
    # Implementation depends on the repo configuration
    
    cond do
      Map.has_key?(user_lookup, :email) ->
        find_user_by_email(user_lookup.email, repo)
      Map.has_key?(user_lookup, :user_id) ->
        find_user_by_id(user_lookup.user_id, repo)
      Map.has_key?(user_lookup, :external_user_id) ->
        find_user_by_external_id(user_lookup.external_user_id, repo)
      true ->
        {:error, :invalid_user_lookup}
    end
  end

  defp validate_device_attrs(device_attrs, opts) do
    required_fields = [:device_id, :device_name]
    
    case validate_required_fields(device_attrs, required_fields) do
      {:ok, attrs} ->
        validate_device_security(attrs, opts)
      error ->
        error
    end
  end

  defp validate_required_fields(attrs, required_fields) do
    missing_fields = Enum.filter(required_fields, fn field ->
      is_nil(Map.get(attrs, field)) and is_nil(Map.get(attrs, to_string(field)))
    end)
    
    case missing_fields do
      [] -> {:ok, attrs}
      fields -> {:error, {:missing_fields, fields}}
    end
  end

  defp validate_device_security(attrs, _opts) do
    device_id = Map.get(attrs, :device_id) || Map.get(attrs, "device_id")
    device_name = Map.get(attrs, :device_name) || Map.get(attrs, "device_name")
    
    cond do
      String.length(device_id) < 8 ->
        {:error, :device_id_too_short}
      String.length(device_name) > 100 ->
        {:error, :device_name_too_long}
      true ->
        {:ok, attrs}
    end
  end

  defp create_device_registration(user, device_attrs, repo) do
    device_id = Map.get(device_attrs, :device_id) || Map.get(device_attrs, "device_id")
    device_name = Map.get(device_attrs, :device_name) || Map.get(device_attrs, "device_name")
    
    # Check if device is already registered
    case device_already_registered?(device_id, repo) do
      true ->
        {:error, :device_already_registered}
      false ->
        register_new_device(user, device_id, device_name, repo)
    end
  end

  defp register_new_device(user, device_id, device_name, _repo) do
    # This would typically create or update the user record with device info
    # Implementation depends on the repo configuration
    
    registration_data = %{
      user_id: user.id,
      device_id: device_id,
      device_name: device_name,
      registered_at: DateTime.utc_now(),
      status: :active
    }
    
    {:ok, registration_data}
  end

  defp revoke_device_access(user, device_id, _repo) do
    # This would typically update the database to mark the device as revoked
    # Implementation depends on the repo configuration
    
    case user.device_id == device_id do
      true ->
        # Remove device info from user or mark as revoked
        {:ok, %{device_id: device_id, status: :revoked, revoked_at: DateTime.utc_now()}}
      false ->
        {:error, :device_not_associated}
    end
  end

  defp device_already_registered?(device_id, _repo) do
    # This would typically query the database to check if device_id exists
    # Implementation depends on the repo configuration
    false
  end

  defp find_user_by_email(_email, _repo) do
    # This would typically query the database
    # Implementation depends on the repo configuration
    {:error, :not_implemented}
  end

  defp find_user_by_id(_user_id, _repo) do
    # This would typically query the database
    # Implementation depends on the repo configuration
    {:error, :not_implemented}
  end

  defp find_user_by_external_id(_external_id, _repo) do
    # This would typically query the database
    # Implementation depends on the repo configuration
    {:error, :not_implemented}
  end

  defp find_user_by_device(device_id, _repo) do
    # This would typically query the database for a user with the given device_id
    # Implementation depends on the repo configuration
    nil
  end

  defp get_repo(opts) do
    # This would typically get the repo module from opts or application config
    # For now, returning nil as a placeholder
    Keyword.get(opts, :repo)
  end
end