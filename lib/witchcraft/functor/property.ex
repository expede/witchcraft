defmodule Witchcraft.Functor.Property do
  @moduledoc ~S"""
  Check samples of your functor to confirm that your data adheres to the
  functor properties. *All members* of your datatype should adhere to these rules.
  They are placed here as a quick way to spotcheck some of your values.
  """

  import Quark, only: [compose: 1, id: 1]
  import Witchcraft.Functor, only: [lift: 2]

  @doc ~S"""
  Check that lifting a function into some context returns a member of the target type
  """
  @spec spotcheck_associates_object(any, (any -> any), (any -> boolean)) :: boolean
  def spotcheck_associates_object(context, func, typecheck) do
    lift(context, func) |> typecheck.()
  end

  @doc ~S"""
  Check that lifting a function does not interfere with identity.
  In other words, lifting `id(a)` shoud be the same as the identity of lifting `a`.

       A ---- id ----> A

       |               |
      (f)             (f)
       |               |
       v               v

       B ---- id ----> B

  """
  @spec spotcheck_preserve_identity(any, (any -> any)) :: boolean
  def spotcheck_preserve_identity(context, func) do
    lift(id(context), func) == id(lift(context, func))
  end

  @doc ~S"""
  Check that lifting a composed function is the same as lifting functions in sequence
  """
  @spec spotcheck_preserve_compositon(any, (any -> any), (any -> any)) :: boolean
  def spotcheck_preserve_compositon(context, f, g) do
    lift(lift(context, f), g) == lift(context, compose([g, f]))
  end

  @doc ~S"""
  Spotcheck all functor properties
  """
  @spec spotcheck(any, (any -> any), (any -> any), (any -> boolean)) :: boolean
  def spotcheck(context, f, g, typecheck) do
    spotcheck_associates_object(context, f, typecheck)
      and spotcheck_preserve_identity(context, f)
      and spotcheck_preserve_compositon(context, f, g)
  end
end
