defmodule Witchcraft.Monoid.Property do
  @moduledoc """
  Check samples of your monoid to confirm that your data adheres to the
  monoidal properties. *All members* of your datatype should adhere to these rules.
  They are placed here as a quick way to spotcheck some of your values.
  """

  use Witchcraft.Monoid

  @doc ~S"""
  Check that some member of your monoid combines with the identity to return itself

      iex> spotcheck_identity("well formed")
      true

  """
  @spec spotcheck_identity(any) :: boolean
  def spotcheck_identity(member), do: (identity(member) <> member) == member

  @doc ~S"""
  Check that `Monoid.append` is [associative](https://en.wikipedia.org/wiki/Associative_property)
  (ie: brackets don't matter)

      iex> spotcheck_associativity("a", "b", "c")
      true

  """
  @spec spotcheck_associativity(any, any, any) :: boolean
  def spotcheck_associativity(member1, member2, member3) do
    (member1 <> (member2 <> member3)) == ((member1 <> member2) <> member3)
  end

  @doc """
  Spotcheck all monoid properties

      iex> spotcheck(1,2,3)
      true

  """
  @spec spotcheck(any, any, any) :: boolean
  def spotcheck(a, b, c) do
    spotcheck_identity(a) and spotcheck_associativity(a, b, c)
  end
end
