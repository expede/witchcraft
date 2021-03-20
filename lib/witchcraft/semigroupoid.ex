import TypeClass

defclass Witchcraft.Semigroupoid do
  @moduledoc """
  A semigroupoid describes some way of composing morphisms on between some
  collection of objects.

  ## Type Class

  An instance of `Witchcraft.Semigroupoid` must define `Witchcraft.Semigroupoid.compose/2`.

      Semigroupoid  [compose/2]
  """

  alias __MODULE__
  import Kernel, except: [apply: 2]

  @type t :: any()

  defmacro __using__(opts \\ []) do
    overrides = [apply: 2]
    excepts = Keyword.get(opts, :except, [])

    if Access.get(opts, :override_kernel, true) do
      kernel_imports = Macro.escape(except: overrides -- excepts)
      module_imports = Macro.escape(except: excepts)

      quote do
        import Kernel, unquote(kernel_imports)
        import unquote(__MODULE__), unquote(module_imports)
      end
    else
      module_imports = Macro.escape(except: Enum.uniq(overrides ++ excepts))

      quote do
        import unquote(__MODULE__), unquote(module_imports)
      end
    end
  end

  where do
    @doc """
    Take two morphisms and return their composition "the math way".
    That is, `(b -> c) -> (a -> b) -> (a -> c)`.

    ## Examples

        iex> times_ten_plus_one = compose(fn x -> x + 1 end, fn y -> y * 10 end)
        ...> times_ten_plus_one.(5)
        51

    """
    @spec compose(Semigroupoid.t(), Semigroupoid.t()) :: Semigroupoid.t()
    def compose(morphism_a, morphism_b)

    @doc """
    Express how to apply arguments to the _very end_ of a semigroupoid,
    or "run the morphism". This should not be used to inject values part way
    though a composition chain.

    It is provided here to remain idiomatic with Elixir, and to make
    prop testing _possible_.

    ## Examples

        iex> Witchcraft.Semigroupoid.apply(&inspect/1, [42])
        "42"

    """
    @spec apply(Semigroupoid.t(), [any()]) :: Semigroupoid.t() | any()
    def apply(morphism, arguments)
  end

  @doc """
  Pipe some data through a morphism.

  Similar to `apply/2`, but with a single argument, not needing to wrap
  the argument in a list.

  ## Examples

      iex> pipe(42, &(&1 + 1))
      43

  """
  @spec pipe(any(), Semigroupoid.t()) :: any()
  def pipe(data, fun), do: apply(fun, [data])

  @doc """
  `compose/2`, but with the arguments flipped (same direction as `|>`).

  ## Examples

      iex> times_ten_plus_one = pipe_compose(fn y -> y * 10 end, fn x -> x + 1 end)
      ...> times_ten_plus_one.(5)
      51

  """
  @spec pipe_compose(t(), t()) :: t()
  def pipe_compose(b, a), do: compose(a, b)

  @doc """
  Composition operator "the math way". Alias for `compose/2`.

  ## Examples

      iex> times_ten_plus_one =
      ...>       fn x -> x + 1  end
      ...>   <|> fn y -> y * 10 end
      ...>
      ...> times_ten_plus_one.(5)
      51

  """
  @spec t() <|> any() :: t()
  def g <|> f, do: compose(g, f)

  @doc """
  Composition operator "the pipe way". Alias for `pipe_compose/2`.

  ## Examples

      iex> times_ten_plus_one =
      ...>       fn y -> y * 10 end
      ...>   <~> fn x -> x + 1  end
      ...>
      ...> times_ten_plus_one.(5)
      51

  """
  @spec t() <~> any() :: t()
  def f <~> g, do: compose(g, f)

  properties do
    def associativity(data) do
      a = generate(data)
      b = generate(data)
      c = generate(data)

      left = Semigroupoid.compose(Semigroupoid.compose(a, b), c)
      right = Semigroupoid.compose(a, Semigroupoid.compose(b, c))

      equal?(left, right)
    end
  end
end

definst Witchcraft.Semigroupoid, for: Function do
  def apply(fun, args), do: Kernel.apply(fun, args)
  def compose(fun_a, fun_b), do: Quark.compose(fun_a, fun_b)
end
