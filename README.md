# TabletAuth

A secure authentication system designed for tablet and mobile device applications requiring simple PIN-based access with device registration capabilities.

## Features

- **PIN-based Authentication**: Secure numeric PIN authentication with configurable length
- **Device Registration**: Register mobile devices to user accounts via HTTPS API
- **Account Security**: Built-in protection against brute force attacks with account lockout
- **PIN Strength Validation**: Prevents weak PINs (sequential, repetitive, common patterns)
- **Session Management**: Track user activity and session validity
- **Flexible Integration**: Designed to work with any Ecto-compatible database

## Installation

Add `tablet_auth` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tablet_auth, "~> 0.1.0"}
  ]
end
```

## Usage

TabletAuth supports two registration patterns:

1. **Tablet User Authentication** - Direct PIN authentication for tablet users
2. **Display-Based Registration** - PIN-based tablet registration using display entities (recommended for family photo sharing apps)

### Display-Based Tablet Registration (Recommended)

This is the primary approach for applications that manage displays/frames that can have tablets registered to them.

#### Generating a Registration PIN

```elixir
# Generate a PIN for a display that tablets can use to register
case TabletAuth.generate_display_pin(display, repo: MyApp.Repo) do
  {:ok, updated_display} -> 
    # Display now has registration_pin and pin_expires_at set
    # Share this PIN with users to register their tablets
  {:error, changeset} -> 
    # Handle validation errors
end
```

#### Registering a Tablet with PIN

```elixir
attrs = %{friendly_name: "Kitchen Tablet"}

opts = [
  repo: MyApp.Repo,
  display_schema: MyApp.Display,  # Your display schema (optional if using default)
  user_display_schema: MyApp.UsersDisplays,  # Association schema (optional)
  post_schema: MyApp.Post,  # For finding best parent display (optional)
  pubsub_module: Phoenix.PubSub,  # For broadcasting updates (optional)
  broadcast_topic: "user_settings:{owner_id}"  # Topic pattern (optional)
]

case TabletAuth.register_tablet_with_pin("123456", attrs, opts) do
  {:ok, %{tablet: tablet, association: association}} -> 
    # Tablet registered successfully
    # tablet.secret_key can be used for tablet access
  {:error, :invalid_or_expired_pin} -> 
    # Wrong or expired PIN
  {:error, changeset} -> 
    # Handle registration failure
end
```

#### Looking Up Tablets

```elixir
# Validate a PIN (useful for API endpoints)
case TabletAuth.validate_pin("123456", repo: MyApp.Repo) do
  %Display{} = display -> 
    # PIN is valid, display can be used for registration
  nil -> 
    # Invalid or expired PIN
end

# Get tablet by secret key (for tablet access)
case TabletAuth.get_tablet_by_secret(secret_key, repo: MyApp.Repo) do
  %Display{} = tablet -> 
    # Tablet found
  nil -> 
    # Tablet not found
end
```

### Creating a Tablet User

```elixir
attrs = %{
  name: "John Doe",
  pin: "1357"
}

opts = [
  pin_length: 4,
  max_attempts: 3,
  lockout_duration: 15  # minutes
]

case TabletAuth.create_tablet_user(attrs, opts) do
  {:ok, changeset} -> 
    # Save changeset to your database
    MyApp.Repo.insert(changeset)
  {:error, :weak_pin} -> 
    # Handle weak PIN error
  {:error, changeset} -> 
    # Handle validation errors
end
```

### Authenticating with PIN

```elixir
# For tablet authentication (finds active tablet user)
case TabletAuth.authenticate_pin("1357") do
  {:ok, user} -> 
    # Authentication successful
  {:error, :invalid_pin} -> 
    # Wrong PIN
  {:error, :account_locked} -> 
    # Too many failed attempts
end

# For device authentication
case TabletAuth.authenticate_device("1357", "device_123") do
  {:ok, user} -> 
    # Device authentication successful
  {:error, reason} -> 
    # Handle authentication failure
end
```

### Device Registration

```elixir
device_attrs = %{
  device_id: "mobile_device_abc123",
  device_name: "John's iPhone"
}

