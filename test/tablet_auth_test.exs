defmodule TabletAuthTest do
  use ExUnit.Case
  # doctest TabletAuth  # Disabled due to external dependencies
  
  import Ecto.Changeset

  alias TabletAuth.{User, Security}

  describe "Security.validate_pin_strength/2" do
    test "accepts strong PIN" do
      attrs = %{pin: "1357"}
      assert {:ok, ^attrs} = Security.validate_pin_strength(attrs, [])
    end

    test "rejects nil PIN" do
      attrs = %{}
      assert {:error, :pin_required} = Security.validate_pin_strength(attrs, [])
    end

    test "rejects PIN that is too short" do
      attrs = %{pin: "123"}
      assert {:error, :pin_too_short} = Security.validate_pin_strength(attrs, pin_length: 4)
    end

    test "rejects weak PIN patterns" do
      weak_pins = ["0000", "1111", "1234", "4321"]
      
      for pin <- weak_pins do
        attrs = %{pin: pin}
        assert {:error, :weak_pin} = Security.validate_pin_strength(attrs, [])
      end
    end

    test "rejects sequential PINs" do
      sequential_pins = ["2345", "6543", "0123"]
      
      for pin <- sequential_pins do
        attrs = %{pin: pin}
        assert {:error, :weak_pin} = Security.validate_pin_strength(attrs, [])
      end
    end

    test "rejects repetitive PINs" do
      repetitive_pins = ["1122", "3311", "5577"]
      
      for pin <- repetitive_pins do
        attrs = %{pin: pin}
        assert {:error, :weak_pin} = Security.validate_pin_strength(attrs, [])
      end
    end
  end

  describe "User.changeset/3" do
    test "creates valid changeset with good data" do
      attrs = %{name: "John Doe", pin: "1357"}
      changeset = User.changeset(%User{}, attrs)
      
      assert changeset.valid?
      assert get_change(changeset, :name) == "John Doe"
      assert get_change(changeset, :pin_hash)
      refute get_change(changeset, :pin)  # PIN should be removed after hashing
    end

    test "validates required fields" do
      changeset = User.changeset(%User{}, %{})
      
      refute changeset.valid?
      assert errors_on(changeset) == %{name: ["can't be blank"], pin: ["can't be blank"]}
    end

    test "validates PIN format" do
      attrs = %{name: "John Doe", pin: "abc1"}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "PIN must be numeric" in errors_on(changeset).pin
    end

    test "validates PIN length" do
      attrs = %{name: "John Doe", pin: "123"}
      changeset = User.changeset(%User{}, attrs, pin_length: 4)
      
      refute changeset.valid?
      assert "should be 4 character(s)" in errors_on(changeset).pin
    end

    test "validates name length" do
      long_name = String.duplicate("a", 101)
      attrs = %{name: long_name, pin: "1357"}
      changeset = User.changeset(%User{}, attrs)
      
      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).name
    end

    test "sets registered_at timestamp" do
      attrs = %{name: "John Doe", pin: "1357"}
      changeset = User.changeset(%User{}, attrs)
      
      assert get_change(changeset, :registered_at)
    end
  end

  describe "User.verify_pin/2" do
    test "verifies correct PIN" do
      attrs = %{name: "John Doe", pin: "1357"}
      changeset = User.changeset(%User{}, attrs)
      user = apply_changes(changeset)
      
      assert User.verify_pin(user, "1357")
    end

    test "rejects incorrect PIN" do
      attrs = %{name: "John Doe", pin: "1357"}
      changeset = User.changeset(%User{}, attrs)
      user = apply_changes(changeset)
      
      refute User.verify_pin(user, "9999")
    end

    test "handles nil user safely (timing attack protection)" do
      refute User.verify_pin(nil, "1357")
    end

    test "handles user with nil pin_hash safely" do
      user = %User{pin_hash: nil}
      refute User.verify_pin(user, "1357")
    end
  end

  # Helper function to extract errors from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end