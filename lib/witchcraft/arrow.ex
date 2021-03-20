import TypeClass

defclass Witchcraft.Arrow do
  @moduledoc """
  Arrows abstract the idea of computations, potentially with a context.

  Arrows are in fact an abstraction above monads, and can be used both to
  express all other type classes in Witchcraft. They also enable some nice
  flow-based reasoning about computation.

  For a nice illustrated explination,
  see [Haskell/Understanding arrows](https://en.wikibooks.org/wiki/Haskell/Understanding_arrows)

  Arrows let you think diagrammatically, and is a powerful way of thinking
  about flow programming, concurrency, and more.

                   ┌---> f --------------------------┐
                   |                                 v
      input ---> split                            unsplit ---> result
                   |                                 ^
                   |              ┌--- h ---┐        |
                   |              |         v        |
                   └---> g ---> split     unsplit ---┘
                                  |         ^
                                  └--- i ---┘

  ## Type Class

  An instance of `Witchcraft.Arrow` must also implement `Witchcraft.Category`,
  and define `Witchcraft.Arrow.arrowize/2`.

      Semigroupoid  [compose/2, apply/2]
          ↓
       Category     [identity/1]
          ↓
        Arrow       [arrowize/2]

  """

  alias __MODULE__
  extend Witchcraft.Category
  use Witchcraft.Category

  @type t :: fun()

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Category, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    Lift a function into an arrow, much like how `of/2` does with data.

    Essentially a label for composing functions end-to-end, where instances
    may have their own special idea of what composition means. The simplest example
    is a regular function. Others are possible, such as Kleisli arrows.

    ## Examples

        iex> use Witchcraft.Arrow
        ...> times_ten = arrowize(fn -> nil end, &(&1 * 10))
        ...> 5 |> pipe(times_ten)
        50

    """
    @spec arrowize(Arrow.t(), fun()) :: Arrow.t()
    def arrowize(sample, fun)
  end

  properties do
    def arrow_identity(sample) do
      a = generate(nil)

      left = Arrow.arrowize(sample, &Quark.id/1)
      right = &Quark.id/1

      equal?(a |> pipe(left), a |> pipe(right))
    end

    def arrow_composition(sample) do
      use Witchcraft.Category

      a = generate(nil)

      f = fn x -> "#{x}-#{x}" end
      g = &inspect/1

      left = Arrow.arrowize(sample, f) <|> Arrow.arrowize(sample, g)
      right = Arrow.arrowize(sample, f <|> g)

      equal?(pipe(a, left), pipe(a, right))
    end

    def first_commutativity(sample) do
      a = {generate(nil), generate(nil)}
      f = &inspect/1

      left = Witchcraft.Arrow.first(Arrow.arrowize(sample, f))
      right = Arrow.arrowize(sample, Witchcraft.Arrow.first(f))

      equal?(pipe(a, left), pipe(a, right))
    end

    def first_composition(sample) do
      a = {generate(nil), generate(nil)}

      f = Arrow.arrowize(sample, fn x -> "#{x}-#{x}" end)
      g = Arrow.arrowize(sample, &inspect/1)

      left = Witchcraft.Arrow.first(f <|> g)
      right = Witchcraft.Arrow.first(f) <|> Witchcraft.Arrow.first(g)

      equal?(pipe(a, left), pipe(a, right))
    end

    def second_arrow_commutativity(sample) do
      a = {generate(nil), generate(nil)}
      f = &inspect/1

      left = Witchcraft.Arrow.second(Arrow.arrowize(sample, f))
      right = Arrow.arrowize(sample, Witchcraft.Arrow.second(f))

      equal?(pipe(a, left), pipe(a, right))
    end

    def second_composition(sample) do
      a = {generate(nil), generate(nil)}

      f = Arrow.arrowize(sample, fn x -> "#{x}-#{x}" end)
      g = Arrow.arrowize(sample, &inspect/1)

      left = Witchcraft.Arrow.second(f <|> g)
      right = Witchcraft.Arrow.second(f) <|> Witchcraft.Arrow.second(g)

      equal?(pipe(a, left), pipe(a, right))
    end

    def product_composition(sample) do
      a = {generate(nil), generate(nil)}

      f = &inspect/1
      g = fn x -> "#{inspect(x)}-#{inspect(x)}" end

      left =
        Witchcraft.Arrow.product(
          Arrow.arrowize(sample, f),
          Arrow.arrowize(sample, g)
        )

      right = Arrow.arrowize(sample, Witchcraft.Arrow.product(f, g))

      equal?(pipe(a, left), pipe(a, right))
    end

    def fanout_composition(sample) do
      a = generate(nil)

      f = &inspect/1
      g = fn x -> "#{inspect(x)}-#{inspect(x)}" end

      left =
        Witchcraft.Arrow.fanout(
          Arrow.arrowize(sample, f),
          Arrow.arrowize(sample, g)
        )

      right = Arrow.arrowize(sample, Witchcraft.Arrow.fanout(f, g))

      equal?(pipe(a, left), pipe(a, right))
    end

    def first_reassociaton(sample) do
      a = {{generate(nil), generate(nil)}, {generate(nil), generate(nil)}}
      f = fn x -> "#{inspect(x)}-#{inspect(x)}" end

      x = Witchcraft.Arrow.first(Arrow.arrowize(sample, f))
      y = Arrow.arrowize(sample, &Witchcraft.Arrow.reassociate/1)

      left = Witchcraft.Arrow.first(x) <~> y
      right = y <~> x

      equal?(a |> pipe(left), a |> pipe(right))
    end

    def first_identity(sample) do
      a = {generate(nil), generate(nil)}
      f = fn x -> "#{inspect(x)}-#{inspect(x)}" end

      left = Witchcraft.Arrow.first(f) <~> Arrow.arrowize(sample, fn {x, _} -> x end)
      right = Arrow.arrowize(sample, fn {x, _} -> x end) <~> f

      equal?(pipe(a, left), pipe(a, right))
    end

    def first_product_commutativity(sample) do
      a = {generate(nil), generate(nil)}

      f = &inspect/1
      g = fn x -> "#{inspect(x)}-#{inspect(x)}" end

      x = Arrow.arrowize(sample, Witchcraft.Arrow.product(&Quark.id/1, g))
      y = Witchcraft.Arrow.first(f)

      left = x <|> y
      right = y <|> x

      equal?(pipe(a, left), pipe(a, right))
    end
  end

  @doc """
  Take two arguments (as a 2-tuple), and run one function on the left side (first element),
  and run a different function on the right side (second element).

        ┌------> f.(a) = x -------┐
        |                         v
      {a, b}                    {x, y}
        |                         ^
        └------> g.(b) = y -------┘

  ## Examples

      iex> product(&(&1 - 10), &(&1 <> "!")).({42, "Hi"})
      {32, "Hi!"}

  """
  @spec product(Arrow.t(), Arrow.t()) :: Arrow.t()
  def product(arrow_f, arrow_g), do: first(arrow_f) <~> second(arrow_g)

  @doc """
  Alias for `product/2`, meant to invoke a spacial metaphor.

  ## Examples

      iex> beside(&(&1 - 10), &(&1 <> "!")).({42, "Hi"})
      {32, "Hi!"}

  """
  @spec beside(Arrow.t(), Arrow.t()) :: Arrow.t()
  defalias beside(a, b), as: :product

  @doc """
  Operator alias for `product/2`.

  ## Examples

      iex> arr = fn x -> x - 10 end ^^^ fn y -> y <> "!" end
      ...> arr.({42, "Hi"})
      {32, "Hi!"}

      iex> {42, "Hi"} |> (fn x -> x - 10 end ^^^ fn y -> y <> "!" end).()
      {32, "Hi!"}

  """
  @spec Arrow.t() ^^^ Arrow.t() :: Arrow.t()
  defalias a ^^^ b, as: :product

  @doc """
  Swap positions of elements in a tuple.

  ## Examples

      iex> swap({1, 2})
      {2, 1}

  """
  @spec swap({any(), any()}) :: {any(), any()}
  def swap({x, y}), do: {y, x}

  @doc """
  Target the first element of a tuple.

  ## Examples

      iex> first(fn x -> x * 50 end).({1, 1})
      {50, 1}

  """
  @spec first(Arrow.t()) :: Arrow.t()
  def first(arrow) do
    arrowize(arrow, fn {x, y} ->
      {
        x |> pipe(arrow),
        y |> pipe(id_arrow(arrow))
      }
    end)
  end

  @doc """
  Target the second element of a tuple.

  ## Examples

      iex> second(fn x -> x * 50 end).({1, 1})
      {1, 50}

  """
  @spec second(Arrow.t()) :: Arrow.t()
  def second(arrow) do
    arrowize(arrow, fn {x, y} ->
      {
        x |> pipe(id_arrow(arrow)),
        y |> pipe(arrow)
      }
    end)
  end

  @doc """
  The identity function lifted into an arrow of the correct type.

  ## Examples

      iex> id_arrow(fn -> nil end).(99)
      99

  """
  @spec id_arrow(Arrow.t()) :: (any() -> Arrow.t())
  def id_arrow(sample), do: arrowize(sample, &Quark.id/1)

  @doc """
  Duplicate incoming data into both halves of a 2-tuple, and run one function
  on the left copy, and a different function on the right copy.

               ┌------> f.(a) = x ------┐
               |                        v
      a ---> split = {a, a}           {x, y}
               |                        ^
               └------> g.(a) = y ------┘

  ## Examples

      iex> Witchcraft.Semigroupoid.pipe(42, fanout(&(&1 - 10), &(inspect(&1) <> "!")))
      {32, "42!"}

  """
  @spec fanout(Arrow.t(), Arrow.t()) :: Arrow.t()
  def fanout(arrow_f, arrow_g) do
    arrow_f |> arrowize(&split/1) <~> (arrow_f ^^^ arrow_g)
  end

  @doc """
  Operator alias for `fanout/2`.

  ## Examples

      iex> fanned = fn x -> x - 10 end &&& fn y -> inspect(y) <> "!" end
      ...> fanned.(42)
      {32, "42!"}

      iex> fanned =
      ...>   fn x -> x - 10 end
      ...>   &&& fn y -> inspect(y) <> "!" end
      ...>   &&& fn z -> inspect(z) <> "?" end
      ...>   &&& fn d -> inspect(d) <> inspect(d) end
      ...>   &&& fn e -> e / 2 end
      ...>
      ...> fanned.(42)
      {{{{32, "42!"}, "42?"}, "4242"}, 21.0}

  """
  @spec Arrow.t() &&& Arrow.t() :: Arrow.t()
  defalias a &&& b, as: :fanout

  @doc """
  Copy a single value into both positions of a 2-tuple.

  This is useful is you want to run functions on the input separately.

  ## Examples

      iex> split(42)
      {42, 42}

      iex> import Witchcraft.Semigroupoid, only: [<~>: 2]
      ...> 5
      ...> |> split()
      ...> |> (second(fn x -> x - 2 end)
      ...> <~> first(fn y -> y * 10 end)
      ...> <~> second(&inspect/1)).()
      {50, "3"}

      iex> use Witchcraft.Arrow
      ...> 5
      ...> |> split()
      ...> |> pipe(second(fn x -> x - 2 end))
      ...> |> pipe(first(fn y -> y * 10 end))
      ...> |> pipe(second(&inspect/1))
      {50, "3"}

  """
  @spec split(any()) :: {any(), any()}
  def split(x), do: {x, x}

  @doc """
  Merge two tuple values with a combining function.

  ## Examples

      iex> unsplit({1, 2}, &+/2)
      3

  """
  @spec unsplit({any(), any()}, (any(), any() -> any())) :: any()
  def unsplit({x, y}, combine), do: combine.(x, y)

  @doc """
  Switch the associativity of a nested tuple. Helpful since many arrows act
  on a subset of a tuple, and you may want to move portions in and out of that stream.

  ## Examples

      iex> reassociate({1, {2, 3}})
      {{1, 2}, 3}

      iex> reassociate({{1, 2}, 3})
      {1, {2, 3}}

  """
  @spec reassociate({any(), {any(), any()}} | {{any(), any()}, any()}) ::
          {{any(), any()}, any()} | {any(), {any(), any()}}
  def reassociate({{a, b}, c}), do: {a, {b, c}}
  def reassociate({a, {b, c}}), do: {{a, b}, c}

  @doc """
  Compose a function (left) with an arrow (right) to produce a new arrow.

  ## Examples

      iex> f = precompose(
      ...>   fn x -> x + 1 end,
      ...>   arrowize(fn _ -> nil end, fn y -> y * 10 end)
      ...> )
      ...> f.(42)
      430

  """
  @spec precompose(fun(), Arrow.t()) :: Arrow.t()
  def precompose(fun, arrow), do: arrowize(arrow, fun) <~> arrow

  @doc """
  Compose an arrow (left) with a function (right) to produce a new arrow.

  ## Examples

      iex> f = postcompose(
      ...>   arrowize(fn _ -> nil end, fn x -> x + 1 end),
      ...>   fn y -> y * 10 end
      ...> )
      ...> f.(42)
      430

  """
  @spec precompose(Arrow.t(), fun()) :: Arrow.t()
  def postcompose(arrow, fun), do: arrow <~> arrowize(arrow, fun)
end

definst Witchcraft.Arrow, for: Function do
  use Quark

  def arrowize(_, fun), do: curry(fun)
  def first(arrow), do: fn {target, unchanged} -> {arrow.(target), unchanged} end
end
