import TypeClass

defclass Witchcraft.Applicative do
  @moduledoc """
  `Applicative` extends `Apply` with the ability to lift value into a
  particular data type or "context".

  This fills in the connection between regular function application and `Apply`

                 data --------------- function ---------------> result
                   |                      |                       |
       of(Container, data)    of(Container, function) of(Container, result)
                   ↓                      ↓                       ↓
      %Container<data> --- %Container<function> ---> %Container<result>

  ## Type Class

  An instance of `Witchcraft.Applicative` must also implement `Witchcraft.Apply`,
  and define `Witchcraft.Applicative.of/2`.

         Functor    [map/2]
            ↓
          Apply     [convey/2]
            ↓
       Applicative  [of/2]
  """

  alias __MODULE__
  extend Witchcraft.Apply

  @type t :: any()

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Apply, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    Bring a value into the same data type as some sample

    ## Examples

        iex> of([], 42)
        [42]

        iex> of([1, 2, 3], 42)
        [42]

        iex> of({"a", "b", 155}, 42)
        {"", "", 42}

        iex> of(fn -> nil end, 42).(55)
        42

        iex> of(fn(a, b, c) -> a + b - c end, 42).(55)
        42

        iex> import Witchcraft.Apply
        ...>
        ...> []
        ...> |> of(&+/2)
        ...> |> provide([1, 2, 3])
        ...> |> ap(of([], 42))
        [43, 44, 45]

    """
    @spec of(Applicative.t(), any()) :: Applicative.t()
    def of(sample, to_wrap)
  end

  @doc """
  Partially apply `of/2`, generally as a way to bring many values into the same context.

  ## Examples

      iex> {"very example", "much wow"}
      ...> |> of()
      ...> |> Witchcraft.Functor.across([42, "hello", [1, 2, 3]])
      [{"", 42}, {"", "hello"}, {"", [1, 2, 3]}]

  """
  @spec of(Applicative.t()) :: (any() -> Applicative.t())
  def of(sample), do: fn to_wrap -> of(sample, to_wrap) end

  @doc """
  Alias for `of/2`, for cases that this helps legibility or style.

  ## Example

      iex> wrap({":|", "^.~"}, 42)
      {"", 42}

      iex> [] |> wrap(42)
      [42]

  """
  @spec wrap(Applicative.t(), any()) :: Applicative.t()
  defalias wrap(sample, to_wrap), as: :of

  @doc """
  Alias for `of/2`, for cases that this helps legibility or style.

  ## Example

      iex> pure({"ohai", "thar"}, 42)
      {"", 42}

      iex> [] |> pure(42)
      [42]

  """
  @spec pure(Applicative.t(), any()) :: Applicative.t()
  defalias pure(sample, to_wrap), as: :of

  @doc """
  `of/2` with arguments reversed.

  ## Example

      iex> to(42, {"ohai", "thar"})
      {"", 42}

      iex> 42 |> to([])
      [42]

      42 |> to(%Algae.Id{})
      #=> %Algae.Id{id: 42}

  """
  @spec to(any(), Applicative.t()) :: Applicative.t()
  def to(to_wrap, sample), do: of(sample, to_wrap)

  @doc """
  Prime a value to be brought into other data types

  ## Example

      iex> make = to(42)
      ...> make.({"ohai", "thar"})
      {"", 42}
      ...> make.([])
      [42]

  """
  @spec to(any()) :: (Applicative.t() -> Applicative.t())
  def to(to_wrap), do: fn type -> of(type, to_wrap) end

  @doc """
  Alias for `of/2`, for cases that this helps legibility or style

  ## Example

      iex> unit({":)", ":("}, 42)
      {"", 42}

      iex> [] |> unit(42)
      [42]

  """
  @spec unit(Applicative.t(), any()) :: Applicative.t()
  defalias unit(sample, to_wrap), as: :of

  properties do
    import Witchcraft.Functor
    import Witchcraft.Apply

    def identity(data) do
      a = generate(data)
      f = &Quark.id/1

      equal?(a, a ~>> Applicative.of(a, f))
    end

    def homomorphism(data) do
      arg = 42
      a = generate(data)
      f = &inspect/1

      left = Applicative.of(a, arg) ~>> Applicative.of(a, f)
      right = Applicative.of(a, f.(arg))

      equal?(left, right)
    end

    def interchange(data) do
      arg = 42
      as = generate(data)
      fs = replace(as, &inspect/1)

      left = Applicative.of(as, arg) ~>> fs
      right = fs ~>> Applicative.of(as, fn g -> g.(arg) end)

      equal?(left, right)
    end
  end
end

definst Witchcraft.Applicative, for: Function do
  def of(_, unwrapped), do: &Quark.SKI.k(unwrapped, &1)
end

definst Witchcraft.Applicative, for: List do
  def of(_, unwrapped), do: [unwrapped]
end

definst Witchcraft.Applicative, for: Tuple do
  custom_generator(_) do
    import TypeClass.Property.Generator, only: [generate: 1]
    {generate(0), generate(0)}
  end

  def of(sample, unwrapped) do
    size = tuple_size(sample)

    sample
    |> elem(0)
    |> Witchcraft.Monoid.empty()
    |> Tuple.duplicate(size)
    |> put_elem(size - 1, unwrapped)
  end
end
