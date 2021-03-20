import TypeClass

defclass Witchcraft.Ord do
  @moduledoc ~S"""
  `Ord` describes how to order elements of a data type.

  This is a total order, so all elements are either `:equal`, `:greater`, or `:lesser`
  than each other.

  ## Type Class

  An instance of `Witchcraft.Ord` must also implement `Witchcraft.Setoid`,
  and define `Witchcraft.Ord.compare/2`.

      Setoid  [equivalent?/2]
        ↓
       Ord    [compare/2]
  """

  extend Witchcraft.Setoid

  @type t :: any()
  @type ordering :: :lesser | :equal | :greater

  alias __MODULE__
  import Kernel, except: [<: 2, >: 2, <=: 2, >=: 2]

  defmacro __using__(opts \\ []) do
    overrides = [<: 2, >: 2, <=: 2, >=: 2]
    excepts = Keyword.get(opts, :except, [])

    if Access.get(opts, :override_kernel, true) do
      kernel_imports = Macro.escape(except: overrides -- excepts)
      module_imports = Macro.escape(except: excepts)

      quote do
        import Kernel, unquote(kernel_imports)
        use Witchcraft.Semigroupoid, unquote(opts)
        import unquote(__MODULE__), unquote(module_imports)
      end
    else
      module_imports = Macro.escape(except: Enum.uniq(overrides ++ excepts))

      quote do
        use Witchcraft.Semigroupoid, unquote(opts)
        import unquote(__MODULE__), unquote(module_imports)
      end
    end
  end

  where do
    @doc """
    Get the ordering relationship between two elements.

    Possible results are `:lesser`, `:equal`, and `:greater`

    ## Examples

        iex> compare(1, 1)
        :equal

        iex> compare([1], [2])
        :lesser

        iex> compare([1, 2], [3])
        :lesser

        iex> compare([3, 2, 1], [1, 2, 3, 4, 5])
        :greater

    """
    @spec compare(Ord.t(), Ord.t()) :: Ord.ordering()
    def compare(ord_a, ord_b)
  end

  properties do
    def reflexivity(data) do
      a = generate(data)
      comparison = Ord.compare(a, a)
      equal?(comparison, :equal) or equal?(comparison, :lesser)
    end

    def transitivity(data) do
      x = generate(data)
      y = generate(data)
      z = generate(data)

      x_y = Ord.compare(x, y)
      y_z = Ord.compare(y, z)
      x_z = Ord.compare(x, z)

      if x_y != :greater and y_z != :greater do
        equal?(x_z, :lesser) or equal?(x_z, :equal)
      else
        true
      end
    end

    def antisymmetry(data) do
      a = generate(data)
      b = generate(data)

      a_b = Ord.compare(a, b)
      b_a = Ord.compare(b, a)

      if a_b != :greater and b_a != :greater, do: a_b == :equal, else: true
    end
  end

  @doc """
  Determine if two elements are `:equal`.

  ## Examples

      iex> equal?(1, 1.0)
      true

      iex> equal?(1, 2)
      false

  """
  @spec equal?(Ord.t(), Ord.t()) :: boolean()
  def equal?(a, b), do: compare(a, b) == :equal

  @doc """
  Determine if an element is `:greater` than another.

  ## Examples

      iex> greater?(1, 1)
      false

      iex> greater?(1.1, 1)
      true

  """
  @spec greater?(Ord.t(), Ord.t()) :: boolean()
  def greater?(a, b), do: compare(a, b) == :greater

  defalias a > b, as: :greater?

  @doc """
  Determine if an element is `:lesser` than another.

  ## Examples

      iex> lesser?(1, 1)
      false

      iex> lesser?(1, 1.1)
      true

  """
  @spec lesser?(Ord.t(), Ord.t()) :: boolean()
  def lesser?(a, b), do: compare(a, b) == :lesser

  defalias a < b, as: :lesser?

  @doc """
  Determine if an element is `:lesser` or `:equal` to another.

  ## Examples

      iex> use Witchcraft.Ord
      ...> 1 <= 2
      true
      ...> [] <= [1, 2, 3]
      false
      ...> [1] <= [1, 2, 3]
      true
      ...> [4] <= [1, 2, 3]
      false

  """
  # credo:disable-for-next-line Credo.Check.Warning.OperationOnSameValues
  @spec Ord.t() <= Ord.t() :: boolean()
  def a <= b, do: compare(a, b) != :greater

  @doc """
  Determine if an element is `:greater` or `:equal` to another.

  ## Examples

      iex> use Witchcraft.Ord
      ...> 2 >= 1
      true
      ...> [1, 2, 3] >= []
      true
      ...> [1, 2, 3] >= [1]
      true
      ...> [1, 2, 3] >= [4]
      false

  """
  # credo:disable-for-next-line Credo.Check.Warning.OperationOnSameValues
  @spec Ord.t() >= Ord.t() :: boolean()
  def a >= b, do: compare(a, b) != :lesser
end
