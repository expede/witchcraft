import TypeClass

defclass Witchcraft.Monoid do
  @moduledoc ~S"""
  Monoid extends the semigroup with the concept of an "empty" or "zero" element.

  ## Type Class

  An instance of `Witchcraft.Monoid` must also implement `Witchcraft.Semigroup`,
  and define `Witchcraft.Monoid.empty/1`.

      Semigroup  [append/2]
          ↓
       Monoid    [empty/1]
  """

  alias __MODULE__
  extend Witchcraft.Semigroup, alias: true

  @type t :: any()

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Semigroup, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc ~S"""
    An "emptied out" or "starting position" of the passed data.

    ## Example

        iex> empty(10)
        0

        iex> empty [1, 2, 3, 4, 5]
        []

    """
    def empty(sample)
  end

  defalias zero(sample), as: :empty

  @doc """
  Check if a value is the empty element of that type.

  ## Examples

      iex> empty?([])
      true

      iex> empty?([1])
      false

  """
  @spec empty?(Monoid.t()) :: boolean
  def empty?(monoid), do: empty(monoid) == monoid

  properties do
    def left_identity(data) do
      a = generate(data)

      if is_function(a) do
        equal?(Semigroup.append(Monoid.empty(a), a).("foo"), a.("foo"))
      else
        equal?(Semigroup.append(Monoid.empty(a), a), a)
      end
    end

    def right_identity(data) do
      a = generate(data)

      if is_function(a) do
        Semigroup.append(a, Monoid.empty(a)).("foo") == a.("foo")
      else
        Semigroup.append(a, Monoid.empty(a)) == a
      end
    end
  end
end

definst Witchcraft.Monoid, for: Function do
  def empty(sample) when is_function(sample), do: &Quark.id/1
end

definst Witchcraft.Monoid, for: Integer do
  def empty(_), do: 0
end

definst Witchcraft.Monoid, for: Float do
  def empty(_), do: 0.0
end

definst Witchcraft.Monoid, for: BitString do
  def empty(_), do: ""
end

definst Witchcraft.Monoid, for: List do
  def empty(_), do: []
end

definst Witchcraft.Monoid, for: Map do
  def empty(_), do: %{}
end

definst Witchcraft.Monoid, for: Tuple do
  custom_generator(_) do
    {}
  end

  def empty(sample), do: Witchcraft.Functor.map(sample, &Witchcraft.Monoid.empty/1)
end

definst Witchcraft.Monoid, for: MapSet do
  def empty(_), do: MapSet.new()
end

definst Witchcraft.Monoid, for: Witchcraft.Unit do
  require Witchcraft.Semigroup
  def empty(_), do: %Witchcraft.Unit{}
end
