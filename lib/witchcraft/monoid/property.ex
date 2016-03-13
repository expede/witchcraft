defmodule Witchcraft.Monoid.Property do
  @moduledoc """
  Check samples of your monoid to confirm that your data adheres to the
  monoidal properties. *All members* of your datatype should adhere to these rules.
  They are placed here as a quick way to spotcheck some of your values.
  """

  import Witchcraft.Monoid
  import Witchcraft.Monoid.Operator, only: [<|>: 2]

  @doc ~S"""
  Check that some member of your monoid combines with the identity to return itself

  ```elixir

  iex> identity("well formed")
  true

  # Float under division
  iex> identity(%Witchcraft.Sad{})
  false

  ```

  """
  @spec identity(any) :: boolean
  def identity(member), do: (identity(member) <|> member) == member

  @doc ~S"""
  Check that `Monoid.append` is [associative](https://en.wikipedia.org/wiki/Associative_property)
  (ie: brackets don't matter)

  ```elixir

  iex> associativity("a", "b", "c")
  true

  # Float under division
  iex> associativity(%Witchcraft.Sad{sad: -9.1}, %Witchcraft.Sad{sad: 42.0}, %Witchcraft.Sad{sad: 88.8})
  false

  ```

  """
  @spec associativity(any, any, any) :: boolean
  def associativity(member1, member2, member3) do
    (member1 <|> (member2 <|> member3)) == ((member1 <|> member2) <|> member3)
  end

  @doc """
  Spotcheck all monoid properties

  ```elixir

  iex> spotcheck(1,2,3)
  true

  # Float under division
  iex> spotcheck(%Witchcraft.Sad{sad: -9.1}, %Witchcraft.Sad{sad: 42.0}, %Witchcraft.Sad{sad: 88.8})
  false

  ```

  """
  @spec spotcheck(any, any, any) :: boolean
  def spotcheck(a, b, c) do
    identity(a) and associativity(a, b, c)
  end
end
