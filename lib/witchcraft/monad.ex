import TypeClass

defclass Witchcraft.Monad do
  @moduledoc """
  Very similar to `Chain`, `Monad` provides a way to link actions, and a way
  to bring plain values into the correct context (`Applicative`).

  This allows us to view actions in a full framework along the lines of
  functor and applicative:

                 data ---------------- function ----------------------------> result
                   |                      |                                     |
       of(Container, data)          of/2, or similar                of(Container, result)
                   ↓                      ↓                                     ↓
      %Container<data> --- (data -> %Container<updated_data>) ---> %Container<updated_data>

  As you can see, the linking function may just be `of` now that we have that.

  For a nice, illustrated introduction,
  see [Functors, Applicatives, And Monads In Pictures](http://adit.io/posts/2013-04-17-functors,_applicatives,_and_monads_in_pictures.html).

  Having `of` also lets us enhance do-notation with a convenuenct `return` function (see `monad/2`)

  ## Type Class

  An instance of `Witchcraft.Monad` must also implement `Witchcraft.Applicative`
  and `Wicthcraft.Chainable`.

                       Functor     [map/2]
                          ↓
                        Apply      [convey/2]
                        ↓   ↓
      [of/2]  Applicative   Chain  [chain/2]
                        ↓   ↓
                        Monad
                         [_]
  """

  extend Witchcraft.Applicative
  extend Witchcraft.Chain

  use Witchcraft.Applicative
  use Witchcraft.Chain

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Applicative, unquote(opts)
      use Witchcraft.Chain, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  properties do
    import Witchcraft.Applicative
    import Witchcraft.Chain

    def left_identity(data) do
      a = generate(data)
      f = &Witchcraft.Functor.replace(a, inspect(&1))

      left = a |> of(a) |> chain(f)
      right = f.(a)

      equal?(left, right)
    end

    def right_identity(data) do
      a = generate(data)
      left = a >>> (&of(a, &1))

      equal?(a, left)
    end
  end

  @doc """
  Asynchronous variant of `Witchcraft.Chain.chain/2`.

  Note that _each_ `async_chain` call awaits that step's completion. This is a
  feature not a bug, since `chain` can introduce dependencies between nested links.
  However, this means that the async features on only really useful on larger data sets,
  because otherwise we're just sparking tasks and immediaetly waiting a single application.

  ## Examples

      iex> async_chain([1, 2, 3], fn x -> [x, x] end)
      [1, 1, 2, 2, 3, 3]

      iex> async_chain([1, 2, 3], fn x ->
      ...>   async_chain([x + 1], fn y ->
      ...>     [x * y]
      ...>   end)
      ...> end)
      [2, 6, 12]

      0..10_000
      |> Enum.to_list()
      |> async_chain(fn x ->
        async_chain([x + 1], fn y ->
          Process.sleep(500)
          [x * y]
        end)
      end)
      #=> [0, 2, 6, 12, 20, 30, 42, ...] in around a second

  """
  @spec async_chain(Chain.t(), Chain.link()) :: Chain.t()
  def async_chain(chainable, link) do
    chainable
    |> chain(fn x ->
      # credo:disable-for-lines:3 Credo.Check.Refactor.PipeChainStart
      fn -> link.(x) end
      |> Task.async()
      |> to(chainable)
    end)
    |> chain(&Task.await/1)
  end

  @doc "Alias for `async_chain/2`"
  @spec async_chain(Chain.t(), Chain.link()) :: Chain.t()
  def async_bind(chainable, link), do: async_chain(chainable, link)

  @doc """
  Asynchronous variant of `Witchcraft.Chain.draw/2`.

  Note that _each_ `async_draw` call awaits that step's completion. This is a
  feature not a bug, since `chain` can introduce dependencies between nested links.
  However, this means that the async features on only really useful on larger data sets,
  because otherwise we're just sparking tasks and immediaetly waiting a single application.

  ## Examples

      iex> async_draw(fn x -> [x, x] end, [1, 2, 3])
      [1, 1, 2, 2, 3, 3]

      iex> (fn y -> [y * 5, y * 10] end)
      ...> |> async_draw(fn x -> [x, x] end
      ...> |> async_draw([1, 2, 3])) # note the "extra" closing paren
      [5, 10, 5, 10, 10, 20, 10, 20, 15, 30, 15, 30]

      iex> fn x ->
      ...>   fn y ->
      ...>     [x * y]
      ...>   end
      ...>   |> async_draw([x + 1])
      ...> end
      ...> |> async_draw([1, 2, 3])
      [2, 6, 12]

      fn x ->
        fn y ->
          Process.sleep(500)
          [x * y]
        end
        |> async_draw([x + 1])
      end
      |> async_draw(Enum.to_list(0..10_000))
      [0, 2, 6, 12, ...] # in under a second

  """
  @spec async_draw(Chain.t(), Chain.link()) :: Chain.t()
  def async_draw(link, chainable), do: async_chain(chainable, link)

  @doc ~S"""
  do-notation enhanced with a `return` operation.

  `return` is the simplest possible linking function, providing the correct `of/2`
  instance for your monad.

  ## Examples

      iex> monad [] do
      ...>   [1, 2, 3]
      ...> end
      [1, 2, 3]

      iex> monad [] do
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

      iex> monad [] do
      ...>   Witchcraft.Applicative.of([], 1)
      ...> end
      [1]

      iex> monad [] do
      ...>   return 1
      ...> end
      [1]

      iex> monad [] do
      ...>   monad {999} do
      ...>     return 1
      ...>   end
      ...> end
      {1}

      iex> monad [] do
      ...>  a <- [1,2,3]
      ...>  b <- [4,5,6]
      ...>  return(a * b)
      ...> end
      [
        4,  5,  6,
        8,  10, 12,
        12, 15, 18
      ]

      iex> monad [] do
      ...>   a <- return 1
      ...>   b <- return 2
      ...>   return(a + b)
      ...> end
      [3]

  """
  defmacro monad(sample, do: input) do
    returnized = desugar_return(input, sample)
    Witchcraft.Chain.do_notation(returnized, &Witchcraft.Chain.chain/2)
  end

  @doc ~S"""
  Variant of `monad/2` where each step internally occurs asynchonously, but lines
  run strictly one after another.

  ## Examples

      iex> async [] do
      ...>   [1, 2, 3]
      ...> end
      [1, 2, 3]

      iex> async [] do
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

      iex> async [] do
      ...>   Witchcraft.Applicative.of([], 1)
      ...> end
      [1]

      iex> async [] do
      ...>  a <- [1,2,3]
      ...>  b <- [4,5,6]
      ...>  return(a * b)
      ...> end
      [
        4,  5,  6,
        8,  10, 12,
        12, 15, 18
      ]

      iex> async [] do
      ...>   a <- return 1
      ...>   b <- return 2
      ...>   return(a + b)
      ...> end
      [3]

  """
  defmacro async(sample, do: input) do
    returnized = desugar_return(input, sample)
    Witchcraft.Chain.do_notation(returnized, &Witchcraft.Monad.async_bind/2)
  end

  @doc false
  # Convert `return`s to `of`s in the correct monadic context
  def desugar_return(ast, sample) do
    ast
    |> Macro.prewalk(fn
      {:monad = f, ctx, [inner_sample, inner_ast]} ->
        {f, ctx, [inner_sample, desugar_return(inner_ast, inner_sample)]}

      {{:., _, [_aliases, :monad]} = f, ctx, [inner_sample, inner_ast]} ->
        {f, ctx, [inner_sample, desugar_return(inner_ast, inner_sample)]}

      {:return, _ctx, [inner]} ->
        quote do: Witchcraft.Applicative.of(unquote(sample), unquote(inner))

      ast ->
        ast
    end)
  end
end

definst Witchcraft.Monad, for: Function
definst Witchcraft.Monad, for: List

definst Witchcraft.Monad, for: Tuple do
  use Witchcraft.Semigroup
  import TypeClass.Property.Generator, only: [generate: 1]

  custom_generator(_) do
    {generate(""), generate("")}
  end
end
