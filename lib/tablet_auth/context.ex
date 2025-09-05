defmodule TabletAuth.Context do
  @moduledoc false
  
  alias TabletAuth.{User, Security}
  import Ecto.Query

  def create_tablet_user(attrs, opts \\ []) do
    with {:ok, validated_attrs} <- Security.validate_pin_strength(attrs, opts),
         changeset <- User.changeset(%User{}, validated_attrs, opts) do
      case changeset.valid? do
        true -> {:ok, changeset}
        false -> {:error, changeset}
      end
    end
  end

  def authenticate_pin(pin, opts \\ []) do
    repo = get_repo(opts)
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    lockout_duration = Keyword.get(opts, :lockout_duration, 15)
    
    case find_user_by_pin_context(opts) do
      nil ->
        {:error, :user_not_found}
      user ->
        authenticate_user_with_pin(user, pin, max_attempts, lockout_duration, repo)
    end
  end

  def authenticate_device(pin, device_id, opts \\ []) do
    repo = get_repo(opts)
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    lockout_duration = Keyword.get(opts, :lockout_duration, 15)
    
    case find_user_by_device(device_id, repo) do
      nil ->
        {:error, :device_not_found}
      user ->
        authenticate_user_with_pin(user, pin, max_attempts, lockout_duration, repo)
    end
  end

  def update_last_activity(user_id) do
    # This would typically update the database
    # Implementation depends on the repo configuration
    {:ok, DateTime.utc_now()}
  end

  def session_valid?(user_id, opts \\ []) do
    session_timeout = Keyword.get(opts, :session_timeout_minutes, 60)
    
    # This would typically check the database for last_activity
    # and compare with current time minus session_timeout
    # For now, returning true as a placeholder
    true
  end

  defp authenticate_user_with_pin(user, pin, max_attempts, lockout_duration, repo) do
    cond do
      is_locked?(user, lockout_duration) ->
        {:error, :account_locked}
      
      user.failed_attempts >= max_attempts ->
        lock_user(user, lockout_duration, repo)
        {:error, :account_locked}
      
      User.verify_pin(user, pin) ->
        reset_failed_attempts(user, repo)
        update_last_activity_timestamp(user, repo)
        {:ok, user}
      
      true ->
        increment_failed_attempts(user, repo)
        {:error, :invalid_pin}
    end
  end

  defp is_locked?(user, lockout_duration) do
    case user.locked_until do
      nil -> false
      locked_until ->
        DateTime.compare(DateTime.utc_now(), locked_until) == :lt
    end
  end

  defp lock_user(user, lockout_duration, _repo) do
    locked_until = DateTime.add(DateTime.utc_now(), lockout_duration * 60, :second)
    # This would typically update the database
    # Implementation depends on the repo configuration
    %{user | locked_until: locked_until, failed_attempts: user.failed_attempts + 1}
  end

  defp reset_failed_attempts(user, _repo) do
    # This would typically update the database
    # Implementation depends on the repo configuration
    %{user | failed_attempts: 0, locked_until: nil}
  end

  defp increment_failed_attempts(user, _repo) do
    # This would typically update the database
    # Implementation depends on the repo configuration
    %{user | failed_attempts: user.failed_attempts + 1}
  end

  defp update_last_activity_timestamp(user, _repo) do
    # This would typically update the database
    # Implementation depends on the repo configuration
    %{user | last_activity: DateTime.utc_now()}
  end

  defp find_user_by_pin_context(opts) do
    # This would typically query the database based on context
    # For tablet mode, this might find the single active tablet user
    # Implementation depends on the specific use case and repo configuration
    nil
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