defmodule TabletAuth.Registration do
  @moduledoc """
  Context for handling tablet registration workflows.
  
  This module provides high-level functions for tablet registration
  that applications can use with their existing schemas and repositories.
  """

  alias TabletAuth.Display
  alias Ecto.Multi
  require Logger

  @doc """
  Registers a tablet using a PIN code and associates it with the display owner.
  
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
  """
  def register_tablet_with_pin(pin, attrs, opts) do
    repo = Keyword.fetch!(opts, :repo)
    display_schema = Keyword.get(opts, :display_schema, Display)
    user_display_schema = Keyword.get(opts, :user_display_schema)
    post_schema = Keyword.get(opts, :post_schema)
    
    Logger.info("Tablet registration attempt with PIN: [REDACTED]")
    
    case validate_pin_with_schema(pin, repo, display_schema) do
      nil ->
        Logger.warning("Invalid or expired PIN: [REDACTED]")
        {:error, :invalid_or_expired_pin}
        
      display ->
        Logger.info("Found display for registration: #{display.id}")
        
        friendly_name = Map.get(attrs, :friendly_name) || Map.get(attrs, "friendly_name")
        
        register_tablet_transaction(display, friendly_name, display_schema, user_display_schema, post_schema, repo, opts)
    end
  end

  @doc """
  Generates a registration PIN for a display.
  
  ## Parameters
  - `display` - The display struct
  - `opts` - Configuration options
  
  ## Options
  - `:repo` - Ecto repository module (required)
  - `:display_schema` - Display schema module (default: TabletAuth.Display)
  - `:pin_length` - PIN length (default: 6)
  - `:expiry_hours` - Hours until PIN expires (default: 6)
  
  Returns `{:ok, updated_display}` or `{:error, changeset}`
  """
  def generate_pin_for_display(display, opts) do
    repo = Keyword.fetch!(opts, :repo)
    display_schema = Keyword.get(opts, :display_schema, Display)
    
    case display_schema.generate_registration_pin(display, repo, opts) do
      {:ok, updated_display} ->
        Logger.info("Generated PIN for display #{display.id}")
        {:ok, updated_display}
      {:error, changeset} ->
        Logger.error("Failed to generate PIN: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
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
  """
  def get_tablet_by_secret(secret_key, opts) do
    repo = Keyword.fetch!(opts, :repo)
    display_schema = Keyword.get(opts, :display_schema, Display)
    
    Logger.info("Looking up tablet by secret: #{String.slice(secret_key, 0, 8)}...")
    find_tablet_by_secret_with_schema(secret_key, repo, display_schema)
  end

  # Private helper functions

  defp register_tablet_transaction(display, friendly_name, display_schema, user_display_schema, post_schema, repo, opts) do
    # Find the best parent display (most posts) for auto-assignment
    best_parent = if post_schema do
      display_schema.find_best_parent_display(display.owner_id, repo, post_schema)
    else
      nil
    end
    
    Multi.new()
    |> Multi.run(:complete_registration, fn _repo, _changes ->
      changeset = display_schema.complete_registration(display, [
        friendly_name: friendly_name,
        parent_display_id: best_parent && best_parent.id
      ])
      
      repo.update(changeset)
    end)
    |> Multi.run(:associate_user, fn _repo, %{complete_registration: updated_display} ->
      associate_display_with_user(updated_display, user_display_schema, repo)
    end)
    |> Multi.run(:broadcast_update, fn _repo, %{complete_registration: updated_display} ->
      broadcast_registration_complete(updated_display, opts)
      {:ok, updated_display}
    end)
    |> repo.transaction()
    |> case do
      {:ok, %{complete_registration: tablet, associate_user: association}} ->
        Logger.info("Tablet registration successful: #{tablet.id}")
        {:ok, %{tablet: tablet, association: association}}
        
      {:error, step, changeset, _changes} ->
        Logger.error("Tablet registration failed at step #{step}: #{inspect(changeset)}")
        {:error, changeset}
    end
  end

  defp associate_display_with_user(_display, nil, _repo) do
    # No user-display association schema provided
    {:ok, nil}
  end

  defp associate_display_with_user(display, user_display_schema, repo) do
    # Check if association already exists
    case repo.get_by(user_display_schema, user_id: display.owner_id, display_id: display.id) do
      nil ->
        # Create new association  
        user_display_schema.__struct__()
        |> user_display_schema.changeset(%{user_id: display.owner_id, display_id: display.id})
        |> repo.insert()
      existing -> 
        {:ok, existing}
    end
  end

  defp broadcast_registration_complete(display, opts) do
    case {Keyword.get(opts, :pubsub_module), Keyword.get(opts, :broadcast_topic)} do
      {nil, _} -> :ok
      {_, nil} -> :ok
      {pubsub_module, topic_pattern} ->
        topic = String.replace(topic_pattern, "{owner_id}", display.owner_id)
        pubsub_module.broadcast(Alzheimer.PubSub, topic, :reload_settings)
    end
  end

  # Schema delegation helper functions
  
  defp validate_pin_with_schema(pin, repo, Display) do
    # Use tablet_auth's own Display module
    Display.validate_registration_pin(pin, repo)
  end
  
  defp validate_pin_with_schema(pin, _repo, display_schema) do
    # Delegate to the application's display schema
    # Assume it has a validate_registration_pin/1 function
    display_schema.validate_registration_pin(pin)
  end
  
  defp find_tablet_by_secret_with_schema(secret_key, repo, Display) do
    # Use tablet_auth's own Display module  
    Display.find_tablet_by_secret(secret_key, repo)
  end
  
  defp find_tablet_by_secret_with_schema(secret_key, repo, display_schema) do
    # Use a generic query for application display schemas
    import Ecto.Query
    
    query = from d in display_schema,
      where: d.secret_key == ^secret_key and d.is_tablet == true,
      select: d
    
    repo.one(query)
  end
end