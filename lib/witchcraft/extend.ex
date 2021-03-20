import TypeClass

defclass Witchcraft.Extend do
  @moduledoc """
  `Extend` is essentially "co`Chain`", meaning that it reverses the relationships
  in `Chain`.

  Instead of a flattening operation, we have `nest` which wraps the data in
  an additional layer of itsef.

  Instead of a `chain`ing function that acts on raw data and wraps it,
  we have `extend` which unwraps data, may modify it, and returns the unwrapped value

  ## Type Class

  An instance of `Witchcraft.Extend` must also implement `Witchcraft.Functor`,
  and define `Witchcraft.Extend.nest/1`.

      Functor  [map/2]
         ↓
      Extend   [nest/1]

  """

  alias __MODULE__
  alias Witchcraft.Functor

  extend Witchcraft.Functor

  use Quark

  @type t :: any()
  @type colink :: (Extend.t() -> any())

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Functor, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    Wrap some nestable data structure in another layer of itself

    ## Examples

        iex> nest([1, 2, 3])
        [[1, 2, 3], [2, 3], [3]]

    """
    @spec nest(Extend.t()) :: Extend.t()
    def nest(data)
  end

  properties do
    def extend_composition(data) do
      if is_function(data) do
        use Witchcraft.Semigroup

        a = &inspect/1

        monoid = Enum.random([1, [], ""])

        arg1 = generate(monoid)
        arg2 = generate(monoid)
        arg3 = generate(monoid)

        f = fn x -> x <|> fn a -> a <> a end end
        g = fn y -> y <|> fn b -> b <> b <> b end end

        left =
          a
          |> Witchcraft.Extend.extend(g)
          |> Witchcraft.Extend.extend(f)

        right =
          Witchcraft.Extend.curried_extend(a, fn x ->
            x
            |> Witchcraft.Extend.curried_extend(g)
            |> f.()
          end)

        equal?(left.(arg1).(arg2).(arg3), right.(arg1).(arg2).(arg3))
      else
        a = generate(data)

        f = fn x -> "#{inspect(x)}-#{inspect(x)}" end
        g = fn y -> "#{inspect(y)} / #{inspect(y)} / #{inspect(y)}" end

        left =
          a
          |> Witchcraft.Extend.curried_extend(g)
          |> Witchcraft.Extend.curried_extend(f)

        right =
          Witchcraft.Extend.curried_extend(a, fn x ->
            x
            |> Witchcraft.Extend.curried_extend(g)
            |> f.()
          end)

        equal?(left, right)
      end
    end

    def naturality(data) do
      a = generate(data)

      if is_function(data) do
        fun = &inspect/1

        monoid = Enum.random([1, [], ""])

        arg1 = generate(monoid)
        arg2 = generate(monoid)
        arg3 = generate(monoid)

        left =
          fun
          |> Extend.nest()
          |> Functor.lift(&Extend.nest/1)

        right =
          fun
          |> Extend.nest()
          |> Extend.nest()

        equal?(left.(arg1).(arg2).(arg3), right.(arg1).(arg2).(arg3))
      else
        a
        |> Extend.nest()
        |> Functor.lift(&Extend.nest/1)
        |> equal?(a |> Extend.nest() |> Extend.nest())
      end
    end

    def extend_as_nest(data) do
      if is_function(data) do
        fun = &inspect/1

        monoid = Enum.random([1, [], ""])

        arg1 = generate(monoid)
        arg2 = generate(monoid)

        left = Witchcraft.Extend.extend(fun, &Quark.id/1)
        right = Witchcraft.Extend.nest(fun)

        equal?(left.(arg1).(arg2), right.(arg1).(arg2))
        true
      else
        a = generate(data)

        a
        |> Witchcraft.Extend.extend(&Quark.id/1)
        |> equal?(Witchcraft.Extend.nest(a))
      end
    end

    def nest_as_extend(data) do
      if is_function(data) do
        f = fn x -> x <> x end
        g = &inspect/1

        monoid = Enum.random([1, [], ""])

        arg1 = generate(monoid)
        arg2 = generate(monoid)

        left =
          g
          |> Extend.nest()
          |> Functor.lift(&Functor.lift(&1, f))

        right = Extend.nest(Functor.lift(g, f))

        equal?(left.(arg1).(arg2), right.(arg1).(arg2))
      else
        a = generate(data)
        f = &inspect/1

        a
        |> Extend.nest()
        |> Functor.lift(&Functor.lift(&1, f))
        |> equal?(Extend.nest(Functor.lift(a, f)))
      end
    end
  end

  @doc """
  Similar to `Witchcraft.Chain.chain/2`, except that it reverses the input and output
  types of the colinking function.

  ## Examples

  Chain:

      iex> Witchcraft.Chain.chain([1, 2, 3], fn x -> [x * 10] end)
      [10, 20, 30]

  Extend:

      iex> extend([1, 2, 3], fn list -> List.first(list) * 10 end)
      [10, 20, 30]

  """
  @spec extend(Extend.t(), Extend.colink()) :: Extend.t()
  def extend(data, colink) do
    data
    |> nest()
    |> Functor.map(colink)
  end

  @doc """
  `extend/2` with arguments flipped.

  Makes piping composed colinks easier (see `compose_colink/2` and `pipe_compose_colink/2`).

  ## Examples

      iex> fn list -> List.first(list) * 10 end
      ...> |> peel([1, 2, 3])
      [10, 20, 30]

  """
  @spec peel(Extend.colink(), Extend.t()) :: Extend.t()
  def peel(colink, data), do: Extend.extend(data, colink)

  @doc """
  The same as `extend/2`, but with the colinking function curried.

  ## Examples

      iex> [1, 2, 3]
      ...> |> curried_extend(fn(list, coeff) -> List.first(list) * coeff end)
      ...> |> extend(fn(funs) -> List.first(funs).(10) end)
      [10, 20, 30]

  """
  @spec curried_extend(Extend.t(), fun()) :: Extend.t()
  def curried_extend(data, colink), do: Extend.extend(data, curry(colink))

  @doc """
  The same as `extend/2`, but with the colinking function curried.

  ## Examples

      iex> fn(list) -> List.first(list) * 10 end
      ...> |> curried_peel([1, 2, 3])
      [10, 20, 30]

  """
  @spec curried_peel(Extend.t(), fun()) :: Extend.t()
  def curried_peel(colink, data), do: curried_extend(data, colink)

  @doc """

  ## Examples

      iex> composed =
      ...>   fn xs -> List.first(xs) * 10 end
      ...>   |> compose_colink(fn ys -> List.first(ys) - 10 end)
      ...>
      ...> extend([1, 2, 3], composed)
      [-90, -80, -70]

      iex> fn xs -> List.first(xs) * 10 end
      ...> |> compose_colink(fn ys -> List.first(ys) - 10 end)
      ...> |> compose_colink(fn zs -> List.first(zs) * 50 end)
      ...> |> peel([1, 2, 3])
      [400, 900, 1400]

      iex> fn xs -> List.first(xs) * 10 end
      ...> |> compose_colink(fn ys -> List.first(ys) - 10 end)
      ...> |> compose_colink(fn zs -> List.first(zs) * 50 end)
      ...> |> compose_colink(fn zs -> List.first(zs) + 12 end)
      ...> |> peel([1, 2, 3])
      [6400, 6900, 7400]

  """
  @spec compose_colink(Extend.colink(), Extend.colink()) :: (Extend.t() -> any())
  def compose_colink(g, f), do: fn x -> x |> curried_extend(f) |> g.() end

  @doc """
  `pipe_colink/2` with functions curried.

  ## Examples

      iex> fn xs -> List.first(xs) * 10 end
      ...> |> pipe_compose_colink(fn ys -> List.first(ys) - 2 end)
      ...> |> peel([1, 2, 3])
      [8, 18, 28]

      iex> composed =
      ...>   fn xs -> List.first(xs) * 10 end
      ...>   |> pipe_compose_colink(fn ys -> List.first(ys) - 2 end)
      ...>   |> pipe_compose_colink(fn zs -> List.first(zs) * 5 end)
      ...>
      ...> extend([1, 2, 3], composed)
      [40, 90, 140]

      iex> fn xs -> List.first(xs) * 10 end
      ...> |> pipe_compose_colink(fn ys -> List.first(ys) - 2 end)
      ...> |> pipe_compose_colink(fn zs -> List.first(zs) * 5 end)
      ...> |> pipe_compose_colink(fn zs -> List.first(zs) + 1 end)
      ...> |> peel([1, 2, 3])
      [41, 91, 141]

  """
  @spec pipe_compose_colink(Extend.colink(), Extend.colink()) :: (Extend.t() -> any())
  def pipe_compose_colink(f, g), do: compose_colink(g, f)
end

definst Witchcraft.Extend, for: Function do
  def nest(fun) do
    use Quark

    fn left ->
      fn right ->
        left
        |> Witchcraft.Semigroup.append(right)
        |> curry(fun).()
      end
    end
  end
end

definst Witchcraft.Extend, for: List do
  def nest([]), do: []
  # Could be improved
  def nest(entire = [_head | tail]), do: [entire | nest(tail)]
end

definst Witchcraft.Extend, for: Tuple do
  custom_generator(_) do
    import TypeClass.Property.Generator, only: [generate: 1]
    {generate(nil), generate(nil)}
  end

  def nest({x, y}), do: {x, {x, y}}
end
