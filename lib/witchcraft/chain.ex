import TypeClass

defclass Witchcraft.Chain do
  @moduledoc """
  Chain function applications on contained data that may have some additional effect

  As a diagram:

      %Container<data> --- (data -> %Container<updated_data>) ---> %Container<updated_data>

  ## Examples

      iex> chain([1, 2, 3], fn x -> [x, x] end)
      [1, 1, 2, 2, 3, 3]

      alias Algae.Maybe.{Nothing, Just}

      %Just{just: 42} >>> fn x -> %Just{just: x + 1} end
      #=> %Just{just: 43}

      %Just{just: 42}
      >>> fn x -> if x > 50, do: %Just{just: x + 1}, else: %Nothing{} end
      >>> fn y -> y * 100 end
      #=> %Nothing{}

  ## Type Class

  An instance of `Witchcraft.Chain` must also implement `Witchcraft.Apply`,
  and define `Witchcraft.Chain.chain/2`.

      Functor  [map/2]
         ↓
       Apply   [convey/2]
         ↓
       Chain   [chain/2]
  """

  alias __MODULE__
  extend Witchcraft.Apply
  use Witchcraft.Apply

  @type t :: any()
  @type link :: (any() -> Chain.t())

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Apply, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    Sequentially compose actions, piping values through successive function chains.

    The applied linking function must be unary and return data in the same
    type of container as the input. The chain function essentially "unwraps"
    a contained value, applies a linking function that returns
    the initial (wrapped) type, and collects them into a flat(ter) structure.

    `chain/2` is sometimes called "flat map", since it can also
    be expressed as `data |> map(link_fun) |> flatten()`.

    As a diagram:

        %Container<data> --- (data -> %Container<updated_data>) ---> %Container<updated_data>

    ## Examples

        iex> chain([1, 2, 3], fn x -> [x, x] end)
        [1, 1, 2, 2, 3, 3]

        iex> [1, 2, 3]
        ...> |> chain(fn x -> [x, x] end)
        ...> |> chain(fn y -> [y, 2 * y, 3 * y] end)
        [1, 2, 3, 1, 2, 3, 2, 4, 6, 2, 4, 6, 3, 6, 9, 3, 6, 9]

        iex> chain([1, 2, 3], fn x ->
        ...>   chain([x + 1], fn y ->
        ...>     chain([y + 2, y + 10], fn z ->
        ...>       [x, y, z]
        ...>     end)
        ...>   end)
        ...> end)
        [1, 2, 4, 1, 2, 12, 2, 3, 5, 2, 3, 13, 3, 4, 6, 3, 4, 14]

    """
    @spec chain(Chain.t(), Chain.link()) :: Chain.t()
    def chain(chainable, link_fun)
  end

  @doc """
  `chain/2` but with the arguments flipped.

  ## Examples

      iex> draw(fn x -> [x, x] end, [1, 2, 3])
      [1, 1, 2, 2, 3, 3]

      iex> (fn y -> [y * 5, y * 10] end)
      ...> |> draw((fn x -> [x, x] end)
      ...> |> draw([1, 2, 3])) # note the "extra" closing paren
      [5, 10, 5, 10, 10, 20, 10, 20, 15, 30, 15, 30]

  """
  @spec draw(Chain.link(), Chain.t()) :: Chain.t()
  def draw(chain_fun, chainable), do: chain(chainable, chain_fun)

  @doc """
  An alias for `chain/2`.

  Provided as a convenience for those coming from other languages.
  """
  @spec bind(Chain.t(), Chain.link()) :: Chain.t()
  defalias bind(chainable, binder), as: :chain

  @doc """
  Operator alias for `chain/2`.

  Extends the `~>` / `~>>` heirarchy with one more level of power / abstraction

  ## Examples

      iex> to_monad = fn x -> (fn _ -> x end) end
      ...> bound = to_monad.(&(&1 * 10)) >>> to_monad.(&(&1 + 10))
      ...> bound.(10)
      20

  In Haskell, this is the famous `>>=` operator, but Elixir doesn't allow that
  infix operator.

  """
  @spec Chain.t() >>> Chain.link() :: Chain.t()
  defalias chainable >>> chain_fun, as: :chain

  @doc """
  Operator alias for `draw/2`

  Extends the `<~` / `<<~` heirarchy with one more level of power / abstraction

  ## Examples

      iex> to_monad = fn x -> (fn _ -> x end) end
      ...> bound = to_monad.(&(&1 + 10)) <<< to_monad.(&(&1 * 10))
      ...> bound.(10)
      20

  In Haskell, this is the famous `=<<` operator, but Elixir doesn't allow that
  infix operator.

  """
  @spec Chain.t() <<< Chain.link() :: Chain.t()
  defalias chain_fun <<< chainable, as: :draw

  @doc """
  Join together one nested level of a data structure that contains itself

  ## Examples

      iex> join([[1, 2, 3]])
      [1, 2, 3]

      iex> join([[1, 2, 3], [4, 5, 6]])
      [1, 2, 3, 4, 5, 6]

      iex> join([[[1, 2, 3], [4, 5, 6]]])
      [[1, 2, 3], [4, 5, 6]]

      alias Algae.Maybe.{Nothing, Just}
      %Just{
        just: %Just{
          just: 42
        }
      } |> join()
      #=> %Just{just: 42}

      join %Just{just: %Nothing{}}
      #=> %Nothing{}

      join %Just{just: %Just{just: %Nothing{}}}
      #=> %Just{just: %Nothing{}}

      %Nothing{} |> join() |> join() |> join() # ...and so on, forever
      #=> %Nothing{}

  Joining tuples is a bit counterintuitive, as it requires a very specific format:

      iex> join {      # Outer 2-tuple
      ...>   {1, 2},   # Inner 2-tuple
      ...>   {
      ...>     {3, 4}, # Doubly inner 2-tuple
      ...>     {5, 6, 7}
      ...>   }
      ...> }
      {{4, 6}, {5, 6, 7}}

      iex> join {
      ...>   {"a", "b"},
      ...>   {
      ...>     {"!", "?"},
      ...>     {:ok, 123}
      ...>   }
      ...> }
      {{"a!", "b?"}, {:ok, 123}}

  """
  @spec join(Chain.t()) :: Chain.t()
  def join(nested), do: nested >>> (&Quark.id/1)

  @spec flatten(Chain.t()) :: Chain.t()
  defalias flatten(nested), as: :join

  @doc """
  Compose link functions to create a new link function.

  Note that this runs the same direction as `<|>` ("the math way").

  This is `pipe_compose_link/2` with arguments flipped.

  ## Examples

      iex> links =
      ...>   fn x -> [x, x] end
      ...>   |> compose_link(fn y -> [y * 10] end)
      ...>   |> compose_link(fn z -> [z + 42] end)
      ...>
      ...> [1, 2, 3] >>> links
      [430, 430, 440, 440, 450, 450]

  """
  @spec compose_link(Chain.link(), Chain.link()) :: Chain.link()
  def compose_link(action_g, action_f), do: pipe_compose_link(action_f, action_g)

  @doc """
  Compose link functions to create a new link function.

  This is `compose_link/2` with arguments flipped.

  ## Examples

      iex> links =
      ...>   fn x -> [x, x] end
      ...>   |> pipe_compose_link(fn y -> [y * 10] end)
      ...>   |> pipe_compose_link(fn z -> [z + 42] end)
      ...>
      ...> [1, 2, 3] >>> links
      [52, 52, 62, 62, 72, 72]

  """
  @spec pipe_compose_link(Chain.link(), Chain.link()) :: Chain.link()
  def pipe_compose_link(action_f, action_g) do
    fn data -> action_f.(data) >>> action_g end
  end

  @doc """
  `do` notation sugar

  Sequences chainable actions. Note that each line must be of the same type.

  For a version with `return`, please see `Witchcraft.Monad.do/2`

  ## Examples

      iex> chain do
      ...>   [1]
      ...> end
      [1]

      iex> chain do
      ...>   [1, 2, 3]
      ...>   [4, 5, 6]
      ...>   [7, 8, 9]
      ...> end
      [
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9
      ]

      iex> chain do
      ...>   a <- [1, 2, 3]
      ...>   b <- [4, 5, 6]
      ...>   [a * b]
      ...> end
      [
        4,  5,  6,
        8,  10, 12,
        12, 15, 18
      ]

  Normal functions are fine within the `do` as well, as long as each line
  ends up being the same chainable type

      iex> import Witchcraft.{Functor, Applicative}
      ...> chain do
      ...>   map([1, 2, 3], fn x -> x + 1 end)
      ...>   of([], 42)
      ...>   [7, 8, 9] ~> fn x -> x * 10 end
      ...> end
      [
        70, 80, 90,
        70, 80, 90,
        70, 80, 90
      ]

  Or with a custom type

      alias Algae.Maybe.{Nothing, Just}

      chain do
        %Just{just: 4}
        %Just{just: 5}
        %Just{just: 6}
      end
      #=> %Just{just: 6}

      chain do
        %Just{just: 4}
        %Nothing{}
        %Just{just: 6}
      end
      #=> %Nothing{}

  ## `let` bindings

  `let`s allow you to hold static or intermediate values inside a
  do-block, much like normal assignment

      iex> chain do
      ...>   let a = 4
      ...>   [a]
      ...> end
      [4]

      iex> chain do
      ...>   a <- [1, 2]
      ...>   b <- [3, 4]
      ...>   let [h | _] = [a * b]
      ...>   [h, h, h]
      ...> end
      [3, 3, 3, 4, 4, 4, 6, 6, 6, 8, 8, 8]

  ## Desugaring

  ### Sequencing

  The most basic form

      chain do
        [1, 2, 3]
        [4, 5, 6]
        [7, 8, 9]
      end

  is equivalent to

      [1, 2, 3]
      |> then([4, 5, 6])
      |> then([7, 8, 9])

  ### `<-` ("drawn from")

  Drawing values from within a chainable structure is similar feels similar
  to assignmet, but it is pulling each value separately in a chain link function.

  For instance

      iex> chain do
      ...>   a <- [1, 2, 3]
      ...>   b <- [4, 5, 6]
      ...>   [a * b]
      ...> end
      [4, 5, 6, 8, 10, 12, 12, 15, 18]

  desugars to this

      iex> [1, 2, 3] >>> fn a ->
      ...>   [4, 5, 6] >>> fn b ->
      ...>     [a * b]
      ...>   end
      ...> end
      [4, 5, 6, 8, 10, 12, 12, 15, 18]

  but is often much cleaner to read in do-notation, as it cleans up all of the
  nested functions (especially when the chain is very long).

  You can also use values recursively:

      # iex> chain do
      # ...>   a <- [1, 2, 3]
      # ...>   b <- [a, a * 10, a * 100]
      # ...>   [a + 1, b + 1]
      # ...> end
      # [
      #   2, 2, 2, 11, 2, 101,
      #   3, 3, 3, 21, 3, 201,
      #   4, 4, 4, 31, 4, 301
      # ]

  """
  defmacro chain(do: input) do
    Witchcraft.Chain.do_notation(input, &Witchcraft.Chain.chain/2)
  end

  @doc false
  # credo:disable-for-lines:31 Credo.Check.Refactor.Nesting
  def do_notation(input, chainer) do
    input
    |> normalize()
    |> Enum.reverse()
    |> Witchcraft.Foldable.left_fold(fn
      continue, {:let, _, [{:=, _, [assign, value]}]} ->
        quote do: unquote(value) |> (fn unquote(assign) -> unquote(continue) end).()

      continue, {:<-, _, [assign, value]} ->
        quote do
          import Witchcraft.Chain, only: [>>>: 2]

          unquote(value) >>> fn unquote(assign) -> unquote(continue) end
        end

      continue, value ->
        quote do
          import Witchcraft.Chain, only: [>>>: 2]
          unquote(value) >>> fn _ -> unquote(continue) end
        end
    end)
  end

  @doc false
  def normalize({:__block__, _, inner}), do: inner
  def normalize(single) when is_list(single), do: [single]
  def normalize(plain), do: List.wrap(plain)

  properties do
    def associativity(data) do
      a = generate(data)
      f = fn x -> Witchcraft.Applicative.of(a, inspect(x)) end
      g = fn y -> Witchcraft.Applicative.of(a, y <> y) end

      left = a |> Chain.chain(f) |> Chain.chain(g)
      right = a |> Chain.chain(fn x -> x |> f.() |> Chain.chain(g) end)

      equal?(left, right)
    end
  end
end

definst Witchcraft.Chain, for: Function do
  alias Witchcraft.Chain
  use Quark

  @spec chain(Chain.t(), (any() -> any())) :: Chain.t()
  def chain(fun, chain_fun), do: fn r -> curry(chain_fun).(fun.(r)).(r) end
end

definst Witchcraft.Chain, for: List do
  use Quark
  def chain(list, chain_fun), do: Enum.flat_map(list, curry(chain_fun))
end

definst Witchcraft.Chain, for: Tuple do
  use Witchcraft.Semigroup

  custom_generator(_) do
    import TypeClass.Property.Generator, only: [generate: 1]
    seed = fn -> Enum.random([0, 1.1, "", []]) end
    {generate(seed.()), generate(seed.())}
  end

  def chain({a, b}, chain_fun) do
    {c, d} = chain_fun.(b)
    {a <> c, d}
  end
end
