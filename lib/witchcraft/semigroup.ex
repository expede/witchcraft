import TypeClass

defclass Witchcraft.Semigroup do
  @moduledoc ~S"""
  A semigroup is a structure describing data that can be appendenated with others of its type.
  That is to say that appending another list returns a list, appending one map
  to another returns a map, and appending two integers returns an integer, and so on.

  These can be chained together an arbitrary number of times. For example:

      1 <> 2 <> 3 <> 5 <> 7 == 18
      [1, 2, 3] <> [4, 5, 6] <> [7, 8, 9] == [1, 2, 3, 4, 5, 6, 7, 8, 9]
      "foo" <> " " <> "bar" == "foo bar"

  This generalizes the idea of a monoid, as it does not require an `empty` version.

  ## Type Class

  An instance of `Witchcraft.Semigroup` must define `Witchcraft.Semigroup.append/2`.

      Semigroup  [append/2]
  """

  alias __MODULE__
  import Kernel, except: [<>: 2]

  @type t :: any()

  defmacro __using__(opts \\ []) do
    overrides = [<>: 2]
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
    @doc ~S"""
    `append`enate two data of the same type. These can be chained together an arbitrary number of times. For example:

        iex> 1 |> append(2) |> append(3)
        6

        iex> [1, 2, 3]
        ...> |> append([4, 5, 6])
        ...> |> append([7, 8, 9])
        [1, 2, 3, 4, 5, 6, 7, 8, 9]

        iex> "foo" |> append(" ") |> append("bar")
        "foo bar"

    ## Operator

        iex> use Witchcraft.Semigroup
        ...> 1 <> 2 <> 3 <> 5 <> 7
        18

        iex> use Witchcraft.Semigroup
        ...> [1, 2, 3] <> [4, 5, 6] <> [7, 8, 9]
        [1, 2, 3, 4, 5, 6, 7, 8, 9]

        iex> use Witchcraft.Semigroup
        ...> "foo" <> " " <> "bar"
        "foo bar"

    There is an operator alias `a <> b`. Since this conflicts with `Kernel.<>/2`,
    `use Witchcraft,Semigroup` will automatically exclude the Kernel operator.
    This is highly recommended, since `<>` behaves the same on bitstrings, but is
    now available on more datatypes.

    """
    def append(a, b)
  end

  defalias a <> b, as: :append

  @doc ~S"""
  Flatten a list of homogeneous semigroups to a single container.

  ## Example

      iex> concat [
      ...>   [1, 2, 3],
      ...>   [4, 5, 6]
      ...> ]
      [1, 2, 3, 4, 5, 6]

  """
  @spec concat(Semigroup.t()) :: [Semigroup.t()]
  def concat(semigroup_of_lists) do
    Enum.reduce(semigroup_of_lists, [], &Semigroup.append(&2, &1))
  end

  @doc ~S"""
  Repeat the contents of a semigroup a certain number of times.

  ## Examples

      iex> [1, 2, 3] |> repeat(times: 3)
      [1, 2, 3, 1, 2, 3, 1, 2, 3]

  """
  @spec repeat(Semigroup.t(), times: non_neg_integer()) :: Semigroup.t()
  # credo:disable-for-lines:6 Credo.Check.Refactor.PipeChainStart
  def repeat(to_repeat, times: times) do
    fn -> to_repeat end
    |> Stream.repeatedly()
    |> Stream.take(times)
    |> Enum.reduce(&Semigroup.append(&2, &1))
  end

  properties do
    def associative(data) do
      a = generate(data)
      b = generate(data)
      c = generate(data)

      left = a |> Semigroup.append(b) |> Semigroup.append(c)
      right = Semigroup.append(a, Semigroup.append(b, c))

      equal?(left, right)
    end
  end
end

definst Witchcraft.Semigroup, for: Function do
  def append(f, g) when is_function(g), do: Quark.compose(g, f)
end

definst Witchcraft.Semigroup, for: Witchcraft.Unit do
  def append(_, _), do: %Witchcraft.Unit{}
end

definst Witchcraft.Semigroup, for: Integer do
  def append(a, b), do: a + b
end

definst Witchcraft.Semigroup, for: Float do
  def append(a, b), do: a + b
end

definst Witchcraft.Semigroup, for: BitString do
  def append(a, b), do: Kernel.<>(a, b)
end

definst Witchcraft.Semigroup, for: List do
  def append(a, b), do: a ++ b
end

definst Witchcraft.Semigroup, for: Map do
  def append(a, b), do: Map.merge(a, b)
end

definst Witchcraft.Semigroup, for: MapSet do
  def append(a, b), do: MapSet.union(a, b)
end

definst Witchcraft.Semigroup, for: Tuple do
  # credo:disable-for-lines:5 Credo.Check.Refactor.PipeChainStart
  custom_generator(_) do
    Stream.repeatedly(fn -> TypeClass.Property.Generator.generate(%{}) end)
    |> Enum.take(10)
    |> List.to_tuple()
  end

  def append(tuple_a, tuple_b) do
    tuple_a
    |> Tuple.to_list()
    |> Enum.zip(Tuple.to_list(tuple_b))
    |> Enum.map(fn {x, y} -> Witchcraft.Semigroup.append(x, y) end)
    |> List.to_tuple()
  end
end
