import TypeClass

defclass Witchcraft.Bifunctor do
  @moduledoc """
  Similar to `Witchcraft.Functor`, but able to map two functions over two
  separate portions of some data structure (some product type).

  Especially helpful when you need different hebaviours on different fields.

  ## Type Class

  An instance of `Witchcraft.Bifunctor` must also implement `Witchcraft.Functor`,
  and define `Witchcraft.Apply.ap/2`.

       Functor   [map/2]
          ↓
      Bifunctor  [bimap/2]

  """

  extend Witchcraft.Functor

  alias __MODULE__
  use Quark

  @type t :: any()

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Functor, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    `map` separate fuctions over two fields in a product type.

    The order of fields doesn't always matter in the map.
    The first/second function application is determined by the instance.
    It also does not have to map all fields in a product type.

    ## Diagram

                  ┌------------------------------------┐
                  ↓                                    |
        %Combo{a: 5, b: :ok, c: "hello"} |> bimap(&(&1 * 100), &String.upcase/1)
                                    ↑                                 |
                                    └---------------------------------┘
        #=> %Combo{a: 500, b: :ok, c: "HELLO"}

    ## Examples

        iex> {1, "a"} |> bimap(&(&1 * 100), &(&1 <> "!"))
        {100, "a!"}

        iex> {:msg, 42, "number is below 50"}
        ...> |> bimap(&(%{subject: &1}), &String.upcase/1)
        {:msg, %{subject: 42}, "NUMBER IS BELOW 50"}

    """
    @spec bimap(Bifunctor.t(), (any() -> any()), (any() -> any())) :: Bifunctor.t()
    def bimap(data, f, g)
  end

  properties do
    def identity(data) do
      a = generate(data)

      left = Bifunctor.bimap(a, &Quark.id/1, &Quark.id/1)
      equal?(left, a)
    end

    def composition(data) do
      a = generate(data)

      f = &Witchcraft.Semigroup.append(&1, &1)
      g = &inspect/1

      h = &is_number/1
      i = &!/1

      left = Bifunctor.bimap(a, fn x -> f.(g.(x)) end, fn y -> h.(i.(y)) end)
      right = a |> Bifunctor.bimap(g, i) |> Bifunctor.bimap(f, h)

      equal?(left, right)
    end
  end

  @doc """
  The same as `bimap/3`, but with the functions curried

  ## Examples

      iex> {:ok, 2, "hi"}
      ...> |> bilift(&*/2, &<>/2)
      ...> |> bimap(fn f -> f.(9) end, fn g -> g.("?!") end)
      {:ok, 18, "hi?!"}

  """
  @spec bilift(Bifunctor.t(), fun(), fun()) :: Bifunctor.t()
  def bilift(data, f, g), do: bimap(data, curry(f), curry(g))

  @doc """
  `map` a function over the first value only

  ## Examples

      iex> {:ok, 2, "hi"} |> map_first(&(&1 * 100))
      {:ok, 200, "hi"}

  """
  @spec map_first(Bifunctor.t(), (any() -> any())) :: Bifunctor.t()
  def map_first(data, f), do: Bifunctor.bimap(data, f, &Quark.id/1)

  @doc """
  The same as `map_first`, but with a curried function

  ## Examples

      iex> {:ok, 2, "hi"}
      ...> |> lift_first(&*/2)
      ...> |> map_first(fn f -> f.(9) end)
      {:ok, 18, "hi"}

  """
  @spec lift_first(Bifunctor.t(), fun()) :: Bifunctor.t()
  def lift_first(data, f), do: map_first(data, curry(f))

  @doc """
  `map` a function over the second value only

  ## Examples

      iex> {:ok, 2, "hi"} |> map_second(&(&1 <> "!?"))
      {:ok, 2, "hi!?"}

  """
  @spec map_second(Bifunctor.t(), (any() -> any())) :: Bifunctor.t()
  def map_second(data, g), do: Bifunctor.bimap(data, &Quark.id/1, g)

  @doc """
  The same as `map_second`, but with a curried function

  ## Examples

      iex> {:ok, 2, "hi"}
      ...> |> lift_second(&<>/2)
      ...> |> map_second(fn f -> f.("?!") end)
      {:ok, 2, "hi?!"}

  """
  @spec lift_second(Bifunctor.t(), fun()) :: Bifunctor.t()
  def lift_second(data, g), do: map_second(data, curry(g))
end

definst Witchcraft.Bifunctor, for: Tuple do
  # credo:disable-for-lines:6 Credo.Check.Refactor.PipeChainStart
  custom_generator(_) do
    fn -> TypeClass.Property.Generator.generate(nil) end
    |> Stream.repeatedly()
    |> Enum.take(Enum.random(2..12))
    |> List.to_tuple()
  end

  def bimap(tuple, f, g) do
    case tuple do
      {a, b} ->
        {f.(a), g.(b)}

      {x, a, b} ->
        {x, f.(a), g.(b)}

      {x, y, a, b} ->
        {x, y, f.(a), g.(b)}

      {x, y, z, a, b} ->
        {x, y, z, f.(a), g.(b)}

      big_tuple when tuple_size(big_tuple) > 5 ->
        index_a = tuple_size(big_tuple) - 2

        mapped_a =
          big_tuple
          |> elem(index_a)
          |> f.()

        big_tuple
        |> Witchcraft.Functor.map(g)
        |> put_elem(index_a, mapped_a)
    end
  end
end
