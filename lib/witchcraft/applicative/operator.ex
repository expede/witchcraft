defmodule Witchcraft.Applicative.Operator do
  @moduledoc ~S"""
  """

  import Witchcraft.Applicative, only: [seq: 2]

  @doc ~S"""
  Infix alias for `Witchcraft.Applicative.seq`. If chaining, be sure to wrap
  each layer in parentheses, as `~>>` and `~>` are left associative.

  ## Examples

      iex> [1,2,3] ~>> [&(&1 + 1), &(&1 * 10)]
      [2,3,4,10,20,30]

      iex> import Witchcraft.Functor.Operator, only: [~>: 2]
      iex> [9, 10] ~>> ([1,2,3] ~> &(fn x -> x * &1 end))
      [9, 10, 18, 20, 27, 30]

  """
  @spec any ~>> any :: any
  def value ~>> func, do: seq(value, func)

  @doc ~S"""
  Infix alias for `Witchcraft.Applicative.seq`, with arguments reversed.

  This version is preferred, as it makes chaining arguments along wrapped
  partial applications clearer when reading left-to-right.

  ## Examples

      iex> [&(&1 + 1), &(&1 * 10)] <<~ [1,2,3]
      [2,3,4,10,20,30]

      iex> import Witchcraft.Functor.Operator, only: [<~: 2]
      iex> (&(fn x -> x * &1 end)) <~ [1,2,3] <<~ [9,10,11]
      [9,10,11,18,20,22,27,30,33]

  """
  @spec any <<~ any :: any
  def func <<~ value, do: value ~>> func
end
