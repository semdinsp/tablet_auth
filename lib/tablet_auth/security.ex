defmodule TabletAuth.Security do
  @moduledoc false
  
  def validate_pin_strength(attrs, opts) do
    pin = Map.get(attrs, :pin) || Map.get(attrs, "pin")
    min_length = Keyword.get(opts, :pin_length, 4)
    
    cond do
      is_nil(pin) -> 
        {:error, :pin_required}
      String.length(pin) < min_length -> 
        {:error, :pin_too_short}
      is_weak_pin?(pin) -> 
        {:error, :weak_pin}
      true -> 
        {:ok, attrs}
    end
  end

  # SECURITY: Prevent common weak PINs
  defp is_weak_pin?(pin) do
    weak_patterns = ["0000", "1111", "2222", "3333", "4444", 
                     "5555", "6666", "7777", "8888", "9999",
                     "1234", "4321", "0123", "9876"]
    
    pin in weak_patterns or
    is_sequential?(pin) or
    is_repetitive?(pin)
  end

  defp is_sequential?(pin) do
    # Check for ascending/descending sequences
    digits = String.graphemes(pin) |> Enum.map(&String.to_integer/1)
    
    ascending = Enum.chunk_every(digits, 2, 1, :discard)
                |> Enum.all?(fn [a, b] -> b == a + 1 end)
    
    descending = Enum.chunk_every(digits, 2, 1, :discard)
                 |> Enum.all?(fn [a, b] -> b == a - 1 end)
    
    ascending or descending
  end

  defp is_repetitive?(pin) do
    # Check if more than half the digits are the same
    digits = String.graphemes(pin)
    unique_count = Enum.uniq(digits) |> length()
    unique_count <= String.length(pin) / 2
  end
end