user_lookup = %{
  email: "john@example.com"
  # or user_id: "user_123"
  # or external_user_id: "external_456"
}

case TabletAuth.register_device(device_attrs, user_lookup) do
  {:ok, registration} -> 
    # Device registered successfully
  {:error, :device_already_registered} -> 
    # Device is already registered
  {:error, reason} -> 
    # Handle registration failure
end
```

### Session Management

```elixir
# Update user activity
TabletAuth.update_last_activity(user_id)

# Check if session is valid
if TabletAuth.session_valid?(user_id, session_timeout_minutes: 60) do
  # Session is still active
else
  # Session expired, require re-authentication
end

# Revoke device access
case TabletAuth.revoke_device("device_123") do
  {:ok, revocation} -> 
    # Device access revoked
  {:error, reason} -> 
    # Handle revocation failure
end
```

## Database Schema

### For Display-Based Registration

Create a migration for the displays table:

```elixir
defmodule MyApp.Repo.Migrations.CreateDisplays do
  use Ecto.Migration

  def change do
    create table(:displays, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :registration_pin, :string
      add :pin_expires_at, :utc_datetime
      add :secret_key, :string
      add :friendly_name, :string
      add :is_tablet, :boolean, default: false
      add :tablet_parent_display, :binary_id
      add :owner_id, :binary_id, null: false
      
      timestamps(type: :utc_datetime)
    end
    
    create index(:displays, [:owner_id])
    create index(:displays, [:registration_pin])
    create index(:displays, [:secret_key])
    create index(:displays, [:is_tablet])
    create index(:displays, [:tablet_parent_display])
  end
end
```

### For Tablet User Authentication

Create a migration for the tablet users table:

```elixir
defmodule MyApp.Repo.Migrations.CreateTabletUsers do
  use Ecto.Migration

  def change do
    create table(:tablet_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :pin_hash, :string, null: false
      add :active, :boolean, default: true
      add :last_activity, :utc_datetime
      add :failed_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
      add :device_id, :string
      add :device_name, :string
      add :registered_at, :utc_datetime
      add :external_user_id, :string
      
      timestamps()
    end
    
    create unique_index(:tablet_users, [:device_id])
    create index(:tablet_users, [:external_user_id])
    create index(:tablet_users, [:active])
  end
end
```

## Security Features

### PIN Strength Validation

The system automatically rejects weak PINs including:
- All same digits (0000, 1111, etc.)
- Sequential patterns (1234, 4321, etc.)
- Common weak patterns
- Repetitive patterns (more than half digits the same)

### Account Security

- **Failed Attempt Tracking**: Counts consecutive failed login attempts
- **Account Lockout**: Temporarily locks accounts after too many failures
- **Secure Hashing**: Uses bcrypt with 12 rounds for PIN storage
- **No Plaintext Storage**: PINs are never stored in plaintext

### Session Security

- **Activity Tracking**: Updates last activity timestamp on successful auth
- **Session Timeouts**: Configurable session timeout validation
- **Device Revocation**: Ability to remotely revoke device access

## Configuration Options

All functions accept an `opts` keyword list for configuration:

- `:pin_length` - Required PIN length (default: 4)
- `:max_attempts` - Maximum failed attempts before lockout (default: 3)
- `:lockout_duration` - Lockout duration in minutes (default: 15)
- `:session_timeout_minutes` - Session timeout in minutes (default: 60)
- `:repo` - Ecto repo module for database operations

## Integration with Your App

This library is designed to be framework-agnostic. You'll need to:

1. **Add the schema to your app** and customize fields as needed
2. **Implement the database operations** in your context modules
3. **Add API endpoints** for device registration and authentication
4. **Configure security settings** based on your requirements

## Security Considerations

- Always use HTTPS for device registration and authentication APIs
- Implement rate limiting on authentication endpoints
- Consider additional security measures for high-value applications
- Regularly review and update PIN strength requirements
- Monitor failed authentication attempts for suspicious activity

## License

MIT License. See LICENSE file for details.