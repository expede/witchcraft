import TypeClass

defclass Witchcraft.Comonad do
  @moduledoc """
  The dual of monads, `Comonad` brings an unwrapping function to `Extend`able data.

  Note that the unwrapping function (`extract`) *must return a value*, and is not
  available on many data structres that have an empty element. For example,
  there is no `Comonad` instance for `List` because we cannot pull a value
  out of `[]`.

  ## Type Class

  An instance of `Witchcraft.Comonad` must also implement `Witchcraft.Extend`,
  and define `Witchcraft.Comonad.extract/1`.

      Functor  [map/2]
         ↓
      Extend   [nest/1]
         ↓
      Comonad  [extract/1]
  """

  alias __MODULE__
  extend Witchcraft.Extend
  use Quark

  @type t :: any()

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Extend, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    Extract a value out of some context / data structure. This is the opposite
    of `Witchcraft.Applicative.of/2`.

    ## Examples

        iex> extract({1, 2})
        2

        extract(%Id{id: 42})
        #=> 42

    """
    @spec extract(Comonad.t()) :: any()
    def extract(nested)
  end

  @doc """
  Alias for `extract/1`

  ## Examples

      iex> unwrap({1, 2})
      2

      unwrap(%Id{id: 42})
      #=> 42

  """
  @spec unwrap(Comonad.t()) :: any()
  def unwrap(nested), do: extract(nested)

  properties do
    def left_identity(data) do
      a = generate(data)

      a
      |> Witchcraft.Extend.extend(&Comonad.extract/1)
      |> equal?(a)
    end

    def right_identity(data) do
      a = generate(data)

      f = fn x ->
        x
        |> Comonad.extract()
        |> inspect()
      end

      a
      |> Witchcraft.Extend.extend(f)
      |> Comonad.extract()
      |> equal?(f.(a))
    end
  end
end

definst Witchcraft.Comonad, for: Tuple do
  custom_generator(_) do
    import TypeClass.Property.Generator, only: [generate: 1]
    {generate(nil), generate(nil)}
  end

  def extract(tuple) when tuple_size(tuple) >= 1 do
    elem(tuple, tuple_size(tuple) - 1)
  end
end
